local Settings <const> = lib.load('data.settings')
local cfg <const> = lib.load('data.time')
local MINUTES_PER_DAY <const> = 1440

local msPerMinute <const> = cfg.dayLength > 0 and cfg.dayLength * 60000 // MINUTES_PER_DAY or 0

Clock = {
    minutes = (cfg.start.hour * 60 + cfg.start.minute) % MINUTES_PER_DAY,
    frozen = cfg.frozen,
    nextResync = 0,
}

---@return integer hour, integer minute
function Clock:get()
    return math.floor(self.minutes) // 60 % 24, math.floor(self.minutes) % 60
end

---@param force? boolean send even if the minute has not changed
function Clock:publish(force)
    local hour, minute = self:get()
    local now = GetGameTimer()

    if not force and minute == self.lastMinute and now < self.nextResync then return end

    self.lastMinute = minute
    self.nextResync = now + cfg.resync
    GlobalState.currentTime = { hour = hour, minute = minute }
end

function Clock:publishScale()
    GlobalState.freezeTime = self.frozen
    GlobalState.timeScale = not self.frozen and msPerMinute or 0
end

---@param t number 0-1
---@return number
local function ease(t)
    if t < 0.5 then return 4 * t ^ 3 end
    return 1 + 0.5 * (2 * t - 2) ^ 3
end

---@param instant? boolean skip the transition
function Clock:set(hour, minute, instant)
    hour, minute = tonumber(hour), tonumber(minute) or 0
    if not hour or hour < 0 or hour > 23 or minute < 0 or minute > 59 then return false end

    local target = hour * 60 + minute
    local delta = (target - self.minutes) % MINUTES_PER_DAY

    if instant or cfg.transition <= 0 or delta == 0 then
        self.transition = nil
        self.minutes = target
        self:publish(true)
    else
        self.transition = { from = self.minutes, delta = delta, started = GetGameTimer() }
    end

    return true
end

---@param state boolean
function Clock:freeze(state)
    self.frozen = state
    self:publishScale()
    self:publish(true)
end

---@param dt number ms since the last tick
function Clock:tick(dt)
    local transition = self.transition

    if transition then
        local progress = math.min(1, (GetGameTimer() - transition.started) / cfg.transition)

        self.minutes = (transition.from + transition.delta * ease(progress)) % MINUTES_PER_DAY
        if progress >= 1 then self.transition = nil end

        return self:publish(true)
    end

    if not self.frozen and msPerMinute > 0 then
        self.minutes = (self.minutes + dt / msPerMinute) % MINUTES_PER_DAY
        self:publish()
    end
end

if Settings.enable.time then
    CreateThread(function()
        Clock:publishScale()
        Clock:publish(true)

        local last = GetGameTimer()

        while true do
            Wait(Clock.transition and 50 or 250)

            local now = GetGameTimer()
            Clock:tick(now - last)
            last = now
        end
    end)
end

exports('setTime', function(hour, minute, instant) return Clock:set(hour, minute, instant) end)
exports('freezeTime', function(state) Clock:freeze(state == true) end)
exports('getClock', function()
    local hour, minute = Clock:get()
    return { hour = hour, minute = minute, frozen = Clock.frozen }
end)
