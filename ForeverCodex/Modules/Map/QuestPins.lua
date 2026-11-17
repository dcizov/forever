--[[
    Forever Codex - Quest Pins
    Where your quests are, from what the Recorder learned (Lib/Book.lua) and, with QuestieDB,
    where the quests you can take start (Lib/QuestGivers.lua), on the world map and the minimap
    (UI/MapPins.lua), drawn the way Forever++'s Quest Pins draws them (QuestPinLook.lua):
      * Givers: a "!" where a quest you can take now starts (QuestieDB, by Forever++'s rules),
        and where you were offered one you haven't taken or done. Tinted by the kind of its
        quests (or by how hard, or not at all: Pin Colors), faded when its quests are all a few
        levels ahead of you (Upcoming Quests) or far under you. A giver's spawns close together
        share a pin, at the one nearest you, up to CLUSTER_LIMIT a giver (Group Spawns).
        Forever++'s Quest Pins draws the first kind too: while it's on, these step back, so a "!"
        never shows twice.
      * Quest items: where a creature dropped an item that starts a quest you haven't taken.
      * Turn-ins: a quest in your log, at the one who takes it in: a yellow "?" once it's ready,
        a grey one until then.
      * Objectives: where each objective still to do of a quest in your log went up before (its
        busiest few places), as the objective mark.
    Quests at the same spot share one pin; point at it for each one and what it's there for.
    Clicks go through to the map; Ctrl+click puts Blizzard's map pin there, Shift+click opens its
    first quest where ns.ShowQuest does (your quest log while it's in it; a giver's quests are
    discovered first). On a continent's map the givers, quest items and turn-ins of its zones
    show too. Drawn again when the quest log changes and when the Recorder learns a quest's place
    or title.
]]

local _, ns = ...
local L = ns.L

local pairs, ipairs, type, pcall, format, sort = pairs, ipairs, type, pcall, string.format, table.sort
local Book, Places, QuestGivers, QuestieDB = ns.Book, ns.Places, ns.QuestGivers, ns.QuestieDB
local Look = assert(ns.QuestPinLook, "QuestPins.lua loads after QuestPinLook.lua")

local OBJECTIVE_PLACES = 4 -- an objective's busiest places shown, at most
local CLUSTER_LIMIT = 6    -- pins a giver gets on one map, at most
local UPCOMING_LEVELS = 3  -- levels ahead an upcoming quest shows
local LOW_GAP, HIGH_GAP = 6, 5 -- levels under you a quest is faded, above you it's hidden
local FADED = 0.5          -- a faded pin's alpha
local ATLAS = { giver = "QuestNormal", ender = "QuestTurnin", objective = "QuestObjective" }
local ITEM_ICON = "Interface\\Icons\\INV_Misc_Note_02"
local LAYER = { objective = 0, item = 1, giver = 2, ender = 3 }
local ZONE_TYPE = 3 -- Enum.UIMapType.Zone: maps below a continent

local GROUP = { label = L.QPINS_SHOW, format = L.QPINS_SHOW_COUNT, tooltip = L.QPINS_SHOW_TIP }
local KINDS = { label = L.QPINS_KINDS, format = L.QPINS_SHOW_COUNT, tooltip = L.QPINS_KINDS_TIP }
local COLORS = { { "kind", L.QPINS_COLOR_KIND }, { "difficulty", L.QPINS_COLOR_DIFFICULTY }, { "plain", L.QPINS_COLOR_PLAIN } }

local M = ns:NewModule("QuestPins", {
    title = L.QPINS_TITLE,
    category = "map",
    description = L.QPINS_DESC,
    added = "2.1.0",
    defaults = {
        givers = true, available = true, items = true, turnIns = true, objectives = true, continent = true,
        worldMap = true, size = 16, minimap = true, minimapSize = 14,
        color = "kind", clusters = true, upcoming = true,
        kindClass = true, kindProfession = true, kindRepeatable = false, kindDungeon = false, kindHoliday = false,
    },
    options = {
        { key = "givers", type = "checkbox", label = L.QPINS_GIVERS, tooltip = L.QPINS_GIVERS_TIP, group = GROUP },
        { key = "available", type = "checkbox", label = L.QPINS_AVAILABLE, tooltip = L.QPINS_AVAILABLE_TIP, group = GROUP,
          added = "3.1.0" },
        { key = "items", type = "checkbox", label = L.QPINS_ITEMS, tooltip = L.QPINS_ITEMS_TIP, group = GROUP, added = "2.3.0" },
        { key = "turnIns", type = "checkbox", label = L.QPINS_TURNINS, tooltip = L.QPINS_TURNINS_TIP, group = GROUP },
        { key = "objectives", type = "checkbox", label = L.QPINS_OBJECTIVES, tooltip = L.QPINS_OBJECTIVES_TIP, group = GROUP },
        { key = "kindClass", type = "checkbox", label = L.QPINS_KIND_CLASS, tooltip = L.QPINS_KIND_CLASS_TIP, group = KINDS,
          added = "3.2.0" },
        { key = "kindProfession", type = "checkbox", label = L.QPINS_KIND_PROFESSION, tooltip = L.QPINS_KIND_PROFESSION_TIP,
          group = KINDS, added = "3.2.0" },
        { key = "kindRepeatable", type = "checkbox", label = L.QPINS_KIND_REPEATABLE, tooltip = L.QPINS_KIND_REPEATABLE_TIP,
          group = KINDS, added = "3.2.0" },
        { key = "kindDungeon", type = "checkbox", label = L.QPINS_KIND_DUNGEON, tooltip = L.QPINS_KIND_DUNGEON_TIP,
          group = KINDS, added = "3.2.0" },
        { key = "kindHoliday", type = "checkbox", label = L.QPINS_KIND_HOLIDAY, tooltip = L.QPINS_KIND_HOLIDAY_TIP,
          group = KINDS, added = "3.2.0" },
        { key = "upcoming", type = "checkbox", label = L.QPINS_UPCOMING, tooltip = L.QPINS_UPCOMING_TIP, added = "3.2.0" },
        { key = "clusters", type = "checkbox", label = L.QPINS_CLUSTERS, tooltip = L.QPINS_CLUSTERS_TIP, added = "3.2.0" },
        { key = "color", type = "dropdown", label = L.QPINS_COLOR, tooltip = L.QPINS_COLOR_TIP, choices = COLORS,
          added = "3.2.0" },
        { key = "continent", type = "checkbox", label = L.QPINS_CONTINENT, tooltip = L.QPINS_CONTINENT_TIP, added = "2.3.0" },
        { key = "worldMap", type = "checkbox", label = L.PINS_WORLD, tooltip = L.PINS_WORLD_TIP, slider = "size" },
        { key = "size", type = "slider", label = L.PINS_SIZE, min = 10, max = 32, step = 2, format = "%d px",
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

-- Adds a quest to the pin at (x, y) of `kind`, made when it's the first there. `place` ({ map,
-- x, y }) is where Ctrl+click puts the map pin.
local function addTo(pins, byKey, kind, x, y, entry, place)
    local key = format("%s:%.3f:%.3f", kind, x, y)
    local pin = byKey[key]
    if not pin then
        pin = { x = x, y = y, kind = kind, atlas = ATLAS[kind], layer = LAYER[kind], entries = {}, gray = true, place = place }
        if kind == "item" then pin.atlas, pin.texture = nil, ITEM_ICON end
        byKey[key] = pin
        pins[#pins + 1] = pin
    end
    pin.entries[#pin.entries + 1] = entry
    -- A turn-in pin is yellow once any quest at it is ready; the others always are.
    if kind ~= "ender" or entry.ready then pin.gray = false end
    return pin
end

-- A giver's colour, gray and alpha (QuestPinLook.Tint), once its quests are all in.
local function lookOf(pin)
    if pin.kind ~= "giver" then return end
    Look.Sort(pin.entries)
    pin.color, pin.gray = Look.Tint(pin.entries, M.db.color)
    local low = Look.Faded(pin.entries) and pin.entries[1].low
    if low then pin.color, pin.gray = nil, true end
    pin.alpha = Look.Faded(pin.entries) and FADED or 1
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
                addTo(pins, byKey, "objective", x, y, { questID = questID, text = objective.text }, { map = mapID, x = x, y = y })
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

-- Whether Forever++'s Quest Pins draws the "!" now (ours step back).
local function forPlusPlusPins()
    local api = ForeverPlusPlusAPI and ForeverPlusPlusAPI.v1
    if type(api) ~= "table" or type(api.IsModuleEnabled) ~= "function" then return false end
    local ok, on = pcall(api.IsModuleEnabled, "QuestPins")
    return ok and on == true
end

-- What Quest Pins shows of the quests you can take (QuestGivers.Check's rules).
local function rules()
    local db = M.db
    return {
        kinds = { normal = true, class = db.kindClass, profession = db.kindProfession, repeatable = db.kindRepeatable,
            instance = db.kindDungeon, holiday = db.kindHoliday },
        upcoming = db.upcoming and UPCOMING_LEVELS or 0, low = "fade", lowGap = LOW_GAP, highGap = HIGH_GAP,
    }
end

-- The "!" where the quests you can take now start on `mapID` (QuestieDB's givers, its zone maps
-- only): a pin for each group of a giver's spawns there. Returns the quests pinned.
local function addAvailable(list, mapID)
    local shown, check = {}, rules()
    local px, py = Look.PlayerSpot(mapID)
    for _, source in ipairs(QuestGivers.On(mapID)) do
        if QuestGivers.Friendly(source.friendly) then
            local entries = {}
            for _, questID in ipairs(source.quests) do
                local ok, note = QuestGivers.Check(questID, check)
                if ok then
                    entries[#entries + 1] = { questID = questID, source = source, upcoming = note == "upcoming", low = note == "low" }
                    shown[questID] = true
                end
            end
            if #entries > 0 then
                local points = {}
                for i = 1, #source.xs do points[i] = { x = source.xs[i], y = source.ys[i] } end
                local groups = M.db.clusters and Look.Cluster(points, CLUSTER_LIMIT) or { points }
                for _, group in ipairs(groups) do
                    local at = Look.Nearest(group, px, py)
                    local copy = {}
                    for i, entry in ipairs(entries) do copy[i] = entry end
                    list[#list + 1] = { x = at.x, y = at.y, kind = "giver", atlas = ATLAS.giver, layer = LAYER.giver,
                        entries = copy, count = #group, place = { map = mapID, x = at.x, y = at.y } }
                end
            end
        end
    end
    return shown
end

local function addOffered(pins, byKey, questID, rec, mapID, rects, shown)
    local db = M.db
    if C_QuestLog.IsQuestFlaggedCompleted(questID) then return end
    if db.givers and rec.giver and not shown[questID] and not forPlusPlusPins() then
        local x, y = spotOn(rec.giver, mapID, rects)
        if x then addTo(pins, byKey, "giver", x, y, { questID = questID, daily = rec.daily == true }, rec.giver) end
    end
    if db.items and rec.itemFrom then
        local x, y = spotOn(rec.itemFrom, mapID, rects)
        if x then
            addTo(pins, byKey, "item", x, y, { questID = questID, itemID = rec.startItem, npc = rec.itemFrom.npc }, rec.itemFrom)
        end
    end
end

-- The pins on `mapID`.
local function pinsOn(mapID)
    local db, pins, byKey = M.db, {}, {}
    local log = questsInLog()
    local rects = db.continent and isContinent(mapID) and {} or nil
    local available, shown = {}, {}
    if db.available and not rects and not forPlusPlusPins() then shown = addAvailable(available, mapID) end
    for questID, rec in pairs(Book.Quests()) do
        local objectives = log[questID]
        if objectives then
            local ender = rec.ender
            if db.turnIns and ender then
                local x, y = spotOn(ender, mapID, rects)
                if x then
                    addTo(pins, byKey, "ender", x, y, { questID = questID, ready = C_QuestLog.ReadyForTurnIn(questID) }, ender)
                end
            end
            if db.objectives and not rects then addObjectives(pins, byKey, questID, rec, objectives, mapID) end
        else
            addOffered(pins, byKey, questID, rec, mapID, rects, shown)
        end
    end
    for _, pin in ipairs(available) do pins[#pins + 1] = pin end
    pins = Look.Stack(pins)
    for _, pin in ipairs(pins) do lookOf(pin) end
    return pins
end

local pins = ns.MapPins.Both(M, {
    specs = pinsOn,
    tooltip = Look.Tooltip,
    click = Look.Click,
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
    for _, event in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "PLAYER_LEVEL_UP" }) do
        self:RegisterEvent(event, refreshSoon)
    end
    -- Where quests start: read from QuestieDB a little each frame (loaded first if it loads on demand).
    if self.db.available then
        QuestieDB.OnReady(self, function() QuestGivers.Build(self, refreshSoon) end)
    end
end

function M:OnSettingChanged(key)
    if key == "available" and self.db.available then
        QuestieDB.OnReady(self, function() QuestGivers.Build(self, refreshSoon) end)
    end
    refreshSoon()
end

function M:DebugLine()
    local mapID = C_Map.GetBestMapForUnit("player")
    return format(L.QPINS_DEBUG, mapID and #pinsOn(mapID) or 0)
end
