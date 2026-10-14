---@class Showcase : OxClass
local Showcase = lib.class('Showcase')

local cfg <const> = lib.load('data.sickness').showcase
local Sicknesses <const> = lib.load('data.sicknesses')

---@param sickness Sickness
---@param effects Effects
function Showcase:constructor(sickness, effects)
    self.sickness = sickness
    self.effects = effects
    self.token = 0
end

---@param id? string
---@return { sickness: table, stage: table }[]
local function buildSteps(id)
    local steps = {}

    for _, sickness in ipairs(Sicknesses) do
        if not id or sickness.id == id then
            local stages = { table.unpack(sickness.stages) }
            table.sort(stages, function(a, b) return a.threshold < b.threshold end)

            for _, stage in ipairs(stages) do
                steps[#steps + 1] = { sickness = sickness, stage = stage }
            end
        end
    end

    return steps
end

---@param description string
---@param type? string
local function notify(description, type)
    lib.notify({ title = locale('showcase.title'), description = description, type = type or 'inform', icon = 'vial' })
end

---@param stage table
---@param token integer
---@return boolean alive
function Showcase:hold(stage, token)
    local deadline = GetGameTimer() + cfg.stageDuration
    local nextCough = 0

    while GetGameTimer() < deadline do
        if self.token ~= token then return false end

        if stage.cough and GetGameTimer() >= nextCough then
            self.effects:cough(stage.cough.anim)
            nextCough = GetGameTimer() + cfg.coughInterval
        end

        Wait(100)
    end

    return true
end

---@param id? string one sickness, or all of them
function Showcase:start(id)
    if self.running then return false end

    local steps = buildSteps(id)
    if #steps == 0 then return notify(locale('showcase.unknown', id), 'error') end

    self.running = true
    self.token = self.token + 1
    self.saved = self.sickness:getState()
    self.health = GetEntityHealth(cache.ped)
    self.sickness.paused = true

    local token = self.token

    CreateThread(function()
        for index, step in ipairs(steps) do
            self.sickness:infect(step.sickness.id, step.stage.threshold)
            notify(locale('showcase.step', index, #steps, step.sickness.label, step.stage.id))

            if not self:hold(step.stage, token) then return end
        end

        self:stop(locale('showcase.complete'))
    end)

    return true
end

---@param message? string
---@return boolean
function Showcase:stop(message)
    if not self.running then return false end

    self.running = false
    self.token = self.token + 1

    self.sickness:cure(100, 0)
    self.sickness:restore(self.saved)
    self.sickness.paused = false

    if cfg.restoreHealth and not IsEntityDead(cache.ped) and GetEntityHealth(cache.ped) < self.health then
        SetEntityHealth(cache.ped, self.health)
    end

    notify(message or locale('showcase.stopped'))

    return true
end

return Showcase
