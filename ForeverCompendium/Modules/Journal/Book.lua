--[[
    Forever Compendium - Modules/Journal/Book.lua
    What the addon has learned, and the one way to read and add to it. The Recorder module owns
    the saved tables (its data: ForeverCompendiumDB.data.Recorder) and attaches them here at
    login; the journal, map pins, tooltips, badges and sharing only read through Book.

      creatures[npcID] = {
          name, title (the line under its name, "Innkeeper"), minLevel, maxLevel, skull (seen
          as "??"), classification ("normal", "elite", "rare", "rareelite", "worldboss", "minus",
          "trivial"), creatureType, family, reaction (1-8, from the player),
          first, last (time() first and last seen), kills, firstKill, lastKill, deaths (yours
          to it), looted (corpses looted), money (copper looted), moneyCorpses,
          display (its first model's display ID), displays = { [displayID] = true } (its looks),
          zones = { [mapID] = { cells = { [cell] = n }, sub = { [subzone] = true } } } (Places),
          instances = { [instance name] = "party" | "raid" | ... } (where no map is known),
          loot = { [itemID] = corpses it was on }, wares = { [itemID] = { price, stack, limited } },
          abilities = { [spellID] = true }, defenses = { [school] = "resist" | "immune" },
          rep = { [faction] = { total, count, min, max } } (reputation its kills gave),
          starts, ends = { [questID] = true }, quests = { [questID] = role } (role "slay",
          "loot", "speak", "item" (drops an item that starts it); true when not known),
          pinned (shown on the map, top of the list), note (yours), shared (only known from
          another player, until you meet it), sharedBy,
      }
      quests[questID] = {
          title, level, cat ("elite", "dungeon", "raid", "pvp"), daily, objectives = { { text,
          type } }, rewards, choices = { itemID, ... }, giver, ender = { npc, name, map, x, y },
          startItem, itemFrom = { npc, map, x, y } (an item that starts it, and where it dropped),
          marks = { [objective] = { [mapID] = { cells = { [cell] = n } } } } (where it progressed),
      }
      items[itemID] = { name, quality, icon }
]]

local _, ns = ...
local L = ns.L

local pairs, ipairs, tonumber, type, time, format = pairs, ipairs, tonumber, type, time, string.format
local Plain = ns.Plain

local Book = {}
ns.Book = Book

local db -- the Recorder's db (its data tables read through it)

function Book.Attach(recorderDB) db = recorderDB end

function Book.Creatures() return db and db.creatures or {} end
function Book.Quests() return db and db.quests or {} end
function Book.Items() return db and db.items or {} end

function Book.Creature(npcID) return db and db.creatures[npcID] end
function Book.Quest(questID) return db and db.quests[questID] end
function Book.Item(itemID) return db and db.items[itemID] end

-- A creature's ID from its GUID ("Creature-0-server-instance-zone-npcID-spawn"; Vehicle the
-- same), or nil for players, pets, objects and secret GUIDs.
function Book.NpcOf(guid)
    guid = Plain(guid)
    if type(guid) ~= "string" then return nil end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
    return tonumber(id)
end

-- The creature's record, made when it's first met. Returns it and whether it's new.
function Book.Meet(npcID, name)
    local creatures = db.creatures
    local rec = creatures[npcID]
    if rec then return rec, false end
    local now = time()
    rec = { name = name, first = now, last = now, kills = 0, looted = 0, zones = {}, loot = {} }
    creatures[npcID] = rec
    Book.Changed()
    return rec, true
end

-- The quest's record, made when first asked for.
function Book.QuestRecord(questID)
    local quests = db.quests
    local rec = quests[questID]
    if not rec then
        rec = {}
        quests[questID] = rec
    end
    return rec
end

-- Sets a key-set entry on a record: rec[field][key] = value (true by default).
function Book.Mark(rec, field, key, value)
    local set = rec[field]
    if not set then
        set = {}
        rec[field] = set
    end
    if value == nil then value = true end
    set[key] = value
end

-- What the creature does for a quest: a known role replaces "true" (not known), never the other
-- way round, and "item" (it drops the quest's start) wins over the rest.
function Book.SetQuestRole(rec, questID, role)
    local now = rec.quests and rec.quests[questID]
    if now == nil or now == true or role == "item" then Book.Mark(rec, "quests", questID, role) end
end

function Book.SetItem(itemID, name, quality, icon)
    local items = db.items
    local item = items[itemID] or {}
    item.name, item.quality, item.icon = Plain(name) or item.name, Plain(quality) or item.quality, Plain(icon) or item.icon
    items[itemID] = item
end

-- How often `itemID` dropped from the creature: 0..1, or nil before any corpse was looted.
function Book.DropRate(rec, itemID)
    local looted = rec.looted or 0
    if looted == 0 then return nil end
    return math.min(1, ((rec.loot or {})[itemID] or 0) / looted)
end

-- How many entries a table has.
function Book.Count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

---------------------------------------------------------------------------
-- Quest titles
---------------------------------------------------------------------------

local asked = {} -- questID -> true once its data was asked of the server this session

-- A quest's title: what was learned, else the game's (kept once known), else nil while the
-- game loads it (the Recorder hears QUEST_DATA_LOAD_RESULT and keeps the title then).
function Book.QuestTitle(questID)
    local rec = db and db.quests[questID]
    if rec and rec.title then return rec.title end
    local title = Plain(C_QuestLog.GetTitleForQuestID(questID))
    if title and title ~= "" then
        if rec then rec.title = title end
        return title
    end
    if not asked[questID] then
        asked[questID] = true
        C_QuestLog.RequestLoadQuestByID(questID)
    end
    return nil
end

-- A quest's title, or "Quest #1234" while it isn't known.
function Book.QuestName(questID)
    return Book.QuestTitle(questID) or format(L.BOOK_QUEST_ID, questID)
end

---------------------------------------------------------------------------
-- Finding creatures
---------------------------------------------------------------------------

local names -- lower-case name -> { npcID, ... }, made when first asked, dropped on change

-- Something was added or merged: indexes are made again when next asked.
function Book.Changed() names = nil end

-- Puts `data`'s creatures, quests and items in place of the book's (the Archive's restore).
function Book.Replace(data)
    for _, key in ipairs({ "creatures", "quests", "items" }) do
        local t = db[key]
        for k in pairs(t) do t[k] = nil end
        for k, v in pairs(type(data[key]) == "table" and data[key] or {}) do t[k] = v end
    end
    Book.Changed()
end

-- The creatures named `name` (any case), several when one name has several IDs.
function Book.Named(name)
    if not names then
        names = {}
        for npcID, rec in pairs(Book.Creatures()) do
            local key = rec.name and rec.name:lower()
            if key then
                names[key] = names[key] or {}
                names[key][#names[key] + 1] = npcID
            end
        end
    end
    return names[name:lower()] or {}
end

-- The quests in your log now: questID -> true.
function Book.LogQuests()
    local list = {}
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID then list[info.questID] = true end
    end
    return list
end

-- A creature worth a trophy: "boss" (a world boss, or a skull), "rare", or nil.
function Book.TrophyKind(rec)
    if rec.classification == "worldboss" or rec.skull then return "boss" end
    if rec.classification == "rare" or rec.classification == "rareelite" then return "rare" end
end

-- Whether a quest in `log` (Book.LogQuests) has you kill, loot or speak to the creature (where
-- you hand a quest in is the quest pins' to show).
function Book.WantedBy(rec, log)
    for questID in pairs(rec.quests or {}) do
        if log[questID] then return true end
    end
    return false
end
