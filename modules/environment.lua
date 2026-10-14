local Climate = require 'modules.climate'

---@class Environment : OxClass
local Environment = lib.class('Environment')

local cfg <const> = lib.load('data.weather')
local enable <const> = lib.load('data.settings').enable
local FROZEN_CLOCK <const> = 2147483647
local REASSERT <const> = 10000

---@param regions RegionTracker
function Environment:constructor(regions)
    self.regions = regions
    self.holds = {}
    self.holdCount = 0
    self.blendUntil = 0
    self.nextReassert = 0

    regions:onChange(function(_, _, snap)
        if self:isSynced() then self:applyRegion(nil, snap and 0 or cfg.blend.region) end
    end)

    -- State bag handlers run before the new value is stored, so pass it along.
    AddStateBagChangeHandler('regionWeather', 'global', function(_, _, value)
        if self:isSynced() then self:applyRegion(value, cfg.blend.weather) end
    end)

    AddStateBagChangeHandler('blackOut', 'global', function(_, _, value)
        self:applyBlackout(nil, value)
    end)

    AddStateBagChangeHandler('currentTime', 'global', function(_, _, value)
        if self:isSynced() then self:applyTime(value) end
    end)

    AddStateBagChangeHandler('timeScale', 'global', function(_, _, value)
        if self:isSynced() then self:applyTimeScale(value) end
    end)

    CreateThread(function()
        if enable.weather then
            lib.waitFor(function() return GlobalState.regionWeather end, nil, false)
        end

        self:refresh()

        while true do
            Wait(1000)
            self:maintain()
        end
    end)
end

---@param id? string
---@param all? table<string, LiveWeather>
---@return LiveWeather?
function Environment:getPayload(id, all)
    all = all or GlobalState.regionWeather
    return all and (all[id or self.regions:getId()] or all.default)
end

--------------------------------------------------------------------------------
-- Applying
--------------------------------------------------------------------------------

---@param weather? string
---@param blend? number seconds
function Environment:setWeather(weather, blend)
    if not enable.weather or not weather or weather == self.applied then return end

    local previous = self.applied
    self.applied = weather

    ClearOverrideWeather()
    ClearWeatherTypePersist()

    if blend and blend > 0 then
        SetWeatherTypeOverTime(weather, blend + 0.0)
        self.blendUntil = GetGameTimer() + blend * 1000
    else
        SetWeatherTypePersist(weather)
        SetWeatherTypeNowPersist(weather)
        self.blendUntil = 0
    end

    SetRainLevel(-1.0)

    local snow = Climate.SNOW[weather] == true
    SetForceVehicleTrails(snow)
    SetForcePedFootstepsTracks(snow)

    self.nextReassert = GetGameTimer() + REASSERT

    TriggerEvent('amphy_dynamicworld:weatherChanged', weather, previous, self.regions:getId())
end

---@param payload? LiveWeather
function Environment:setWind(payload)
    if not enable.weather or not payload then return end

    SetWind(payload.windSpeed)
    SetWindSpeed(payload.windSpeed)
    SetWindDirection(payload.windDirection)
end

---@param all? table<string, LiveWeather>
---@param blend? number seconds
function Environment:applyRegion(all, blend)
    local payload = self:getPayload(nil, all)
    if not payload then return end

    self:setWeather(payload.weather, blend)
    self:setWind(payload)
    self:applyBlackout(payload)
end

---@param time? { hour: number, minute: number }
function Environment:applyTime(time)
    if enable.time and time then NetworkOverrideClockTime(time.hour, time.minute, 0) end
end

---@param scale number? ms per game minute, 0 or nil freezes the clock
function Environment:applyTimeScale(scale)
    if not enable.time then return end
    NetworkOverrideClockMillisecondsPerGameMinute(scale and scale > 0 and scale or FROZEN_CLOCK)
end

---@param payload? LiveWeather
---@param global? boolean
---@return boolean
function Environment:isBlackout(payload, global)
    if self.playerBlackout then return true end

    local hold = self:getHold()
    if hold then return hold.blackout == true end

    if global == nil then global = GlobalState.blackOut end
    payload = payload or self:getPayload()

    return global == true or (payload and payload.blackout) == true
end

---@param payload? LiveWeather
---@param global? boolean
function Environment:applyBlackout(payload, global)
    if not enable.weather then return end

    local state = self:isBlackout(payload, global)
    if state == self.blackout then return end

    self.blackout = state
    SetArtificialLightsState(state)
    SetArtificialLightsStateAffectsVehicles(false)
end

---@param state? boolean
function Environment:setPlayerBlackout(state)
    self.playerBlackout = state or nil
    self:applyBlackout()
end

function Environment:refresh()
    self.applied = nil
    self.blackout = nil

    local hold = self:getHold()

    if hold then
        local interior = cfg.interior
        local freeze = hold.freeze
        if freeze == nil then freeze = interior.freeze end

        self:setWeather(hold.weather or interior.weather)
        self:applyTime(hold.time or interior.time)
        self:applyTimeScale(not freeze and GlobalState.timeScale or 0)
    else
        self:applyRegion(nil, 0)
        self:applyTime(GlobalState.currentTime)
        self:applyTimeScale(GlobalState.timeScale)
    end

    self:applyBlackout()
end

--- Re-assert the weather now and then so nothing else quietly takes it over.
function Environment:maintain()
    if not enable.weather or not self:isSynced() then return end

    local payload = self:getPayload()
    if not payload then return end

    if payload.weather ~= self.applied then
        return self:applyRegion(nil, cfg.blend.weather)
    end

    local now = GetGameTimer()

    if now >= self.blendUntil and now >= self.nextReassert then
        SetWeatherTypePersist(self.applied)
        SetWeatherTypeNowPersist(self.applied)
        SetRainLevel(-1.0)
        self:setWind(payload)
        self.nextReassert = now + REASSERT
    end

    self:applyBlackout(payload)
end

--------------------------------------------------------------------------------
-- Holds (interiors, shells, IPLs)
--------------------------------------------------------------------------------

---@return boolean
function Environment:isSynced()
    return next(self.holds) == nil
end

---@return table?
function Environment:getHold()
    local latest

    for _, hold in pairs(self.holds) do
        if not latest or hold.order > latest.order then latest = hold end
    end

    return latest
end

---@param id string
---@param options? { weather?: string, time?: { hour: number, minute: number }, freeze?: boolean, blackout?: boolean }
function Environment:pause(id, options)
    self.holdCount = self.holdCount + 1

    local hold = options and lib.table.deepclone(options) or {}
    hold.weather = Climate.normalise(hold.weather)
    hold.order = self.holdCount

    self.holds[id] = hold
    self:refresh()
end

---@param id string
function Environment:resume(id)
    if not self.holds[id] then return end

    self.holds[id] = nil
    self:refresh()
end

---@param state boolean
function Environment:setSync(state)
    if state then
        self.holds = {}
        self:refresh()
    else
        self:pause('manual')
    end
end

--------------------------------------------------------------------------------
-- Getters
--------------------------------------------------------------------------------

---@return string?
function Environment:getWeather()
    if not enable.weather then
        return Climate.BY_HASH[GetPrevWeatherTypeHashName()]
    end

    local hold = self:getHold()
    if hold then return hold.weather or cfg.interior.weather end

    local payload = self:getPayload()
    return payload and payload.weather
end

---@return number
function Environment:getWindSpeed()
    local payload = self:getPayload()
    return payload and payload.windSpeed or GetWindSpeed()
end

return Environment
