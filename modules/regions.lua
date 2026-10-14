local Geometry = require 'modules.geometry'

---@class RegionTracker : OxClass
local Regions = lib.class('RegionTracker')

local border <const> = lib.load('data.weather').border

function Regions:constructor()
    self.ordered = Geometry.prepare(GlobalState.weatherRegions)
    self.listeners = {}

    AddStateBagChangeHandler('weatherRegions', 'global', function(_, _, value)
        self.ordered = Geometry.prepare(value)
        self:check(true)
    end)

    CreateThread(function()
        while true do
            self:check()
            Wait(border.checkInterval)
        end
    end)
end

---@param fn fun(id: string, previous: string?, snap: boolean)
function Regions:onChange(fn)
    self.listeners[#self.listeners + 1] = fn
end

---@param x number
---@param y number
---@param z? number
---@return string regionId
function Regions:resolve(x, y, z)
    return Geometry.resolve(self.ordered, x, y, z)
end

---@param id string
---@param snap boolean
function Regions:switch(id, snap)
    local previous = self.current
    self.current, self.pending = id, nil

    for _, fn in ipairs(self.listeners) do fn(id, previous, snap) end
    TriggerEvent('amphy_dynamicworld:regionChanged', id, previous)
end

---@param immediate? boolean skip the border dwell
function Regions:check(immediate)
    local coords = GetEntityCoords(cache.ped)
    local id = self:resolve(coords.x, coords.y, coords.z)
    local jumped = self.lastCoords and #(coords - self.lastCoords) > border.teleportDistance

    self.lastCoords = coords

    if id == self.current then
        self.pending = nil
    elseif not self.current or jumped then
        self:switch(id, true)
    elseif immediate then
        self:switch(id, false)
    elseif self.pending ~= id then
        self.pending, self.pendingSince = id, GetGameTimer()
    elseif GetGameTimer() - self.pendingSince >= border.dwell then
        self:switch(id, false)
    end
end

---@return string
function Regions:getId()
    return self.current or 'default'
end

---@return table? region definition as published by the server
function Regions:get(id)
    id = id or self:getId()

    for _, region in ipairs(GlobalState.weatherRegions or {}) do
        if region.id == id then return region end
    end
end

---@return RegionRecord[]
function Regions:getAll()
    return GlobalState.weatherRegions or {}
end

return Regions
