--[[
    Forever Codex - tests/scenarios/compendium/recorder.lua
    The Recorder learning as the player plays: creatures met (and who isn't one), their places,
    kills, each corpse's loot counted once, quest givers and enders from gossip, greetings and
    quest windows, objectives marking where they went up, and each part turning off.
    Run by tests/run.lua (lua5.1 tests/run.lua recorder), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverCodex")
login()
local Book, Places = ns.Book, ns.Places
local news = {}
ns:OnNews({ name = "Test" }, function(_, event, ...) news[#news + 1] = { event, ... } end)
local function lastNews() return news[#news] and news[#news][1] end

W.place = { map = 1413, x = 0.52, y = 0.31 }
W.subzone = "The Crossroads"

-- Meeting a creature: target it.
W.Creature("target", 3296, "Orgrimmar Grunt", { level = 12, classification = "elite", reaction = 4 })
W.Fire("PLAYER_TARGET_CHANGED")
local grunt = Book.Creature(3296)
check(grunt ~= nil, "met on target")
eq(grunt.name, "Orgrimmar Grunt", "its name")
eq(grunt.minLevel, 12, "its level")
eq(grunt.classification, "elite", "its kind")
eq(grunt.reaction, 4, "how it stands toward you")
local cell = Places.Cell(0.52, 0.31)
eq(grunt.zones[1413].cells[cell], 1, "where you saw it")
check(grunt.zones[1413].sub["The Crossroads"], "the subzone")
eq(lastNews(), "CREATURE_NEW", "news of a new creature")
eq(news[#news][2], 3296, "naming it")

-- Its model: read from the target, once the game has it (a moment later).
local guid = W.unitInfo.target.guid
W.displays[guid] = 0
W.Advance(0.3)
eq(grunt.display, nil, "no model yet")
W.displays[guid] = 4259
W.Advance(0.3)
eq(grunt.display, 4259, "the model read a moment later")
-- Two looks read at once each get a model frame of their own: one frame shared by both could
-- answer with the other's display as its model finished loading.
local function probes()
    local n = 0
    for _, f in ipairs(W.frames) do if f._kind == "PlayerModel" and f._unit then n = n + 1 end end
    return n
end
local slowA = W.Creature("target", 3297, "Slow Loader")
W.displays[slowA.guid] = 0
W.Fire("PLAYER_TARGET_CHANGED")
local slowB = W.Creature("mouseover", 3298, "Other Loader")
W.displays[slowB.guid] = 0
W.Fire("UPDATE_MOUSEOVER_UNIT")
eq(probes(), 2, "a model frame for each look being read")
W.displays[slowA.guid], W.displays[slowB.guid] = 1111, 2222
W.Advance(0.3)
eq(Book.Creature(3297).display, 1111, "the first its own look")
eq(Book.Creature(3298).display, 2222, "the second its own")
Book.Creatures()[3297], Book.Creatures()[3298] = nil, nil
Book.ForgetIndex()
W.unitInfo.target, W.unitInfo.mouseover = W.unitInfo.mouseover and nil, nil
W.Creature("target", 3296, "Orgrimmar Grunt", { level = 12, classification = "elite", reaction = 4 })
W.unitInfo.target.guid = guid

-- Seen again at once: no second place; later, and at another level, both counted.
W.unitInfo.mouseover = W.unitInfo.target
W.Fire("UPDATE_MOUSEOVER_UNIT")
eq(grunt.zones[1413].cells[cell], 1, "a place at most every few seconds")
W.Advance(6)
W.unitInfo.mouseover.level = 14
W.Fire("UPDATE_MOUSEOVER_UNIT")
eq(grunt.zones[1413].cells[cell], 2, "counted again later")
eq(grunt.maxLevel, 14, "level range grows")
local count = #news
W.Fire("UPDATE_MOUSEOVER_UNIT")
eq(#news, count, "no news for a creature already known")

-- Seen somewhere new: news of its locations, once.
local function learned(npc, what)
    local n = 0
    for _, item in ipairs(news) do
        if item[1] == "CREATURE_LEARNED" and item[2] == npc and item[3] == what then n = n + 1 end
    end
    return n
end
W.subzone = "Far Watch Post"
W.Advance(6)
W.Fire("UPDATE_MOUSEOVER_UNIT")
eq(learned(3296, "locations"), 1, "a new subzone: its locations learned")
W.Advance(6)
W.Fire("UPDATE_MOUSEOVER_UNIT")
eq(learned(3296, "locations"), 1, "the same place again: no news")
W.subzone = "The Crossroads"

-- Not creatures: players, pets, and secret names.
W.unitInfo.target = { guid = "Player-4618-0ABC", name = "Somebody", player = true }
W.Fire("PLAYER_TARGET_CHANGED")
W.Creature("target", 4000, "Wolf Pet", { controlled = true })
W.Fire("PLAYER_TARGET_CHANGED")
eq(Book.Creature(4000), nil, "a pet isn't met")
-- Nor what another player owns that the game doesn't call player-controlled: guardians,
-- minions (an owner line in its tooltip), totems.
W.Creature("target", 4001, "Infernal", { otherPet = true })
W.Fire("PLAYER_TARGET_CHANGED")
eq(Book.Creature(4001), nil, "another player's pet or guardian isn't met")
W.Creature("target", 4002, "Risen Ghoul")
W.unitTips.target = { { Enum.TooltipDataLineType.UnitOwner, "Somebody's Minion" } }
W.Fire("PLAYER_TARGET_CHANGED")
eq(Book.Creature(4002), nil, "nor a unit with an owner line")
W.unitTips.target = nil
W.Creature("target", 4003, "Searing Totem", { creatureType = "Totem" })
W.Fire("PLAYER_TARGET_CHANGED")
eq(Book.Creature(4003), nil, "nor a totem")
-- Records of them from before (or another book, or Bestiary) are known by their title.
check(Book.LooksOwned("Somebody's Pet"), "an owner line as a title")
check(not Book.LooksOwned("Innkeeper"), "a real title")
check(not Book.LooksOwned("Gnarlpine's Hunter"), "an NPC's title naming someone")
local secret = W.Creature("nameplate1", 5000, "Hidden")
W.secrets[secret.name] = true
W.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
eq(Book.Creature(5000), nil, "nothing kept when its name is secret")
-- Nor what you can't fight (until you deal with it), vehicles, critters, pets, nor anything
-- seen from a flight path.
W.Creature("nameplate1", 5001, "Stormwind Guard", { reaction = 5 })
W.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
eq(Book.Creature(5001), nil, "a friendly guard isn't met on sight")
W.Creature("nameplate1", 5002, "Captain's Guard", { reaction = 4, attackable = false })
W.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
eq(Book.Creature(5002), nil, "nor a neutral one you can't attack")
local wyvern = W.Creature("nameplate1", 5003, "Wind Rider")
wyvern.guid = wyvern.guid:gsub("^Creature", "Vehicle")
W.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
eq(Book.Creature(5003), nil, "nor a vehicle")
W.Creature("nameplate1", 5004, "Rabbit", { creatureType = "Critter" })
W.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
eq(Book.Creature(5004), nil, "nor a critter")
W.Creature("nameplate1", 5005, "Fledgling Prowler", { creatureType = "Wild Pet" })
W.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
eq(Book.Creature(5005), nil, "nor a battle pet")
W.taxi = true
W.Creature("nameplate1", 5006, "Venture Co. Peon")
W.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
eq(Book.Creature(5006), nil, "nor anything seen from a flight path")
W.taxi = false
W.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
check(Book.Creature(5006) ~= nil, "landed: met")
Book.Creatures()[5006] = nil
Book.ForgetIndex()
eq(Book.Count(Book.Creatures()), 1, "only the creature")

-- A kill, then its corpse looted: once, however often the window opens.
local boar = W.Creature("nameplate2", 3100, "Mottled Boar", { creatureType = "Beast", family = "Boar" })
W.Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
W.Fire("PARTY_KILL", "Player-4618-0ABC", boar.guid)
eq(Book.Creature(3100).kills, 1, "a kill counted")
W.items["[Chunk of Boar Meat]"] = { id = 769 }
W.items["[Ruined Pelt]"] = { id = 4865 }
W.lootSource = boar.guid
W.loot = { { link = "[Chunk of Boar Meat]", count = 1, quality = 1 }, { money = true } }
W.OpenLoot()
local rec = Book.Creature(3100)
eq(rec.looted, 1, "a corpse looted")
eq(rec.loot[769], 1, "the item it held")
eq(Book.Item(769).name, "[Chunk of Boar Meat]", "the item's name kept")
eq(lastNews(), "LOOT_NEW", "news of new loot")
W.OpenLoot()
eq(rec.looted, 1, "the same corpse counts once")
-- A second corpse, with something else and a quest item; area looting with a stranger's corpse.
local second = "Creature-0-4618-0-3041-3100-0000BEEF01"
W.loot = { { link = "[Ruined Pelt]", count = 1, quest = true, questID = 300 } }
W.lootSources = { { second, 1, "Creature-0-4618-0-3041-9999-0000BEEF02", 1 } }
W.OpenLoot()
eq(rec.looted, 2, "a second corpse")
eq(Book.DropRate(rec, 769), 0.5, "drop rate: on one of two corpses")
eq(Book.DropRate(rec, 4865), 0.5, "the other item too")
check(rec.quests and rec.quests[300], "a quest item ties the creature to its quest")
eq(Book.Creature(9999), nil, "a creature never met isn't made from its corpse")
W.lootSources = {}
W.CloseLoot()

-- Auto loot: read on LOOT_READY, before the slots are taken (LOOT_OPENED then finds them gone).
local function corpse(npc, n) return "Creature-0-4618-0-3041-" .. npc .. "-0000C0FFE" .. n end
W.lootSource = corpse(3100, 1)
W.loot = { { link = "[Ruined Pelt]", count = 1 }, { money = true, count = 12 } }
W.AutoLoot()
eq(rec.looted, 3, "an auto-looted corpse counts")
eq(rec.loot[4865], 2, "with what auto loot took")
W.CloseLoot()
-- Opened again (a slot left behind): nothing counted twice.
W.lootSource = corpse(3100, 1)
W.loot = { { link = "[Ruined Pelt]", count = 1 } }
W.OpenLoot()
eq(rec.looted, 3, "a corpse opened again isn't another")
eq(rec.loot[4865], 2, "nor its item")
W.CloseLoot()

-- A corpse whose creature wasn't met (killed by your group, never targeted): kept until it is.
W.lootSource = corpse(7000, 1)
W.loot = { { link = "[Chunk of Boar Meat]", count = 1 } }
W.OpenLoot()
W.CloseLoot()
eq(Book.Creature(7000), nil, "not met by its corpse alone")
W.Creature("nameplate3", 7000, "Kobold Laborer")
W.Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
eq(Book.Creature(7000).looted, 1, "its corpse counts once it's met")
eq(Book.Creature(7000).loot[769], 1, "with what it held")
-- One you target as you loot it is met then.
local gnoll = W.Creature("target", 7100, "Gnoll Brute", { dead = true })
W.lootSource = gnoll.guid
W.loot = { { link = "[Chunk of Boar Meat]", count = 1 } }
W.OpenLoot()
W.CloseLoot()
eq((Book.Creature(7100) or {}).looted, 1, "a targeted corpse meets its creature")

-- Pick Pocket: the living creature's pockets aren't its corpse, which still counts after.
local mark = W.Creature("target", 3100, "Mottled Boar", { dead = false })
W.lootSource = mark.guid
W.loot = { { link = "[Ruined Pelt]", count = 1 } }
W.OpenLoot()
W.CloseLoot()
eq(rec.looted, 3, "pockets aren't a corpse")
mark.dead = true
W.loot = { { link = "[Chunk of Boar Meat]", count = 1 } }
W.OpenLoot()
W.CloseLoot()
eq(rec.looted, 4, "its corpse counts after")
-- Skinning a corpse: not its loot.
W.spells[8613], W.spells[8617] = "Skinning", "Skinning"
W.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 8617)
W.lootSource = corpse(3100, 2)
W.loot = { { link = "[Ruined Pelt]", count = 1 } }
W.OpenLoot()
W.CloseLoot()
eq(rec.looted, 4, "a skinned corpse's leather isn't its loot")
W.unitInfo.target = nil

-- Quest givers and enders.
-- A friendly NPC is met when you talk to it (not when you target it), then its gossip lists quests.
W.Creature("npc", 3337, "Kargal Battlescar", { reaction = 5 })
W.unitInfo.target = W.unitInfo.npc
W.Fire("PLAYER_TARGET_CHANGED")
eq(Book.Creature(3337), nil, "a friendly NPC isn't met when targeted")
W.gossip = {
    available = { { questID = 100, title = "Kolkar Leaders", questLevel = 12 } },
    active = { { questID = 101, title = "Plainstrider Menace", questLevel = 10, isComplete = true } },
}
W.Fire("GOSSIP_SHOW")
local q100, q101 = Book.Quest(100), Book.Quest(101)
eq(q100.title, "Kolkar Leaders", "a quest offered in gossip")
eq(q100.level, 12, "its level")
eq(q100.giver.npc, 3337, "its giver")
eq(q100.giver.map, 1413, "where")
eq(q101.ender.npc, 3337, "an active quest: its ender")
check(Book.Creature(3337).starts[100] and Book.Creature(3337).ends[101], "the NPC knows them")
check(Book.IsNpc(Book.Creature(3337)), "met as an NPC")
eq(lastNews(), "QUEST_PLACE", "news of a quest's place")
local questNews = 0
for _, item in ipairs(news) do
    if item[1] == "CREATURE_LEARNED" and item[2] == 3337 and item[3] == "quests" then questNews = questNews + 1 end
end
eq(questNews, 2, "the NPC's quests learned: one for the quest it gives, one for the one it takes in")
W.Fire("GOSSIP_SHOW")
local again = 0
for _, item in ipairs(news) do
    if item[1] == "CREATURE_LEARNED" and item[2] == 3337 and item[3] == "quests" then again = again + 1 end
end
eq(again, 2, "and not again for the same quests")
W.questWindow = { questID = 102, title = "Fungal Spores" }
W.Fire("QUEST_DETAIL")
eq(Book.Quest(102).giver.npc, 3337, "a quest window's giver")
W.Fire("QUEST_COMPLETE")
eq(Book.Quest(102).ender.npc, 3337, "and its ender")
W.greeting = { available = { { questID = 103, title = "Lost in Battle", level = 15 } }, active = {} }
W.Fire("QUEST_GREETING")
eq(Book.Quest(103).level, 15, "a greeting's quests")
-- A quest shared by a party member has no giver place.
W.unitInfo.npc = { guid = "Player-4618-0DEF", name = "Friend", player = true }
W.questWindow = { questID = 104, title = "Shared" }
W.Fire("QUEST_DETAIL")
eq(Book.Quest(104).giver, nil, "a shared quest has no giver")
eq(Book.Quest(104).title, "Shared", "but its title")

-- Objectives: where they went up, and the creature killed just before.
W.quests = { { title = "Kolkar Leaders", questID = 100, level = 12,
    objectives = { { type = "monster", text = "Boar slain: 0/5", numFulfilled = 0, numRequired = 5 } } } }
W.Fire("QUEST_ACCEPTED", 100)
W.Fire("QUEST_LOG_UPDATE")
W.RunTimers()
W.Fire("PARTY_KILL", "Player-4618-0ABC", boar.guid)
W.quests[1].objectives[1].numFulfilled = 1
W.place = { map = 1413, x = 0.6, y = 0.4 }
W.Fire("QUEST_LOG_UPDATE")
W.Fire("QUEST_LOG_UPDATE")
W.RunTimers()
local marks = q100.marks and q100.marks[1] and q100.marks[1][1413]
check(marks and marks.cells[Places.Cell(0.6, 0.4)] == 1, "the objective's place marked once")
check(rec.quests[100], "the boar killed just before is part of the quest")
W.Advance(10)
W.Fire("PARTY_KILL", "Player-4618-0ABC", "Creature-0-4618-0-3041-3337-0000000001")
W.Advance(10)
W.quests[1].objectives[1].numFulfilled = 2
W.Fire("QUEST_LOG_UPDATE")
W.RunTimers()
check(not (Book.Creature(3337).quests or {})[100], "a kill long before doesn't count")

-- Each part turns off on its own.
ns:SetOption("Recorder", "learnCreatures", false)
W.Creature("target", 6000, "Kolkar Drudge")
W.Fire("PLAYER_TARGET_CHANGED")
eq(Book.Creature(6000), nil, "Creatures off: not met")
ns:SetOption("Recorder", "learnCreatures", true)
W.Fire("PLAYER_TARGET_CHANGED")
check(Book.Creature(6000) ~= nil, "on again: met")
check(ns.modules.Recorder:DebugLine():find("creatures", 1, true) ~= nil, "Debug line")
-- What's learned is saved data: it stays through Reset All.
ns:ResetAll()
check(Book.Creature(6000) ~= nil, "reset keeps what was learned")
finish()
