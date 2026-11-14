--[[
    Forever Compendium - tests/scenarios/compendium/import.lua
    Bestiary Import: with Forever Bestiary's saved variables loaded, its creatures come in by
    creature ID (from their models or its name index, or a creature of that name already in the
    journal; one named only by quest text is left out), counts take the larger of the two (never
    added), places fold into the journal's grid, and quests bring titles, givers and turn-ins
    with their places, objectives' places, kinds and start items. Running it twice changes
    nothing more. Without Bestiary loaded it only says so.
    Run by tests/run.lua (lua5.1 tests/run.lua import), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverCompendium")
login()
local Book, Places = ns.Book, ns.Places
local import = ns.modules.Import

-- Without Bestiary: nothing to do.
import.Run()
check(W.ChatHas("isn't loaded"), "says Bestiary's data isn't loaded")
eq(Book.Count(Book.Creatures()), 0, "nothing imported")

-- A creature both addons saw: our counts are kept where larger.
local ours = Book.Meet(3098, "Mottled Boar")
ours.kills, ours.looted, ours.loot = 20, 3, { [769] = 3 }

ForeverBestiaryCharDB = {
    npcIndex = { [3099] = "Dire Mottled Boar" },
    creatures = {
        ["Mottled Boar"] = {
            name = "Mottled Boar", kills = 12, looted = 12, minLevel = 1, maxLevel = 2, ctype = "Beast", class = "normal",
            firstSeen = 1000, lastSeen = 5000, deaths = 1, disp = { Horde = "hostile" },
            variants = { { npcID = 3098 }, { npcID = 3098, displayID = 503 } },
            loot = { [769] = { name = "Chunk of Boar Meat", quality = 1, icon = 133970, drops = 7 },
                [4865] = { name = "Ruined Pelt", quality = 0, icon = 134371, drops = 6 } },
            zones = { Durotar = { ["Valley of Trials"] = true } }, zoneMaps = { Durotar = 1411 },
            spots = { [1411] = { [6445] = 4 } }, spotSubs = { [1411] = { [6445] = "Valley of Trials" } },
            abilities = { { name = "Charge", spellID = 3385 } }, defenses = { Fire = "resist" },
            notes = { { title = "Tip", text = "Kite it." } }, pinned = true,
        },
        ["Dire Mottled Boar"] = { name = "Dire Mottled Boar", kills = 1, variants = {}, money = { total = 50, drops = 1 } },
        ["Lord Serpentis"] = { name = "Lord Serpentis", kills = 1, variants = {}, zones = { ["Wailing Caverns"] = {} },
            zoneKinds = { ["Wailing Caverns"] = "dungeon" } },
        ["Galak Scout"] = { name = "Galak Scout", placeholder = true, variants = {} },
    },
    quests = {
        [788] = { id = 788, title = "Cutting Teeth", level = 2, starters = { ["Gornek"] = true }, enders = { ["Gornek"] = true },
            objectives = { { kind = "monster", target = "Mottled Boar", text = "0/10 Mottled Boar slain", need = 10 } } },
    },
    questPins = {
        npcs = { Gornek = { { m = 1411, x = 0.42, y = 0.68, pts = {} } } },
        offers = { Gornek = { [789] = { level = 3 } } },
        enders = { [788] = { Gornek = true } },
        marks = { [788] = { { m = 1411, x = 0.45, y = 0.65, obj = 1, kind = "gather", pts = {} } } },
        qcat = { [789] = { ["repeat"] = true, elite = true } },
        loot = { [790] = { creature = "Mottled Boar", item = 4866, level = 4 } },
    },
}
local gornek = Book.Meet(3143, "Gornek")
import.Run()
local boar = Book.Creature(3098)
eq(boar.kills, 20, "the larger kill count: ours")
eq(boar.looted, 12, "the larger corpse count: Bestiary's")
eq(boar.loot[769], 7, "an item's larger count")
eq(boar.loot[4865], 6, "an item only Bestiary saw")
eq(Book.Item(4865).name, "Ruined Pelt", "its name")
eq(boar.first, 1000, "first seen: the earlier")
eq(boar.deaths, 1, "deaths")
eq(boar.reaction, 2, "hostile to your faction")
check(boar.displays and boar.displays[503], "its look")
check(boar.abilities and boar.abilities[3385], "an ability")
eq(boar.defenses and boar.defenses.Fire, "resist", "a resistance")
check(boar.zones[1411].cells[Places.Cell(0.455, 0.645)], "a place, folded into the journal's grid")
check(boar.zones[1411].sub["Valley of Trials"], "its subzone")
check(boar.note and boar.note:find("Kite it.", 1, true), "its note")
eq(boar.pinned, true, "pinned")
eq(Book.Creature(3099) and Book.Creature(3099).money, 50, "a creature found by Bestiary's name index")
eq(Book.Named("Lord Serpentis")[1], nil, "one with no creature ID anywhere is left out")
eq(Book.Named("Galak Scout")[1], nil, "one named only by quest text too")

local q = Book.Quest(788)
eq(q.title, "Cutting Teeth", "a quest's title")
eq(q.giver and q.giver.npc, 3143, "its giver, by name")
eq(q.giver.map, 1411, "where it stands")
eq(q.ender and q.ender.x, 0.42, "its turn-in")
check(gornek.starts[788] and gornek.ends[788], "the NPC knows the quest")
eq(q.objectives[1].text, "0/10 Mottled Boar slain", "its objectives")
check(q.marks and q.marks[1] and q.marks[1][1411], "where an objective went up")
eq(Book.Quest(789).giver.npc, 3143, "a quest only offered: its giver")
eq(Book.Quest(789).daily, true, "a repeatable quest is a daily")
eq(Book.Quest(789).cat, "elite", "its kind")
eq(Book.Quest(790).startItem, 4866, "an item that starts a quest")
eq(boar.quests[790], "item", "the creature drops it")

-- Twice: nothing more counted.
import.Run()
eq(boar.loot[769], 7, "importing again counts nothing twice")
eq(boar.kills, 20, "kills either")
finish()
