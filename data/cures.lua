-- ox_inventory items that treat sickness. The key is the item name.
--   cures           sickness ids it treats, or 'all'
--   removeSeverity  severity taken off (100 = full cure)
--   removeExposure  exposure taken off
--   immunity        seconds of immunity after a full cure (also bought by using it while healthy)
--   cooldown        seconds before the same item can be used again
--   health          health given
--   useTime, label, anim, prop, disable  the ox_lib progress bar

local PILL <const> = {
    anim = { dict = 'mp_suicide', clip = 'pill' },
    prop = { model = 'prop_cs_pills', bone = 28422 },
}

local DRINK <const> = {
    anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
    prop = { model = 'prop_ld_flow_bottle', bone = 18905, pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
}

return {
    cold_medicine = {
        label = 'Taking cold medicine...',
        useTime = 3500,
        anim = PILL.anim,
        prop = PILL.prop,
        cures = { 'common_cold' },
        removeSeverity = 100,
        removeExposure = 25,
        immunity = 300,
        cooldown = 30,
        health = 5,
    },

    antibiotics = {
        label = 'Taking antibiotics...',
        useTime = 3500,
        anim = PILL.anim,
        prop = PILL.prop,
        cures = { 'common_cold', 'flu', 'infection' },
        removeSeverity = 100,
        removeExposure = 40,
        immunity = 600,
        cooldown = 120,
        health = 10,
    },

    flu_shot = {
        label = 'Administering flu shot...',
        useTime = 9000,
        anim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer' },
        prop = { model = 'prop_syringe_01', bone = 28422 },
        disable = { move = true, car = true, combat = true },
        cures = { 'flu' },
        removeSeverity = 100,
        removeExposure = 20,
        immunity = 1800,
        cooldown = 300,
    },

    water_bottle = {
        label = 'Drinking...',
        useTime = 4000,
        anim = DRINK.anim,
        prop = DRINK.prop,
        cures = { 'heat_stroke' },
        removeSeverity = 45,
        removeExposure = 15,
        immunity = 60,
        cooldown = 10,
    },

    electrolytes = {
        label = 'Drinking...',
        useTime = 5000,
        anim = DRINK.anim,
        prop = DRINK.prop,
        cures = { 'heat_stroke' },
        removeSeverity = 100,
        removeExposure = 35,
        immunity = 240,
        cooldown = 60,
        health = 5,
    },

    hot_coffee = {
        label = 'Warming up...',
        useTime = 6000,
        anim = { dict = 'amb@world_human_aa_coffee@base', clip = 'base' },
        prop = { model = 'p_amb_coffeecup_01', bone = 28422 },
        cures = { 'hypothermia' },
        removeSeverity = 60,
        removeExposure = 30,
        immunity = 120,
        cooldown = 45,
        health = 3,
    },

    thermal_blanket = {
        label = 'Wrapping up...',
        useTime = 12000,
        anim = { dict = 'amb@world_human_bum_slumped@male@laying_on_left_side@base', clip = 'base', flag = 1 },
        disable = { move = true, car = true, combat = true },
        cures = { 'hypothermia' },
        removeSeverity = 100,
        removeExposure = 50,
        immunity = 300,
        cooldown = 120,
        health = 5,
    },
}
