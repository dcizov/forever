--[[
    Forever Codex - Modules/Data/ImportQuests.lua
    Bestiary Import's quests (Import.lua runs it): Forever Bestiary's quests and quest pins made
    into the journal's. Quests bring their titles, levels and objectives; givers and turn-ins
    (by name, matched to creatures in the journal) come with where they stand; quest kinds and
    repeatables (dailies), where objectives went up, and items that start quests with the
    creature that drops them. What the journal already has is kept.
]]

local _, ns = ...

local pairs, ipairs, type = pairs, ipairs, type
local Book, Places = ns.Book, ns.Places

local ImportQuests = {}
ns.ImportQuests = ImportQuests

-- The spot Bestiary keeps for an NPC by name: { npc, name, map, x, y }.
local function spotOf(store, name)
    local spots = store.npcs and store.npcs[name]
    local spot = spots and spots[1]
    if not (spot and spot.m and spot.x) then return nil end
    return { npc = Book.Named(name)[1], name = name, map = spot.m, x = spot.x, y = spot.y }
end

local function markNamed(name, field, questID)
    for _, npcID in ipairs(Book.Named(name)) do Book.Mark(Book.Creature(npcID), field, questID) end
end

local function importQuest(questID, q, store)
    local rec = Book.QuestRecord(questID)
    rec.title = rec.title or q.title
    rec.level = rec.level or q.level
    if not rec.objectives and type(q.objectives) == "table" and q.objectives[1] then
        rec.objectives = {}
        for i, o in ipairs(q.objectives) do rec.objectives[i] = { text = o.text, type = o.kind } end
    end
    for name in pairs(q.starters or {}) do
        markNamed(name, "starts", questID)
        rec.giver = rec.giver or spotOf(store, name)
    end
    for name in pairs(q.enders or {}) do
        markNamed(name, "ends", questID)
        rec.ender = rec.ender or spotOf(store, name)
    end
end

local function importQuestPins(store)
    for name, offers in pairs(store.offers or {}) do
        for questID in pairs(offers) do
            if type(questID) == "number" then
                local rec = Book.QuestRecord(questID)
                rec.giver = rec.giver or spotOf(store, name)
                markNamed(name, "starts", questID)
            end
        end
    end
    for questID, names in pairs(store.enders or {}) do
        for name in pairs(names) do
            local rec = Book.QuestRecord(questID)
            rec.ender = rec.ender or spotOf(store, name)
            markNamed(name, "ends", questID)
        end
    end
    for questID, cats in pairs(store.qcat or {}) do
        local rec = Book.QuestRecord(questID)
        for cat in pairs(cats) do
            if cat == "repeat" then rec.daily = true else rec.cat = rec.cat or cat end
        end
    end
    for questID, marks in pairs(store.marks or {}) do
        local rec = Book.QuestRecord(questID)
        for _, mark in ipairs(marks) do
            if mark.m and mark.x and mark.obj then
                rec.marks = rec.marks or {}
                rec.marks[mark.obj] = rec.marks[mark.obj] or {}
                Places.Add(rec.marks[mark.obj], mark.m, mark.x, mark.y)
            end
        end
    end
end

local function importStartItems(store)
    for questID, drop in pairs(store.loot or {}) do
        local npcID = drop.creature and Book.Named(drop.creature)[1]
        local rec = Book.QuestRecord(questID)
        rec.startItem = rec.startItem or drop.item
        local creature = npcID and Book.Creature(npcID)
        if creature then
            Book.SetQuestRole(creature, questID, "item")
            for mapID, zone in pairs(creature.zones or {}) do
                local cell = next(zone.cells)
                if cell and not rec.itemFrom then
                    local x, y = Places.CellCenter(cell)
                    rec.itemFrom = { npc = npcID, map = mapID, x = x, y = y }
                end
            end
        end
    end
end

-- Brings in one Bestiary save's quests and quest pins. Returns how many quests.
function ImportQuests.Import(db)
    local store, count = db.questPins or {}, 0
    for questID, q in pairs(db.quests or {}) do
        if type(questID) == "number" and type(q) == "table" then
            count = count + 1
            importQuest(questID, q, store)
        end
    end
    importQuestPins(store)
    importStartItems(store)
    return count
end
