local Settings <const> = lib.load('data.settings')

if not Settings.enable.sickness then return end

local Sicknesses <const> = lib.load('data.sicknesses')
local persistence <const> = lib.load('data.sickness').persistence

local CONTAGIOUS = {}
for _, sickness in ipairs(Sicknesses) do CONTAGIOUS[sickness.id] = sickness.contagious == true end

---@type table<number, table>
local players = {}

--------------------------------------------------------------------------------
-- Persistence (oxmysql)
--------------------------------------------------------------------------------

local dirty = {}

if persistence.enabled then
    MySQL.ready(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `dynamicworld_sickness` (
                `identifier` VARCHAR(64) NOT NULL,
                `sickness` VARCHAR(50) DEFAULT NULL,
                `severity` TINYINT UNSIGNED NOT NULL DEFAULT 0,
                `stage` VARCHAR(20) DEFAULT NULL,
                `exposure` TINYINT UNSIGNED NOT NULL DEFAULT 0,
                `immune_until` INT UNSIGNED NOT NULL DEFAULT 0,
                `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (`identifier`)
            )
        ]])

        MySQL.update.await('DELETE FROM `dynamicworld_sickness` WHERE `updated_at` < NOW() - INTERVAL ? DAY',
            { persistence.expireAfterDays })
    end)
end

---@param citizenid string
---@return table?
local function load(citizenid)
    if not persistence.enabled then return end

    local row = MySQL.single.await(
        'SELECT `sickness`, `severity`, `stage`, `exposure`, `immune_until` FROM `dynamicworld_sickness` WHERE `identifier` = ?',
        { citizenid })

    return row and {
        sickness = row.sickness,
        stage = row.stage,
        severity = row.severity,
        exposure = row.exposure,
        immuneUntil = row.immune_until,
    }
end

---@param player table
local function save(player)
    if persistence.enabled then dirty[player.citizenid] = player end
end

--- Write every changed player in two batched queries.
local function flush()
    local upserts, deletes = {}, {}

    for citizenid, player in pairs(dirty) do
        if not player.sickness and player.exposure <= 0 and player.immuneUntil <= os.time() then
            deletes[#deletes + 1] = { citizenid }
        else
            upserts[#upserts + 1] = {
                citizenid, player.sickness, math.floor(player.severity), player.stage,
                math.floor(player.exposure), player.immuneUntil,
            }
        end
    end

    dirty = {}

    if #upserts > 0 then
        MySQL.prepare([[
            INSERT INTO `dynamicworld_sickness` (`identifier`, `sickness`, `severity`, `stage`, `exposure`, `immune_until`)
            VALUES (?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE `sickness` = VALUES(`sickness`), `severity` = VALUES(`severity`),
                `stage` = VALUES(`stage`), `exposure` = VALUES(`exposure`), `immune_until` = VALUES(`immune_until`)
        ]], upserts)
    end

    if #deletes > 0 then
        MySQL.prepare('DELETE FROM `dynamicworld_sickness` WHERE `identifier` = ?', deletes)
    end
end

if persistence.enabled then
    lib.cron.new('* * * * *', flush)
end

--------------------------------------------------------------------------------
-- Players
--------------------------------------------------------------------------------

---@param source number
---@return table?
local function getPlayer(source)
    if players[source] then return players[source] end

    local character = exports.qbx_core:GetPlayer(source)
    if not character then return end

    players[source] = {
        citizenid = character.PlayerData.citizenid,
        severity = 0,
        exposure = 0,
        immuneUntil = 0,
    }

    return players[source]
end

---@param source number
---@param state table
---@return table?
local function update(source, state)
    local player = getPlayer(source)
    if not player then return end

    player.sickness = CONTAGIOUS[state.sickness] ~= nil and state.sickness or nil
    player.stage = type(state.stage) == 'string' and state.stage or nil
    player.severity = lib.math.clamp(tonumber(state.severity) or 0, 0, 100)
    player.exposure = lib.math.clamp(tonumber(state.exposure) or 0, 0, 100)
    player.immuneUntil = math.max(0, tonumber(state.immuneUntil) or 0)

    Player(source).state:set('dw_sickness', player.sickness and {
        sickness = player.sickness,
        stage = player.stage,
        severity = player.severity,
        contagious = CONTAGIOUS[player.sickness],
    } or nil, true)

    save(player)

    return player
end

--- Save and forget a character: logging out to the character menu, or leaving.
local function unload(source)
    if not players[source] then return end

    players[source] = nil
    Player(source).state:set('dw_sickness', nil, true)
    flush()
end

lib.callback.register('amphy_dynamicworld:server:getSickness', function(source)
    local player = getPlayer(source)
    local record = player and load(player.citizenid)

    if record then update(source, record) end

    return record
end)

RegisterNetEvent('amphy_dynamicworld:server:syncSickness', function(state)
    if type(state) ~= 'table' then return end

    local player = update(source, state)
    if not player then return end

    TriggerEvent('amphy_dynamicworld:sicknessChanged', source, {
        citizenid = player.citizenid,
        sickness = player.sickness,
        stage = player.stage,
        severity = player.severity,
    })
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', unload)
AddEventHandler('playerDropped', function() unload(source) end)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then flush() end
end)

--------------------------------------------------------------------------------
-- Exports
--------------------------------------------------------------------------------

exports('getPlayerState', function(source)
    local player = getPlayer(source)
    if not player then return end

    return {
        citizenid = player.citizenid,
        sickness = player.sickness,
        stage = player.stage,
        severity = player.severity,
        exposure = player.exposure,
        immuneUntil = player.immuneUntil,
        immune = os.time() < player.immuneUntil,
    }
end)

exports('isPlayerSick', function(source)
    local player = getPlayer(source)
    return player ~= nil and player.sickness ~= nil
end)

exports('getSickPlayers', function()
    local sick = {}

    for source, player in pairs(players) do
        if player.sickness then
            sick[source] = { citizenid = player.citizenid, sickness = player.sickness, stage = player.stage, severity = player.severity }
        end
    end

    return sick
end)

exports('infectPlayer', function(source, id, severity)
    TriggerClientEvent('amphy_dynamicworld:client:infect', source, id, severity)
end)

exports('curePlayer', function(source, amount, immunity)
    TriggerClientEvent('amphy_dynamicworld:client:cure', source, amount or 100, immunity)
end)

exports('setPlayerExposure', function(source, value)
    TriggerClientEvent('amphy_dynamicworld:client:setExposure', source, value)
end)
