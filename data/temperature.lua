-- How weather and the time of day move a climate's numbers.
return {
    hottestHour = 15, -- the coldest is twelve hours later

    -- °C added on top of the day/night curve.
    weatherTemperature = {
        EXTRASUNNY = 2, CLEAR = 0, SMOG = 1, CLEARING = -1, CLOUDS = -1, OVERCAST = -2,
        FOGGY = -3, RAIN = -4, THUNDER = -5, SNOWLIGHT = -2, SNOW = -4, BLIZZARD = -7,
        XMAS = -5, HALLOWEEN = -2,
    },

    -- Humidity % added on top of the climate's base.
    weatherHumidity = {
        EXTRASUNNY = -10, CLEAR = -5, SMOG = 5, CLEARING = 0, CLOUDS = 5, OVERCAST = 10,
        FOGGY = 25, RAIN = 25, THUNDER = 25, SNOWLIGHT = 15, SNOW = 20, BLIZZARD = 20,
        XMAS = 10, HALLOWEEN = 15,
    },

    nightHumidity = 15, -- extra % at the coldest hour, as cooler air holds less water

    -- "Feels like" adjustments, in line with the NWS wind chill and heat index.
    windChill = { below = 10, perWind = -2.0, max = -10 },
    heatIndex = { above = 27, pivot = 40, perHumidity = 0.15, max = 10 },
    wetChill = -2,

    -- Names for felt temperature, checked top to bottom.
    bands = {
        { below = 0, name = 'freezing' },
        { below = 10, name = 'cold' },
        { below = 16, name = 'cool' },
        { below = 25, name = 'comfortable' },
        { below = 32, name = 'warm' },
        { name = 'hot' },
    },
}
