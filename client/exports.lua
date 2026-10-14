local Climate = DW.Climate
local Regions = DW.Regions
local Environment = DW.Environment

---@param key string field of the conditions table
---@return function
local function conditions(key)
    return function() return DW.getConditions()[key] end
end

--------------------------------------------------------------------------------
-- Weather where the player is
--------------------------------------------------------------------------------

exports('getConditions', DW.getConditions)
exports('getRegion', function() return Regions:getId() end)
exports('getRegionLabel', conditions('label'))
exports('getClimate', conditions('climate'))
exports('getWeather', function() return Environment:getWeather() end)
exports('getWeatherLabel', conditions('weatherLabel'))
exports('isWeather', function(name) return Environment:getWeather() == name end)
exports('isRaining', conditions('raining'))
exports('isSnowing', conditions('snowing'))
exports('isPrecipitating', conditions('precipitating'))
exports('getTemperature', conditions('temperature'))
exports('getHumidity', conditions('humidity'))
exports('getFeelsLike', conditions('feelsLike'))
exports('getTemperatureBand', conditions('band'))
exports('getWindSpeed', function() return Environment:getWindSpeed() end)
exports('isBlackout', function() return Environment:isBlackout() end)
exports('isInside', function() return DW.Sickness and DW.Sickness:isIndoors() or GetInteriorFromEntity(cache.ped) ~= 0 end)

--------------------------------------------------------------------------------
-- Anywhere
--------------------------------------------------------------------------------

exports('getRegions', function() return Regions:getAll() end)
exports('getRegionInfo', function(id) return Regions:get(id) end)
exports('getRegionAt', function(coords) return Regions:resolve(coords.x, coords.y, coords.z) end)
exports('getRegionWeather', function(id) return Environment:getPayload(id) end)
exports('getWeatherAt', function(coords)
    local payload = Environment:getPayload(Regions:resolve(coords.x, coords.y, coords.z))
    return payload and payload.weather
end)
exports('getAllWeathers', function() return Climate.WEATHERS end)

--------------------------------------------------------------------------------
-- Time
--------------------------------------------------------------------------------

exports('getTime', function() return { hour = GetClockHours(), minute = GetClockMinutes() } end)
exports('getTimePeriod', function() return Climate.timePeriod(GetClockHours()) end)
exports('isNightTime', function() return Climate.isNight(GetClockHours()) end)
exports('isTimeFrozen', function() return GlobalState.freezeTime == true end)
exports('getSeason', function() return GlobalState.season end)

--------------------------------------------------------------------------------
-- Sync holds for interiors, shells and IPLs
--------------------------------------------------------------------------------

exports('pauseWeatherSync', function(id, options) Environment:pause(id, options) end)
exports('resumeWeatherSync', function(id) Environment:resume(id) end)
exports('setWeatherSync', function(state) Environment:setSync(state) end)
exports('isWeatherSynced', function() return Environment:isSynced() end)

--------------------------------------------------------------------------------
-- Sickness (safe to call with the system disabled)
--------------------------------------------------------------------------------

---@param method string Sickness method to forward to
---@param fallback any returned while sickness is disabled
---@return function
local function sickness(method, fallback)
    return function(...)
        if not DW.Sickness then return fallback end
        return DW.Sickness[method](DW.Sickness, ...)
    end
end

exports('isSick', sickness('isSick', false))
exports('isImmune', sickness('isImmune', false))
exports('getSicknessState', sickness('getState'))
exports('infect', sickness('infect', false))
exports('cure', sickness('cure', false))
exports('setSeverity', sickness('setSeverity'))
exports('setImmunity', sickness('setImmunity'))
exports('setExposure', sickness('setExposure'))
exports('removeExposure', sickness('removeExposure'))
exports('setSicknessEnabled', sickness('setEnabled'))

exports('getSickness', function() return DW.Sickness and DW.Sickness:getState().sickness end)
exports('getStage', function() return DW.Sickness and DW.Sickness.stageId end)
exports('getSeverity', function() return DW.Sickness and DW.Sickness:getState().severity or 0 end)
exports('getExposure', function() return DW.Sickness and DW.Sickness:getState().exposure or 0 end)

exports('forceCough', function(anim) return DW.Effects and DW.Effects:cough(anim) or false end)
exports('startShowcase', function(id) return DW.Showcase and DW.Showcase:start(id) or false end)
exports('stopShowcase', function() return DW.Showcase and DW.Showcase:stop() or false end)

--- ox_inventory item export: client = { export = 'amphy_dynamicworld.useCure' }
exports('useCure', function(item)
    if not DW.Cures then return end

    DW.Cures:use(item.name, function()
        local result = promise.new()
        local settled = false

        local function settle(used)
            if settled then return end
            settled = true
            result:resolve(used)
        end

        exports.ox_inventory:useItem(item, function(data) settle(data ~= nil) end)
        SetTimeout(5000, function() settle(false) end)

        return Citizen.Await(result)
    end)
end)

--------------------------------------------------------------------------------
-- Editor
--------------------------------------------------------------------------------

exports('openRegionEditor', function() DW.Editor:openUi() end)
exports('closeRegionEditor', function() DW.Editor:closeUi() end)
exports('previewRegions', function(seconds) DW.Editor:preview(seconds) end)
