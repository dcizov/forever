--[[
    Forever Compendium - Modules/Recorder/RecorderLoot.lua
    The Recorder's Loot part (Modules/Recorder/Recorder.lua registers LOOT_OPENED and calls Opened):
    what each creature's corpse held. Each slot names the corpses it came from (GetLootSourceInfo:
    a GUID and a count for each, several with area looting; for money the count is its copper).
    A corpse counts once: `looted` goes up the first time its window opens, and each item it held
    counts once for it, so an item's drop rate is the corpses it was on over the corpses looted.
    Objects (nodes, chests, fishing) and creatures the journal hasn't met are left out.

    Quests: an item for a quest marks the creature as one you loot for that quest; an item that
    starts a quest (its quest not active yet) marks the creature as dropping it, and the quest
    keeps the item and where it dropped (the quest pins show it).
]]

local _, ns = ...

local pairs, tonumber = pairs, tonumber
local Book, Places, Plain = ns.Book, ns.Places, ns.Plain

local Loot = {}
ns.RecorderLoot = Loot

local counted = {} -- corpse GUID -> true once counted this session
local countedSize = 0

local function remember(guid)
    if countedSize > 500 then -- a long session: start over (an old corpse is long gone)
        counted, countedSize = {}, 0
    end
    counted[guid] = true
    countedSize = countedSize + 1
end

-- { [guid] = { npc, count } } of the creatures slot `slot` came from.
local function sourcesOf(slot)
    local list = {}
    local info = { GetLootSourceInfo(slot) }
    for i = 1, #info, 2 do
        local guid = Plain(info[i])
        local npc = guid and Book.NpcOf(guid)
        if npc and Book.Creature(npc) then list[guid] = { npc = npc, count = tonumber(Plain(info[i + 1])) or 0 } end
    end
    return list
end

-- The item `slot` holds that starts a quest, or is for one: itemID, questID, starts.
local function questOf(slot)
    local _, _, _, _, _, _, isQuestItem, questID, isActive = GetLootSlotInfo(slot)
    questID = Plain(questID)
    if not (questID and questID > 0) then return nil end
    return questID, Plain(isActive) == false and Plain(isQuestItem) ~= nil
end

local function startsQuest(npc, questID, itemID)
    local quest = Book.QuestRecord(questID)
    local isNew = quest.startItem == nil
    quest.startItem = itemID
    local map, x, y = Places.Here()
    if map then quest.itemFrom = { npc = npc, map = map, x = x, y = y } end
    if Book.SetQuestRole(Book.Creature(npc), questID, "item") then ns:Announce("CREATURE_LEARNED", npc, "quests") end
    if isNew then ns:Announce("QUEST_PLACE", questID, "item") end
end

-- One slot: what it gives each corpse it came from (into `corpses`).
local function readSlot(slot, corpses)
    local sources = sourcesOf(slot)
    for guid, source in pairs(sources) do
        corpses[guid] = corpses[guid] or { npc = source.npc, items = {}, money = 0 }
    end
    local kind = GetLootSlotType(slot)
    if kind == Enum.LootSlotType.Money then
        for guid, source in pairs(sources) do corpses[guid].money = corpses[guid].money + source.count end
        return
    end
    if kind ~= Enum.LootSlotType.Item then return end
    local link = Plain(GetLootSlotLink(slot))
    local itemID = link and C_Item.GetItemInfoInstant(link)
    if not itemID then return end
    local icon, name, _, _, quality = GetLootSlotInfo(slot)
    Book.SetItem(itemID, name, quality, icon, link)
    local questID, starts = questOf(slot)
    for guid, source in pairs(sources) do
        corpses[guid].items[itemID] = true
        if questID and starts then
            startsQuest(source.npc, questID, itemID)
        elseif questID and Book.SetQuestRole(Book.Creature(source.npc), questID, "loot") then
            ns:Announce("CREATURE_LEARNED", source.npc, "quests")
        end
    end
end

function Loot.Opened(mod)
    local corpses = {} -- guid -> { npc, items = { itemID = true }, money }
    for slot = 1, GetNumLootItems() do readSlot(slot, corpses) end
    for guid, corpse in pairs(corpses) do
        if not counted[guid] then
            remember(guid)
            local npc = corpse.npc
            local rec = Book.Creature(npc)
            rec.looted = (rec.looted or 0) + 1
            if corpse.money > 0 then
                rec.money = (rec.money or 0) + corpse.money
                rec.moneyCorpses = (rec.moneyCorpses or 0) + 1
            end
            rec.loot = rec.loot or {}
            for itemID in pairs(corpse.items) do
                local before = rec.loot[itemID]
                rec.loot[itemID] = (before or 0) + 1
                if not before then ns:Announce("LOOT_NEW", npc, itemID) end
            end
            mod:Debug("looted", rec.name, Book.Count(corpse.items), "items")
        end
    end
end
