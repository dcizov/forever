--[[
    Forever Compendium - Modules/Data/BookMerge.lua
    Taking in a creature or quest someone else's book has (Sharing's, Modules/Social/Sharing.lua)
    or an older copy of your own has (the Archive's imports, Archive.lua), without counting the
    same thing twice:

      * Facts (its name, title, kind, rank, look...) fill only what yours doesn't know.
      * Sets (its looks, abilities, resistances, instances, quests) are joined.
      * Places keep the larger count of each map cell; the level range widens.
      * Loot: whichever book looted more corpses is kept whole, so the drop rates stay one
        book's own rates.
      * Wares fill what yours doesn't list.
    `full` (an import) also takes your own history from it: the larger kill, death and money
    counts, the earliest first seen and kill, the latest last ones, reputation, the pin and the
    note (a note only where yours has none). Sharing leaves those out.
]]

local _, ns = ...

local pairs, ipairs, type, math = pairs, ipairs, type, math
local Book = ns.Book

local FACTS = { "name", "title", "minLevel", "maxLevel", "skull", "classification", "creatureType", "family",
    "reaction", "display" }
local SETS = { "displays", "abilities", "defenses", "instances", "starts", "ends", "quests" }
local COUNTS = { "kills", "deaths", "money", "moneyCorpses" }
local EARLIEST, LATEST = { "first", "firstKill" }, { "last", "lastKill" }

Book.SHARED_FACTS, Book.SHARED_SETS = FACTS, SETS

local function mergeZones(rec, zones)
    rec.zones = rec.zones or {}
    for mapID, zone in pairs(zones or {}) do
        if type(mapID) == "number" and type(zone) == "table" then
            local ours = rec.zones[mapID] or { cells = {} }
            rec.zones[mapID] = ours
            for cell, n in pairs(type(zone.cells) == "table" and zone.cells or {}) do
                if type(n) == "number" then ours.cells[cell] = math.max(ours.cells[cell] or 0, math.min(n, 255)) end
            end
            for sub in pairs(type(zone.sub) == "table" and zone.sub or {}) do
                ours.sub = ours.sub or {}
                ours.sub[sub] = true
            end
        end
    end
end

local function mergeLoot(rec, theirs)
    if type(theirs.looted) ~= "number" or theirs.looted <= (rec.looted or 0) then return end
    rec.looted = theirs.looted
    rec.loot = {}
    for itemID, n in pairs(type(theirs.loot) == "table" and theirs.loot or {}) do
        if type(n) == "number" then rec.loot[itemID] = n end
    end
end

local function mergeHistory(rec, theirs)
    for _, key in ipairs(COUNTS) do
        if type(theirs[key]) == "number" then rec[key] = math.max(rec[key] or 0, theirs[key]) end
    end
    for _, key in ipairs(EARLIEST) do
        if type(theirs[key]) == "number" then rec[key] = math.min(rec[key] or theirs[key], theirs[key]) end
    end
    for _, key in ipairs(LATEST) do
        if type(theirs[key]) == "number" then rec[key] = math.max(rec[key] or theirs[key], theirs[key]) end
    end
    for faction, r in pairs(type(theirs.rep) == "table" and theirs.rep or {}) do
        rec.rep = rec.rep or {}
        if rec.rep[faction] == nil and type(r) == "table" then rec.rep[faction] = r end
    end
    if theirs.pinned == true then rec.pinned = true end
    if type(theirs.note) == "string" and (rec.note or "") == "" then rec.note = theirs.note end
end

-- Takes in creature `npcID` as `theirs` has it (a record of Book.lua's shape). Returns your
-- record and whether it was new to you; nil for something that isn't a creature record.
function Book.MergeCreature(npcID, theirs, full)
    if type(npcID) ~= "number" or type(theirs) ~= "table" or type(theirs.name) ~= "string" then return nil end
    local rec, isNew = Book.Meet(npcID, theirs.name)
    for _, key in ipairs(FACTS) do
        if rec[key] == nil and type(theirs[key]) ~= "table" then rec[key] = theirs[key] end
    end
    for _, key in ipairs(SETS) do
        for k, v in pairs(type(theirs[key]) == "table" and theirs[key] or {}) do
            if not (rec[key] and rec[key][k]) then Book.Mark(rec, key, k, v) end
        end
    end
    if type(theirs.minLevel) == "number" then rec.minLevel = math.min(rec.minLevel or theirs.minLevel, theirs.minLevel) end
    if type(theirs.maxLevel) == "number" then rec.maxLevel = math.max(rec.maxLevel or theirs.maxLevel, theirs.maxLevel) end
    mergeZones(rec, theirs.zones)
    mergeLoot(rec, theirs)
    for itemID, ware in pairs(type(theirs.wares) == "table" and theirs.wares or {}) do
        rec.wares = rec.wares or {}
        rec.wares[itemID] = rec.wares[itemID] or ware
    end
    if full then mergeHistory(rec, theirs) end
    return rec, isNew
end

-- Takes in quest `questID` as `theirs` has it: what yours doesn't know.
function Book.MergeQuest(questID, theirs)
    if type(questID) ~= "number" or type(theirs) ~= "table" then return end
    local q = Book.QuestRecord(questID)
    for key, value in pairs(theirs) do
        if q[key] == nil then q[key] = value end
    end
end

-- Takes in item `itemID` (its name, quality and icon) where yours doesn't have it.
function Book.MergeItem(itemID, item)
    if type(itemID) ~= "number" or type(item) ~= "table" or Book.Item(itemID) then return end
    Book.SetItem(itemID, item.name, item.quality, item.icon)
end
