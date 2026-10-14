return {
    -- false: every region keeps its weather until an admin or export changes it.
    dynamic = true,

    blend = {
        weather = 45.0, -- seconds to blend when a region's weather changes
        region = 20.0,  -- seconds to blend when crossing into another region
    },

    border = {
        dwell = 2500,             -- ms a player must stay past a border before it counts
        checkInterval = 500,      -- ms between position checks
        teleportDistance = 400.0, -- moving further than this between checks snaps instead of blending
    },

    -- Chance a change ignores the transitions below and picks straight from the climate,
    -- so every weather a climate lists can turn up.
    surprise = 0.12,

    blackout = false,

    -- Scripts written for a single sky (HUDs reading GlobalState.weather) see this region.
    primaryRegion = 'los_santos',

    -- Used while an interior or shell pauses a player's sync.
    interior = {
        weather = 'EXTRASUNNY',
        time = { hour = 21, minute = 0 },
        freeze = true,
    },

    -- Fixed weather for every region between two dates (MM-DD). Climates with
    -- seasons = false are left alone.
    seasons = {
        { weather = 'HALLOWEEN', from = '10-25', to = '10-31' },
        { weather = 'XMAS', from = '12-01', to = '12-31' },
    },

    labels = {
        EXTRASUNNY = 'Extra sunny',
        CLEAR      = 'Clear',
        NEUTRAL    = 'Neutral',
        SMOG       = 'Smog',
        FOGGY      = 'Foggy',
        OVERCAST   = 'Overcast',
        CLOUDS     = 'Cloudy',
        CLEARING   = 'Clearing',
        RAIN       = 'Rain',
        THUNDER    = 'Thunderstorm',
        SNOWLIGHT  = 'Light snow',
        SNOW       = 'Snow',
        BLIZZARD   = 'Blizzard',
        XMAS       = 'Deep snow',
        HALLOWEEN  = 'Halloween',
    },

    -- Wind speed range per weather. A climate's wind value scales it.
    wind = {
        default    = { 0.2, 1.0 },
        EXTRASUNNY = { 0.0, 0.4 },
        CLEAR      = { 0.1, 0.5 },
        SMOG       = { 0.0, 0.3 },
        FOGGY      = { 0.0, 0.2 },
        CLOUDS     = { 0.4, 1.1 },
        OVERCAST   = { 0.6, 1.4 },
        CLEARING   = { 0.4, 1.0 },
        RAIN       = { 0.8, 1.8 },
        THUNDER    = { 1.4, 2.6 },
        SNOWLIGHT  = { 0.5, 1.2 },
        SNOW       = { 0.8, 1.8 },
        BLIZZARD   = { 2.0, 3.5 },
    },

    -- What tends to follow what. Each weight is multiplied by the climate's weight
    -- for that weather, so clouds come before rain everywhere, but a desert rarely
    -- gets past the clouds.
    transitions = {
        EXTRASUNNY = { CLEAR = 6, CLOUDS = 3, SMOG = 1 },
        CLEAR      = { EXTRASUNNY = 4, CLOUDS = 4, SMOG = 1, FOGGY = 1 },
        NEUTRAL    = { CLEAR = 4, CLOUDS = 4, OVERCAST = 2 },
        SMOG       = { CLEAR = 3, CLOUDS = 3, FOGGY = 2 },
        FOGGY      = { CLEARING = 4, CLOUDS = 3, OVERCAST = 2 },
        CLOUDS     = { CLEARING = 3, OVERCAST = 4, CLEAR = 3, FOGGY = 1, SNOWLIGHT = 1 },
        OVERCAST   = { RAIN = 4, CLOUDS = 3, CLEARING = 2, FOGGY = 1, SNOWLIGHT = 3 },
        RAIN       = { THUNDER = 2, CLEARING = 5, OVERCAST = 3 },
        THUNDER    = { RAIN = 4, CLEARING = 3 },
        CLEARING   = { CLEAR = 5, CLOUDS = 3, EXTRASUNNY = 2 },
        SNOWLIGHT  = { SNOW = 3, CLEARING = 2, OVERCAST = 2 },
        SNOW       = { SNOWLIGHT = 3, BLIZZARD = 1, OVERCAST = 2 },
        BLIZZARD   = { SNOW = 4, SNOWLIGHT = 2 },
        XMAS       = { SNOWLIGHT = 2, SNOW = 2 },
        HALLOWEEN  = { FOGGY = 3, OVERCAST = 2 },
    },
}
