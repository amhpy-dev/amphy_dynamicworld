if not lib then print('^1ox_lib must be started before this resource.^0') return end
lib.locale()

local Climate = require 'modules.climate'
local enable <const> = lib.load('data.settings').enable

DW = { Climate = Climate }

DW.Regions = require('modules.regions'):new()
DW.Environment = require('modules.environment'):new(DW.Regions)
DW.Editor = require('modules.editor'):new(DW.Regions)

--- Weather, temperature and the rest for a region; with no id, for the player.
---@param regionId? string
---@return table
function DW.getConditions(regionId)
    local here = not regionId or regionId == DW.Regions:getId()
    regionId = regionId or DW.Regions:getId()

    local region = DW.Regions:get(regionId)
    local payload = DW.Environment:getPayload(regionId) or {}
    local weather = here and DW.Environment:getWeather() or payload.weather

    local result = Climate.conditions(region and region.climate, weather,
        GetClockHours(), GetClockMinutes(), payload.windSpeed or GetWindSpeed())

    result.region = regionId
    result.label = region and region.label
    result.forced = payload.forced == true
    result.ends = payload.time
    result.season = GlobalState.season
    result.synced = DW.Environment:isSynced()

    if here then
        result.blackout = DW.Environment:isBlackout()
    else
        result.blackout = GlobalState.blackOut == true or payload.blackout == true
    end

    return result
end

RegisterNetEvent('amphy_dynamicworld:client:setSync', function(state, options)
    if state then DW.Environment:resume('server') else DW.Environment:pause('server', options) end
end)

RegisterNetEvent('amphy_dynamicworld:client:setBlackout', function(state)
    DW.Environment:setPlayerBlackout(state)
end)

if enable.regionNotify then
    DW.Regions:onChange(function(id, previous)
        if not previous or not DW.Environment:isSynced() then return end

        local info = DW.getConditions(id)

        lib.notify({
            title = info.label,
            description = locale('weather.region_changed', info.weatherLabel, math.floor(info.temperature + 0.5)),
            icon = 'cloud-sun',
        })
    end)
end

--------------------------------------------------------------------------------
-- Sickness
--------------------------------------------------------------------------------

if enable.sickness then
    DW.Effects = require('modules.effects'):new()
    DW.Sickness = require('modules.sickness'):new(DW.getConditions, DW.Effects)
    DW.Showcase = require('modules.showcase'):new(DW.Sickness, DW.Effects)

    if enable.cures then
        DW.Cures = require('modules.cures'):new(DW.Sickness)
    end

    local function loadCharacter()
        DW.Sickness:restore(lib.callback.await('amphy_dynamicworld:server:getSickness', false))
    end

    AddEventHandler('QBCore:Client:OnPlayerLoaded', loadCharacter)

    RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
        DW.Showcase:stop()
        DW.Sickness:reset()
    end)

    if LocalPlayer.state.isLoggedIn then CreateThread(loadCharacter) end

    RegisterNetEvent('amphy_dynamicworld:client:infect', function(id, severity)
        DW.Sickness:infect(id, severity)
    end)

    RegisterNetEvent('amphy_dynamicworld:client:cure', function(amount, immunity)
        DW.Sickness:cure(amount, immunity)
    end)

    RegisterNetEvent('amphy_dynamicworld:client:setExposure', function(value)
        DW.Sickness:setExposure(value)
    end)

    RegisterNetEvent('amphy_dynamicworld:client:showcase', function(id)
        DW.Showcase:start(id)
    end)

    RegisterNetEvent('amphy_dynamicworld:client:showcaseStop', function()
        DW.Showcase:stop()
    end)

    RegisterNetEvent('amphy_dynamicworld:client:testPain', function(id)
        DW.Effects:playVocal(id)
    end)

    RegisterNetEvent('amphy_dynamicworld:client:testCough', function(anim)
        local played, reason = DW.Effects:cough(anim)
        lib.notify({ description = played and locale('sickness.coughing') or reason, type = played and 'success' or 'error' })
    end)

    lib.callback.register('amphy_dynamicworld:client:getState', function()
        return { conditions = DW.getConditions(), sickness = DW.Sickness:getState() }
    end)
end

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    DW.Editor:closeUi()

    if DW.Showcase then DW.Showcase:stop() end
    if DW.Effects then DW.Effects:clear() end

    ClearWeatherTypePersist()
    ClearOverrideWeather()
    NetworkClearClockTimeOverride()
    SetArtificialLightsState(false)
    SetForceVehicleTrails(false)
    SetForcePedFootstepsTracks(false)
end)
