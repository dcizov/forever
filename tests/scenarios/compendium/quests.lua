--[[
    Forever Codex - tests/scenarios/compendium/quests.lua
    The journal's Quests page (Lib/QuestIndex.lua, Modules/Journal/Quest*.lua) on a small
    QuestieDB: only the quests your race and class can take, grouped by zone or category; one not
    yet yours to take is locked until the one before it is done; a chain runs both ways; a quest's
    giver you haven't met puts Blizzard's map pin on where it stands (QuestieDB's spawn on its
    map), one you met opens its page; the item page lists the quests an item is used in. Without
    QuestieDB the page lists the quests you saw, and says why.
    Where a quest opens: Blizzard's quest log while it's in your log, Spoken's Azeroth's
    Codex when it has the quest's words, else the journal's quest page.
    Run by tests/run.lua (lua5.1 tests/run.lua quests), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root, under = T.check, T.eq, T.login, T.finish, T.root, T.under

-- A QuestieDB with a few quests: its tables keyed by its own field names.
local QUESTS = {
    [100] = { name = "Wolves at the Door", questLevel = 5, zoneOrSort = 14, requiredRaces = 2,
        startedBy = { { 3143 } }, finishedBy = { { 3143 } }, objectives = { { { 3100, "Mottled Boar" } }, nil, { { 769 } } },
        objectivesText = { "Kill boars for Gornek." }, nextQuestInChain = 101 },
    [101] = { name = "The Next Step", questLevel = 6, zoneOrSort = 14, preQuestSingle = { 100 }, startedBy = { { 3143 } } },
    [102] = { name = "For the Alliance", questLevel = 5, zoneOrSort = 12, requiredRaces = 1 },
    [103] = { name = "Mage Training", questLevel = 10, zoneOrSort = -161, requiredClasses = 128 },
    [104] = { name = "Warrior's Call", questLevel = 10, zoneOrSort = -81, requiredClasses = 1 },
    -- One quest for each race, in a category of Forever's own (no name of ours).
    [105] = { name = "Camping 101", questLevel = 5, zoneOrSort = -666 },
    [106] = { name = "Camping 101", questLevel = 5, zoneOrSort = -666 },
}
local NPCS = { [3143] = { name = "Gornek", spawns = { [14] = { { 40, 60 } } }, zoneID = 14 } }
local ITEMS = { [769] = { name = "Chunk of Boar Meat", relatedQuests = { 100 } } }
local function entity(rows)
    local e = {}
    function e.Get(id, key) return rows[id] and rows[id][key] end
    function e.GetAll(id, keys)
        local row = rows[id]
        if not row then return nil end
        local out = { n = #keys }
        for i, key in ipairs(keys) do out[i] = row[key] end
        return out
    end
    function e.GetAllIds()
        local ids = {}
        for id in pairs(rows) do ids[#ids + 1] = id end
        table.sort(ids)
        return ids
    end
    return e
end
LibQuestieDB = { Quest = entity(QUESTS), Npc = entity(NPCS), Item = entity(ITEMS), Object = entity({}),
    Support = { Get = function(name)
        if name == "ZoneDB" then return { private = { areaIdToUiMapId = "return { [14] = 1411 }" } } end
    end } }

W.Strict()
local ns = W.LoadAddon(root, "ForeverCodex")
local L = ns.L
login()
W.areas[14] = "Durotar"
local QuestIndex, Book = ns.QuestIndex, ns.Book

eq(ns.QuestieDB.Status(), "ready", "QuestieDB read")
W.FPP.own.QuestPins = { enabled = false, title = "Quest Pins", options = {} }
local window
local function shownTexts(frame)
    local all = {}
    for _, f in ipairs(under(frame or window, function(f) return f._kind == "FontString" and f:IsVisible() end)) do
        all[#all + 1] = tostring(f:GetText() or "")
    end
    return table.concat(all, "\n")
end

-- Nothing discovered: nothing listed, and a quest asked for gives nothing away.
eq(#QuestIndex.List(), 0, "no quest discovered yet: none listed")
ns.ShowQuest(100)
window = ForeverCodexQuest
check(window:IsShown(), "a quest neither in your log nor Spoken's opens on the journal's quest page")
check(shownTexts():find(L.QUESTS_NOT_DISCOVERED, 1, true) ~= nil, "an undiscovered quest shows nothing")
check(shownTexts():find("Wolves at the Door", 1, true) == nil, "not even its title")

-- Quest Pins: a ! where a quest you can take starts (QuestieDB, by Forever++'s rules).
local pinsModule = ns.modules.QuestPins
W.place = { map = 1411, x = 0.5, y = 0.5 }
W.playerLevel = 5
W.RunTimers()
check(ns.QuestGivers.ready, "where quests start read from QuestieDB")
check(ns.QuestGivers.CanTake(100), "a quest your race can take, nothing needed first")
check(not ns.QuestGivers.CanTake(101), "not one whose quest before isn't done")
check(not ns.QuestGivers.CanTake(102), "nor another race's")
eq(pinsModule:DebugLine(), format(L.QPINS_DEBUG, 1), "its giver's pin on the map")
W.FPP.SetOwn("QuestPins", true)
eq(pinsModule:DebugLine(), format(L.QPINS_DEBUG, 0), "Forever++'s Quest Pins on: ours step back")
W.FPP.SetOwn("QuestPins", false)

-- Discovered: met (a pin clicked), started, or done.
Book.Discover(100)
W.questsDone[104] = true
QuestIndex.Forget()
local listed = {}
for _, entry in ipairs(QuestIndex.List()) do listed[entry.questID] = entry end
check(listed[100], "a quest whose pin you clicked")
check(listed[104], "a quest the game has done")
check(not listed[101] and not listed[102] and not listed[103], "nothing else")
eq(listed[100].groupName, "Durotar", "listed under its zone")
eq(listed[104].groupName, L.QUEST_SORT_81, "or its category")
-- A category without a name of ours is Other; quests of one title in one group are one line.
W.questsDone[105], W.questsDone[106] = true, true
QuestIndex.Forget()
eq(QuestIndex.Entry(105).groupName, L.QUESTS_GROUP_OTHER, "a category of Forever's own: Other, not its key")
W.questsDone[104], W.questsDone[105], W.questsDone[106] = nil, nil, nil
QuestIndex.Forget()

-- Where each stands: locked until the one before is done.
eq(ns.JournalText.QuestState(101), "locked", "a quest whose one before isn't done: not yet available")
W.questsDone[100] = true
eq(ns.JournalText.QuestState(101), "open", "once it's done: yours to take")
eq(ns.JournalText.QuestState(100), "done", "and that one done")
W.questsDone[100] = nil

-- Its chain runs both ways.
local before, after = QuestIndex.Chain(101)
eq(#before, 1, "one quest before it")
eq(before[1], 100, "the one it needs")
before, after = QuestIndex.Chain(100)
eq(after[1], 101, "and the one it leads to")

-- The quest shown: its giver (never met: QuestieDB's name, a click puts the map pin on it),
-- its objectives, its chain (the next quest, not discovered, a nameless padlock).
ns.ShowQuest(100)
local shown = shownTexts()
check(shown:find("Wolves at the Door", 1, true) ~= nil, "the quest shown")
check(shown:find("Gornek", 1, true) ~= nil, "its giver, from QuestieDB")
check(shown:find("Kill boars for Gornek.", 1, true) ~= nil, "what it's about")
check(shown:find("Mottled Boar", 1, true) ~= nil, "what it asks")
check(shown:find(L.QUESTS_CHAIN, 1, true) ~= nil and shown:find("\194\183 2", 1, true) ~= nil, "its chain, two steps")
check(shown:find(L.QUESTS_UNDISCOVERED, 1, true) ~= nil, "the next step, not discovered, unnamed")
check(shown:find("The Next Step", 1, true) == nil, "its title kept hidden")
-- Shift-click on its title links it in chat, opening the chat line when it's closed.
W.shift = true
ns.JournalKit.Link("quest", 100, "LeftButton")
W.shift = false
eq(W.linked[#W.linked], "quest:100", "linked")
check(W.chatOpen, "the chat line opened with it")
local giver = under(window, function(f) return f._kind == "FontString" and f:IsVisible() and tostring(f:GetText() or ""):find("Gornek", 1, true) end)[1]
giver:GetParent():Fire("OnClick", "LeftButton")
eq(W.waypoint and W.waypoint.map, 1411, "a giver not met: the map pin on its map")
eq(W.waypoint.x, 0.4, "where it stands")
-- Ctrl-click on a quest: on the world map, from QuestieDB: where it starts and where it's turned in.
W.ctrl = true
ns.JournalKit.Link("quest", 100, "LeftButton")
W.ctrl = false
eq(ns.modules.QuestFocus.Focus(), 100, "Ctrl-click shows the quest on the map")
eq(W.openedMap, 1411, "the map opened where it starts")
W.worldMapID, W.canvasScale = 1411, 1
WorldMapFrame:Show()
W.RunTimers()
local function focusPins(kind)
    local n = 0
    for _, f in ipairs(W.frames) do
        local spec = rawget(f, "spec")
        if spec and spec.entries and f:IsShown() and f._kind == "Button" and spec.kind == kind
            and spec.entries[1].questID == 100 then n = n + 1 end
    end
    return n
end
check(focusPins("giver") >= 1, "a ! where it starts")
eq(focusPins("ender"), 1, "a ? where it's turned in")
WorldMapFrame:Hide()
eq(ns.modules.QuestFocus.Focus(), nil, "the map closed: let go")
-- Met (talked to), the giver's line opens its page.
W.Creature("npc", 3143, "Gornek", { reaction = 5 })
W.gossip = { available = {}, active = {} }
W.Fire("GOSSIP_SHOW")
check(Book.IsNpc(Book.Creature(3143)), "met as an NPC")
ns.ShowQuest(100)
giver = under(window, function(f) return f._kind == "FontString" and f:IsVisible() and tostring(f:GetText() or ""):find("Gornek", 1, true) end)[1]
giver:GetParent():Fire("OnClick", "LeftButton")
check(shownTexts(ForeverCodexJournal):find(L.NPCS_GOSSIP, 1, true) ~= nil, "met: a click opens it on the NPCs page, what you dealt with it for")
check(#under(ForeverCodexJournal, function(f) return f._creature == 3143 and f:IsVisible() end) == 1,
    "its look never read: its model by its ID")

-- The item page: the quests it's used in.
Book.SetItem(769, "Chunk of Boar Meat", 1, 133970)
ns.ShowItem(769)
check(shownTexts(ForeverCodexJournal):find(L.JITEMS_USED_IN, 1, true) ~= nil, "an item's quests, from QuestieDB")

-- Where a quest named in the journal opens: in your log, Blizzard's quest log; Spoken Quests
-- having its words, Azeroth's Compendium; else the journal's quest page.
W.quests = { { questID = 100, title = "Wolves at the Door", level = 5 } }
ns.ShowQuest(100)
eq(W.openedQuest, 100, "a quest in your log: Blizzard's quest log")
W.quests = {}
local opened
VoiceOver = { QuestsTab = { Has = function(_, id) return id == 100 end, Open = function(_, id) opened = id end } }
check(ns.Spoken.HasLore(100), "Spoken has words for it")
check(not ns.Spoken.HasLore(104), "not for another")
ns.ShowQuest(100)
eq(opened, 100, "Spoken's words for it: opened in Azeroth's Compendium")
VoiceOver = nil
check(not ns.Spoken.HasLore(100), "without Spoken: nothing")

-- Without QuestieDB: the quests you saw, and why only those.
LibQuestieDB = nil
QuestIndex.Forget(true)
eq(ns.QuestieDB.Status() ~= "ready", true, "QuestieDB gone")
Book.QuestRecord(900).title = "Seen Only"
ns:Announce("BOOK_MERGED")
ns.ShowQuest(900)
shown = shownTexts()
check(shown:find("Seen Only", 1, true) ~= nil, "a quest you saw still shows")
check(shown:find(L.QUESTS_NO_QUESTIEDB, 1, true) ~= nil, "saying why only those")
eq(#W.errors, 0, "no errors")
finish()
