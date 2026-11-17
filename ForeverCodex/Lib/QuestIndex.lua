--[[
    Forever Codex - Lib/QuestIndex.lua
    The quests the Quests page lists: the ones you've discovered, and only those (nothing is given
    away). A quest is discovered once you met it: the book has it (a giver offered it, you saw its
    window, it was in your log, you looted what starts it, you clicked its pin: Book.Discover),
    it's in your log now, or the game has it done (C_QuestLog.GetAllCompletedQuestIDs, so quests
    done before the addon count). What QuestieDB knows of a discovered quest (Shared/Lib/QuestieDB.lua:
    its zone, level, givers, objectives, chain) is read here and shown, never written into the book.

      * QuestIndex.List(): the list, made when first asked and again after Forget (a quest
        discovered, taken, given up or turned in): { questID, name, level, group, groupName,
        seen, daily, prerequisites }. QuestIndex.Discovered(questID) says whether one is in it.
      * Groups: the zone a quest is listed in (QuestieDB's AreaTable ID, named by the game), else
        its quest log category (a class, a profession, a holiday: the locale's QUEST_SORT strings),
        else "Other".
      * QuestIndex.Quest(questID): QuestieDB's whole record (kept once read); IsLocked: a quest not
        yet yours to take (one before it isn't done); Chain: the quests before and after it.
]]

local _, ns = ...
local L = ns.L

local pairs, ipairs, type, table = pairs, ipairs, type, table
local Book, QuestieDB = ns.Book, ns.QuestieDB

local QuestIndex = {}
ns.QuestIndex = QuestIndex

local CHAIN_MAX = 30 -- quests followed each way along a chain

local records = {} -- questID -> QuestieDB's whole record, for the quests looked at (false: it doesn't know it)
local list         -- the list, once made
local byID = {}    -- questID -> its entry in the list

-- QuestieDB's record of `questID`, read once (nil while it can't be read or doesn't know it).
function QuestIndex.Quest(questID)
    local rec = records[questID]
    if rec == nil then
        if QuestieDB.Status() ~= "ready" then return nil end
        rec = QuestieDB.Quest(questID) or false
        records[questID] = rec
    end
    return rec or nil
end

local function done(questID) return C_QuestLog.IsQuestFlaggedCompleted(questID) == true end

-- Whether quest `questID` isn't yet yours to take: one it needs first isn't done (every one of
-- its group, or any one of its alternatives). False when QuestieDB can't say.
function QuestIndex.IsLocked(questID)
    local listed = byID[questID]
    local q = listed and listed.prerequisites and listed or QuestIndex.Quest(questID)
    if not q then return false end
    for _, before in ipairs(q.prerequisites.all) do
        if not done(before) then return true end
    end
    local any = q.prerequisites.any
    if #any == 0 then return false end
    for _, before in ipairs(any) do
        if done(before) then return false end
    end
    return true
end

-- A quest's level: the book's, else QuestieDB's.
function QuestIndex.Level(questID)
    local seen = Book.Quest(questID)
    if seen and seen.level then return seen.level end
    local q = byID[questID] or QuestIndex.Quest(questID)
    return q and q.level
end

-- The group a quest is listed under: key, name.
function QuestIndex.GroupOf(q)
    if q and q.areaID then
        local name = C_Map.GetAreaInfo(q.areaID)
        if name then return "area:" .. q.areaID, name end
    end
    if q and q.sortID then
        -- A category without a name of ours (Forever's own) is Other: L gives a missing key back.
        local key = "QUEST_SORT_" .. q.sortID
        if L[key] ~= key then return "sort:" .. q.sortID, L[key] end
    end
    return "other", L.QUESTS_GROUP_OTHER
end

-- The quests before quest `questID` (oldest first) and after it, along its chain: one it needs
-- first (the first of its group or alternatives) back, and the one it leads to forward.
function QuestIndex.Chain(questID)
    local before, after, seen = {}, {}, { [questID] = true }
    local q = QuestIndex.Quest(questID)
    while q and #before < CHAIN_MAX do
        local prev = q.prerequisites.all[1] or q.prerequisites.any[1]
        if not prev or seen[prev] then break end
        seen[prev] = true
        table.insert(before, 1, prev)
        q = QuestIndex.Quest(prev)
    end
    q = QuestIndex.Quest(questID)
    while q and #after < CHAIN_MAX do
        local nextID = q.next or (#q.children == 1 and q.children[1]) or nil
        if not nextID or seen[nextID] then break end
        seen[nextID] = true
        after[#after + 1] = nextID
        q = QuestIndex.Quest(nextID)
    end
    return before, after
end

---------------------------------------------------------------------------
-- The list
---------------------------------------------------------------------------

local function entry(questID, q, seen)
    local key, name = QuestIndex.GroupOf(q)
    return { questID = questID, name = (seen and seen.title) or (q and q.name) or Book.QuestName(questID),
        level = (seen and seen.level) or (q and q.level), group = key, groupName = name, seen = seen ~= nil,
        daily = (seen and seen.daily) or (q and q.repeatable) or nil, prerequisites = q and q.prerequisites }
end

-- Every quest discovered: questID -> true.
local function discovered()
    local found = {}
    for questID in pairs(Book.Quests()) do
        if type(questID) == "number" then found[questID] = true end
    end
    ns.EachLogQuest(function(questID) found[questID] = true end)
    for _, questID in ipairs(C_QuestLog.GetAllCompletedQuestIDs() or {}) do found[questID] = true end
    return found
end

-- The list (made now if it isn't).
function QuestIndex.List()
    if list then return list end
    list, byID = {}, {}
    local ready = QuestieDB.Status() == "ready"
    for questID in pairs(discovered()) do
        local q = ready and QuestieDB.QuestBrief(questID) or nil
        local seen = Book.Quest(questID)
        -- A quest done that neither the book nor QuestieDB knows (a hidden flag quest) isn't one to list.
        if q or seen then
            local e = entry(questID, q, seen)
            list[#list + 1] = e
            byID[questID] = e
        end
    end
    return list
end

-- Whether quest `questID` is discovered (in the list).
function QuestIndex.Discovered(questID)
    QuestIndex.List()
    return byID[questID] ~= nil
end

-- Quest `questID`'s entry in the list (nil: not discovered).
function QuestIndex.Entry(questID)
    QuestIndex.List()
    return byID[questID]
end

-- Forgets the list (a quest discovered, taken, given up or turned in; the book changed): it's
-- made again when next asked. `all` forgets what QuestieDB said too (QuestieDB came or went).
function QuestIndex.Forget(all)
    list, byID = nil, {}
    if all then records = {} end
end
