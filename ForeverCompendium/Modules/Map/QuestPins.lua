--[[
    Forever Compendium - Quest Pins
    Where your quests are, from what the Recorder learned (Lib/Book.lua), on the
    world map and the minimap (Forever Core's UI/MapPins.lua), drawn the way Questie draws them:
      * Givers: a quest you were offered and haven't taken or done, at the one who offered it
        (a yellow "!", blue for a daily).
      * Quest items: where a creature dropped an item that starts a quest you haven't taken.
      * Turn-ins: a quest in your log, at the one who takes it in: a yellow "?" once it's ready,
        a grey one until then.
      * Objectives: where each objective still to do of a quest in your log went up before (its
        busiest few places), as the objective mark.
    Quests at the same spot share one pin; point at it for each one and what it's there for,
    right-click it (world map) to open the journal on its first quest. On a continent's map the
    givers, quest items and turn-ins of its zones show too. Drawn again when the quest log
    changes and when the Recorder learns a quest's place or title.
]]

local _, ns = ...
local L = ns.L

local pairs, ipairs, format, sort = pairs, ipairs, string.format, table.sort
local Book, Places = ns.Book, ns.Places
local Text = assert(ns.JournalText, "QuestPins.lua loads after JournalText.lua")

local OBJECTIVE_PLACES = 4 -- an objective's busiest places shown, at most
local ATLAS = { giver = "QuestNormal", daily = "QuestDaily", ender = "QuestTurnin", objective = "QuestObjective" }
local ITEM_ICON = "Interface\\Icons\\INV_Misc_Note_02"
local LAYER = { objective = 0, item = 1, giver = 2, ender = 3 }
local ZONE_TYPE = 3 -- Enum.UIMapType.Zone: maps below a continent

local GROUP = { label = L.QPINS_SHOW, format = L.QPINS_SHOW_COUNT, tooltip = L.QPINS_SHOW_TIP }

local M = ns:NewModule("QuestPins", {
    title = L.QPINS_TITLE,
    category = "map",
    description = L.QPINS_DESC,
    added = "2.1.0",
    defaults = {
        givers = true, items = true, turnIns = true, objectives = true, continent = true,
        worldMap = true, size = 20, minimap = true, minimapSize = 14,
    },
    options = {
        { key = "givers", type = "checkbox", label = L.QPINS_GIVERS, tooltip = L.QPINS_GIVERS_TIP, group = GROUP },
        { key = "items", type = "checkbox", label = L.QPINS_ITEMS, tooltip = L.QPINS_ITEMS_TIP, group = GROUP, added = "2.3.0" },
        { key = "turnIns", type = "checkbox", label = L.QPINS_TURNINS, tooltip = L.QPINS_TURNINS_TIP, group = GROUP },
        { key = "objectives", type = "checkbox", label = L.QPINS_OBJECTIVES, tooltip = L.QPINS_OBJECTIVES_TIP, group = GROUP },
        { key = "continent", type = "checkbox", label = L.QPINS_CONTINENT, tooltip = L.QPINS_CONTINENT_TIP, added = "2.3.0" },
        { key = "worldMap", type = "checkbox", label = L.PINS_WORLD, tooltip = L.PINS_WORLD_TIP, slider = "size" },
        { key = "size", type = "slider", label = L.PINS_SIZE, min = 12, max = 32, step = 2, format = "%d px",
          requires = "worldMap", tooltip = L.PINS_SIZE_TIP },
        { key = "minimap", type = "checkbox", label = L.PINS_MINIMAP, tooltip = L.PINS_MINIMAP_TIP, slider = "minimapSize" },
        { key = "minimapSize", type = "slider", label = L.PINS_SIZE, min = 8, max = 24, step = 1, format = "%d px",
          requires = "minimap", tooltip = L.PINS_SIZE_TIP },
    },
})

---------------------------------------------------------------------------
-- What to draw
---------------------------------------------------------------------------

-- The quests in the log: questID -> its objectives (C_QuestLog.GetQuestObjectives).
local function questsInLog()
    local list = {}
    ns.EachLogQuest(function(questID) list[questID] = C_QuestLog.GetQuestObjectives(questID) or {} end)
    return list
end

-- Adds a quest to the pin at (x, y) of `kind`, made when it's the first there.
local function addTo(pins, byKey, kind, x, y, entry)
    local key = format("%s:%.3f:%.3f", kind, x, y)
    local pin = byKey[key]
    if not pin then
        pin = { x = x, y = y, kind = kind, atlas = ATLAS[kind], layer = LAYER[kind], entries = {}, gray = true }
        if kind == "item" then pin.atlas, pin.texture = nil, ITEM_ICON end
        byKey[key] = pin
        pins[#pins + 1] = pin
    end
    pin.entries[#pin.entries + 1] = entry
    -- A turn-in pin is yellow once any quest at it is ready; the others always are.
    if kind ~= "ender" or entry.ready then pin.gray = false end
    -- A giver pin is a daily's blue only while every quest at it is a daily.
    if kind == "giver" then
        pin.allDaily = (pin.allDaily ~= false) and entry.daily or false
        pin.atlas = pin.allDaily and ATLAS.daily or ATLAS.giver
    end
end

-- The busiest few cells of an objective's places on `mapID`, most first.
local function busiest(marks, mapID)
    local zone = marks and marks[mapID]
    if not zone then return {} end
    local cells = {}
    for cell, n in pairs(zone.cells) do cells[#cells + 1] = { cell = cell, n = n } end
    sort(cells, function(a, b) return a.n > b.n end)
    for i = OBJECTIVE_PLACES + 1, #cells do cells[i] = nil end
    return cells
end

local function addObjectives(pins, byKey, questID, rec, objectives, mapID)
    for j, objective in ipairs(objectives) do
        if not objective.finished then
            for _, place in ipairs(busiest(rec.marks and rec.marks[j], mapID)) do
                local x, y = Places.CellCenter(place.cell)
                addTo(pins, byKey, "objective", x, y, { questID = questID, text = objective.text })
            end
        end
    end
end

-- `place` ({ map, x, y }) on `mapID`: its own spot there, or its spot on the zone's rectangle
-- on a continent's map (`rects`: mapID -> { left, right, top, bottom } or false).
local function spotOn(place, mapID, rects)
    if place.map == mapID then return place.x, place.y end
    if not rects then return nil end
    local rect = rects[place.map]
    if rect == nil then
        local left, right, top, bottom = C_Map.GetMapRectOnMap(place.map, mapID)
        rect = left and right > left and bottom > top and { left, right, top, bottom } or false
        rects[place.map] = rect
    end
    if not rect then return nil end
    return rect[1] + place.x * (rect[2] - rect[1]), rect[3] + place.y * (rect[4] - rect[3])
end

-- Whether `mapID` is a continent's or the world's (its zones' pins show on it).
local function isContinent(mapID)
    local info = C_Map.GetMapInfo(mapID)
    return info ~= nil and info.mapType ~= nil and info.mapType < ZONE_TYPE
end

local function addOffered(pins, byKey, questID, rec, mapID, rects)
    local db = M.db
    if C_QuestLog.IsQuestFlaggedCompleted(questID) then return end
    if db.givers and rec.giver then
        local x, y = spotOn(rec.giver, mapID, rects)
        if x then addTo(pins, byKey, "giver", x, y, { questID = questID, daily = rec.daily == true }) end
    end
    if db.items and rec.itemFrom then
        local x, y = spotOn(rec.itemFrom, mapID, rects)
        if x then addTo(pins, byKey, "item", x, y, { questID = questID, itemID = rec.startItem, npc = rec.itemFrom.npc }) end
    end
end

-- The pins on `mapID`.
local function pinsOn(mapID)
    local db, pins, byKey = M.db, {}, {}
    local log = questsInLog()
    local rects = db.continent and isContinent(mapID) and {} or nil
    for questID, rec in pairs(Book.Quests()) do
        local objectives = log[questID]
        if objectives then
            local ender = rec.ender
            if db.turnIns and ender then
                local x, y = spotOn(ender, mapID, rects)
                if x then addTo(pins, byKey, "ender", x, y, { questID = questID, ready = C_QuestLog.ReadyForTurnIn(questID) }) end
            end
            if db.objectives and not rects then addObjectives(pins, byKey, questID, rec, objectives, mapID) end
        else
            addOffered(pins, byKey, questID, rec, mapID, rects)
        end
    end
    return pins
end

---------------------------------------------------------------------------
-- The tooltip: each quest at the pin, and what it's there for
---------------------------------------------------------------------------

local function questLine(questID)
    local rec = Book.Quest(questID) or {}
    local title = Book.QuestName(questID)
    local kind = Text.QuestKind(rec)
    if rec.level then title = format("%s (%d)", title, rec.level) end
    return kind and (title .. " - " .. kind) or title
end

local function whatFor(pin, entry)
    if pin.kind == "giver" then
        local giver = (Book.Quest(entry.questID) or {}).giver
        local rec = giver and giver.npc and Book.Creature(giver.npc)
        local who = rec and rec.name or giver and giver.name
        return who and format(L.QPINS_GIVES_NAMED, who) or L.QPINS_GIVES
    end
    if pin.kind == "item" then
        local rec = entry.npc and Book.Creature(entry.npc)
        return format(L.QPINS_ITEM, Text.ItemName(entry.itemID), rec and rec.name or "?")
    end
    if pin.kind == "ender" then return entry.ready and L.QPINS_READY or L.QPINS_NOT_READY end
    return entry.text or L.QPINS_OBJECTIVE
end

local function tooltip(owner, pin)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    for i, entry in ipairs(pin.entries) do
        if i > 1 then GameTooltip:AddLine(" ") end
        GameTooltip:AddLine(questLine(entry.questID), 1, 0.82, 0)
        GameTooltip:AddLine(whatFor(pin, entry), 1, 1, 1, true)
    end
    if owner:GetObjectType() == "Button" then GameTooltip:AddLine(L.QPINS_HINT, 0.1, 1, 0.1) end
    GameTooltip:Show()
end

local pins = ns.MapPins.Both(M, {
    specs = pinsOn,
    tooltip = tooltip,
    click = function(_, pin) ns.ShowQuest(pin.entries[1].questID) end,
    world = { shown = function() return M.db.worldMap end, size = function() return M.db.size end, level = 20 },
    minimap = { shown = function() return M.db.minimap end, size = function() return M.db.minimapSize end, level = 2 },
})


local refresh = pins.Refresh

local function refreshSoon() M:Soon(refresh) end

-- What the Recorder learns of a quest's place or title shows at once.
M:OnNews(function(_, event)
    if event == "QUEST_PLACE" or event == "QUEST_TITLE" or event == "BOOK_MERGED" then refreshSoon() end
end)

function M:OnEnable()
    for _, event in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN" }) do
        self:RegisterEvent(event, refreshSoon)
    end
end

function M:DebugLine()
    local mapID = C_Map.GetBestMapForUnit("player")
    return format(L.QPINS_DEBUG, mapID and #pinsOn(mapID) or 0)
end
