local Settings <const> = lib.load('data.settings')

if not Settings.enable.sickness or not Settings.enable.cures then return end

local Sicknesses <const> = lib.load('data.sicknesses')
local Cures <const> = lib.load('data.cures')

local LABELS = {}
for _, sickness in ipairs(Sicknesses) do LABELS[sickness.id] = sickness.label end

---@param cure table
---@return string
local function describe(cure)
    if cure.cures == 'all' then return locale('cures.treats_all') end

    local labels = {}
    for _, id in ipairs(cure.cures) do labels[#labels + 1] = LABELS[id] end

    return locale('cures.treats', table.concat(labels, ', '))
end

CreateThread(function()
    local ok = pcall(lib.waitFor, function()
        return GetResourceState('ox_inventory') == 'started' or nil
    end, nil, 10000)

    if not ok then return lib.print.warn('ox_inventory is not running, cure items are disabled') end

    local filter = {}
    for name in pairs(Cures) do filter[name] = true end

    -- Say on the item what it treats.
    exports.ox_inventory:registerHook('createItem', function(payload)
        local metadata = payload.metadata or {}
        metadata.description = metadata.description or describe(Cures[payload.item.name])
        return metadata
    end, { itemFilter = filter })
end)
