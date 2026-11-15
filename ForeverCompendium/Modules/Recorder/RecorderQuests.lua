--[[
    Forever Compendium - Modules/Recorder/RecorderQuests.lua
    The Recorder's Quests part (Modules/Recorder/Recorder.lua registers the events and calls these):
    where quests are taken and turned in, what they ask and give, and where their objectives
    progress.

      * Givers: an NPC's gossip lists the quests it offers (C_GossipInfo.GetAvailableQuests), an
        NPC without gossip greets with them (QUEST_GREETING), and a quest's own window opens
        with it (QUEST_DETAIL, which also shows its rewards). Each records who gave it (an
        object's name when it isn't a creature) and where the player stands.
      * Turn-ins: the gossip's active quests are the ones this NPC takes in (Blizzard lists a
        quest there only at its ender), as are QUEST_PROGRESS and QUEST_COMPLETE.
      * The log: QUEST_LOG_UPDATE comes often; once a frame the log is read. Each quest in it
        keeps its title, level, kind (elite, dungeon, raid, PvP, daily) and objectives, so a
        quest never shows as a bare number. Each objective that went up marks where the player
        is, and names a creature for it: one killed just before (killed for it, or looted for an
        item objective), or the one you're talking to (spoken to).
      * Titles of quests known only by number come when the game has loaded them
        (QUEST_DATA_LOAD_RESULT, asked for by Book.QuestTitle).
    A giver or ender shared by a party member keeps nothing.
]]

local _, ns = ...

local ipairs, pairs, select, type, GetTime = ipairs, pairs, select, type, GetTime
local Book, Places, Plain = ns.Book, ns.Places, ns.Plain

local Quests = {}
ns.RecorderQuests = Quests

local KILL_WINDOW = 3 -- seconds a kill counts toward the objective that goes up after it
local TALK_WINDOW = 10 -- seconds a gossip with a creature counts toward one (choosing what to say)
-- Quest tags (C_QuestLog.GetQuestTagInfo's tagID) and the kind each one is.
local TAG_KIND = { [1] = "elite", [41] = "pvp", [62] = "raid", [81] = "dungeon", [85] = "dungeon", [88] = "raid", [89] = "raid" }

local talking -- { npc, at } while a gossip or quest window is open with a creature

-- The NPC the quest window or gossip is with, and where it is: { npc, name, map, x, y } (npc
-- nil for an object or item).
local function placeOf(unit)
    local guid = Plain(UnitGUID(unit))
    if guid and guid:find("^Player") then return nil end -- shared by a party member
    local npc = guid and Book.NpcOf(guid)
    if npc then talking = { npc = npc, at = GetTime() } end
    local map, x, y = Places.Here()
    if not map then return nil end
    return { npc = npc, name = Plain(UnitName(unit)), map = map, x = x, y = y }
end

local function npcUnit()
    return UnitExists("questnpc") and "questnpc" or "npc"
end

-- What kind of quest it is: its tag (elite, dungeon, raid, PvP) and whether it's a daily.
local function noteKind(rec, questID, frequency, repeatable)
    local info = C_QuestLog.GetQuestTagInfo(questID)
    local tag = info and Plain(info.tagID)
    rec.cat = TAG_KIND[tag] or rec.cat
    frequency = Plain(frequency)
    if Plain(repeatable) or (type(frequency) == "number" and frequency > 0) then rec.daily = true end
end

-- Records `place` as quest `questID`'s `role` ("giver" or "ender"), with its title and level
-- when known.
local function record(questID, role, place, title, level)
    questID = Plain(questID)
    if not questID or questID == 0 then return end
    local rec = Book.QuestRecord(questID)
    rec.title = Plain(title) or rec.title
    level = Plain(level)
    if level and level > 0 then rec.level = level end
    if not place then return rec end
    local isNew = rec[role] == nil
    rec[role] = place
    local creature = place.npc and Book.Creature(place.npc)
    if creature then
        local field = role == "giver" and "starts" or "ends"
        local known = creature[field] and creature[field][questID]
        Book.Mark(creature, field, questID)
        if not known then ns:Announce("CREATURE_LEARNED", place.npc, "quests") end
    end
    if isNew then ns:Announce("QUEST_PLACE", questID, role) end
    return rec
end

-- The items a quest window offers: { itemID, ... } of `kind` ("reward" or "choice").
local function rewardItems(kind, count)
    local list = {}
    for i = 1, count do
        local link = Plain(GetQuestItemLink(kind, i))
        local itemID = link and C_Item.GetItemInfoInstant(link)
        if itemID then
            local name, texture, _, quality = GetQuestItemInfo(kind, i)
            Book.SetItem(itemID, name, quality, texture)
            list[#list + 1] = itemID
        end
    end
    return #list > 0 and list or nil
end

function Quests.Detail()
    local rec = record(GetQuestID(), "giver", placeOf(npcUnit()), GetTitleText())
    if not rec then return end
    rec.rewards = rewardItems("reward", GetNumQuestRewards()) or rec.rewards
    rec.choices = rewardItems("choice", GetNumQuestChoices()) or rec.choices
end

function Quests.RecordEnder()
    record(GetQuestID(), "ender", placeOf(npcUnit()), GetTitleText())
end

function Quests.Gossip()
    local place = placeOf("npc")
    for _, info in ipairs(C_GossipInfo.GetAvailableQuests()) do
        local rec = record(info.questID, "giver", place, info.title, info.questLevel)
        if rec then noteKind(rec, info.questID, info.frequency, info.repeatable) end
    end
    for _, info in ipairs(C_GossipInfo.GetActiveQuests()) do
        record(info.questID, "ender", place, info.title, info.questLevel)
    end
end

function Quests.Greeting()
    local place = placeOf("npc")
    for i = 1, GetNumAvailableQuests() do
        local questID = select(5, GetAvailableQuestInfo(i))
        record(questID, "giver", place, GetAvailableTitle(i), GetAvailableLevel(i))
    end
    for i = 1, GetNumActiveQuests() do
        record(GetActiveQuestID(i), "ender", place, GetActiveTitle(i))
    end
end

-- A quest taken: its title and level from the log.
function Quests.Accepted(questID)
    local index = C_QuestLog.GetLogIndexForQuestID(questID)
    local info = index and C_QuestLog.GetInfo(index)
    if info then record(questID, "giver", nil, info.title, info.level) end
end

-- The game loaded a quest asked for by number: its title is kept.
function Quests.Loaded(questID, success)
    if not Plain(success) then return end
    local title = Plain(C_QuestLog.GetTitleForQuestID(questID))
    if title and title ~= "" then
        Book.QuestRecord(questID).title = title
        ns:Announce("QUEST_TITLE", questID)
    end
end

---------------------------------------------------------------------------
-- The log
---------------------------------------------------------------------------

local progress -- questID -> { [objective] = done }, from the last look (nil before the first)

-- What the log says of one quest, kept: title, level, kind, objectives. Returns how far along
-- each objective is.
local function readQuest(info)
    local questID = info.questID
    local rec = Book.QuestRecord(questID)
    rec.title = Plain(info.title) or rec.title
    local level = Plain(info.level)
    if level and level > 0 then rec.level = level end
    noteKind(rec, questID, info.frequency, nil)
    local done, objectives = {}, {}
    for j, objective in ipairs(C_QuestLog.GetQuestObjectives(questID) or {}) do
        done[j] = Plain(objective.numFulfilled) or 0
        local text = Plain(objective.text)
        if text then objectives[j] = { text = text, type = Plain(objective.type) } end
    end
    if #objectives > 0 then rec.objectives = objectives end
    return done
end

local function lookAtLog()
    local now = {}
    ns.EachLogQuest(function(questID, info) now[questID] = readQuest(info) end)
    return now
end

-- The creature that made objective `j` of `questID` go up, and what it did for it.
local function creditFor(mod, questID, j)
    local objective = (Book.Quest(questID).objectives or {})[j]
    local kill = mod.lastKill
    if kill and GetTime() - kill.at <= KILL_WINDOW and Book.Creature(kill.npc) then
        return kill.npc, objective and objective.type == "item" and "loot" or "slay"
    end
    if talking and GetTime() - talking.at <= TALK_WINDOW and Book.Creature(talking.npc) then
        return talking.npc, "speak"
    end
end

-- Compares the log with the last look: each objective that went up marks the player's place.
function Quests.LogChanged(mod)
    local now = lookAtLog()
    local before = progress
    progress = now
    if not before then return end
    for questID, done in pairs(now) do
        local was = before[questID]
        for j, n in pairs(done) do
            if was and n > (was[j] or 0) then
                local map, x, y = Places.Here()
                local rec = Book.QuestRecord(questID)
                if map then
                    rec.marks = rec.marks or {}
                    rec.marks[j] = rec.marks[j] or {}
                    Places.Add(rec.marks[j], map, x, y)
                end
                local npc, role = creditFor(mod, questID, j)
                if npc and Book.SetQuestRole(Book.Creature(npc), questID, role) then
                    ns:Announce("CREATURE_LEARNED", npc, "quests")
                end
            end
        end
    end
end

-- Forgets the last look (the part turned off): the next one starts over.
function Quests.Reset()
    progress, talking = nil, nil
end
