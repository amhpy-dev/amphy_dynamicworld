local Climate = require 'modules.climate'

local Settings <const> = lib.load('data.settings')
local cfg <const> = lib.load('data.weather')
local NEVER <const> = 9999999999
local TAU <const> = 2 * math.pi

Weather = {
    states = {},
    dynamic = cfg.dynamic,
    blackout = cfg.blackout,
}

--------------------------------------------------------------------------------
-- Picking weather
--------------------------------------------------------------------------------

---@param pool table<string, number>
---@return string?
local function weighted(pool)
    local total = 0
    for _, weight in pairs(pool) do total = total + weight end
    if total <= 0 then return end

    local roll = math.random() * total

    for name, weight in pairs(pool) do
        roll = roll - weight
        if roll <= 0 then return name end
    end
end

---@param climate ClimateRecord
---@param except? string
---@return string
local function pickAny(climate, except)
    local pool = {}

    for name, weight in pairs(climate.weathers) do
        if name ~= except then pool[name] = weight end
    end

    return weighted(pool) or except or 'CLEAR'
end

---@param current string
---@param climate ClimateRecord
---@return string
local function pickNext(current, climate)
    if math.random() < cfg.surprise then return pickAny(climate, current) end

    local pool = {}

    for name, weight in pairs(cfg.transitions[current] or {}) do
        if name ~= current then pool[name] = weight * (climate.weathers[name] or 0) end
    end

    return weighted(pool) or pickAny(climate, current)
end

---@param climate ClimateRecord
---@return integer ms
local function duration(climate)
    local low, high = climate.duration[1], climate.duration[2]
    return math.floor((low + math.random() * (high - low)) * 60000)
end

---@param state table
---@param climate ClimateRecord
local function rollWind(state, climate)
    local range = cfg.wind[state.weather] or cfg.wind.default

    state.windSpeed = (range[1] + math.random() * (range[2] - range[1])) * (climate.wind or 1.0)
    state.windDirection = ((state.windDirection or math.random() * TAU) + (math.random() - 0.5) * 1.2) % TAU
end

--------------------------------------------------------------------------------
-- Seasons
--------------------------------------------------------------------------------

---@param date string MM-DD
---@return integer
local function dayOfYear(date)
    local month, day = date:match('(%d+)-(%d+)')
    return tonumber(month) * 100 + tonumber(day)
end

---@param today integer
---@param from integer
---@param to integer
---@return boolean
local function within(today, from, to)
    if from <= to then return today >= from and today <= to end
    return today >= from or today <= to
end

---@return table?
local function currentSeason()
    local today = tonumber(os.date('%m%d'))

    for _, season in ipairs(cfg.seasons) do
        if within(today, dayOfYear(season.from), dayOfYear(season.to)) then return season end
    end
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

---@param id string
---@return ClimateRecord
function Weather:climateOf(id)
    local region = Regions:get(id)
    return Climate.get(region and region.climate)
end

--- The season's weather, if the season holds this region.
function Weather:seasonFor(id)
    return self.season and self:climateOf(id).seasons ~= false and self.season.weather or nil
end

--- nil, '*' or 'all' mean every region.
function Weather:targets(region)
    if region == nil or region == '*' or region == 'all' then
        local ids = {}
        for id in pairs(self.states) do ids[#ids + 1] = id end
        return ids
    end

    return self.states[region] and { region }
end

---@param id string
---@param state table
---@return LiveWeather
function Weather:payload(id, state)
    local held = state.forced or not self.dynamic or self:seasonFor(id)

    return {
        weather = state.weather,
        windSpeed = state.windSpeed,
        windDirection = state.windDirection,
        isRain = Climate.isPrecipitating(state.weather),
        time = held and NEVER or os.time() + state.remaining // 1000,
        forced = state.forced,
        blackout = state.blackout,
    }
end

function Weather:publish()
    local all = {}

    for id, state in pairs(self.states) do all[id] = self:payload(id, state) end

    GlobalState.regionWeather = all
    GlobalState.weather = all[cfg.primaryRegion] or all.default
    GlobalState.season = self.season and self.season.weather or false
end

---@param id string
function Weather:ensure(id)
    if self.states[id] then return end

    local climate = self:climateOf(id)
    local state = {
        weather = self:seasonFor(id) or pickAny(climate),
        remaining = math.floor(duration(climate) * (0.3 + math.random() * 0.7)),
        forced = false,
        blackout = false,
    }

    rollWind(state, climate)
    self.states[id] = state
end

---@param forced? boolean nil keeps it as it was
function Weather:apply(id, weather, forced)
    local state = self.states[id]
    local climate = self:climateOf(id)
    local previous = state.weather

    state.weather = weather
    state.remaining = duration(climate)
    if forced ~= nil then state.forced = forced end
    rollWind(state, climate)

    if previous ~= weather then
        TriggerEvent('amphy_dynamicworld:weatherChanged', id, weather, previous, state.forced)
    end
end

--------------------------------------------------------------------------------
-- Controls
--------------------------------------------------------------------------------

---@param region? string nil for everywhere
function Weather:set(weather, region)
    weather = Climate.normalise(weather)
    local ids = self:targets(region)
    if not weather or not ids then return false end

    for _, id in ipairs(ids) do self:apply(id, weather, true) end

    self:publish()
    return true
end

--- Hand a region (or every region) back to its climate.
function Weather:release(region)
    local ids = self:targets(region)
    if not ids then return false end

    if not region then self.dynamic = true end

    for _, id in ipairs(ids) do
        self.states[id].forced = false
        self.states[id].remaining = duration(self:climateOf(id))
    end

    self:publish()
    return true
end

---@param region? string
---@return boolean
function Weather:advance(region)
    local ids = self:targets(region)
    if not ids then return false end

    for _, id in ipairs(ids) do
        self:apply(id, self:seasonFor(id) or pickNext(self.states[id].weather, self:climateOf(id)))
    end

    self:publish()
    return true
end

---@param region? string
---@return boolean
function Weather:hold(region)
    local ids = self:targets(region)
    if not ids then return false end

    for _, id in ipairs(ids) do self.states[id].forced = true end

    self:publish()
    return true
end

---@param state boolean
function Weather:setDynamic(state)
    self.dynamic = state
    self:publish()
end

---@param state boolean
function Weather:setBlackout(state)
    self.blackout = state
    GlobalState.blackOut = state
end

---@param region? string
---@param state boolean
---@return boolean
function Weather:setRegionBlackout(region, state)
    local ids = self:targets(region)
    if not ids then return false end

    for _, id in ipairs(ids) do self.states[id].blackout = state end

    self:publish()
    return true
end

function Weather:applySeason()
    local season = currentSeason()
    if season == self.season then return end

    local ended = self.season ~= nil
    self.season = season

    for id, state in pairs(self.states) do
        if not state.forced then
            local weather = self:seasonFor(id)

            if weather then
                self:apply(id, weather)
            elseif ended then
                self:apply(id, pickNext(state.weather, self:climateOf(id)))
            end
        end
    end

    self:publish()
end

---@param dt number ms since the last tick
function Weather:tick(dt)
    if not self.dynamic then return end

    local changed = false

    for id, state in pairs(self.states) do
        if not state.forced and not self:seasonFor(id) then
            state.remaining = state.remaining - dt

            if state.remaining <= 0 then
                self:apply(id, pickNext(state.weather, self:climateOf(id)))
                changed = true
            end
        end
    end

    if changed then self:publish() end
end

--------------------------------------------------------------------------------
-- Conditions
--------------------------------------------------------------------------------

---@param id string
---@return Conditions?
function Weather:conditions(id)
    local state = self.states[id] or self.states.default
    local region = Regions:get(id) or Regions:get('default')
    local hour, minute = Clock:get()
    local result = Climate.conditions(region.climate, state.weather, hour, minute, state.windSpeed)

    result.region = region.id
    result.label = region.label
    result.forced = state.forced
    result.blackout = self.blackout or state.blackout
    result.season = GlobalState.season

    return result
end

---@param source number
---@return Conditions?
function Weather:forPlayer(source)
    return self:conditions(Regions:forPlayer(source))
end

--------------------------------------------------------------------------------
-- Single players
--------------------------------------------------------------------------------

Weather.playerBlackouts = {}

---@param options? { weather?: string, time?: table, freeze?: boolean, blackout?: boolean }
function Weather:setPlayerSync(source, state, options)
    TriggerClientEvent('amphy_dynamicworld:client:setSync', source, state, options)
end

---@param source number
---@param state boolean
function Weather:setPlayerBlackout(source, state)
    self.playerBlackouts[source] = state or nil
    TriggerClientEvent('amphy_dynamicworld:client:setBlackout', source, state)
end

AddEventHandler('playerDropped', function()
    Weather.playerBlackouts[source] = nil
end)

--------------------------------------------------------------------------------
-- Boot
--------------------------------------------------------------------------------

--- Bring live state in line with the regions and their climates: new regions get
--- weather, removed ones lose it, and a region whose climate no longer allows what
--- it is doing rolls something that fits.
local function reconcile(list)
    local seen = {}

    for _, region in ipairs(list) do
        seen[region.id] = true

        local state = Weather.states[region.id]

        if not state then
            Weather:ensure(region.id)
        elseif not state.forced and not Weather:seasonFor(region.id) and not Climate.get(region.climate).weathers[state.weather] then
            Weather:apply(region.id, pickAny(Climate.get(region.climate)))
        end
    end

    for id in pairs(Weather.states) do
        if not seen[id] then Weather.states[id] = nil end
    end

    Weather:publish()
end

Regions:onChange(reconcile)
Climates:onChange(function() reconcile(Regions:list()) end)

if Settings.enable.weather then
    for _, region in ipairs(Regions:list()) do Weather:ensure(region.id) end

    Weather:setBlackout(Weather.blackout)
    Weather:applySeason()
    Weather:publish()

    lib.cron.new('* * * * *', function() Weather:applySeason() end)

    CreateThread(function()
        local last = GetGameTimer()

        while true do
            Wait(1000)

            local now = GetGameTimer()
            Weather:tick(now - last)
            last = now
        end
    end)
end

--------------------------------------------------------------------------------
-- Exports
--------------------------------------------------------------------------------

exports('setWeather', function(weather, region) return Weather:set(weather, region) end)
exports('releaseWeather', function(region) return Weather:release(region) end)
exports('advanceWeather', function(region) return Weather:advance(region) end)
exports('holdWeather', function(region) return Weather:hold(region) end)
exports('setDynamicWeather', function(state) Weather:setDynamic(state == true) end)
exports('setBlackout', function(state) Weather:setBlackout(state == true) end)
exports('setRegionBlackout', function(region, state) return Weather:setRegionBlackout(region, state == true) end)

exports('getRegionWeather', function(region)
    local state = Weather.states[region]
    return state and Weather:payload(region, state)
end)

exports('getAllRegionWeather', function() return GlobalState.regionWeather end)
exports('getRegionConditions', function(region) return Weather:conditions(region) end)
exports('getPlayerWeather', function(source) return Weather:forPlayer(source) end)
exports('setPlayerSync', function(source, state, options) Weather:setPlayerSync(source, state, options) end)
exports('setPlayerBlackout', function(source, state) Weather:setPlayerBlackout(source, state == true) end)
