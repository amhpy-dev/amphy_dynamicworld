-- The climates the server starts with. Written to the dynamicworld_climates table on first start;
-- after that create and edit them in game (/weatherregions, Climates). Empty the
-- table to start over from this list.
--
-- A region picks one of these. A climate decides:
--   weathers     which weather it gets and how often (missing = never on its own)
--   duration     real minutes each weather lasts, picked between the two
--   temperature  °C at the hottest and coldest hour of a clear day
--   humidity     base %, weather pushes it up or down
--   wind         multiplier on the wind ranges in data/weather.lua
--   seasons      false to ignore the Halloween/Christmas weather
--   colour       on the editor map (bright, the map is dark)
--
-- Numbers are yearly averages of the real places each one stands in for.

return {
    -- Coastal Los Angeles: fair most of the year, June gloom, rain on about 1 day in 10.
    temperate = {
        label = 'Temperate',
        colour = { 102, 187, 106 },
        duration = { 20, 40 },
        weathers = {
            EXTRASUNNY = 22, CLEAR = 30, CLOUDS = 16, OVERCAST = 9, CLEARING = 6,
            SMOG = 7, FOGGY = 4, RAIN = 5, THUNDER = 1,
        },
        temperature = { day = 24, night = 14 },
        humidity = 62,
        wind = 1.0,
    },

    -- Mojave / Salton Sea: huge day-night swing, bone dry, rare monsoon storms.
    desert = {
        label = 'Desert',
        colour = { 255, 138, 76 },
        duration = { 30, 60 },
        weathers = {
            EXTRASUNNY = 50, CLEAR = 32, CLOUDS = 7, SMOG = 4, CLEARING = 3,
            OVERCAST = 2, THUNDER = 2,
        },
        temperature = { day = 36, night = 19 },
        humidity = 22,
        wind = 1.2,
    },

    -- Northern California redwood coast: mild, grey, small day-night swing.
    coastal = {
        label = 'Coastal forest',
        colour = { 38, 198, 180 },
        duration = { 20, 40 },
        weathers = {
            CLEAR = 14, CLOUDS = 22, OVERCAST = 22, FOGGY = 16, RAIN = 16,
            THUNDER = 2, CLEARING = 8,
        },
        temperature = { day = 17, night = 9 },
        humidity = 80,
        wind = 1.3,
    },

    -- High Sierra in the snow season: below freezing at night, clear spells between storms.
    alpine = {
        label = 'Alpine',
        colour = { 120, 190, 255 },
        duration = { 15, 35 },
        weathers = {
            SNOWLIGHT = 24, SNOW = 16, BLIZZARD = 4, OVERCAST = 18, CLOUDS = 12,
            FOGGY = 6, CLEAR = 14, CLEARING = 6,
        },
        temperature = { day = 2, night = -9 },
        humidity = 60,
        wind = 1.5,
    },

    -- Caribbean: warm nights, humid, short heavy showers.
    tropical = {
        label = 'Tropical',
        colour = { 240, 98, 146 },
        duration = { 15, 30 },
        weathers = {
            EXTRASUNNY = 30, CLEAR = 26, CLOUDS = 18, OVERCAST = 6, RAIN = 12,
            THUNDER = 6, CLEARING = 2,
        },
        temperature = { day = 31, night = 24 },
        humidity = 76,
        wind = 0.9,
        seasons = false,
    },
}
