local Editor = DW.Editor

RegisterNetEvent('amphy_dynamicworld:client:openEditor', function()
    Editor:toggleUi()
end)

-- State bag handlers run before the value is stored, so refresh a tick later.
local function refreshSoon()
    if Editor.open then SetTimeout(0, function() Editor:refresh() end) end
end

AddStateBagChangeHandler('weatherRegions', 'global', refreshSoon)
AddStateBagChangeHandler('weatherClimates', 'global', refreshSoon)
AddStateBagChangeHandler('regionWeather', 'global', refreshSoon)
AddStateBagChangeHandler('blackOut', 'global', refreshSoon)

---@param name string
---@param fn fun(data: table)
local function callback(name, fn)
    RegisterNUICallback(name, function(data, cb)
        cb(1)
        fn(data)
    end)
end

---@param name string NUI callback
---@param event string server event it forwards to
local function toServer(name, event)
    callback(name, function(data) TriggerServerEvent(event, data) end)
end

callback('close', function() Editor:closeUi() end)
callback('placeRegion', function(data) Editor:pickForUi(data) end)
callback('preview', function()
    Editor:closeUi()
    Editor:preview(20)
end)

toServer('saveRegion', 'amphy_dynamicworld:server:saveRegion')
toServer('deleteRegion', 'amphy_dynamicworld:server:deleteRegion')
toServer('toggleRegion', 'amphy_dynamicworld:server:toggleRegion')
toServer('setRegionWeather', 'amphy_dynamicworld:server:setRegionWeather')
toServer('setRegionBlackout', 'amphy_dynamicworld:server:setRegionBlackout')
toServer('saveClimate', 'amphy_dynamicworld:server:saveClimate')
toServer('deleteClimate', 'amphy_dynamicworld:server:deleteClimate')

callback('teleport', function(data)
    local x, y = tonumber(data.x), tonumber(data.y)
    if not x or not y then return end

    Editor:closeUi()

    CreateThread(function()
        local ped = cache.ped

        FreezeEntityPosition(ped, true)
        SetEntityCoords(ped, x, y, 500.0, false, false, false, false)
        RequestCollisionAtCoord(x, y, 0.0)
        pcall(lib.waitFor, function() return HasCollisionLoadedAroundEntity(ped) or nil end, nil, 5000)

        local found, ground = GetGroundZFor_3dCoord(x, y, 1000.0, false)
        SetEntityCoords(ped, x, y, found and ground + 1.0 or 500.0, false, false, false, false)
        FreezeEntityPosition(ped, false)
    end)
end)
