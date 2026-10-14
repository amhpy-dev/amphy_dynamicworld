---@class Effects : OxClass
local Effects = lib.class('Effects')

local cfg <const> = lib.load('data.effects')
local SPRINT_CONTROL <const> = 21

function Effects:constructor()
    self.nextCough = 0

    lib.onCache('ped', function(ped)
        if not self.stage then return end

        local clipset = self.clipset
        self.clipset = nil
        self:setClipset(clipset, ped)
    end)

    CreateThread(function() self:upkeep() end)
    CreateThread(function() self:limitSprint() end)
end

---@param sickness table?
---@param stage table?
function Effects:apply(sickness, stage)
    self.sickness, self.stage = sickness, stage

    self:setClipset(stage and stage.movement)
    self:setTimecycle(stage and (stage.greyscale and cfg.greyscale or stage.timecycle))
    self:setShake(stage and stage.shake)
    SetRunSprintMultiplierForPlayer(cache.playerId, stage and stage.sprintSpeed or 1.0)
    self:scheduleCough(true)
end

function Effects:clear()
    self:apply()
end

---@param clipset? string
---@param ped? number
function Effects:setClipset(clipset, ped)
    if clipset == self.clipset then return end

    self.clipset = clipset
    ped = ped or cache.ped

    if not clipset then return ResetPedMovementClipset(ped, 0.25) end

    CreateThread(function()
        if pcall(lib.requestAnimSet, clipset) and self.clipset == clipset then
            SetPedMovementClipset(ped, clipset, 0.5)
        end
    end)
end

---@param timecycle? { name: string, strength?: number }
function Effects:setTimecycle(timecycle)
    local name = timecycle and timecycle.name

    if name ~= self.timecycle then
        ClearTimecycleModifier()
        if name then SetTimecycleModifier(name) end
        self.timecycle = name
    end

    if name then SetTimecycleModifierStrength(timecycle.strength or 1.0) end
end

---@param shake? { name: string, amplitude?: number }
function Effects:setShake(shake)
    if self.shake and (not shake or shake.name ~= self.shake.name) then
        StopGameplayCamShaking(true)
    end

    self.shake = shake
    if shake then ShakeGameplayCam(shake.name, shake.amplitude or 0.1) end
end

--------------------------------------------------------------------------------
-- Coughing
--------------------------------------------------------------------------------

---@param soon? boolean pick from the first half of the interval
function Effects:scheduleCough(soon)
    local cough = self.stage and self.stage.cough

    if not cough then
        self.nextCough = 0
        return
    end

    self.nextCough = GetGameTimer() + math.random(soon and cough.min // 2 or cough.min, cough.max)
end

---@param pain? integer eAudDamageReason
function Effects:playVocal(pain)
    if not pain then return end

    if cfg.painSyncsOverNetwork then
        ---@diagnostic disable-next-line: redundant-parameter
        PlayPain(cache.ped, pain, cfg.painDamage, true)
    else
        PlayPain(cache.ped, pain, cfg.painDamage)
    end
end

---@return boolean
---@return string? reason
function Effects:canCough()
    local ped = cache.ped

    if self.coughing then return false, 'already coughing' end

    if IsPedDeadOrDying(ped, true) or IsPedRagdoll(ped) or IsPedFalling(ped)
        or IsPedJumping(ped) or IsPedSwimmingUnderWater(ped) then
        return false, 'not able to right now'
    end

    return true
end

---@param name? string animation key from data/effects.lua
---@return boolean played, string? reason
function Effects:cough(name)
    name = name or 'cough_light'

    local anim = cfg.animations[name]
    if not anim then return false, ('no animation named "%s"'):format(name) end

    local ok, reason = self:canCough()
    if not ok then return false, reason end

    self.coughing = true

    CreateThread(function()
        local loaded = pcall(lib.requestAnimDict, anim.dict)

        if loaded then
            TaskPlayAnim(cache.ped, anim.dict, anim.clip, 8.0, -1.0, anim.duration, 48, 0.0, false, false, false)
        end

        self:playVocal(anim.pain)
        Wait(anim.duration)
        self:playVocal(anim.painAfter)
        Wait(1000)

        if loaded then RemoveAnimDict(anim.dict) end
        self.coughing = false
    end)

    return true
end

--------------------------------------------------------------------------------
-- Loops
--------------------------------------------------------------------------------

function Effects:upkeep()
    while true do
        local stage = self.stage

        if stage then
            local now = GetGameTimer()

            if self.nextCough > 0 and now >= self.nextCough then
                local skipped = math.random() > (stage.cough.chance or 1.0)

                if skipped or self:cough(stage.cough.anim) then
                    self:scheduleCough()
                else
                    self.nextCough = now + 2000
                end
            end

            if self.shake and not IsGameplayCamShaking() then
                ShakeGameplayCam(self.shake.name, self.shake.amplitude or 0.1)
            end

            if stage.healthDrain then
                local health = GetEntityHealth(cache.ped)

                if health > cfg.minHealth then
                    SetEntityHealth(cache.ped, math.max(cfg.minHealth, health - stage.healthDrain))
                end
            end
        end

        Wait(1000)
    end
end

--- GTA has no stamina native, so a stage's sprintStamina blocks the sprint key
--- after a shorter run.
function Effects:limitSprint()
    local sprint = cfg.sprint
    local since, blockedUntil = 0, 0

    while true do
        local stamina = self.stage and self.stage.sprintStamina or 1.0

        if stamina >= 1.0 then
            since = 0
            Wait(500)
        else
            local now = GetGameTimer()

            if now < blockedUntil then
                DisableControlAction(0, SPRINT_CONTROL, true)
            elseif IsPedSprinting(cache.ped) then
                if since == 0 then
                    since = now
                elseif now - since >= sprint.duration * stamina then
                    since, blockedUntil = 0, now + sprint.recovery
                    self:playVocal(sprint.pain)
                end
            else
                since = 0
            end

            Wait(0)
        end
    end
end

return Effects
