--[[
    Forever runtime - Shared/Lib/QuestieDB.lua
    The one place the Forever addons read the QuestieDB addon (LibQuestieDB, its public API), the
    way Forever++'s Quest Pins does. QuestieDB is an optional dependency: QuestieDB.Status says
    whether it can be read, QuestieDB.OnReady waits for it (it can load on demand), and a module
    that can't work without it calls QuestieDB.Require as its file loads (red and locked off on
    Forever++'s Modules page with a notice saying to get it; a QuestieDB of another shape is red too).

    Everything is read only, protected (an error of QuestieDB's is read as nothing), and copied
    into plain tables of ours: we never register corrections, change its locale or drop its caches,
    since Questie and other addons share them. Its coordinates are 0-100 percents keyed by AreaTable
    IDs; ours are 0-1 on a uiMapID (the area-to-map table is QuestieDB's own ZoneDB support data).

      * QuestItems, ItemQuests: the items a quest needs, and the quests an item was for (Forever
        Gearbox' Quest Items and Full Bags).
      * Quest, Npc, Object, Item: one record each, in our shape (see each); QuestBrief: the few
        fields a list of every quest needs; Ids(kind): every ID of a kind; UiMapID(areaID): the
        map an area is on (Forever Codex's Quests page).
      * Field(owner, kind, id, key), NpcFlags(): one field in QuestieDB's own (Questie's) shape and
        its NPC flag values, copied (Forever Codex's townsfolk for OpenMap).
    Adapted from Forever++'s Lib/QuestieDB.lua by xIGBClutchIx (MIT License).
]]

local _, ns = ...
local L = ns.L

local type, pairs, ipairs, pcall, loadstring, setfenv = type, pairs, ipairs, pcall, loadstring, setfenv
local floor = math.floor

local QuestieDB = {}
ns.QuestieDB = QuestieDB

QuestieDB.ADDON = "QuestieDB"
local ITEM_OBJECTIVES = 3 -- objectives: creature, object, item, ... groups (QuestieDB questMeta)

-- The fields each kind is read with (QuestieDB's names).
local FIELDS = {
    Quest = { "name", "questLevel", "requiredLevel", "requiredMaxLevel", "startedBy", "finishedBy", "objectives", "objectivesText",
        "preQuestGroup", "preQuestSingle", "nextQuestInChain", "childQuests", "exclusiveTo", "zoneOrSort",
        "requiredRaces", "requiredClasses", "sourceItemId", "breadcrumbForQuestId", "questFlags", "specialFlags",
        "requiredSkill" },
    Npc = { "name", "subName", "minLevel", "maxLevel", "rank", "spawns", "zoneID", "questStarts", "questEnds",
        "friendlyToFaction" },
    Object = { "name", "spawns", "zoneID", "questStarts", "questEnds" },
    Item = { "name", "npcDrops", "objectDrops", "vendors", "startQuest", "relatedQuests" },
}

-- LibQuestieDB when it's there with the calls read here, else nil.
local function lib()
    local db = _G.LibQuestieDB
    if type(db) ~= "table" or type(db.Quest) ~= "table" or type(db.Item) ~= "table" then return nil end
    if type(db.Quest.Get) ~= "function" or type(db.Item.Get) ~= "function" then return nil end
    return db
end

-- Calls fn(...) protected: its first result, or nil when it errors.
local function try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if ok then return result end
    return nil
end

-- C_AddOns' word on QuestieDB: installed, loaded, and loaded on demand (and loadable).
local function addon()
    local name = QuestieDB.ADDON
    local loaded = C_AddOns.IsAddOnLoaded(name) and true or false
    local _, _, _, loadable, reason = C_AddOns.GetAddOnInfo(name)
    local installed = loaded or (reason ~= "MISSING" and reason ~= nil) or loadable and true or false
    local onDemand = C_AddOns.IsAddOnLoadOnDemand(name) and (loadable or reason == "DEMAND_LOADED") and true or false
    return installed, loaded, onDemand
end

-- "ready" (its API answers), "missing", "off" (turned off, or it couldn't load), "waiting"
-- (loaded on demand, not yet), or "shape" (loaded without the API read here).
function QuestieDB.Status()
    if lib() then return "ready" end
    local installed, loaded, onDemand = addon()
    if loaded then return "shape" end
    if not installed then return "missing" end
    if onDemand then return "waiting" end
    return "off"
end

function QuestieDB.Problem()
    return QuestieDB.Status() == "shape"
end

-- The module can't work without QuestieDB: its notices say so, and it's locked off while
-- QuestieDB is missing or off (Forever++ shows it red, with a padlock for its checkbox).
function QuestieDB.Require(mod)
    local notices = mod.notice or {}
    if notices.text or notices.requires then notices = { notices } end
    notices[#notices + 1] = { text = L.QUESTIEDB_NEEDED, tooltip = L.QUESTIEDB_NEEDED_TIP,
        shown = function() local now = QuestieDB.Status() return now == "missing" or now == "off" end }
    notices[#notices + 1] = { text = L.QUESTIEDB_PROBLEM, tooltip = L.QUESTIEDB_PROBLEM_TIP, shown = QuestieDB.Problem }
    mod.notice = notices
    local now = QuestieDB.Status()
    if now == "missing" or now == "off" then
        mod.locked, mod.lockedText = true, L.QUESTIEDB_LOCKED
    end
    function mod.Problem() return mod.locked or QuestieDB.Problem() end
end

-- fn() once QuestieDB can be read: now, or after it loads on demand (out of combat). Asked from
-- the module's OnEnable, so it's the module's event and stops with it.
function QuestieDB.OnReady(owner, fn)
    if lib() then return fn() end
    if QuestieDB.Status() ~= "waiting" then return end
    owner:RegisterEvent("ADDON_LOADED", function(_, _, name)
        if name ~= QuestieDB.ADDON then return end
        owner:UnregisterEvent("ADDON_LOADED")
        if lib() then fn() end
    end)
    ns:AfterCombat(owner, function() C_AddOns.LoadAddOn(QuestieDB.ADDON) end)
end

-- One read, protected: nil when QuestieDB errors (logged to `owner`).
local function get(owner, kind, id, key)
    local db = lib()
    local entity = db and db[kind]
    if not (entity and type(entity.Get) == "function") then return nil end
    local ok, value = pcall(entity.Get, id, key)
    if not ok then
        (owner or ns):Debug("QuestieDB:", value)
        return nil
    end
    return value
end

-- The items quest `questID` needs (item objectives, the item it starts with, the items it
-- takes), added to `ids` (itemID -> true).
function QuestieDB.QuestItems(owner, questID, ids)
    local objectives = get(owner, "Quest", questID, "objectives")
    local items = type(objectives) == "table" and objectives[ITEM_OBJECTIVES]
    for _, objective in ipairs(type(items) == "table" and items or {}) do
        if type(objective) == "table" and type(objective[1]) == "number" then ids[objective[1]] = true end
    end
    local source = get(owner, "Quest", questID, "sourceItemId")
    if type(source) == "number" then ids[source] = true end
    local required = get(owner, "Quest", questID, "requiredSourceItems")
    for _, id in ipairs(type(required) == "table" and required or {}) do
        if type(id) == "number" then ids[id] = true end
    end
end

-- The quests item `itemID` was for: { { name, done } }, at most `max`.
function QuestieDB.ItemQuests(owner, itemID, max)
    local quests = {}
    local related = get(owner, "Item", itemID, "relatedQuests")
    for _, questID in ipairs(type(related) == "table" and related or {}) do
        local name = get(owner, "Quest", questID, "name")
        if type(name) == "string" and #quests < max then
            quests[#quests + 1] = { name = name, done = C_QuestLog.IsQuestFlaggedCompleted(questID) }
        end
    end
    return quests
end

---------------------------------------------------------------------------
-- Plain values out of theirs
---------------------------------------------------------------------------

-- An ID (or a level, a mask), or nil for QuestieDB's 0 ("none") and anything that isn't a number.
local function id(value)
    if type(value) == "number" and value ~= 0 then return value end
    return nil
end

local function str(value) return type(value) == "string" and value or nil end

-- A list of IDs as our own list: only the non-zero numbers, in order.
local function ids(list)
    local out = {}
    if type(list) == "table" then
        for _, value in ipairs(list) do
            if id(value) then out[#out + 1] = value end
        end
    end
    return out
end

local function strings(list)
    local out = {}
    if type(list) == "table" then
        for _, value in ipairs(list) do
            if type(value) == "string" then out[#out + 1] = value end
        end
    end
    return out
end

-- A record's fields, by name (`names`, else all of FIELDS[kind]; GetAll when it has it, else one
-- Get each), or nil for an unknown ID.
local function readFields(kind, entityID, names)
    local db = lib()
    local entity = db and db[kind]
    if type(entity) ~= "table" or type(entityID) ~= "number" then return nil end
    names = names or FIELDS[kind]
    local fields = {}
    if type(entity.GetAll) == "function" then
        local values = try(entity.GetAll, entityID, names)
        if type(values) ~= "table" then return nil end
        for i, field in ipairs(names) do fields[field] = values[i] end
    else
        for _, field in ipairs(names) do fields[field] = try(entity.Get, entityID, field) end
        if fields.name == nil then return nil end
    end
    return fields
end

---------------------------------------------------------------------------
-- Zones: QuestieDB's areas on our maps
---------------------------------------------------------------------------

local zones -- area ID -> uiMapID (false: no map), read once from QuestieDB's ZoneDB support data

-- One of its support tables, which it keeps as Lua source text (`return { ... }`): run with no
-- globals, so it can only build a table. Takes a table as it is.
local function source(value)
    if type(value) == "table" then return value end
    if type(value) ~= "string" then return nil end
    local chunk = loadstring(value)
    if not chunk then return nil end
    setfenv(chunk, {})
    local result = try(chunk)
    return type(result) == "table" and result or nil
end

local function loadZones()
    zones = {}
    local db = lib()
    local support = db and type(db.Support) == "table" and try(db.Support.Get, "ZoneDB")
    local private = type(support) == "table" and type(support.private) == "table" and support.private
    if not private then return end
    -- Its overrides win, as Questie reads them; 0 there means "shown on no map".
    for _, list in ipairs({ source(private.areaIdToUiMapId) or {}, source(private.areaIdToUiMapIdOverride) or {} }) do
        for area, map in pairs(list) do
            if type(area) == "number" and type(map) == "number" then zones[area] = map ~= 0 and map or false end
        end
    end
end

-- The uiMapID QuestieDB puts AreaTable ID `areaID` on, or nil when it has none.
function QuestieDB.UiMapID(areaID)
    if not lib() or type(areaID) ~= "number" then return nil end
    if not zones then loadZones() end
    return zones[areaID] or nil
end

-- Spawns as our own list of { uiMapID, x, y } (x and y 0-1 on that map), and the areas of
-- instances it's somewhere inside (QuestieDB's -1, -1). A spawn in an area with no map is left out.
local function spawns(list)
    local out, instances = {}, {}
    if type(list) ~= "table" then return out, instances end
    for area, points in pairs(list) do
        if type(area) == "number" and type(points) == "table" then
            local map = QuestieDB.UiMapID(area)
            for _, point in ipairs(points) do
                local x, y = type(point) == "table" and point[1], type(point) == "table" and point[2]
                if type(x) == "number" and type(y) == "number" then
                    if x == -1 and y == -1 then
                        instances[#instances + 1] = area
                    elseif map then
                        out[#out + 1] = { uiMapID = map, x = x / 100, y = y / 100 }
                    end
                end
            end
        end
    end
    return out, instances
end

---------------------------------------------------------------------------
-- The readers
---------------------------------------------------------------------------

-- Objectives as { kind = "npc" | "object" | "item", id, text }, in QuestieDB's group order.
local function objectives(groups)
    local out = {}
    if type(groups) ~= "table" then return out end
    for group, kind in ipairs({ "npc", "object", "item" }) do
        for _, row in ipairs(type(groups[group]) == "table" and groups[group] or {}) do
            if type(row) == "table" and id(row[1]) then out[#out + 1] = { kind = kind, id = row[1], text = str(row[2]) } end
        end
    end
    return out
end

-- QuestieDB's quest flag bits read here (Lua 5.1 has no bit operators: one bit is enough).
local QUEST_RAID, QUEST_DAILY, QUEST_WEEKLY = 64, 4096, 32768
local function hasFlag(mask, bit) return floor(mask / bit) % 2 == 1 end

local function group(tbl, index) return ids(type(tbl) == "table" and tbl[index] or nil) end

-- A quest, or nil: { id, name, level, requiredLevel, maxLevel, races, classes (masks, nil: anyone),
-- areaID, uiMapID (the zone it's listed in), sortID (the quest log category of one listed under
-- one instead), starters = { npcs, objects, items }, finishers = { npcs, objects },
-- objectives (Objectives above), objectivesText, prerequisites = { all, any } (every one in
-- all and one of any done first), next, children, exclusiveTo, breadcrumbFor, sourceItemID,
-- repeatable, raid, skill = { id, value } (a profession and the rank it needs, or nil) }.
function QuestieDB.Quest(questID)
    local f = readFields("Quest", questID)
    if not f then return nil end
    local zone = type(f.zoneOrSort) == "number" and f.zoneOrSort or 0
    local flags = type(f.questFlags) == "number" and f.questFlags or 0
    local special = type(f.specialFlags) == "number" and f.specialFlags or 0
    return {
        id = questID, name = str(f.name), level = id(f.questLevel), requiredLevel = id(f.requiredLevel),
        maxLevel = id(f.requiredMaxLevel),
        races = id(f.requiredRaces), classes = id(f.requiredClasses),
        areaID = zone > 0 and zone or nil, uiMapID = zone > 0 and QuestieDB.UiMapID(zone) or nil,
        sortID = zone < 0 and -zone or nil,
        starters = { npcs = group(f.startedBy, 1), objects = group(f.startedBy, 2), items = group(f.startedBy, 3) },
        finishers = { npcs = group(f.finishedBy, 1), objects = group(f.finishedBy, 2) },
        objectives = objectives(f.objectives), objectivesText = strings(f.objectivesText),
        prerequisites = { all = ids(f.preQuestGroup), any = ids(f.preQuestSingle) },
        next = id(f.nextQuestInChain), children = ids(f.childQuests), exclusiveTo = ids(f.exclusiveTo),
        breadcrumbFor = id(f.breadcrumbForQuestId), sourceItemID = id(f.sourceItemId),
        repeatable = special % 2 == 1 or hasFlag(flags, QUEST_DAILY) or hasFlag(flags, QUEST_WEEKLY),
        raid = hasFlag(flags, QUEST_RAID),
        skill = type(f.requiredSkill) == "table" and id(f.requiredSkill[1])
            and { id = f.requiredSkill[1], value = id(f.requiredSkill[2]) or 0 } or nil,
    }
end

-- What a list of every quest needs of one, read lighter than Quest: { name, level, areaID,
-- sortID, races, classes, prerequisites = { all, any }, repeatable }, or nil.
local BRIEF = { "name", "questLevel", "zoneOrSort", "requiredRaces", "requiredClasses", "preQuestGroup", "preQuestSingle",
    "questFlags", "specialFlags" }
function QuestieDB.QuestBrief(questID)
    local f = readFields("Quest", questID, BRIEF)
    if not f then return nil end
    local zone = type(f.zoneOrSort) == "number" and f.zoneOrSort or 0
    local flags = type(f.questFlags) == "number" and f.questFlags or 0
    local special = type(f.specialFlags) == "number" and f.specialFlags or 0
    return {
        name = str(f.name), level = id(f.questLevel), areaID = zone > 0 and zone or nil, sortID = zone < 0 and -zone or nil,
        races = id(f.requiredRaces), classes = id(f.requiredClasses),
        prerequisites = { all = ids(f.preQuestGroup), any = ids(f.preQuestSingle) },
        repeatable = special % 2 == 1 or hasFlag(flags, QUEST_DAILY) or hasFlag(flags, QUEST_WEEKLY),
    }
end

-- An NPC, or nil: { id, name, subName, minLevel, maxLevel, rank, areaID, uiMapID, spawns,
-- instances, questStarts, questEnds, friendlyTo ("A", "H", "AH" or nil) } (spawns as above).
function QuestieDB.Npc(npcID)
    local f = readFields("Npc", npcID)
    if not f then return nil end
    local list, instances = spawns(f.spawns)
    return {
        id = npcID, name = str(f.name), subName = str(f.subName), minLevel = id(f.minLevel), maxLevel = id(f.maxLevel),
        rank = type(f.rank) == "number" and f.rank or 0, areaID = id(f.zoneID),
        uiMapID = id(f.zoneID) and QuestieDB.UiMapID(f.zoneID) or nil, spawns = list, instances = instances,
        questStarts = ids(f.questStarts), questEnds = ids(f.questEnds),
        friendlyTo = (f.friendlyToFaction == "A" or f.friendlyToFaction == "H" or f.friendlyToFaction == "AH")
            and f.friendlyToFaction or nil,
    }
end

-- A world object (a chest, a quest object), or nil: { id, name, areaID, uiMapID, spawns,
-- instances, questStarts, questEnds }.
function QuestieDB.Object(objectID)
    local f = readFields("Object", objectID)
    if not f then return nil end
    local list, instances = spawns(f.spawns)
    return {
        id = objectID, name = str(f.name), areaID = id(f.zoneID),
        uiMapID = id(f.zoneID) and QuestieDB.UiMapID(f.zoneID) or nil, spawns = list, instances = instances,
        questStarts = ids(f.questStarts), questEnds = ids(f.questEnds),
    }
end

-- An item, or nil: { id, name, npcDrops, objectDrops, vendors (NPC IDs), startsQuest, relatedQuests }.
function QuestieDB.Item(itemID)
    local f = readFields("Item", itemID)
    if not f then return nil end
    return {
        id = itemID, name = str(f.name), npcDrops = ids(f.npcDrops), objectDrops = ids(f.objectDrops),
        vendors = ids(f.vendors), startsQuest = id(f.startQuest), relatedQuests = ids(f.relatedQuests),
    }
end

-- A copy of `value` (tables all the way down), so nothing of QuestieDB's is handed on.
local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, inner in pairs(value) do out[key] = copy(inner) end
    return out
end

-- One field of a record as QuestieDB keeps it (Questie's own shape: spawns by area in 0-100
-- percents), copied, or nil. For another addon that reads Questie's shape (Forever Codex hands
-- OpenMap its townsfolk this way).
function QuestieDB.Field(owner, kind, recordID, key)
    return copy(get(owner, kind, recordID, key))
end

-- QuestieDB's NPC flag values (VENDOR, REPAIR, INNKEEPER, ...), copied; empty while it can't be read.
function QuestieDB.NpcFlags()
    local db = lib()
    local enum = db and type(db.Enum) == "table" and db.Enum.npcFlags
    return type(enum) == "table" and copy(enum) or {}
end

-- Every ID of `kind` ("Quest", "Npc", "Item", "Object"), as our own list; empty while QuestieDB
-- can't be read.
function QuestieDB.Ids(kind)
    local db = lib()
    local entity = db and db[kind]
    if type(entity) ~= "table" then return {} end
    return ids(try(entity.GetAllIds))
end
