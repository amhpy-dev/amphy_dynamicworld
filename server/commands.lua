local Climate = require 'modules.climate'

local Settings <const> = lib.load('data.settings')
local Sicknesses <const> = lib.load('data.sicknesses')
local Editor <const> = lib.load('data.editor')

local enable <const> = Settings.enable

---@param source number
---@param description string
---@param type? 'inform' | 'success' | 'error'
local function notify(source, description, type)
    if source == 0 then return print(description) end

    lib.notify(source, { description = description, type = type or 'inform' })
end

---@param name string
---@param help string
---@param params? table[]
---@param fn fun(source: number, args: table)
local function command(name, help, params, fn)
    lib.addCommand(name, { help = help, params = params, restricted = Settings.adminGroup }, fn)
end

---A player id param that defaults to whoever ran the command.
---@param source number
---@param args table
---@return number? target
local function targetOf(source, args)
    local target = args.target or source

    if target == 0 then
        notify(source, locale('errors.console_target'), 'error')
        return
    end

    return target
end

---'here', a region id, or nothing for everywhere.
---@param source number
---@param input? string
---@return string | false | nil region nil for everywhere, false when unknown
local function regionOf(source, input)
    if not input or input == 'all' or input == '*' then return end
    if input == 'here' and source ~= 0 then return Regions:forPlayer(source) end
    if Regions:get(input) then return input end

    local ids = {}
    for _, region in ipairs(Regions:list()) do ids[#ids + 1] = region.id end

    notify(source, locale('regions.unknown', table.concat(ids, ', ')), 'error')
    return false
end

---@param region? string
---@return string
local function where(region)
    if not region then return locale('weather.everywhere') end

    return locale('weather.in_region', Regions:get(region).label)
end

local REGION <const> = { name = 'region', type = 'string', help = locale('commands.region'), optional = true }
local TARGET <const> = { name = 'target', type = 'playerId', help = locale('commands.target'), optional = true }

--------------------------------------------------------------------------------
-- Weather
--------------------------------------------------------------------------------

if enable.weather then
    command('weather', locale('commands.weather.help'), {
        { name = 'type', type = 'string', help = locale('commands.weather.type') },
        REGION,
    }, function(source, args)
        local region = regionOf(source, args.region)
        if region == false then return end

        local input = args.type:lower()

        if input == 'auto' then
            Weather:release(region)
            notify(source, locale('weather.released', where(region)), 'success')
        elseif input == 'next' then
            Weather:advance(region)
            notify(source, locale('weather.advanced', where(region)), 'success')
        elseif Weather:set(input, region) then
            notify(source, locale('weather.set', Climate.label(Climate.normalise(input)), where(region)), 'success')
        else
            notify(source, locale('weather.unknown'), 'error')
        end
    end)

    command('weathers', locale('commands.weathers.help'), nil, function(source)
        notify(source, table.concat(Climate.WEATHERS, ', '))

        for _, region in ipairs(Regions:list()) do
            local state = Weather.states[region.id]

            if state then
                notify(source, locale('weather.listing', region.label, Climate.label(state.weather), state.forced and locale('weather.held') or ''))
            end
        end
    end)

    command('blackout', locale('commands.blackout.help'), {
        { name = 'target', type = 'string', help = locale('commands.blackout.target'), optional = true },
    }, function(source, args)
        local playerId = tonumber(args.target)

        if playerId then
            if not GetPlayerName(playerId) then return notify(source, locale('errors.no_player'), 'error') end

            local state = not Weather.playerBlackouts[playerId]
            Weather:setPlayerBlackout(playerId, state)

            return notify(source, locale('blackout.player', locale(state and 'weather.on' or 'weather.off'), GetPlayerName(playerId)))
        end

        local region = regionOf(source, args.target)
        if region == false then return end

        if region then
            local state = not Weather.states[region].blackout
            Weather:setRegionBlackout(region, state)

            return notify(source, locale(state and 'blackout.cut' or 'blackout.restored', where(region)))
        end

        Weather:setBlackout(not Weather.blackout)
        notify(source, locale(Weather.blackout and 'blackout.on' or 'blackout.off'))
    end)

    command('weathersync', locale('commands.weathersync.help'), {
        { name = 'target', type = 'playerId' },
        { name = 'state', type = 'string', help = locale('commands.weathersync.state') },
    }, function(source, args)
        local state = args.state:lower() == 'on'
        Weather:setPlayerSync(args.target, state)

        notify(source, locale('weather.sync', locale(state and 'weather.on' or 'weather.off'), GetPlayerName(args.target)), 'success')
    end)

    command('weatherinfo', locale('commands.weatherinfo.help'), { TARGET }, function(source, args)
        local target = targetOf(source, args)
        if not target then return end

        local info = Weather:forPlayer(target)

        notify(source, locale('weather.info', info.label, info.weatherLabel, info.forced and locale('weather.held') or '',
            info.temperature, info.feelsLike, info.humidity, info.time.hour, info.time.minute))
    end)

    command(Editor.command, locale('commands.editor.help'), { TARGET }, function(source, args)
        local target = targetOf(source, args)
        if target then TriggerClientEvent('amphy_dynamicworld:client:openEditor', target) end
    end)

    Regions.adminEvent('amphy_dynamicworld:server:setRegionWeather', function(_, data)
        local region = data.id ~= '*' and data.id or nil

        if data.weather == 'auto' then
            Weather:release(region)
        elseif data.weather == 'next' then
            Weather:advance(region)
        else
            Weather:set(data.weather, region)
        end
    end)

    Regions.adminEvent('amphy_dynamicworld:server:setRegionBlackout', function(_, data)
        if data.id == '*' then return Weather:setBlackout(data.state == true) end

        Weather:setRegionBlackout(data.id, data.state == true)
    end)
end

--------------------------------------------------------------------------------
-- Time
--------------------------------------------------------------------------------

if enable.time then
    command('time', locale('commands.time.help'), {
        { name = 'hour', type = 'number', help = locale('commands.time.hour') },
        { name = 'minute', type = 'number', help = locale('commands.time.minute'), optional = true },
        { name = 'now', type = 'string', help = locale('commands.time.now'), optional = true },
    }, function(source, args)
        if not Clock:set(args.hour, args.minute, args.now == 'now') then
            return notify(source, locale('time.invalid'), 'error')
        end

        notify(source, locale('time.moving', args.hour, args.minute or 0), 'success')
    end)

    command('freezetime', locale('commands.freezetime.help'), nil, function(source)
        Clock:freeze(not Clock.frozen)
        notify(source, locale(Clock.frozen and 'time.frozen' or 'time.resumed'))
    end)
end

--------------------------------------------------------------------------------
-- Sickness
--------------------------------------------------------------------------------

if not enable.sickness then return end

local sicknessIds = {}
for _, sickness in ipairs(Sicknesses) do sicknessIds[#sicknessIds + 1] = sickness.id end
sicknessIds = table.concat(sicknessIds, ', ')

---@param name string
---@param help string
---@param params table[]
---@param fn fun(source: number, target: number, args: table)
local function onTarget(name, help, params, fn)
    command(name, help, params, function(source, args)
        local target = targetOf(source, args)
        if target then fn(source, target, args) end
    end)
end

command('infect', locale('commands.infect.help'), {
    { name = 'target', type = 'playerId' },
    { name = 'sickness', type = 'string', help = sicknessIds },
    { name = 'severity', type = 'number', help = locale('commands.infect.severity'), optional = true },
}, function(source, args)
    TriggerClientEvent('amphy_dynamicworld:client:infect', args.target, args.sickness, args.severity)
    notify(source, locale('sickness.infected', GetPlayerName(args.target), args.sickness), 'success')
end)

command('curesickness', locale('commands.curesickness.help'), {
    { name = 'target', type = 'playerId' },
    { name = 'immunity', type = 'number', help = locale('commands.curesickness.immunity'), optional = true },
}, function(source, args)
    TriggerClientEvent('amphy_dynamicworld:client:cure', args.target, 100, args.immunity)
    notify(source, locale('sickness.cured', GetPlayerName(args.target)), 'success')
end)

command('exposure', locale('commands.exposure.help'), {
    { name = 'target', type = 'playerId' },
    { name = 'value', type = 'number', help = locale('commands.exposure.value') },
}, function(source, args)
    TriggerClientEvent('amphy_dynamicworld:client:setExposure', args.target, args.value)
    notify(source, locale('sickness.exposure', GetPlayerName(args.target), args.value), 'success')
end)

onTarget('dwpain', locale('commands.dwpain.help'), {
    { name = 'id', type = 'number', help = locale('commands.dwpain.id'), optional = true },
    TARGET,
}, function(_, target, args)
    TriggerClientEvent('amphy_dynamicworld:client:testPain', target, args.id or 19)
end)

onTarget('dwcough', locale('commands.dwcough.help'), {
    { name = 'anim', type = 'string', help = locale('commands.dwcough.anim'), optional = true },
    TARGET,
}, function(_, target, args)
    TriggerClientEvent('amphy_dynamicworld:client:testCough', target, args.anim)
end)

onTarget('dwshowcase', locale('commands.dwshowcase.help'), {
    { name = 'sickness', type = 'string', help = locale('commands.dwshowcase.sickness', sicknessIds), optional = true },
    TARGET,
}, function(source, target, args)
    TriggerClientEvent('amphy_dynamicworld:client:showcase', target, args.sickness)
    notify(source, locale('sickness.showcasing', args.sickness or locale('sickness.every_sickness'), GetPlayerName(target)), 'success')
end)

onTarget('dwshowcasestop', locale('commands.dwshowcasestop.help'), { TARGET }, function(_, target)
    TriggerClientEvent('amphy_dynamicworld:client:showcaseStop', target)
end)

onTarget('dwdebug', locale('commands.dwdebug.help'), { TARGET }, function(source, target)
    local state = lib.callback.await('amphy_dynamicworld:client:getState', target)
    if not state then return notify(source, locale('errors.no_response'), 'error') end

    lib.print.info(('%s: %s'):format(GetPlayerName(target), json.encode(state, { indent = true })))
    notify(source, locale('errors.printed'), 'success')
end)
