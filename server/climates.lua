local Climate = require 'modules.climate'
local Seeds <const> = lib.load('data.climates')
local Editor <const> = lib.load('data.editor')

local MAX_LABEL <const> = 20

Climates = {
    records = {},
    listeners = {},
    waiting = {},
    loaded = false,
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

---@param value any
---@param min number
---@param max number
---@param fallback number
---@return integer
local function integer(value, min, max, fallback)
    return math.floor(number(value, min, max, fallback) + 0.5)
end

--- Rebuild a climate from untrusted input (the editor, the JSON file).
---@return table? climate, string? reason
function Climates.sanitise(input, id)
    if type(input) ~= 'table' then return nil, locale('climates.invalid') end

    local label = tostring(input.label or ''):sub(1, MAX_LABEL)
    if label == '' then return nil, locale('climates.unnamed') end

    id = (tostring(id or input.id or ''):gsub('[^%w_]', '')):lower():sub(1, 32)
    if id == '' then id = (label:lower():gsub('[^%w]+', '_'):gsub('^_+', ''):gsub('_+$', '')):sub(1, 32) end
    if id == '' then id = ('climate_%d'):format(math.random(1000, 9999)) end

    local weathers, total = {}, 0

    for name, weight in pairs(type(input.weathers) == 'table' and input.weathers or {}) do
        weight = integer(weight, 0, 100, 0)

        if Climate.VALID[name] and weight > 0 then
            weathers[name] = weight
            total = total + weight
        end
    end

    if total == 0 then return nil, locale('climates.no_weather') end

    local colour = type(input.colour) == 'table' and input.colour or {}
    local temperature = type(input.temperature) == 'table' and input.temperature or {}
    local duration = type(input.duration) == 'table' and input.duration or {}
    local shortest = integer(duration[1], 1, 240, 20)

    return {
        id = id,
        label = label,
        colour = { integer(colour[1], 0, 255, 160), integer(colour[2], 0, 255, 160), integer(colour[3], 0, 255, 160) },
        weathers = weathers,
        temperature = {
            day = integer(temperature.day, -40, 55, 20),
            night = integer(temperature.night, -40, 55, 10),
        },
        humidity = integer(input.humidity, 0, 100, 50),
        duration = { shortest, integer(duration[2], shortest, 240, shortest) },
        wind = lib.math.round(number(input.wind, 0, 3, 1), 1),
        seasons = input.seasons ~= false,
    }
end

---@return ClimateRecord[]
function Climates:list()
    local list = {}

    for _, climate in pairs(self.records) do list[#list + 1] = climate end
    table.sort(list, function(a, b) return a.label < b.label end)

    return list
end

---@param id string
---@return ClimateRecord?
function Climates:get(id)
    return self.records[id]
end

---@param fn fun(list: ClimateRecord[])
function Climates:onChange(fn)
    self.listeners[#self.listeners + 1] = fn
end

function Climates:publish()
    local list = self:list()

    Climate.set(list)
    GlobalState.weatherClimates = list

    for _, fn in ipairs(self.listeners) do fn(list) end
end

--- Regions check their climate exists, so they load after this does.
function Climates:whenLoaded(fn)
    if self.loaded then return fn() end
    self.waiting[#self.waiting + 1] = fn
end

--------------------------------------------------------------------------------
-- Storage (oxmysql)
--------------------------------------------------------------------------------

local SCHEMA <const> = {
    [[CREATE TABLE IF NOT EXISTS `dynamicworld_climates` (
        `id` VARCHAR(32) NOT NULL,
        `label` VARCHAR(20) NOT NULL,
        `colour` CHAR(7) NOT NULL,
        `day` TINYINT NOT NULL,
        `night` TINYINT NOT NULL,
        `humidity` TINYINT UNSIGNED NOT NULL,
        `duration_min` SMALLINT UNSIGNED NOT NULL,
        `duration_max` SMALLINT UNSIGNED NOT NULL,
        `wind` DECIMAL(2,1) NOT NULL DEFAULT 1.0,
        `seasons` TINYINT(1) NOT NULL DEFAULT 1,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`)
    )]],
    [[CREATE TABLE IF NOT EXISTS `dynamicworld_climate_weathers` (
        `climate` VARCHAR(32) NOT NULL,
        `weather` VARCHAR(16) NOT NULL,
        `weight` TINYINT UNSIGNED NOT NULL,
        PRIMARY KEY (`climate`, `weather`),
        FOREIGN KEY (`climate`) REFERENCES `dynamicworld_climates` (`id`) ON DELETE CASCADE
    )]],
}

---@param colour number[]
---@return string
local function toHex(colour)
    return ('#%02x%02x%02x'):format(colour[1], colour[2], colour[3])
end

---@param hex string
---@return number[]?
local function fromHex(hex)
    local r, g, b = tostring(hex):match('#?(%x%x)(%x%x)(%x%x)')
    return r and { tonumber(r, 16), tonumber(g, 16), tonumber(b, 16) }
end

--- One transaction: the climate row, then its weathers replaced wholesale.
local function store(climate)
    local queries = {
        {
            query = [[INSERT INTO `dynamicworld_climates`
                (`id`, `label`, `colour`, `day`, `night`, `humidity`, `duration_min`, `duration_max`, `wind`, `seasons`)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE `label` = VALUES(`label`), `colour` = VALUES(`colour`), `day` = VALUES(`day`),
                `night` = VALUES(`night`), `humidity` = VALUES(`humidity`), `duration_min` = VALUES(`duration_min`),
                `duration_max` = VALUES(`duration_max`), `wind` = VALUES(`wind`), `seasons` = VALUES(`seasons`)]],
            values = {
                climate.id, climate.label, toHex(climate.colour), climate.temperature.day, climate.temperature.night,
                climate.humidity, climate.duration[1], climate.duration[2], climate.wind, climate.seasons and 1 or 0,
            },
        },
        { query = 'DELETE FROM `dynamicworld_climate_weathers` WHERE `climate` = ?', values = { climate.id } },
    }

    for weather, weight in pairs(climate.weathers) do
        queries[#queries + 1] = {
            query = 'INSERT INTO `dynamicworld_climate_weathers` (`climate`, `weather`, `weight`) VALUES (?, ?, ?)',
            values = { climate.id, weather, weight },
        }
    end

    MySQL.transaction(queries)
end

function Climates:load()
    for _, query in ipairs(SCHEMA) do MySQL.query.await(query) end

    local rows = MySQL.query.await('SELECT * FROM `dynamicworld_climates`') or {}
    local weathers = {}

    for _, row in ipairs(MySQL.query.await('SELECT * FROM `dynamicworld_climate_weathers`') or {}) do
        weathers[row.climate] = weathers[row.climate] or {}
        weathers[row.climate][row.weather] = row.weight
    end

    for _, row in ipairs(rows) do
        local climate = Climates.sanitise({
            label = row.label,
            colour = fromHex(row.colour),
            weathers = weathers[row.id],
            temperature = { day = row.day, night = row.night },
            humidity = row.humidity,
            duration = { row.duration_min, row.duration_max },
            wind = row.wind,
            seasons = row.seasons == 1 or row.seasons == true,
        }, row.id)

        if climate then
            self.records[climate.id] = climate
        else
            lib.print.warn(('skipped climate %s: it has no weathers'):format(row.id))
        end
    end

    -- First start: seed from data/climates.lua.
    if #rows == 0 then
        for id, entry in pairs(Seeds) do
            local climate = Climates.sanitise(entry, id)

            if climate then
                self.records[climate.id] = climate
                store(climate)
            end
        end
    end

    self:publish()
    self.loaded = true

    for _, fn in ipairs(self.waiting) do fn() end
    self.waiting = {}
end

--- How many regions use a climate, the default region included.
function Climates:usage(id)
    local count = 0

    for _, region in ipairs(GlobalState.weatherRegions or {}) do
        if region.climate == id then count = count + 1 end
    end

    return count
end

---@param input table
---@return ClimateRecord? climate
---@return string? reason
function Climates:save(input)
    local climate, reason = Climates.sanitise(input)
    if not climate then return nil, reason end

    self.records[climate.id] = climate
    store(climate)
    self:publish()

    return climate
end

---@param id string
---@return boolean ok
---@return string? reason
function Climates:delete(id)
    if not self.records[id] then return false, locale('climates.missing') end

    local used = self:usage(id)
    if used > 0 then return false, locale('climates.in_use', used) end

    self.records[id] = nil
    MySQL.update('DELETE FROM `dynamicworld_climates` WHERE `id` = ?', { id })
    self:publish()

    return true
end

MySQL.ready(function() Climates:load() end)

--------------------------------------------------------------------------------
-- Editor
--------------------------------------------------------------------------------

---@param name string
---@param fn fun(source: number, data: table)
local function adminEvent(name, fn)
    RegisterNetEvent(name, function(data)
        local source = source

        if not IsPlayerAceAllowed(tostring(source), ('command.%s'):format(Editor.command)) then
            return lib.print.warn(('%s (%d) used %s without permission'):format(GetPlayerName(source), source, name))
        end

        fn(source, type(data) == 'table' and data or {})
    end)
end

adminEvent('amphy_dynamicworld:server:saveClimate', function(source, data)
    local climate, reason = Climates:save(data)
    lib.notify(source, { description = climate and locale('climates.saved', climate.label) or reason, type = climate and 'success' or 'error' })
end)

adminEvent('amphy_dynamicworld:server:deleteClimate', function(source, data)
    local ok, reason = Climates:delete(data.id)
    lib.notify(source, { description = ok and locale('climates.deleted') or reason, type = ok and 'success' or 'error' })
end)

exports('getClimates', function() return Climates:list() end)
exports('saveClimate', function(input)
    local climate, reason = Climates:save(input)
    return climate and climate.id, reason
end)
exports('deleteClimate', function(id) return Climates:delete(id) end)
