-- The regions the map starts with. Written to the dynamicworld_regions table on first start;
-- after that edit them in game with /weatherregions. Empty the table to start
-- over from this list.
--
--   shape     'poly' with points, or 'circle' with coords and radius (world X/Y)
--   climate   a key from data/climates.lua
--   priority  where regions overlap the higher one wins (ties: the smaller one)
--   floor     optional, the region only applies above this height

return {
    -- Everywhere no region covers, like the open sea.
    default = {
        label = 'San Andreas',
        climate = 'temperate',
    },

    regions = {
        {
            id = 'los_santos',
            label = 'Los Santos',
            climate = 'temperate',
            priority = 10,
            shape = 'poly',
            points = {
                { x = -3400, y = 1500 }, { x = 1200, y = 1500 }, { x = 2500, y = 700 },
                { x = 2900, y = -1300 }, { x = 1800, y = -3000 }, { x = 800, y = -3900 },
                { x = -1600, y = -3900 }, { x = -2700, y = -1800 }, { x = -3400, y = -300 },
            },
        },
        {
            id = 'grand_senora',
            label = 'Grand Senora Desert',
            climate = 'desert',
            priority = 10,
            shape = 'poly',
            points = {
                { x = 0, y = 2300 }, { x = 1300, y = 1700 }, { x = 2700, y = 1500 },
                { x = 3700, y = 2300 }, { x = 3800, y = 3700 }, { x = 2600, y = 4100 },
                { x = 1500, y = 4300 }, { x = 400, y = 3600 }, { x = -300, y = 3000 },
            },
        },
        {
            id = 'blaine_north',
            label = 'North Blaine',
            climate = 'coastal',
            priority = 10,
            shape = 'poly',
            points = {
                { x = -3200, y = 4200 }, { x = -200, y = 3700 }, { x = 1500, y = 4300 },
                { x = 2600, y = 4100 }, { x = 3900, y = 4300 }, { x = 4100, y = 6800 },
                { x = 1800, y = 7600 }, { x = -600, y = 7800 }, { x = -2400, y = 6200 },
            },
        },
        {
            id = 'mount_chiliad',
            label = 'Mount Chiliad',
            climate = 'alpine',
            priority = 20,
            shape = 'circle',
            coords = { x = 500, y = 5600 },
            radius = 900,
            floor = 300,
        },
        {
            id = 'cayo_perico',
            label = 'Cayo Perico',
            climate = 'tropical',
            priority = 10,
            shape = 'circle',
            coords = { x = 4900, y = -5100 },
            radius = 1600,
        },
    },
}
