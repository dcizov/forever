--[[
    Forever Compendium - tests/scenarios/compendium/learning.lua
    What the Recorder learns beyond meeting creatures (2.3.0): a creature's title and looks, the
    spells it casts, what it resists, your deaths to it, the reputation its kills give, the money
    its corpses carry, an item it drops that starts a quest, a vendor's wares, a quest window's
    rewards, quest titles and objectives from the log (never a bare quest number), titles the
    game loads on request, and what a creature does for a quest (killed, spoken to).
    Run by tests/run.lua (lua5.1 tests/run.lua learning), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverCompendium")
login()
local Book = ns.Book
local news = {}
ns:OnNews({ name = "Test" }, function(_, event, ...) news[#news + 1] = { event, ... } end)

W.place = { map = 1413, x = 0.5, y = 0.5 }

-- Title and looks: met as a target, its tooltip's second line, its model read.
local raider = W.Creature("target", 3267, "Bristleback Water Seeker", { level = 12, reaction = 2 })
W.unitTips.target = { { 0, "Bristleback Water Seeker" }, { 0, "Level 12 Humanoid" } }
W.displays[raider.guid] = 1960
W.Fire("PLAYER_TARGET_CHANGED")
W.RunTimers()
local rec = Book.Creature(3267)
eq(rec.title, nil, "a level line is no title")
eq(rec.display, 1960, "its look")
check(rec.displays and rec.displays[1960], "kept among its looks")
local keeper = W.Creature("mouseover", 3934, "Innkeeper Boorand", { level = 30, reaction = 5 })
W.unitTips.mouseover = { { 0, "Innkeeper Boorand" }, { 0, "Innkeeper" } }
W.displays[keeper.guid] = 3000
W.Fire("UPDATE_MOUSEOVER_UNIT")
W.RunTimers()
eq(Book.Creature(3934).title, "Innkeeper", "a title under its name")

-- Combat: a spell it casts, a resist, your death to it, reputation after a kill.
W.spells[5938] = "Shiv"
W.Fire("UNIT_SPELLCAST_START", "target", "Cast-1", 5938)
W.Fire("UNIT_SPELLCAST_SUCCEEDED", "target", "Cast-2", 6603) -- auto attack: no ability
check(rec.abilities and rec.abilities[5938], "a spell it cast")
eq(Book.Count(rec.abilities), 1, "auto attack isn't one")
W.Fire("UNIT_COMBAT", "target", "RESIST", "", 0, 4)
eq(rec.defenses and rec.defenses.Fire, "resist", "a fire attack it resisted")
W.Fire("UNIT_COMBAT", "player", "RESIST", "", 0, 4) -- your own resist isn't the creature's
local isUnit = UnitIsUnit
UnitIsUnit = function(a, b)
    if a == "targettarget" and b == "player" then return W.targetsYou end
    return isUnit(a, b)
end
W.targetsYou = true
W.Fire("PLAYER_DEAD")
eq(rec.deaths, 1, "it had you targeted when you died")
W.Fire("PARTY_KILL", "Player-1", raider.guid)
eq(rec.kills, 1, "a kill")
check(rec.firstKill and rec.lastKill, "dated")
W.Fire("CHAT_MSG_COMBAT_FACTION_CHANGE", "Your Orgrimmar reputation has increased by 5.")
eq(rec.rep and rec.rep.Orgrimmar and rec.rep.Orgrimmar.total, 5, "reputation its kill gave")
W.Advance(5)
W.Fire("CHAT_MSG_COMBAT_FACTION_CHANGE", "Your Orgrimmar reputation has increased by 250.")
eq(rec.rep.Orgrimmar.total, 5, "reputation long after a kill isn't its")

-- Loot: money, and an item that starts a quest.
W.lootSource = raider.guid
W.loot = { { money = true, count = 37 }, { link = "[Tattered Note]", count = 1, quest = true, questID = 888 } }
W.items["[Tattered Note]"] = { id = 7700, quality = 1 }
GetLootSlotInfo = (function(old)
    return function(slot)
        local icon, link, count, cur, quality, locked, isQuest, questID = old(slot)
        if slot == 2 then return icon, link, count, cur, quality, locked, true, 888, false end
        return icon, link, count, cur, quality, locked, isQuest, questID, true
    end
end)(GetLootSlotInfo)
W.OpenLoot()
eq(rec.money, 37, "money from its corpse")
eq(rec.quests and rec.quests[888], "item", "it drops an item that starts a quest")
eq((Book.Quest(888) or {}).startItem, 7700, "the quest keeps its start item")
eq(((Book.Quest(888) or {}).itemFrom or {}).map, 1413, "and where it dropped")

-- A vendor's wares.
W.unitInfo.npc = W.unitInfo.mouseover
W.merchant = { { id = 159, link = "Refreshing Spring Water", price = 25, stackCount = 5, numAvailable = -1 },
    { id = 4565, link = "Simple Dagger", price = 300, numAvailable = 2 } }
W.Fire("MERCHANT_SHOW")
local wares = Book.Creature(3934).wares
eq(wares and wares[159] and wares[159].stack, 5, "what it sells, by the stack")
eq(wares[4565].limited, true, "limited stock marked")

-- A quest window's rewards, and quests from the log with their titles and objectives.
W.questWindow = { questID = 900, title = "Water Seekers" }
W.questRewards, W.questChoices = { 2041 }, { 2045, 2046 }
for _, id in ipairs({ 2041, 2045, 2046 }) do W.items["item:" .. id] = { id = id } end
W.Fire("QUEST_DETAIL")
local q = Book.Quest(900)
eq(q.rewards and q.rewards[1], 2041, "its reward")
eq(q.choices and #q.choices, 2, "its choices")
W.quests = { { title = "Hidden Enemies", questID = 5726, level = 16,
    objectives = { { type = "monster", text = "Bristleback slain: 0/8", numFulfilled = 0, numRequired = 8 } } } }
W.Fire("QUEST_LOG_UPDATE")
W.RunTimers()
eq(Book.Quest(5726).title, "Hidden Enemies", "a quest in the log keeps its title")
eq(Book.Quest(5726).objectives[1].text, "Bristleback slain: 0/8", "and its objectives")
W.Fire("PARTY_KILL", "Player-1", raider.guid)
W.quests[1].objectives[1].numFulfilled = 1
W.Fire("QUEST_LOG_UPDATE")
W.RunTimers()
eq(rec.quests[5726], "slay", "killed for it")

-- A quest known only by number: the game is asked, and its title kept when it loads.
Book.QuestRecord(777)
eq(Book.QuestName(777), "Quest #777", "a bare number while unknown")
eq(W.titleRequests[#W.titleRequests], 777, "the game is asked for it")
W.questTitles[777] = "Burning Shadows"
W.Fire("QUEST_DATA_LOAD_RESULT", 777, true)
eq(Book.Quest(777).title, "Burning Shadows", "kept once loaded")
eq(news[#news][1], "QUEST_TITLE", "news of it")

-- Spoken to: an objective that goes up while talking to a creature.
W.unitInfo.npc = W.unitInfo.mouseover
W.gossip = { available = {}, active = {} }
W.Fire("GOSSIP_SHOW")
W.quests[2] = { title = "Speak to the Innkeeper", questID = 6000, level = 10,
    objectives = { { type = "event", text = "Speak with Boorand: 0/1", numFulfilled = 0, numRequired = 1 } } }
W.Fire("QUEST_LOG_UPDATE")
W.RunTimers()
W.Advance(4)
W.quests[2].objectives[1].numFulfilled = 1
W.Fire("QUEST_LOG_UPDATE")
W.RunTimers()
eq(Book.Creature(3934).quests and Book.Creature(3934).quests[6000], "speak", "spoken to for it")

-- The parts turn off: Combat and Vendors learn nothing more.
ns:SetOption("Recorder", "learnCombat", false)
ns:SetOption("Recorder", "learnVendors", false)
W.spells[8000] = "Other"
W.Fire("UNIT_SPELLCAST_START", "target", "Cast-3", 8000)
check(not rec.abilities[8000], "Combat off: no spell learned")
finish()
