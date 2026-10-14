return {
    command = 'weatherregions',

    placement = {
        reach = 60.0,       -- how far you can aim
        minRadius = 25.0,
        maxRadius = 4000.0,
        step = 10.0,        -- per scroll
        fastStep = 100.0,   -- per scroll with shift held
    },

    -- Leaflet map. `tiles` is relative to web/, or a full URL to another resource's
    -- tiles. Only change the four numbers if your tile set is calibrated differently.
    -- For the light atlas instead: tiles = 'mapStyles/{z}/{x}/{y}.jpg',
    -- emptyTile = 'mapStyles/empty.jpg', background = '#0fa8d2'.
    map = {
        tiles = 'mapStyles/dark/{z}/{x}/{y}.jpg',
        emptyTile = 'mapStyles/dark/empty.jpg',
        minZoom = 0,
        maxZoom = 5,
        zoom = 2,
        background = '#132b43',

        centreX = 117.3,
        centreY = 172.8,
        scaleX = 0.02072,
        scaleY = 0.0205,
    },
}
