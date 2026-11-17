--[[
    Forever Codex - Modules/Recorder/RecorderLoot.lua
    The Recorder's Loot part (Modules/Recorder/Recorder.lua registers the loot events and calls
    these): what each creature's corpse held. Each slot names the corpses it came from
    (GetLootSourceInfo: a GUID and a count for each, several with area looting; for money the
    count is its copper).

    A window is read on LOOT_READY, before auto loot takes anything; LOOT_OPENED reads it again
    only when LOOT_READY didn't (a second read finds nothing new). A corpse counts once: `looted`
    goes up the first time something is read from it, and each item counts once for each corpse,
    so a window opened again (or read twice) adds only what's new, and an item's drop rate is the
    corpses it was on over the corpses looted.

    Left out: objects (nodes, chests), fishing, containers opened from the bags, a living
    creature's pockets (Pick Pocket: its corpse still counts later) and what a corpse gives a
    gathering spell (skinning, mining, herbs: GATHER_SPELLS, cast just before the window).

    Looting a corpse meets its creature: one you target or mouse over is met then (`meet`, the
    Recorder's), and one met nowhere yet keeps its corpses for the session (`pending`) until it is
    (Loot.Met, from the Recorder when it meets a creature).

    Quests: an item for a quest marks the creature as one you loot for that quest; an item that
    starts a quest (its quest not active yet) marks the creature as dropping it, and the quest
    keeps the item and where it dropped (the quest pins show it).
]]

local _, ns = ...

local pairs, ipairs, tonumber, type, next, GetTime = pairs, ipairs, tonumber, type, next, GetTime
local Book, Places, Plain = ns.Book, ns.Places, ns.Plain

local Loot = {}
ns.RecorderLoot = Loot

local SESSION_CORPSES = 500  -- corpses remembered this session before starting over
local PENDING_CORPSES = 200  -- corpses of unmet creatures kept at most
local GATHER_WINDOW = 5      -- seconds after a gathering cast its window is the gathering's
local READ_AGAIN = 1         -- seconds after LOOT_READY that LOOT_OPENED is the same window
-- Spells whose loot window isn't a corpse's loot: Skinning, Mining, Herb Gathering, Pick Pocket.
-- Compared by name, so every rank (and a client's other IDs for them) counts.
local GATHER_SPELLS = { 8613, 2575, 2366, 921 }

local corpses, corpseCount = {}, 0 -- guid -> { items = { itemID = true } } read this session
local pending, pendingCount = {}, 0 -- npcID -> { corpse, ... } of creatures not met yet
local gatheredAt, readAt = nil, nil -- GetTime() of the last gathering cast, of the last LOOT_READY

local gatherNames
local function isGathering(spellID)
    if not gatherNames then
        gatherNames = {}
        for _, id in ipairs(GATHER_SPELLS) do
            local name = Plain(C_Spell.GetSpellName(id))
            if name then gatherNames[name] = true end
        end
    end
    local name = Plain(C_Spell.GetSpellName(spellID))
    return name ~= nil and gatherNames[name] == true
end

-- UNIT_SPELLCAST_SUCCEEDED: the player's gathering casts.
function Loot.Cast(unit, spellID)
    spellID = Plain(spellID)
    if unit == "player" and type(spellID) == "number" and isGathering(spellID) then gatheredAt = GetTime() end
end

local function corpseRead(guid)
    local seen = corpses[guid]
    if not seen then
        if corpseCount >= SESSION_CORPSES then -- a long session: start over (an old corpse is long gone)
            corpses, corpseCount = {}, 0
        end
        seen = { items = {} }
        corpses[guid] = seen
        corpseCount = corpseCount + 1
    end
    return seen
end

-- The unit (target, mouseover) that is `guid` now, if any.
local function unitOf(guid)
    for _, unit in ipairs({ "target", "mouseover" }) do
        if Plain(UnitGUID(unit)) == guid then return unit end
    end
end

-- { [guid] = { npc, count } } of the creatures' corpses slot `slot` came from.
local function sourcesOf(slot)
    local list = {}
    local info = { GetLootSourceInfo(slot) }
    for i = 1, #info, 2 do
        local guid = Plain(info[i])
        local npc = type(guid) == "string" and guid:find("^Creature%-") and Book.NpcOf(guid)
        local unit = npc and unitOf(guid)
        local alive = unit and Plain(UnitIsDead(unit)) == false -- its pockets, not its corpse
        if npc and not alive then list[guid] = { npc = npc, count = tonumber(Plain(info[i + 1])) or 0, unit = unit } end
    end
    return list
end

-- The quest the item in `slot` starts or is for: questID, starts.
local function questOf(slot)
    local _, _, _, _, _, _, isQuestItem, questID, isActive = GetLootSlotInfo(slot)
    questID = Plain(questID)
    if not (questID and questID > 0) then return nil end
    return questID, Plain(isActive) == false and Plain(isQuestItem) ~= nil
end

-- One slot: what it gives each corpse it came from (into `found`).
local function readSlot(slot, found)
    local sources = sourcesOf(slot)
    if not next(sources) then return end
    for guid, source in pairs(sources) do
        found[guid] = found[guid] or { npc = source.npc, unit = source.unit, items = {}, money = 0 }
    end
    local kind = GetLootSlotType(slot)
    if kind == Enum.LootSlotType.Money then
        for guid, source in pairs(sources) do found[guid].money = found[guid].money + source.count end
        return
    end
    if kind ~= Enum.LootSlotType.Item then return end
    local link = Plain(GetLootSlotLink(slot))
    if type(link) ~= "string" then return end
    -- From the link itself: works for an item the client hasn't loaded yet.
    local itemID = tonumber(link:match("item:(%d+)")) or C_Item.GetItemInfoInstant(link)
    if not itemID then return end
    local icon, name, _, _, quality = GetLootSlotInfo(slot)
    Book.SetItem(itemID, name, quality, icon, link)
    local questID, starts = questOf(slot)
    for guid in pairs(sources) do
        found[guid].items[itemID] = { quest = questID, starts = starts }
    end
end

local function startsQuest(npc, questID, itemID, place)
    local quest = Book.QuestRecord(questID)
    local isNew = quest.startItem == nil
    quest.startItem = itemID
    if place then quest.itemFrom = { npc = npc, map = place.map, x = place.x, y = place.y } end
    if Book.SetQuestRole(Book.Creature(npc), questID, "item") then ns:Announce("CREATURE_LEARNED", npc, "quests") end
    if isNew then ns:Announce("QUEST_PLACE", questID, "item") end
end

-- Counts what's new of one corpse for its creature (met by now).
local function record(mod, guid, corpse)
    local npc = corpse.npc
    local rec = Book.Creature(npc)
    local seen = corpseRead(guid)
    if not seen.counted then
        seen.counted = true
        rec.looted = (rec.looted or 0) + 1
        if corpse.money > 0 then
            rec.money = (rec.money or 0) + corpse.money
            rec.moneyCorpses = (rec.moneyCorpses or 0) + 1
        end
    end
    rec.loot = rec.loot or {}
    local added = 0
    for itemID, item in pairs(corpse.items) do
        if not seen.items[itemID] then
            seen.items[itemID] = true
            added = added + 1
            local before = rec.loot[itemID]
            rec.loot[itemID] = (before or 0) + 1
            if not before then ns:Announce("LOOT_NEW", npc, itemID) end
            if item.quest and item.starts then
                startsQuest(npc, item.quest, itemID, corpse.place)
            elseif item.quest and Book.SetQuestRole(rec, item.quest, "loot") then
                ns:Announce("CREATURE_LEARNED", npc, "quests")
            end
        end
    end
    mod:Debug("looted", rec.name, added, "new items")
end

local function hold(guid, corpse)
    if pendingCount >= PENDING_CORPSES then return end
    pending[corpse.npc] = pending[corpse.npc] or {}
    pending[corpse.npc][guid] = corpse
    pendingCount = pendingCount + 1
end

-- The loot window open now. `meet(unit)` is the Recorder's: meets the creature a unit is.
local function read(mod, meet)
    local map, x, y = Places.Here()
    local place = map and { map = map, x = x, y = y }
    local found = {} -- guid -> { npc, unit, items = { itemID = { quest, starts } }, money }
    for slot = 1, GetNumLootItems() do readSlot(slot, found) end
    for guid, corpse in pairs(found) do
        if next(corpse.items) or corpse.money > 0 then
            corpse.place = place
            if not Book.Creature(corpse.npc) and corpse.unit then meet(corpse.unit) end
            if Book.Creature(corpse.npc) then
                record(mod, guid, corpse)
            else
                hold(guid, corpse)
            end
        end
    end
end

-- Whether the window open now isn't a creature's loot (fishing, a container, a gathering cast).
local function notCorpses(isFromItem)
    if Plain(isFromItem) or IsFishingLoot() then return true end
    return gatheredAt ~= nil and GetTime() - gatheredAt <= GATHER_WINDOW
end

-- LOOT_READY: read before auto loot empties the window.
function Loot.Ready(mod, meet)
    readAt = GetTime()
    if notCorpses(false) then return end
    read(mod, meet)
end

-- LOOT_OPENED: the window again, read only if LOOT_READY didn't just now.
function Loot.Opened(mod, meet, isFromItem)
    if readAt and GetTime() - readAt <= READ_AGAIN then return end
    if notCorpses(isFromItem) then return end
    read(mod, meet)
end

-- LOOT_CLOSED: the next window is another.
function Loot.Closed()
    readAt, gatheredAt = nil, nil
end

-- A creature was just met: its corpses looted before now count.
function Loot.Met(mod, npc)
    local list = pending[npc]
    if not list then return end
    pending[npc] = nil
    for guid, corpse in pairs(list) do
        pendingCount = pendingCount - 1
        record(mod, guid, corpse)
    end
end
