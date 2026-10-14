---@class RegionRecord
---@field id string
---@field label string
---@field climate string
---@field shape 'global' | 'circle' | 'poly'
---@field coords? { x: number, y: number }
---@field radius? number
---@field points? { x: number, y: number }[]
---@field priority? number
---@field floor? number
---@field enabled? boolean

local Geometry = {}

---@param region RegionRecord
---@return RegionRecord
local function prepare(region)
    if region.shape == 'circle' then
        region.radiusSq = region.radius ^ 2
        region.area = math.pi * region.radiusSq
        return region
    end

    local points = region.points
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local area = 0

    for i = 1, #points do
        local a, b = points[i], points[i % #points + 1]
        minX, maxX = math.min(minX, a.x), math.max(maxX, a.x)
        minY, maxY = math.min(minY, a.y), math.max(maxY, a.y)
        area = area + a.x * b.y - b.x * a.y
    end

    region.bounds = { minX, minY, maxX, maxY }
    region.area = math.abs(area) / 2

    return region
end

---@param points { x: number, y: number }[]
---@param x number
---@param y number
---@return boolean
local function insidePolygon(points, x, y)
    local inside = false
    local j = #points

    for i = 1, #points do
        local a, b = points[i], points[j]

        if (a.y > y) ~= (b.y > y) and x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x then
            inside = not inside
        end

        j = i
    end

    return inside
end

---@param region RegionRecord prepared
---@param x number
---@param y number
---@param z? number
---@return boolean
function Geometry.contains(region, x, y, z)
    if region.enabled == false then return false end
    if region.floor and z and z < region.floor then return false end

    if region.shape == 'circle' then
        return (x - region.coords.x) ^ 2 + (y - region.coords.y) ^ 2 <= region.radiusSq
    end

    local bounds = region.bounds
    if x < bounds[1] or y < bounds[2] or x > bounds[3] or y > bounds[4] then return false end

    return insidePolygon(region.points, x, y)
end

--- Copies of every shaped region, ordered so the first match wins.
function Geometry.prepare(regions)
    local ordered = {}

    for _, region in ipairs(regions or {}) do
        if region.shape ~= 'global' then
            ordered[#ordered + 1] = prepare(lib.table.deepclone(region))
        end
    end

    table.sort(ordered, function(a, b)
        if (a.priority or 0) ~= (b.priority or 0) then return (a.priority or 0) > (b.priority or 0) end
        if a.area ~= b.area then return a.area < b.area end
        return a.id < b.id
    end)

    return ordered
end

---@return string regionId
function Geometry.resolve(ordered, x, y, z)
    for _, region in ipairs(ordered) do
        if Geometry.contains(region, x, y, z) then return region.id end
    end

    return 'default'
end

return Geometry
