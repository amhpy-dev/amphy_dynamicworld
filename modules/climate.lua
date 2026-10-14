---@class ClimateRecord
---@field id string
---@field label string
---@field colour number[] r, g, b
---@field weathers table<string, number> weather -> weight
---@field temperature { day: number, night: number }
---@field humidity number
---@field duration number[] shortest, longest (real minutes)
---@field wind number
---@field seasons boolean

---@class LiveWeather
---@field weather string
---@field windSpeed number
---@field windDirection number
---@field isRain boolean
---@field time integer os.time() of the next change
---@field forced boolean
---@field blackout boolean

---@class Conditions
---@field region string
---@field label? string
---@field climate string
---@field weather string
---@field weatherLabel string
---@field temperature number
---@field humidity number
---@field feelsLike number
---@field band string
---@field windSpeed number
---@field time { hour: number, minute: number }
---@field timePeriod string
---@field isNight boolean
---@field precipitating boolean
---@field raining boolean
---@field snowing boolean

local Climate = {}

local model <const> = lib.load('data.temperature')
local labels <const> = lib.load('data.weather').labels
local fallback <const> = lib.load('data.regions').default.climate

Climate.WEATHERS = {
    'EXTRASUNNY', 'CLEAR', 'NEUTRAL', 'SMOG', 'FOGGY', 'OVERCAST', 'CLOUDS', 'CLEARING',
    'RAIN', 'THUNDER', 'SNOWLIGHT', 'SNOW', 'BLIZZARD', 'XMAS', 'HALLOWEEN',
}

Climate.VALID = {}
Climate.BY_HASH = {}

for _, name in ipairs(Climate.WEATHERS) do
    Climate.VALID[name] = true
    Climate.BY_HASH[joaat(name)] = name
end

Climate.RAIN = { RAIN = true, THUNDER = true }
Climate.SNOW = { SNOWLIGHT = true, SNOW = true, BLIZZARD = true, XMAS = true }

---@param weather any
---@return string?
function Climate.normalise(weather)
    weather = type(weather) == 'string' and weather:upper()
    return Climate.VALID[weather] and weather or nil
end

---@param weather? string
---@return string
function Climate.label(weather)
    return labels[weather] or weather or 'Unknown'
end

---@param weather? string
---@return boolean
function Climate.isPrecipitating(weather)
    return Climate.RAIN[weather] or Climate.SNOW[weather] or false
end

-- Edited in game and published by server/climates.lua; data/climates.lua only
-- seeds the first start.
local climates = lib.load('data.climates')

---@param list table[] climate records, each with an id
function Climate.set(list)
    local byId = {}
    for _, climate in ipairs(list or {}) do byId[climate.id] = climate end
    if next(byId) then climates = byId end
end

---@param id? string
---@return boolean
function Climate.exists(id)
    return climates[id] ~= nil
end

---@param id? string
---@return ClimateRecord
function Climate.get(id)
    return climates[id] or climates[fallback] or select(2, next(climates))
end

---@return table<string, ClimateRecord>
function Climate.all()
    return climates
end

if not IsDuplicityVersion() then
    Climate.set(GlobalState.weatherClimates)
    AddStateBagChangeHandler('weatherClimates', 'global', function(_, _, value) Climate.set(value) end)
end

-- 1 at the hottest hour, 0 twelve hours later.
---@param hour number
---@param minute? number
---@return number 0-1
local function warmth(hour, minute)
    local h = hour + (minute or 0) / 60
    return (math.cos((h - model.hottestHour) / 24 * 2 * math.pi) + 1) / 2
end

---@param temperature number
---@param humidity number
---@param wind number
---@param weather? string
---@return number
local function feelsLike(temperature, humidity, wind, weather)
    local felt = temperature
    local chill, index = model.windChill, model.heatIndex

    if temperature < chill.below then
        felt = felt + math.max(chill.max, wind * chill.perWind)
    end

    if temperature > index.above then
        felt = felt + lib.math.clamp((humidity - index.pivot) * index.perHumidity, 0, index.max)
    end

    if Climate.isPrecipitating(weather) then
        felt = felt + model.wetChill
    end

    return felt
end

---@param temperature number
---@return string
function Climate.band(temperature)
    for _, band in ipairs(model.bands) do
        if not band.below or temperature < band.below then return band.name end
    end
end

---@param hour number
---@return string
function Climate.timePeriod(hour)
    return hour < 6 and 'EARLY_MORNING' or hour < 12 and 'MORNING' or hour < 18 and 'AFTERNOON' or 'EVENING'
end

---@param hour number
---@return boolean
function Climate.isNight(hour)
    return hour >= 20 or hour < 6
end

--- Every derived number for one climate, weather and moment.
function Climate.conditions(climateId, weather, hour, minute, wind)
    local climate = Climate.get(climateId)
    local heat = warmth(hour, minute)
    wind = wind or 0

    local temperature = climate.temperature.night
        + (climate.temperature.day - climate.temperature.night) * heat
        + (model.weatherTemperature[weather] or 0)

    local humidity = lib.math.clamp(climate.humidity
        + (model.weatherHumidity[weather] or 0)
        + model.nightHumidity * (1 - heat), 5, 100)

    local felt = feelsLike(temperature, humidity, wind, weather)

    return {
        climate = climateId,
        weather = weather,
        weatherLabel = Climate.label(weather),
        temperature = lib.math.round(temperature, 1),
        humidity = math.floor(humidity + 0.5),
        feelsLike = lib.math.round(felt, 1),
        band = Climate.band(felt),
        windSpeed = wind,
        time = { hour = hour, minute = minute },
        timePeriod = Climate.timePeriod(hour),
        isNight = Climate.isNight(hour),
        precipitating = Climate.isPrecipitating(weather),
        raining = Climate.RAIN[weather] == true,
        snowing = Climate.SNOW[weather] == true,
    }
end

return Climate
