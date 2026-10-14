---@class Sickness : OxClass
local Sickness = lib.class('Sickness')

local cfg <const> = lib.load('data.sickness')
local Sicknesses <const> = lib.load('data.sicknesses')
local onStageChanged <const> = lib.load('data.effects').onStageChanged
local clamp <const> = lib.math.clamp

local BY_ID = {}
for _, sickness in ipairs(Sicknesses) do BY_ID[sickness.id] = sickness end

-- The client has no os library; the server compares against its own os.time().
---@return integer unix time
local function now()
    return GetCloudTimeAsInt()
end

---@param sickness table
---@param severity number
---@return table?
local function stageFor(sickness, severity)
    local match

    for _, stage in ipairs(sickness.stages) do
        if severity >= stage.threshold and (not match or stage.threshold > match.threshold) then
            match = stage
        end
    end

    return match
end

---@param sickness table
---@param factors table<string, number>
---@return number
local function strengthOf(sickness, factors)
    local total = 0

    for key, multiplier in pairs(sickness.causes) do
        total = total + (factors[key] or 0) * multiplier
    end

    return total
end

---@param getConditions fun(): table
---@param effects Effects
function Sickness:constructor(getConditions, effects)
    self.getConditions = getConditions
    self.effects = effects
    self.enabled = true
    self.exposure = 0
    self.severity = 0
    self.immuneUntil = 0
    self.scumminess = 0
    self.factors = {}

    CreateThread(function()
        Wait(math.random(1000, cfg.tickInterval))

        while true do
            self:tick()
            Wait(cfg.tickInterval)
        end
    end)
end

--------------------------------------------------------------------------------
-- Conditions
--------------------------------------------------------------------------------

---@return boolean
function Sickness:isIndoors()
    if GetInteriorFromEntity(cache.ped) ~= 0 then return true end

    local vehicle = cache.vehicle
    if not vehicle or not cfg.indoors.vehicles or not DoesVehicleHaveRoof(vehicle) then return false end

    return not IsVehicleAConvertible(vehicle, false) or GetConvertibleRoofState(vehicle) == 0
end

---@param indoors boolean
---@return number 0-1
function Sickness:getContagion(indoors)
    local contagion = cfg.contagion
    if not contagion.enabled then return 0 end

    local factor = 0

    for _, player in ipairs(lib.getNearbyPlayers(GetEntityCoords(cache.ped), contagion.radius, false)) do
        local state = Player(GetPlayerServerId(player.id)).state.dw_sickness
        if state and state.contagious then factor = factor + contagion.perPlayer end
    end

    return clamp(indoors and factor * contagion.indoorMultiplier or factor, 0, 1)
end

---@return table<string, number>
function Sickness:computeFactors()
    local conditions = self.getConditions()
    local indoors = self:isIndoors()
    local inside = cfg.indoors
    local felt = indoors and inside.temperature or conditions.feelsLike
    local humidity = indoors and inside.humidity or conditions.humidity

    local coords = GetEntityCoords(cache.ped)
    local zone = GetZoneAtCoords(coords.x, coords.y, coords.z)

    self.indoors = indoors
    self.scumminess = zone ~= -1 and GetZoneScumminess(zone) or 0

    self.factors = {
        scumminess = self.scumminess / 5 * (indoors and inside.scumminess or 1),
        cold = clamp((cfg.tooCold - felt) / 20, 0, 1),
        heat = clamp((felt - cfg.tooHot) / 20, 0, 1),
        humidity = clamp((humidity - cfg.tooHumid) / 20, 0, 1),
        wet = not indoors and conditions.precipitating and math.max(GetRainLevel(), 0.5) or 0,
        contagion = self:getContagion(indoors),
    }

    return self.factors
end

--------------------------------------------------------------------------------
-- Tick
--------------------------------------------------------------------------------

---@param factors table<string, number>
---@return table?
function Sickness:pick(factors)
    local options, total = {}, 0

    for _, sickness in ipairs(Sicknesses) do
        local weight = strengthOf(sickness, factors) * (sickness.weight or 1)

        if weight > 0 then
            total = total + weight
            options[#options + 1] = { sickness = sickness, weight = weight }
        end
    end

    local roll = math.random() * total

    for _, option in ipairs(options) do
        roll = roll - option.weight
        if roll <= 0 then return option.sickness end
    end
end

function Sickness:tick()
    if not self.enabled or self.paused or not LocalPlayer.state.isLoggedIn or IsEntityDead(cache.ped) then return end

    local factors = self:computeFactors()
    local exposure = cfg.exposure
    local pressure = 0

    for key, strength in pairs(factors) do
        pressure = pressure + strength * (cfg.weights[key] or 0)
    end

    if self.indoors then
        pressure = pressure - exposure.indoorRecovery
    elseif pressure <= 0 then
        pressure = -exposure.recovery
    end

    self.exposure = clamp(self.exposure + pressure, 0, 100)

    local sickness = self.sickness

    if sickness then
        local strength = clamp(strengthOf(sickness, factors), 0, 1)

        if strength > 0.05 then
            self:setSeverity(self.severity + sickness.progression * strength)
        else
            self:setSeverity(self.severity - (self.indoors and sickness.recovery or sickness.passiveRecovery))
        end
    elseif not self:isImmune() and self.exposure > exposure.infectAbove then
        local scale = (self.exposure - exposure.infectAbove) / (100 - exposure.infectAbove)

        if math.random() < exposure.infectChance * scale then
            local picked = self:pick(factors)
            if picked then self:infect(picked.id) end
        end
    end

    self:sync()
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

function Sickness:applyStage()
    local stage = self.sickness and stageFor(self.sickness, self.severity)
    local id = stage and stage.id

    if id == self.stageId then return end

    local previous = self.stageId
    self.stageId = id

    if self.enabled then self.effects:apply(self.sickness, stage) end

    onStageChanged(self.sickness, stage, previous)
end

---@param id string
---@param severity? number
function Sickness:infect(id, severity)
    local sickness = BY_ID[id]
    if not sickness then return false end

    self.sickness = sickness
    self.severity = clamp(severity or 1, 1, 100)
    self.stageId = nil
    self.immuneUntil = 0

    self:applyStage()
    self:sync()

    return true
end

---@param amount? number severity to remove, 100 by default
---@param immunity? number seconds of immunity if it clears
---@return boolean cured
function Sickness:cure(amount, immunity)
    if not self.sickness then return false end

    local remaining = self.severity - (amount or 100)

    if remaining > 0 then
        self:setSeverity(remaining)
        return false
    end

    self.sickness = nil
    self.severity = 0
    self.exposure = math.max(0, self.exposure - 25)
    self.immuneUntil = now() + (immunity or cfg.immunity)

    self:applyStage()
    self:sync()

    return true
end

---@param value number
function Sickness:setSeverity(value)
    if not self.sickness then return end
    if value <= 0 then return self:cure() end

    self.severity = math.min(100, value)
    self:applyStage()
end

---@param seconds number
function Sickness:setImmunity(seconds)
    self.immuneUntil = now() + seconds
    self:sync()
end

---@param amount number
function Sickness:removeExposure(amount)
    self.exposure = clamp(self.exposure - amount, 0, 100)
end

---@param value number
function Sickness:setExposure(value)
    self.exposure = clamp(value, 0, 100)
    self:sync()
end

---@return boolean
function Sickness:isImmune()
    return now() < self.immuneUntil
end

---@return boolean
function Sickness:isSick()
    return self.sickness ~= nil
end

---@return table?
function Sickness:getStage()
    return self.sickness and stageFor(self.sickness, self.severity)
end

---@param enabled boolean
function Sickness:setEnabled(enabled)
    self.enabled = enabled

    if not enabled then return self.effects:clear() end

    self.stageId = nil
    self:applyStage()
end

--- Forget the current character without telling the server (it saved on logout).
function Sickness:reset()
    self.sickness, self.stageId, self.synced = nil, nil, nil
    self.severity, self.exposure, self.immuneUntil = 0, 0, 0
    self.effects:clear()
end

---@param state table? as saved by the server
function Sickness:restore(state)
    if not state then return end

    self.exposure = clamp(state.exposure or 0, 0, 100)
    self.immuneUntil = state.immuneUntil or 0

    if BY_ID[state.sickness] then
        self.sickness = BY_ID[state.sickness]
        self.severity = clamp(state.severity or 1, 1, 100)
        self.stageId = nil
        self:applyStage()
    end

    self:sync()
end

---@return table
function Sickness:getState()
    local sickness = self.sickness

    return {
        sickness = sickness and sickness.id,
        label = sickness and sickness.label,
        contagious = sickness and sickness.contagious or false,
        severity = math.floor(self.severity + 0.5),
        stage = self.stageId,
        exposure = math.floor(self.exposure + 0.5),
        immune = self:isImmune(),
        immuneUntil = self.immuneUntil,
        indoors = self.indoors or false,
        scumminess = self.scumminess,
        factors = self.factors,
    }
end

--- Tell the server, only when something it stores has changed.
function Sickness:sync()
    local state = self:getState()
    local key = ('%s|%s|%d|%d|%d'):format(state.sickness, state.stage, state.severity, state.exposure, state.immuneUntil)

    if key == self.synced then return end
    self.synced = key

    TriggerServerEvent('amphy_dynamicworld:server:syncSickness', {
        sickness = state.sickness,
        stage = state.stage,
        severity = state.severity,
        exposure = state.exposure,
        immuneUntil = state.immuneUntil,
    })
end

return Sickness
