return {
    -- Turn whole systems on or off.
    enable = {
        weather = true,        -- regional weather, wind and blackouts
        time = true,           -- synced day/night cycle
        sickness = true,       -- catching, worsening and recovering from illness
        cures = true,          -- ox_inventory items that treat sickness
        regionNotify = false,  -- tell players when they cross into another region
        compatibility = true,  -- answer qb-weathersync and vSync calls from other resources
    },

    -- ox_lib group allowed to use the admin commands and the region editor.
    adminGroup = 'group.admin',
}
