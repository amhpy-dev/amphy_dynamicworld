return {
    start = { hour = 9, minute = 0 },
    dayLength = 48,     -- real minutes per in-game day, 0 stops the clock
    frozen = false,
    transition = 8000,  -- ms to ease into a time set with /time
    resync = 30000,     -- ms between clock corrections sent to players
}
