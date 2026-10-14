return {
    tickInterval = 10000, -- ms between updates

    -- What builds exposure, and how much each counts.
    weights = {
        scumminess = 1.6, -- grimy parts of the map (GTA's zone scumminess)
        cold = 3.0,
        heat = 2.0,
        wet = 2.2,        -- out in rain or snow
        humidity = 1.0,
        contagion = 2.5,  -- standing near someone contagious
    },

    tooCold = 5,   -- felt °C below which cold counts
    tooHot = 32,   -- felt °C above which heat counts
    tooHumid = 85, -- humidity % above which it counts

    -- Inside a building, or a vehicle with its roof up.
    indoors = {
        vehicles = true,
        temperature = 20,
        humidity = 50,
        scumminess = 0.25, -- share of the area's grime that still reaches you
    },

    exposure = {
        recovery = 2.0,       -- lost per tick when nothing is building it
        indoorRecovery = 5.0,
        infectAbove = 35,     -- exposure (0-100) needed before infections can start
        infectChance = 0.08,  -- chance per tick at full exposure
    },

    immunity = 300, -- seconds of immunity after recovering

    contagion = {
        enabled = true,
        radius = 4.0,
        perPlayer = 0.34,
        indoorMultiplier = 1.5,
    },

    -- Saved per character (qbx citizenid) to the dynamicworld_sickness table.
    persistence = {
        enabled = true,
        expireAfterDays = 14,
    },

    -- /dwshowcase walks a player through every stage.
    showcase = {
        stageDuration = 9000,
        coughInterval = 6000,
        restoreHealth = true,
    },
}
