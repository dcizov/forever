--[[
    Forever Tweaks - Gathering Map
    Every herb, vein and chest you gather is remembered where you stood, for the whole account,
    and shown on the world map and the minimap (Forever Core's UI/MapPins.lua) as the game's own
    gathering icons: point at one for what it is and how often you gathered it; Shift+right-click
    one on the world map forgets it. Nothing is shipped: you see only the spots you found yourself, so
    exploring stays yours. Gathering the same node again counts it and moves its spot toward the
    average of where you stood.
    A gather starts with UNIT_SPELLCAST_SENT for a gathering spell (Mining, Herb Gathering,
    Opening, Pick Lock), which names its target, and counts only once UNIT_SPELLCAST_SUCCEEDED comes
    with the same cast, so one that fails counts for nothing. When the target's name is empty or
    secret, the soft-target object names it. Nothing is recorded in instances.
    Left to Forever++'s Gathering Map while that's on. Ideas from Forever++'s Gathering Map
    (xIGBClutchIx, MIT) and GatherMate2; none of their data.
]]

local _, ns = ...
local L = ns.L

local pairs, ipairs, time, format = pairs, ipairs, time, string.format
local Plain = ns.Plain
local OtherAddons = ns.OtherAddons

local COVERS = { { "ForeverPlusPlus", "GatheringMap" } }
local MERGE_YARDS = 20 -- gathers closer than this to a node of the same name are that node
local KIND_OF = { [2575] = "ore", [2366] = "herb", [3365] = "treasure", [1804] = "treasure" } -- first ranks

local GROUP = { label = L.GMAP_KINDS, format = L.GMAP_KINDS_COUNT, tooltip = L.GMAP_KINDS_TIP }

local M = ns:NewModule("GatherMap", {
    title = L.GMAP_TITLE,
    category = "gathering",
    description = L.GMAP_DESC,
    added = "1.10.0",
    defaults = {
        herb = true, ore = true, treasure = true,
        worldMap = true, minimap = true, size = 16, minimapSize = 12,
        nodes = {}, -- data: mapID -> { { name, kind, x, y, count, last } }, for the account
    },
    options = {
        { key = "herb", type = "checkbox", label = L.GMAP_HERB, group = GROUP },
        { key = "ore", type = "checkbox", label = L.GMAP_ORE, group = GROUP },
        { key = "treasure", type = "checkbox", label = L.GMAP_TREASURE, group = GROUP },
        { key = "worldMap", type = "checkbox", label = L.GMAP_WORLD, tooltip = L.GMAP_WORLD_TIP, slider = "size" },
        { key = "size", type = "slider", label = L.GMAP_SIZE, min = 8, max = 32, step = 2, format = "%d px",
          requires = "worldMap", tooltip = L.GMAP_SIZE_TIP },
        { key = "minimap", type = "checkbox", label = L.GMAP_MINIMAP, tooltip = L.GMAP_MINIMAP_TIP, slider = "minimapSize" },
        { key = "minimapSize", type = "slider", label = L.GMAP_SIZE, min = 6, max = 24, step = 1, format = "%d px",
          requires = "minimap", tooltip = L.GMAP_SIZE_TIP },
    },
})

M.notice = OtherAddons.CoveredNotices(M, COVERS, L.GMAP_WHAT)

local ATLAS = { herb = "Crosshair_GatherHerbs_32", ore = "Crosshair_Mine_32", treasure = "Crosshair_lootall_32" }

local function covered() return OtherAddons.CoveredBy(M, COVERS) ~= nil end

---------------------------------------------------------------------------
-- The pins (Forever Core's UI/MapPins.lua)
---------------------------------------------------------------------------

local forget -- below

-- The pins on `mapID`: shown kinds only.
local function pinsOn(mapID)
    local list = {}
    for _, node in ipairs(M.db.nodes[mapID] or {}) do
        if M.db[node.kind] then list[#list + 1] = { x = node.x, y = node.y, atlas = ATLAS[node.kind], node = node, map = mapID } end
    end
    return list
end

local function tooltip(owner, spec)
    local node = spec.node
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(node.name, 1, 0.82, 0)
    GameTooltip:AddLine(format(L.GMAP_GATHERED, node.count), 1, 1, 1)
    GameTooltip:AddLine(format(L.GMAP_LAST, date("%b %d", node.last)), 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

local world = ns.MapPins.World(M, {
    specs = pinsOn,
    shown = function() return M.db.worldMap and not covered() end,
    size = function() return M.db.size end,
    tooltip = tooltip,
    click = function(_, spec)
        if not IsShiftKeyDown() then return end
        forget(spec.map, spec.node)
        M:Print(format(L.GMAP_FORGOTTEN, spec.node.name))
    end,
})
local minimap = ns.MapPins.Minimap(M, {
    specs = pinsOn,
    shown = function() return M.db.minimap and not covered() end,
    size = function() return M.db.minimapSize end,
    tooltip = tooltip,
})

-- Something changed: the pins draw again.
local function changed()
    world.Refresh()
    minimap.Refresh()
end

---------------------------------------------------------------------------
-- Recording gathers
---------------------------------------------------------------------------

local kindByName -- spell name -> kind, read once (other ranks share the first rank's name)

local function kindOf(spellID)
    if not kindByName then
        kindByName = {}
        for id, kind in pairs(KIND_OF) do
            local name = C_Spell.GetSpellName(id)
            if name then kindByName[name] = kind end
        end
    end
    return KIND_OF[spellID] or kindByName[C_Spell.GetSpellName(spellID) or ""]
end

-- Yards between two map positions, or nil when the map has no size.
local function yards(mapID, x1, y1, x2, y2)
    local width, height = C_Map.GetMapWorldSize(mapID)
    if not (width and width > 0) then return nil end
    local dx, dy = (x1 - x2) * width, (y1 - y2) * height
    return math.sqrt(dx * dx + dy * dy)
end

-- Counts a gather of `name` at (x, y): the same node again if one is near, else a new one.
local function record(mapID, x, y, name, kind)
    local nodes = M.db.nodes
    local list = nodes[mapID] or {}
    nodes[mapID] = list
    for _, node in ipairs(list) do
        local away = node.name == name and yards(mapID, node.x, node.y, x, y)
        if away and away <= MERGE_YARDS then
            node.x = (node.x * node.count + x) / (node.count + 1)
            node.y = (node.y * node.count + y) / (node.count + 1)
            node.count, node.last = node.count + 1, time()
            changed()
            return node
        end
    end
    local node = { name = name, kind = kind, x = x, y = y, count = 1, last = time() }
    list[#list + 1] = node
    M:Debug("new node", name)
    changed()
    return node
end

function forget(mapID, node)
    local list = M.db.nodes[mapID] or {}
    for i, each in ipairs(list) do
        if each == node then
            table.remove(list, i)
            changed()
            return
        end
    end
end

local pending -- the gather sent and not yet done: { cast, name, kind, map, x, y }

local function here()
    local mapID = Plain(C_Map.GetBestMapForUnit("player"))
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return nil end
    local x, y = pos:GetXY()
    x, y = Plain(x), Plain(y)
    if not (x and y) or (x == 0 and y == 0) then return nil end
    return mapID, x, y
end

local function onSent(_, _, unit, target, cast, spellID)
    spellID = Plain(spellID)
    local kind = unit == "player" and spellID and kindOf(spellID)
    if not kind or IsInInstance() or covered() then return end
    local name = Plain(target)
    if not name or name == "" then name = Plain(UnitName("softinteract")) end
    local mapID, x, y = here()
    if not (name and name ~= "" and mapID) then return end
    pending = { cast = Plain(cast), name = name, kind = kind, map = mapID, x = x, y = y }
end

local function onSucceeded(_, _, unit, cast)
    if unit ~= "player" or not pending or Plain(cast) ~= pending.cast then return end
    local done = pending
    pending = nil
    record(done.map, done.x, done.y, done.name, done.kind)
end

function M:OnEnable()
    self:RegisterEvent("UNIT_SPELLCAST_SENT", onSent)
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", onSucceeded)
    changed()
end

function M:OnDisable()
    pending = nil
    changed()
end

function M:OnSettingChanged() changed() end

function M:DebugLine()
    local maps, count = 0, 0
    for _, list in pairs(self.db.nodes) do
        maps, count = maps + 1, count + #list
    end
    return format(L.GMAP_DEBUG, count, maps)
end
