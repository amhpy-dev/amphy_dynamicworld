local Settings <const> = lib.load('data.settings')

if not Settings.enable.compatibility then return end

local Environment = DW.Environment

-- Housing and interior scripts written for qb-weathersync / vSync.
RegisterNetEvent('qb-weathersync:client:DisableSync', function() Environment:pause('compat') end)
RegisterNetEvent('qb-weathersync:client:EnableSync', function() Environment:resume('compat') end)

RegisterNetEvent('vSync:toggle', function(state)
    if state then Environment:resume('compat') else Environment:pause('compat') end
end)
