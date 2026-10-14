---@class Cures : OxClass
local Cures = lib.class('Cures')

local Items <const> = lib.load('data.cures')
local ORIGIN <const> = vec3(0.0, 0.0, 0.0)

---@param sickness Sickness
function Cures:constructor(sickness)
    self.sickness = sickness
    self.cooldowns = {}
end

---@param name string
---@return string
local function itemLabel(name)
    local item = GetResourceState('ox_inventory') == 'started' and exports.ox_inventory:Items(name)
    return item and item.label or name
end

---@param cure table
---@return boolean
function Cures:treats(cure)
    local current = self.sickness.sickness
    return current and (cure.cures == 'all' or lib.table.contains(cure.cures, current.id))
end

---@param cure table
---@return boolean completed
function Cures:progress(cure)
    local prop = cure.prop

    return lib.progressBar({
        duration = cure.useTime or 5000,
        label = cure.label or 'Using...',
        canCancel = true,
        disable = cure.disable or { car = true, combat = true },
        anim = cure.anim and { dict = cure.anim.dict, clip = cure.anim.clip, flag = cure.anim.flag or 49 },
        prop = prop and { model = prop.model, bone = prop.bone, pos = prop.pos or ORIGIN, rot = prop.rot or ORIGIN },
    })
end

--- Play the progress bar and, if it completes, treat the player.
---@param name string item name
---@param consume? fun(): boolean takes the item, false to stop the cure
---@return table result { success, cured?, reason }
function Cures:use(name, consume)
    local cure = Items[name]
    if not cure then return { success = false, reason = 'unknown_item' } end
    if self.busy then return { success = false, reason = 'busy' } end

    if (self.cooldowns[name] or 0) > GetGameTimer() then
        lib.notify({ description = locale('cures.cooldown', itemLabel(name)), type = 'error' })
        return { success = false, reason = 'cooldown' }
    end

    self.busy = true
    local completed = self:progress(cure)
    self.busy = false

    if not completed then return { success = false, reason = 'cancelled' } end
    if consume and not consume() then return { success = false, reason = 'not_consumed' } end

    self.cooldowns[name] = GetGameTimer() + (cure.cooldown or 0) * 1000

    if cure.health then
        SetEntityHealth(cache.ped, math.min(GetEntityMaxHealth(cache.ped), GetEntityHealth(cache.ped) + cure.health))
    end

    if cure.removeExposure then self.sickness:removeExposure(cure.removeExposure) end

    local result

    if self:treats(cure) then
        local sicknessId = self.sickness.sickness.id
        local cured = self.sickness:cure(cure.removeSeverity or 100, cure.immunity)

        lib.notify({
            title = itemLabel(name),
            description = locale(cured and 'cures.cured' or 'cures.better'),
            type = 'success',
            icon = 'pills',
        })

        result = { success = true, cured = cured, sickness = sicknessId, reason = 'cured' }
    elseif not self.sickness:isSick() and cure.immunity then
        self.sickness:setImmunity(cure.immunity)
        lib.notify({ description = locale('cures.immunity'), type = 'success' })
        result = { success = true, cured = false, reason = 'immunity' }
    else
        lib.notify({ description = locale('cures.wrong'), type = 'inform' })
        result = { success = true, cured = false, reason = 'wrong_cure' }
    end

    TriggerEvent('amphy_dynamicworld:cureUsed', name, result)

    return result
end

return Cures
