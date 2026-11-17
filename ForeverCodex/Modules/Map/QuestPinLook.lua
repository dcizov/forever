--[[
    Forever Codex - Modules/Map/QuestPinLook.lua
    How quest pins look and answer, in Forever++'s Quest Pins' style, for Quest Pins
    (QuestPins.lua) and a quest shown from the journal (QuestFocus.lua). A pin's spec (UI/MapPins.lua)
    carries kind ("giver", "item", "ender", "objective"), entries ({ questID, ... } each, what
    it's there for: source (a QuestieDB giver), daily, ready, text, itemID and npc, upcoming,
    low), place ({ map, x, y }: where Ctrl+click puts the map pin), count (the giver's spawns it
    stands for).

      * Look.Tint(entries, mode): a giver's colour and whether it's grayed, by the kind of its
        quests ("kind": holiday pink, dungeon orange-red, repeatable blue, profession orange,
        class in your class's colour), by the first one's level ("difficulty"), or none ("plain").
        Blizzard's "!" is yellow, so a tinted one is desaturated first.
      * Look.Cluster(points, limit): a giver's spawns { x, y } grouped by nearness on the map's
        canvas (CLUSTER px), into at most `limit` groups; Look.Nearest(group, x, y) the spawn of
        a group nearest you, where its pin stands.
      * Look.Tooltip(owner, pin): "[level] Title" in its difficulty colour with its kind in gold
        at the right, the other quests (MAX_LINES, then "and N more"), what it's there for (the
        giver's name, the turn-in, the objective), the level an upcoming quest needs, how many
        spawns it stands for, and, only while Shift is held, what clicks do.
      * Look.Click(pin, spec): Ctrl+click puts Blizzard's map pin on its place, Shift+click
        opens its first quest where ns.ShowQuest does (a giver's quests are discovered first).
    Adapted from Forever++'s Modules/Quests/QuestPins/Map.lua and Lib/MapTooltip.lua by
    xIGBClutchIx (MIT License).
]]

local _, ns = ...
local L = ns.L

local ipairs, format, math, table = ipairs, string.format, math, table
local Book, Places, QuestieDB, QuestGivers = ns.Book, ns.Places, ns.QuestieDB, ns.QuestGivers
local Text = assert(ns.JournalText, "QuestPinLook.lua loads after JournalText.lua")

local Look = {}
ns.QuestPinLook = Look

local CLUSTER = 48   -- px of the map's canvas: a giver's spawns closer than this share a pin
local MAX_LINES = 8  -- quests a tooltip lists
local GRAY = { 0.6, 0.6, 0.6 }
local TINT = {
    holiday = { 1, 0.55, 0.85 }, instance = { 1, 0.32, 0.08 }, repeatable = { 0.12, 0.72, 1 },
    profession = { 1, 0.65, 0.2 },
}
local KIND_ORDER = { "holiday", "instance", "class", "profession", "repeatable" }
local KIND_NAME = {
    holiday = L.QPINS_KIND_HOLIDAY, instance = L.QPINS_KIND_DUNGEON, class = L.QPINS_KIND_CLASS,
    profession = L.QPINS_KIND_PROFESSION, repeatable = L.QPINS_KIND_REPEATABLE,
}

-- What kind of quest an entry is: QuestieDB's for a giver of its, a daily's repeatable.
local function categoryOf(entry)
    if entry.source then return QuestGivers.Category(entry.questID) end
    return entry.daily and "repeatable" or "normal"
end

-- The first kind every entry is of, else nil (a plain pin).
local function kindOf(entries)
    for _, kind in ipairs(KIND_ORDER) do
        local all = true
        for _, entry in ipairs(entries) do
            if categoryOf(entry) ~= kind then
                all = false
                break
            end
        end
        if all then return kind end
    end
end

local function levelOf(questID) return ns.QuestIndex.Level(questID) or QuestGivers.Level(questID) end

function Look.Tint(entries, mode)
    if mode == "plain" then return nil, false end
    local color
    if mode == "difficulty" then
        local level = levelOf(entries[1].questID)
        local c = level and GetQuestDifficultyColor(level)
        color = c and { c.r, c.g, c.b } or nil
    else
        local kind = kindOf(entries)
        if kind == "class" then
            local _, classFile = UnitClass("player")
            local c = classFile and C_ClassColor.GetClassColor(classFile)
            color = c and { c.r, c.g, c.b } or nil
        else
            color = kind and TINT[kind] or nil
        end
    end
    return color, color ~= nil
end

---------------------------------------------------------------------------
-- Clusters
---------------------------------------------------------------------------

-- The world map canvas's size in px (where clusters are measured), or Blizzard's usual one.
local function canvasSize()
    local canvas = WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
    local width, height = canvas and canvas:GetWidth(), canvas and canvas:GetHeight()
    if width and height and width >= 1 and height >= 1 then return width, height end
    return 1000, 667
end

function Look.Cluster(points, limit)
    local width, height = canvasSize()
    local radius2 = CLUSTER * CLUSTER
    local groups = {}
    for _, point in ipairs(points) do
        local joined
        for g = #groups, 1, -1 do
            local group = groups[g]
            for _, other in ipairs(group) do
                local dx, dy = (point.x - other.x) * width, (point.y - other.y) * height
                if dx * dx + dy * dy <= radius2 then
                    if joined then
                        for _, moved in ipairs(group) do joined[#joined + 1] = moved end
                        table.remove(groups, g)
                    else
                        group[#group + 1] = point
                        joined = group
                    end
                    break
                end
            end
        end
        if not joined then groups[#groups + 1] = { point } end
    end
    -- Too many: the nearest two join until it fits.
    while #groups > limit do
        local bi, bj, best
        for i = 1, #groups - 1 do
            for j = i + 1, #groups do
                local a, b = groups[i][1], groups[j][1]
                local dx, dy = (a.x - b.x) * width, (a.y - b.y) * height
                local d = dx * dx + dy * dy
                if not best or d < best then bi, bj, best = i, j, d end
            end
        end
        for _, moved in ipairs(groups[bj]) do groups[bi][#groups[bi] + 1] = moved end
        table.remove(groups, bj)
    end
    return groups
end

-- Where you stand on `mapID` (a giver's pin goes to its spawn nearest you), else its middle.
function Look.PlayerSpot(mapID)
    local position = C_Map.GetPlayerMapPosition(mapID, "player")
    if position then return position:GetXY() end
    return 0.5, 0.5
end

function Look.Nearest(group, x, y)
    local best, bestD
    for _, point in ipairs(group) do
        local d = (point.x - x) ^ 2 + (point.y - y) ^ 2
        if not bestD or d < bestD then best, bestD = point, d end
    end
    return best
end

---------------------------------------------------------------------------
-- The tooltip
---------------------------------------------------------------------------

-- "[12] Title" and the colour of how hard it is for you.
local function questLine(questID)
    local title = Book.QuestName(questID)
    local level = levelOf(questID)
    if not level then return title, HIGHLIGHT_FONT_COLOR end
    return format("[%d] %s", level, title), GetQuestDifficultyColor(level)
end

local function kindName(entry)
    local kind = categoryOf(entry)
    if KIND_NAME[kind] then return KIND_NAME[kind] end
    return Text.QuestKind(Book.Quest(entry.questID) or {})
end

-- What the pin is there for, for one entry.
local function whatFor(pin, entry)
    if pin.kind == "giver" and entry.source then
        local source = entry.source
        local rec = source.kind == "npc" and (Book.Creature(source.id) or QuestieDB.Npc(source.id)) or QuestieDB.Object(source.id)
        return rec and rec.name or L.QPINS_GIVES
    end
    if pin.kind == "giver" then
        local giver = (Book.Quest(entry.questID) or {}).giver
        local rec = giver and giver.npc and Book.Creature(giver.npc)
        return rec and rec.name or giver and giver.name or L.QPINS_GIVES
    end
    if pin.kind == "item" then
        local rec = entry.npc and Book.Creature(entry.npc)
        return format(L.QPINS_ITEM, Text.ItemName(entry.itemID), rec and rec.name or "?")
    end
    if pin.kind == "ender" then return entry.ready and L.QPINS_READY or L.QPINS_NOT_READY end
    return entry.text or L.QPINS_OBJECTIVE
end

local function addLine(text, color)
    GameTooltip:AddLine(text, color.r or color[1], color.g or color[2], color.b or color[3], true)
end

function Look.Tooltip(owner, pin)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local entries = pin.entries
    local text, color = questLine(entries[1].questID)
    local kind = kindName(entries[1])
    if kind then
        local gold = NORMAL_FONT_COLOR
        GameTooltip:AddDoubleLine(text, kind, color.r, color.g, color.b, gold.r, gold.g, gold.b)
    else
        addLine(text, color)
    end
    for i = 2, #entries do
        if i > MAX_LINES then
            addLine(format(L.QPINS_MORE, #entries - MAX_LINES), GRAY)
            break
        end
        addLine(questLine(entries[i].questID))
    end
    local said = {}
    for i, entry in ipairs(entries) do
        local why = i <= MAX_LINES and whatFor(pin, entry)
        if why and not said[why] then
            said[why] = true
            addLine(why, HIGHLIGHT_FONT_COLOR)
        end
        local needs = i <= MAX_LINES and entry.upcoming and QuestGivers.RequiredLevel(entry.questID)
        if needs then addLine(format(L.QPINS_REQUIRES_LEVEL, needs), GRAY) end
    end
    if (pin.count or 1) > 1 then addLine(format(L.QPINS_SPAWNS, pin.count), GRAY) end
    -- What clicks do, only while Shift is held (a world map pin: the minimap's take none).
    if IsShiftKeyDown() and owner:GetObjectType() == "Button" then
        if pin.place then addLine(L.QPINS_HINT_WAYPOINT, GREEN_FONT_COLOR) end
        local inLog = C_QuestLog.GetLogIndexForQuestID(entries[1].questID) ~= nil
        addLine(inLog and L.QPINS_HINT_LOG or L.QPINS_HINT, GREEN_FONT_COLOR)
    end
    GameTooltip:Show()
end

function Look.Click(_, pin)
    if IsControlKeyDown() then
        local place = pin.place
        if place then Places.Waypoint(place.map, place.x, place.y) end
        return
    end
    if not IsShiftKeyDown() then return end
    if pin.kind == "giver" then
        for _, entry in ipairs(pin.entries) do Book.Discover(entry.questID) end
    end
    ns.ShowQuest(pin.entries[1].questID)
end

-- Whether a pin's quests are all ahead of your level or far under it (it's drawn faded).
function Look.Faded(entries)
    for _, entry in ipairs(entries) do
        if not (entry.upcoming or entry.low) then return false end
    end
    return true
end

-- Merges the pins of `list` that stand on one spot (`kind` alike) into one listing every quest.
local SAME_SPOT = 0.002
function Look.Stack(list)
    local stacked = {}
    for _, pin in ipairs(list) do
        local into
        for _, other in ipairs(stacked) do
            if other.kind == pin.kind and (other.x - pin.x) ^ 2 + (other.y - pin.y) ^ 2 < SAME_SPOT ^ 2 then
                into = other
                break
            end
        end
        if into then
            local have = {}
            for _, entry in ipairs(into.entries) do have[entry.questID] = true end
            for _, entry in ipairs(pin.entries) do
                if not have[entry.questID] then into.entries[#into.entries + 1] = entry end
            end
            into.count = math.max(into.count or 1, pin.count or 1)
        else
            stacked[#stacked + 1] = pin
        end
    end
    return stacked
end

-- Ahead of your level, far under it, then each by ID: what's worth taking now comes first.
function Look.Sort(entries)
    table.sort(entries, function(a, b)
        local fa, fb = (a.upcoming or a.low) and 1 or 0, (b.upcoming or b.low) and 1 or 0
        if fa ~= fb then return fa < fb end
        return a.questID < b.questID
    end)
end
