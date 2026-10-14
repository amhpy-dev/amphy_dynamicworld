-- PLAY_PAIN voice lines (eAudDamageReason). Test one with /dwpain <id>.
local PAIN <const> = {
    wheeze = 18,
    cough = 19,
    exhaustion = 21,
    sneeze = 30,
}

return {
    -- Cough and sneeze animations, referenced by a stage's cough.anim.
    animations = {
        cough_light = {
            dict = 'timetable@gardener@smoking_joint',
            clip = 'idle_cough',
            duration = 4000,
            pain = PAIN.cough,
        },
        cough_heavy = {
            dict = 'timetable@gardener@smoking_joint',
            clip = 'idle_cough',
            duration = 4000,
            pain = PAIN.cough,
            painAfter = PAIN.wheeze,
        },
        sneeze = {
            dict = 'timetable@gardener@smoking_joint',
            clip = 'idle_cough',
            duration = 1500,
            pain = PAIN.sneeze,
        },
    },

    painDamage = 1.0,          -- must be above 0 or the ped stays silent
    painSyncsOverNetwork = true, -- turn off on old game builds if nobody else hears coughs

    -- A stage's sprintStamina below 1.0 shortens how long you can sprint.
    sprint = {
        duration = 9000, -- ms of sprinting at full stamina
        recovery = 4000, -- ms the sprint key is blocked when you run out
        pain = PAIN.exhaustion,
    },

    -- Timecycle used by any stage with greyscale = true.
    greyscale = { name = 'DeathFailMPIn', strength = 1.0 },

    minHealth = 125, -- health drain never goes below this

    onStageChanged = function(sickness, stage, previousStage)
        if stage then
            lib.notify({
                title = sickness.label,
                description = stage.label,
                type = stage.id == 'severe' and 'error' or 'inform',
                icon = 'virus',
            })
        elseif previousStage then
            lib.notify({
                title = locale('sickness.recovered'),
                description = locale('sickness.recovered_text'),
                type = 'success',
                icon = 'heart-pulse',
            })
        end
    end,
}
