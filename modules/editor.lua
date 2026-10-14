local Climate = require 'modules.climate'

---@class Editor : OxClass
local Editor = lib.class('Editor')

local cfg <const> = lib.load('data.editor')
local place <const> = cfg.placement

local KEY <const> = { click = 0x01, cancel = 0x02, undo = 0x08, finish = 0x0D, escape = 0x1B }
local CONTROL <const> = { click = 24, cancel = 25, undo = 194, finish = 191, escape = 202, sprint = 21 }
local BLOCKED <const> = { 24, 25, 140, 141, 142, 257, 263, 14, 15 }

---@param regions RegionTracker
function Editor:constructor(regions)
    self.regions = regions
    self.open = false
end

---@param climateId? string
---@return number[]
local function colourOf(climateId)
    return Climate.exists(climateId) and Climate.get(climateId).colour or { 255, 255, 255 }
end

--------------------------------------------------------------------------------
-- Aiming in the world
--------------------------------------------------------------------------------

-- Which control a click lands on varies by build and weapon, so raw keys are
-- watched too. A key already down when placing starts is not a press.
local held, edges = {}, {}

local function pollKeys()
    if not IsRawKeyPressed then return end

    for name, key in pairs(KEY) do
        local down = IsRawKeyPressed(key) == true
        edges[name] = down and held[name] == false
        held[name] = down
    end
end

---@param name string
---@return boolean
local function pressed(name)
    return IsDisabledControlJustPressed(0, CONTROL[name]) or edges[name] == true
end

--- Where the camera is pointing; the ground under the end of the ray on a miss.
local function aim()
    local hit, _, coords = lib.raycast.fromCamera(511, 4, place.reach)
    if hit then return coords end

    local rot = GetFinalRenderedCamRot(2)
    local pitch, yaw = math.rad(rot.x), math.rad(rot.z)
    local forward = vec3(-math.sin(yaw) * math.abs(math.cos(pitch)), math.cos(yaw) * math.abs(math.cos(pitch)), math.sin(pitch))
    local target = GetFinalRenderedCamCoord() + forward * place.reach
    local found, ground = GetGroundZFor_3dCoord(target.x, target.y, target.z + 50.0, false)

    return vec3(target.x, target.y, found and ground or target.z)
end

local function holdControls()
    DisablePlayerFiring(cache.playerId, true)
    for _, control in ipairs(BLOCKED) do DisableControlAction(0, control, true) end
end

---@param a vector3
---@param b vector3
---@param colour number[]
local function line(a, b, colour)
    DrawLine(a.x, a.y, a.z, b.x, b.y, b.z, colour[1], colour[2], colour[3], 220)
end

---@diagnostic disable: param-type-mismatch
local function dot(coords, colour)
    DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3,
        colour[1], colour[2], colour[3], 220, false, false, 0, false, false, false, false)
end

---@param coords vector3
---@param radius number
---@param colour number[]
local function ring(coords, radius, colour)
    DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, radius * 2, radius * 2, 2.0,
        colour[1], colour[2], colour[3], 90, false, false, 0, false, false, false, false)
end
---@diagnostic enable: param-type-mismatch

--- Runs until the player confirms or cancels. Call from its own thread.
---@param onFrame fun(coords: vector3, ready: boolean): string, table? prompt, and a result once done
function Editor:aimLoop(onFrame)
    self.placing = true
    held, edges = {}, {}

    local ready = GetGameTimer() + 250
    local shown, result

    while self.placing do
        Wait(0)
        pollKeys()
        holdControls()

        local coords = aim()
        local prompt, done = onFrame(coords, GetGameTimer() > ready)

        if prompt ~= shown then
            shown = prompt
            lib.showTextUI(prompt, { position = 'bottom-center' })
        end

        if done ~= nil then
            result = done
            break
        end

        if pressed('cancel') or pressed('escape') then break end
    end

    lib.hideTextUI()
    self.placing = false

    return result
end

---@param radius number
---@param colour number[]
---@return table?
function Editor:pickCircle(radius, colour)
    return self:aimLoop(function(coords, ready)
        line(GetEntityCoords(cache.ped) + vec3(0.0, 0.0, 0.5), coords, colour)
        dot(coords, colour)
        ring(coords, radius, colour)

        local step = IsControlPressed(0, CONTROL.sprint) and place.fastStep or place.step

        if IsControlJustPressed(0, 241) or IsDisabledControlJustPressed(0, 15) then
            radius = math.min(place.maxRadius, radius + step)
        elseif IsControlJustPressed(0, 242) or IsDisabledControlJustPressed(0, 14) then
            radius = math.max(place.minRadius, radius - step)
        end

        local prompt = ('[LMB] place  •  [Scroll] %dm  •  [Shift] faster  •  [RMB] cancel'):format(radius)

        if ready and (pressed('click') or pressed('finish')) then
            return prompt, { coords = coords, radius = radius }
        end

        return prompt
    end)
end

---@param colour number[]
---@return table?
function Editor:pickPolygon(colour)
    local points = {}

    return self:aimLoop(function(coords, ready)
        for i, point in ipairs(points) do
            dot(point, colour)
            line(point, point + vec3(0.0, 0.0, 3.0), colour)
            if points[i + 1] then line(point, points[i + 1], colour) end
        end

        dot(coords, colour)
        if #points > 0 then line(points[#points], coords, colour) end
        if #points >= 2 then line(coords, points[1], colour) end

        if ready and pressed('click') then points[#points + 1] = coords end
        if pressed('undo') then points[#points] = nil end

        local prompt = ('[LMB] corner %d  •  %s[Backspace] undo  •  [RMB] cancel')
            :format(#points + 1, #points >= 3 and '[Enter] finish  •  ' or '')

        if #points >= 3 and pressed('finish') then
            return prompt, { points = points }
        end

        return prompt
    end)
end

--------------------------------------------------------------------------------
-- Panel
--------------------------------------------------------------------------------

---@param path? string
---@return string?
local function resolveUrl(path)
    if not path or path:find('^https?://') then return path end
    return ('https://cfx-nui-%s/web/%s'):format(cache.resource, path)
end

---@return ClimateRecord[]
local function climateList()
    local list = {}

    for id, climate in pairs(Climate.all()) do
        local entry = lib.table.deepclone(climate)
        entry.id = id
        list[#list + 1] = entry
    end

    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

---@return table
function Editor:getData()
    local coords = GetEntityCoords(cache.ped)
    local map = lib.table.deepclone(cfg.map)
    local hour, minute = GetClockHours(), GetClockMinutes()
    local weathers, live = {}, {}

    map.tiles, map.emptyTile = resolveUrl(map.tiles), resolveUrl(map.emptyTile)

    for i, name in ipairs(Climate.WEATHERS) do
        weathers[i] = { name = name, label = Climate.label(name) }
    end

    for id, payload in pairs(GlobalState.regionWeather or {}) do
        local region = self.regions:get(id)
        local conditions = Climate.conditions(region and region.climate, payload.weather, hour, minute)

        live[id] = {
            weather = payload.weather,
            label = conditions.weatherLabel,
            temperature = conditions.temperature,
            forced = payload.forced,
            blackout = payload.blackout,
            ends = payload.time,
        }
    end

    return {
        regions = self.regions:getAll(),
        climates = climateList(),
        weathers = weathers,
        live = live,
        current = self.regions:getId(),
        here = DW.getConditions(),
        blackout = GlobalState.blackOut == true,
        season = GlobalState.season or false,
        frozen = GlobalState.freezeTime == true,
        map = map,
        limits = { minRadius = place.minRadius, maxRadius = place.maxRadius },
        player = { x = coords.x, y = coords.y, z = coords.z },
    }
end

function Editor:openUi()
    if self.open then return end

    self.open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = self:getData() })

    CreateThread(function()
        while self.open do
            Wait(2000)
            if not self.placing then self:refresh() end
        end
    end)
end

function Editor:closeUi()
    if not self.open then return end

    self.open = false
    self.placing = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

function Editor:toggleUi()
    if self.open then self:closeUi() else self:openUi() end
end

function Editor:refresh()
    if self.open then SendNUIMessage({ action = 'data', data = self:getData() }) end
end

--- Leave the panel, let the player aim, then hand the result back to it.
---@param options { climate?: string, radius?: number, polygon?: boolean }
function Editor:pickForUi(options)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })

    CreateThread(function()
        local colour = colourOf(options.climate)
        local result = options.polygon and self:pickPolygon(colour)
            or self:pickCircle(options.radius or 500.0, colour)

        if self.open then SetNuiFocus(true, true) end

        local payload

        if result then
            local points = {}
            local centre = result.coords or vec3(0.0, 0.0, 0.0)

            for i, point in ipairs(result.points or {}) do
                points[i] = { x = point.x, y = point.y }
                centre = centre + point / #result.points
            end

            payload = {
                coords = { x = centre.x, y = centre.y, z = centre.z },
                radius = result.radius,
                points = result.points and points,
            }
        end

        SendNUIMessage({ action = 'placed', result = payload })
    end)
end

--------------------------------------------------------------------------------
-- Preview
--------------------------------------------------------------------------------

--- Draw every border around the player's height for a while.
function Editor:preview(seconds)
    local untilTime = GetGameTimer() + (seconds or 20) * 1000

    CreateThread(function()
        while GetGameTimer() < untilTime do
            local z = GetEntityCoords(cache.ped).z

            for _, region in ipairs(self.regions.ordered) do
                local colour = colourOf(region.climate)
                local r, g, b = colour[1], colour[2], colour[3]

                if region.shape == 'poly' then
                    local points = region.points

                    for i, a in ipairs(points) do
                        local c = points[i % #points + 1]
                        DrawLine(a.x, a.y, z - 20.0, a.x, a.y, z + 80.0, r, g, b, 220)

                        for h = z - 20.0, z + 80.0, 20.0 do
                            DrawLine(a.x, a.y, h, c.x, c.y, h, r, g, b, 160)
                        end
                    end
                else
                    local steps = lib.math.clamp(region.radius // 25, 24, 96)
                    local height = math.max(z, region.floor or z)

                    for i = 0, steps - 1 do
                        local t1, t2 = i / steps * 2 * math.pi, (i + 1) / steps * 2 * math.pi
                        local x, y = region.coords.x, region.coords.y

                        DrawLine(x + math.cos(t1) * region.radius, y + math.sin(t1) * region.radius, height,
                            x + math.cos(t2) * region.radius, y + math.sin(t2) * region.radius, height, r, g, b, 200)
                    end
                end
            end

            Wait(0)
        end
    end)
end

return Editor
