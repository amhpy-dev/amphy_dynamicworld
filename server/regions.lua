local Geometry = require 'modules.geometry'
local Climate = require 'modules.climate'
local Seeds <const> = lib.load('data.regions')
local Editor <const> = lib.load('data.editor')

local DEFAULT <const> = 'default'
local MAX_LABEL <const> = 20

Regions = {
    records = {},
    ordered = {},
    listeners = {},
}

---@param value any
---@param min number
---@param max number
---@param fallback? number
---@return number?
local function number(value, min, max, fallback)
    value = tonumber(value)
    return value and lib.math.clamp(value, min, max) or fallback
end

---@param input any
---@return { x: number, y: number }?
local function point(input)
    if type(input) ~= 'table' or not tonumber(input.x) or not tonumber(input.y) then return end
    return { x = number(input.x, -20000, 20000), y = number(input.y, -20000, 20000) }
end

--- Rebuild a region from untrusted input (NUI, exports, the database).
---@return table? region, string? reason
function Regions.sanitise(input)
    if type(input) ~= 'table' then return nil, locale('regions.invalid') end

    local id = tostring(input.id or ''):gsub('[^%w_%-]', ''):sub(1, 48)
    local climate = Climate.exists(input.climate) and input.climate or Seeds.default.climate
    local label = tostring(input.label or ''):sub(1, MAX_LABEL)

    if id == DEFAULT then
        return { id = DEFAULT, shape = 'global', climate = climate, label = label ~= '' and label or Seeds.default.label }
    end

    local region = {
        id = id ~= '' and id or ('region_%d'):format(math.random(100000, 999999)),
        label = label ~= '' and label or locale('regions.unnamed'),
        climate = climate,
        shape = input.shape == 'circle' and 'circle' or 'poly',
        priority = number(input.priority, 0, 100, 10),
        floor = number(input.floor, -200, 2000),
        enabled = input.enabled ~= false,
    }

    if region.shape == 'circle' then
        region.coords = point(input.coords)
        region.radius = number(input.radius, 1, 10000, 500)

        if not region.coords then return nil, locale('regions.no_centre') end
        return region
    end

    region.points = {}

    for _, entry in ipairs(type(input.points) == 'table' and input.points or {}) do
        region.points[#region.points + 1] = point(entry)
    end

    if #region.points < 3 or #region.points > 64 then
        return nil, locale('regions.corners')
    end

    local x, y = 0, 0
    for _, corner in ipairs(region.points) do x, y = x + corner.x, y + corner.y end
    region.coords = { x = x / #region.points, y = y / #region.points }

    return region
end

---@return RegionRecord[]
function Regions:list()
    local list = {}

    for _, region in pairs(self.records) do list[#list + 1] = region end

    table.sort(list, function(a, b)
        if (a.id == DEFAULT) ~= (b.id == DEFAULT) then return a.id == DEFAULT end
        if a.label ~= b.label then return a.label < b.label end
        return a.id < b.id
    end)

    return list
end

---@param id string
---@return RegionRecord?
function Regions:get(id)
    return self.records[id]
end

---@param fn fun(list: RegionRecord[])
function Regions:onChange(fn)
    self.listeners[#self.listeners + 1] = fn
end

function Regions:publish()
    local list = self:list()

    self.ordered = Geometry.prepare(list)
    GlobalState.weatherRegions = list

    for _, fn in ipairs(self.listeners) do fn(list) end
end

--------------------------------------------------------------------------------
-- Storage (oxmysql)
--------------------------------------------------------------------------------

local SCHEMA <const> = {
    [[CREATE TABLE IF NOT EXISTS `dynamicworld_regions` (
        `id` VARCHAR(48) NOT NULL,
        `label` VARCHAR(20) NOT NULL,
        `climate` VARCHAR(32) NOT NULL,
        `shape` ENUM('global', 'circle', 'poly') NOT NULL,
        `x` FLOAT NULL,
        `y` FLOAT NULL,
        `radius` FLOAT NULL,
        `priority` TINYINT UNSIGNED NOT NULL DEFAULT 10,
        `floor` FLOAT NULL,
        `enabled` TINYINT(1) NOT NULL DEFAULT 1,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`)
    )]],
    [[CREATE TABLE IF NOT EXISTS `dynamicworld_region_points` (
        `region` VARCHAR(48) NOT NULL,
        `idx` TINYINT UNSIGNED NOT NULL,
        `x` FLOAT NOT NULL,
        `y` FLOAT NOT NULL,
        PRIMARY KEY (`region`, `idx`),
        FOREIGN KEY (`region`) REFERENCES `dynamicworld_regions` (`id`) ON DELETE CASCADE
    )]],
}

--- One transaction: the region row, then its corners replaced wholesale.
local function store(region)
    local coords = region.coords or {}
    local queries = {
        {
            query = [[INSERT INTO `dynamicworld_regions`
                (`id`, `label`, `climate`, `shape`, `x`, `y`, `radius`, `priority`, `floor`, `enabled`)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE `label` = VALUES(`label`), `climate` = VALUES(`climate`), `shape` = VALUES(`shape`),
                `x` = VALUES(`x`), `y` = VALUES(`y`), `radius` = VALUES(`radius`), `priority` = VALUES(`priority`),
                `floor` = VALUES(`floor`), `enabled` = VALUES(`enabled`)]],
            values = {
                region.id, region.label, region.climate, region.shape, coords.x, coords.y, region.radius,
                region.priority or 10, region.floor, region.enabled == false and 0 or 1,
            },
        },
        { query = 'DELETE FROM `dynamicworld_region_points` WHERE `region` = ?', values = { region.id } },
    }

    for index, point in ipairs(region.points or {}) do
        queries[#queries + 1] = {
            query = 'INSERT INTO `dynamicworld_region_points` (`region`, `idx`, `x`, `y`) VALUES (?, ?, ?, ?)',
            values = { region.id, index, point.x, point.y },
        }
    end

    MySQL.transaction(queries)
end

function Regions:load()
    for _, query in ipairs(SCHEMA) do MySQL.query.await(query) end

    local rows = MySQL.query.await('SELECT * FROM `dynamicworld_regions`') or {}
    local points = {}

    for _, row in ipairs(MySQL.query.await('SELECT * FROM `dynamicworld_region_points` ORDER BY `region`, `idx`') or {}) do
        points[row.region] = points[row.region] or {}
        points[row.region][#points[row.region] + 1] = { x = row.x, y = row.y }
    end

    local entries = {}

    for _, row in ipairs(rows) do
        entries[#entries + 1] = {
            id = row.id,
            label = row.label,
            climate = row.climate,
            shape = row.shape,
            coords = row.x and { x = row.x, y = row.y },
            radius = row.radius,
            priority = row.priority,
            floor = row.floor,
            enabled = row.enabled == 1 or row.enabled == true,
            points = points[row.id],
        }
    end

    -- First start: seed from data/regions.lua.
    local seeding = #rows == 0
    if seeding then entries = Seeds.regions end

    for _, entry in ipairs(entries) do
        local region, reason = Regions.sanitise(entry)

        if region then
            self.records[region.id] = region
            if seeding then store(region) end
        else
            lib.print.warn(('skipped region %s: %s'):format(entry.id, reason))
        end
    end

    if not self.records[DEFAULT] then
        self.records[DEFAULT] = Regions.sanitise({ id = DEFAULT })
        store(self.records[DEFAULT])
    end

    self:publish()
end

---@param input table
---@return RegionRecord? region
---@return string? reason
function Regions:save(input)
    local region, reason = Regions.sanitise(input)
    if not region then return nil, reason end

    self.records[region.id] = region
    store(region)
    self:publish()

    return region
end

---@param id string
---@return boolean
function Regions:delete(id)
    if id == DEFAULT or not self.records[id] then return false end

    self.records[id] = nil
    MySQL.update('DELETE FROM `dynamicworld_regions` WHERE `id` = ?', { id })
    self:publish()

    return true
end

---@param id string
---@param state? boolean omit to flip it
---@return boolean?
function Regions:setEnabled(id, state)
    local region = self.records[id]
    if not region or id == DEFAULT then return end

    if state == nil then state = region.enabled == false end

    region.enabled = state
    MySQL.update('UPDATE `dynamicworld_regions` SET `enabled` = ? WHERE `id` = ?', { state and 1 or 0, id })
    self:publish()

    return state
end

---@param x number
---@param y number
---@param z? number
---@return string regionId
function Regions:resolve(x, y, z)
    return Geometry.resolve(self.ordered, x, y, z)
end

---@param source number
---@return string regionId
function Regions:forPlayer(source)
    local coords = GetEntityCoords(GetPlayerPed(source))
    return self:resolve(coords.x, coords.y, coords.z)
end

--- Admin check for the editor's net events.
function Regions.allowed(source)
    return IsPlayerAceAllowed(tostring(source), ('command.%s'):format(Editor.command))
end

MySQL.ready(function() Climates:whenLoaded(function() Regions:load() end) end)

--------------------------------------------------------------------------------
-- Editor
--------------------------------------------------------------------------------

---@param name string
---@param fn fun(source: number, data: table)
local function adminEvent(name, fn)
    RegisterNetEvent(name, function(data)
        local source = source

        if not Regions.allowed(source) then
            return lib.print.warn(('%s (%d) used %s without permission'):format(GetPlayerName(source), source, name))
        end

        fn(source, type(data) == 'table' and data or {})
    end)
end

Regions.adminEvent = adminEvent

adminEvent('amphy_dynamicworld:server:saveRegion', function(source, data)
    local region, reason = Regions:save(data)
    lib.notify(source, { description = region and locale('regions.saved', region.label) or reason, type = region and 'success' or 'error' })
end)

adminEvent('amphy_dynamicworld:server:deleteRegion', function(source, data)
    local region = Regions:get(data.id)

    if Regions:delete(data.id) then
        lib.notify(source, { description = locale('regions.deleted', region.label), type = 'success' })
    end
end)

adminEvent('amphy_dynamicworld:server:toggleRegion', function(_, data)
    Regions:setEnabled(data.id)
end)

--------------------------------------------------------------------------------
-- Exports
--------------------------------------------------------------------------------

exports('getRegions', function() return Regions:list() end)
exports('getRegion', function(id) return Regions:get(id) end)
exports('getRegionAt', function(coords) return Regions:resolve(coords.x, coords.y, coords.z) end)
exports('getPlayerRegion', function(source) return Regions:forPlayer(source) end)
exports('deleteRegion', function(id) return Regions:delete(id) end)
exports('setRegionEnabled', function(id, state) return Regions:setEnabled(id, state) end)
exports('saveRegion', function(input)
    local region, reason = Regions:save(input)
    return region and region.id, reason
end)
