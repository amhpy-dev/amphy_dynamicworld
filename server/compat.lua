local Settings <const> = lib.load('data.settings')

if not Settings.enable.compatibility then return end

-- qb-weathersync's surface. Getters answer for primaryRegion in data/weather.lua;
-- setters act on every region, which is what single-sky scripts expect.

exports('getWeatherState', function() return GlobalState.weather and GlobalState.weather.weather end)
exports('getBlackoutState', function() return Weather.blackout end)
exports('getTimeFreezeState', function() return Clock.frozen end)
exports('getDynamicWeather', function() return Weather.dynamic end)
exports('getTime', function() return Clock:get() end)
exports('setTimeFreeze', function(state) Clock:freeze(state == true) end)
exports('nextWeatherStage', function() Weather:advance() end)

---@param event string
---@param ace string
---@param fn function
local function guarded(event, ace, fn)
    RegisterNetEvent(event, function(...)
        if IsPlayerAceAllowed(tostring(source), ace) then fn(...) end
    end)
end

guarded('qb-weathersync:server:setWeather', 'command.weather', function(weather) Weather:set(weather) end)
guarded('qb-weathersync:server:setTime', 'command.time', function(hour, minute) Clock:set(hour, minute, true) end)
guarded('qb-weathersync:server:toggleBlackout', 'command.blackout', function() Weather:setBlackout(not Weather.blackout) end)
guarded('qb-weathersync:server:toggleFreezeTime', 'command.freezetime', function() Clock:freeze(not Clock.frozen) end)
