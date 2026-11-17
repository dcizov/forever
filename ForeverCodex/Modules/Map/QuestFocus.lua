--[[
    Forever Codex - Quest on the Map
    One quest from the journal shown on the world map and the minimap (UI/MapPins.lua) in Quest
    Pins' look (QuestPinLook.lua), from QuestieDB (Shared/Lib/QuestieDB.lua): where it starts
    (a "!" at its givers), where it's turned in (a "?", yellow once it's ready), and where its
    objectives are (the objective mark at the creatures and objects it asks for, and at what drops
    the items it asks for). A giver's or a creature's spawns close together share a pin, at the one
    nearest you. Without QuestieDB, what the Recorder learned of it: who gave it, who takes it in,
    where its objectives went up.

      ns.FocusQuest(questID, spot): shows it, opening the world map on `spot` ({ map or uiMapID,
        x, y }: Blizzard's map pin goes there too) or else where it starts. The quest page's Show
        on Map and a Ctrl-click on a creature's quest line call it. Closing the map lets it go.
    Nothing read from QuestieDB is kept.
]]

local _, ns = ...
local L = ns.L

local ipairs, pairs, format = ipairs, pairs, string.format
local Book, Places, QuestieDB = ns.Book, ns.Places, ns.QuestieDB
local Look = assert(ns.QuestPinLook, "QuestFocus.lua loads after QuestPinLook.lua")

local CLUSTER_LIMIT = 6 -- pins one giver or creature gets, at most
local DROP_SOURCES = 8  -- creatures and objects shown at most for an item it asks for
local ATLAS = { giver = "QuestNormal", ender = "QuestTurnin", objective = "QuestObjective" }
local LAYER = { objective = 0, giver = 2, ender = 3 }

local M = ns:NewModule("QuestFocus", {
    title = L.QFOCUS_TITLE,
    category = "map",
    description = L.QFOCUS_DESC,
    added = "3.2.0",
    defaults = { worldMap = true, size = 18, minimap = true, minimapSize = 14 },
    options = {
        { key = "worldMap", type = "checkbox", label = L.PINS_WORLD, tooltip = L.PINS_WORLD_TIP, slider = "size" },
        { key = "size", type = "slider", label = L.PINS_SIZE, min = 10, max = 32, step = 2, format = "%d px",
          requires = "worldMap", tooltip = L.PINS_SIZE_TIP },
        { key = "minimap", type = "checkbox", label = L.PINS_MINIMAP, tooltip = L.PINS_MINIMAP_TIP, slider = "minimapSize" },
        { key = "minimapSize", type = "slider", label = L.PINS_SIZE, min = 8, max = 24, step = 1, format = "%d px",
          requires = "minimap", tooltip = L.PINS_SIZE_TIP },
    },
})

local focus -- the quest shown, or nil

---------------------------------------------------------------------------
-- What to draw
---------------------------------------------------------------------------

-- Pins at the spawns on `mapID` of an NPC or object (`kind`), grouped by nearness.
local function addSpawns(list, mapID, kind, id, pinKind, entry)
    local rec = kind == "npc" and QuestieDB.Npc(id) or QuestieDB.Object(id)
    local points = {}
    for _, spawn in ipairs(rec and rec.spawns or {}) do
        if spawn.uiMapID == mapID then points[#points + 1] = { x = spawn.x, y = spawn.y } end
    end
    if #points == 0 then return end
    local px, py = Look.PlayerSpot(mapID)
    for _, group in ipairs(Look.Cluster(points, CLUSTER_LIMIT)) do
        local at = Look.Nearest(group, px, py)
        list[#list + 1] = { x = at.x, y = at.y, kind = pinKind, atlas = ATLAS[pinKind], layer = LAYER[pinKind],
            entries = { entry }, count = #group, place = { map = mapID, x = at.x, y = at.y },
            gray = pinKind == "ender" and not entry.ready }
    end
end

-- What QuestieDB has of the quest on `mapID`.
local function fromQuestie(list, mapID, questID, q)
    for _, npc in ipairs(q.starters.npcs) do
        addSpawns(list, mapID, "npc", npc, "giver", { questID = questID, source = { kind = "npc", id = npc } })
    end
    for _, object in ipairs(q.starters.objects) do
        addSpawns(list, mapID, "object", object, "giver", { questID = questID, source = { kind = "object", id = object } })
    end
    local ready = C_QuestLog.ReadyForTurnIn(questID)
    for _, npc in ipairs(q.finishers.npcs) do
        addSpawns(list, mapID, "npc", npc, "ender", { questID = questID, ready = ready })
    end
    for _, object in ipairs(q.finishers.objects) do
        addSpawns(list, mapID, "object", object, "ender", { questID = questID, ready = ready })
    end
    for _, objective in ipairs(q.objectives) do
        local entry = { questID = questID, text = objective.text }
        if objective.kind == "item" then
            local item = QuestieDB.Item(objective.id)
            entry.text = entry.text or (item and item.name)
            local left = DROP_SOURCES
            for _, npc in ipairs(item and item.npcDrops or {}) do
                if left > 0 then addSpawns(list, mapID, "npc", npc, "objective", entry) end
                left = left - 1
            end
            for _, object in ipairs(item and item.objectDrops or {}) do
                if left > 0 then addSpawns(list, mapID, "object", object, "objective", entry) end
                left = left - 1
            end
        else
            local rec = objective.kind == "npc" and QuestieDB.Npc(objective.id) or QuestieDB.Object(objective.id)
            entry.text = entry.text or (rec and rec.name)
            addSpawns(list, mapID, objective.kind, objective.id, "objective", entry)
        end
    end
end

-- What the Recorder learned of the quest on `mapID`: its giver, ender and objectives' places.
local function fromBook(list, mapID, questID, rec)
    local function at(place, kind, entry)
        if place and place.map == mapID then
            list[#list + 1] = { x = place.x, y = place.y, kind = kind, atlas = ATLAS[kind], layer = LAYER[kind],
                entries = { entry }, place = place, gray = kind == "ender" and not entry.ready }
        end
    end
    at(rec.giver, "giver", { questID = questID })
    at(rec.ender, "ender", { questID = questID, ready = C_QuestLog.ReadyForTurnIn(questID) })
    for j, marks in pairs(rec.marks or {}) do
        local zone = marks[mapID]
        local objective = rec.objectives and rec.objectives[j]
        for cell in pairs(zone and zone.cells or {}) do
            local x, y = Places.CellCenter(cell)
            at({ map = mapID, x = x, y = y }, "objective", { questID = questID, text = objective and objective.text })
        end
    end
end

local function pinsOn(mapID)
    if not focus then return {} end
    local list = {}
    local q = QuestieDB.Quest(focus)
    if q then
        fromQuestie(list, mapID, focus, q)
    else
        fromBook(list, mapID, focus, Book.Quest(focus) or {})
    end
    return Look.Stack(list)
end

local pins = ns.MapPins.Both(M, {
    specs = pinsOn,
    tooltip = Look.Tooltip,
    click = Look.Click,
    world = { shown = function() return M.db.worldMap end, size = function() return M.db.size end, level = 30 },
    minimap = { shown = function() return M.db.minimap end, size = function() return M.db.minimapSize end, level = 3 },
})

---------------------------------------------------------------------------
-- Showing a quest
---------------------------------------------------------------------------

-- Where to open the map for a quest: where it starts, else where it's turned in.
local function startOf(questID)
    local q = QuestieDB.Quest(questID)
    for _, group in ipairs(q and { q.starters, q.finishers } or {}) do
        for _, kind in ipairs({ "npcs", "objects" }) do
            for _, id in ipairs(group[kind] or {}) do
                local rec = kind == "npcs" and QuestieDB.Npc(id) or QuestieDB.Object(id)
                local spawn = rec and rec.spawns[1]
                if spawn then return spawn end
            end
        end
    end
    local seen = Book.Quest(questID)
    return seen and (seen.giver or seen.ender)
end

function ns.FocusQuest(questID, spot)
    spot = spot or startOf(questID)
    if not M.active then
        if spot then Places.Waypoint(spot.map or spot.uiMapID, spot.x, spot.y) end
        return
    end
    focus = questID
    M:Debug("showing quest", questID)
    -- Let go when the map closes (installed once, inert while nothing's shown).
    M:HookScript(WorldMapFrame, "OnHide", function()
        if focus then
            focus = nil
            pins.Refresh()
        end
    end)
    if spot then
        Places.Waypoint(spot.map or spot.uiMapID, spot.x, spot.y)
    else
        OpenWorldMap()
    end
    pins.Refresh()
end

-- The quest shown now (for the tests and /codex debug), or nil.
function M.Focus() return focus end

function M:OnEnable()
    for _, event in ipairs({ "QUEST_LOG_UPDATE", "QUEST_TURNED_IN" }) do
        self:RegisterEvent(event, function() if focus then self:Soon(pins.Refresh) end end)
    end
end

function M:OnDisable() focus = nil end

function M:DebugLine()
    return focus and format(L.QFOCUS_DEBUG, Book.QuestName(focus)) or L.QFOCUS_IDLE
end
