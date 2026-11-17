--[[
    Forever suite - tests/scenarios/core/migrate.lua
    Saved variables from before the suite (Forever Gearbox 1.10.0, Forever Codex 0.3.0) carry
    over to 3.0.0: Gearbox' Minimap Button, Update Notice and chat settings go (Codex's are
    its own), as do Codex's own old button, Gearbox' Forever Bestiary module (removed in
    2.1.0), the Fishing Outfit (2.6.0) and the modules Forever++ has too (3.0.0, Quest Nameplates
    and Item Tooltips with their data); Gearbox' settings move into Forever++'s profile and its
    modules' on/off become what Forever++ is told they default to (one on a Forever++ module's page,
    such as Fishing, keeps its settings in Gearbox' own); nothing else changes.
    Run by tests/run.lua (lua5.1 tests/run.lua migrate), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

ForeverGearboxDB = {
    version = 9, installed = "1.2.0", quiet = true, debug = true,
    settings = {
        MinimapButton = { where = "both", angle = 123 },
        Updates = { share = false, enabled = "yes" }, -- enabled of the wrong type: dropped
        Performance = { size = 20, enabled = false },
        LayerInfo = { enabled = true, size = 99 }, -- a size out of range: dropped
        Bestiary = { window = false, bannerX = 10 }, -- removed in 2.1.0
        Fishing = { combatWeapons = false, sound = true }, -- Combat Weapons: removed in 2.6.0
        QuestNameplates = { completed = false, side = "right" }, -- the check: removed in 2.6.0
    },
    data = {
        Updates = { newest = { version = "1.11.0" } },
        -- What disenchanting showed, as 2.3.0 kept it: materials as strings beside n.
        ItemTooltips = { disenchanted = {
            ["2:4:16"] = { n = 3, [10940] = "3:1:2", [10938] = "1:1:1", [10978] = "bad" },
            ["2:4:21"] = { n = 0 },
        } },
    },
    seenModules = { MinimapButton = "1.5.0", Performance = "1.5.0" },
}
-- A character in its fishing outfit (skill line 356), saved before 2.6.0 removed it.
ForeverTweaksCharDB = { version = 1, data = { Fishing = { state = { wearing = 356 } } } }
ForeverCompendiumDB = { -- (Forever Codex was Forever Compendium until 3.3.0)
    version = 1, installed = "0.1.0", quiet = false,
    settings = { MinimapButton = { where = "compartment", angle = 210 }, Journal = { sort = "kills" } },
    data = { Recorder = { creatures = {
        [1] = { name = "Boar", reaction = 2, kills = 3 },
        [2] = { name = "Guard", reaction = 5, kills = 0 }, -- only seen: goes
        [3] = { name = "Innkeeper", reaction = 5, title = "Innkeeper" }, -- known for something: an NPC
        [4] = { name = "Smith", reaction = 5, wares = { [159] = { price = 5 } } },
        [5] = { name = "Rabbit", reaction = 4, creatureType = "Critter" }, -- a critter only seen: goes
        [6] = { name = "Rat", reaction = 4, creatureType = "Critter", pinned = true }, -- pinned: stays
    } } }, seenModules = { MinimapButton = "0.1.0", Journal = "0.3.0" },
}

W.Strict()
local ns = W.LoadAddon(root, "ForeverCodex") -- Codex first, as the game would (by name)
W.LoadAddon(root, "ForeverGearbox")
login()

eq(ForeverGearboxDB.version, 20, "Gearbox: at the newest layout")
eq(ForeverCodexDB.version, 5, "Codex: at the newest layout")
eq(ForeverCompendiumDB, nil, "Forever Compendium's saved variables taken over and cleared")
eq(ForeverTweaksCharDB, nil, "and Forever Tweaks' character ones")
check(ForeverGearboxCharDB.data.Fishing ~= nil, "which Forever Gearbox reads")

-- 3.1.0's NPCs: a friendly one known for something is an NPC, one only seen goes, as do critters.
local book = ForeverCodexDB.data.Recorder.creatures
check(book[1] and not book[1].npc, "a creature stays one")
eq(book[2], nil, "a friendly NPC only ever seen goes")
check(book[3] and book[3].npc, "one with a title is an NPC")
check(book[4] and book[4].npc and book[4].services.vendor, "a vendor is one, for its wares")
eq(book[5], nil, "a critter only seen goes")
check(book[6] ~= nil, "a pinned one stays")

-- What Gearbox kept for the suite goes.
eq(ForeverGearboxDB.quiet, nil, "Gearbox' chat setting goes")
eq(ForeverGearboxDB.settings.MinimapButton, nil, "Gearbox' table forgets the button")
eq(ForeverGearboxDB.data.Updates, nil, "and the Update Notice")
eq(ForeverGearboxDB.settings.Bestiary, nil, "the removed Forever Bestiary module's settings are forgotten")
eq(ForeverGearboxCharDB.data.Fishing.state, nil, "the outfit worn is forgotten")
eq(ForeverGearboxDB.data.ItemTooltips, nil, "a module Forever++ has too: its data goes")
check(W.FPP.Module("QuestNameplates") == nil, "and it isn't registered")

-- Gearbox' settings are its own (3.3.0): the 1.x ones once kept aside for Forever++ come in there.
local tweaks = W.LoadAddon(root, "ForeverGearbox")
local own = ForeverGearboxDB.settings
eq(own.Performance.size, 20, "a 1.x setting kept for Forever++ is Gearbox' own")
eq(tweaks.modules.Performance.db.size, 20, "and read from there")
eq((ForeverPlusPlusDB and ForeverPlusPlusDB.settings or {}).ForeverGearboxPerformance, nil, "nothing written into Forever++'s profile")
eq(own.Fishing.sound, true, "Fishing's settings come over")
eq(own.Fishing.combatWeapons, nil, "but not one the module no longer has")
eq(tweaks.modules.Fishing.db.sound, true, "and read from there")
eq(own.LayerInfo and own.LayerInfo.size, nil, "nor one out of its slider's range")
eq(ForeverGearboxDB.movedSettings, nil, "moved once")
check(not tweaks.modules.Performance.active, "a module that was off stays off")
check(tweaks.modules.LayerInfo.active, "one that was on stays on")
eq(ForeverGearboxDB.enabledDefaults, nil, "its on/off is its own setting now")

-- The rest stays where it was.
eq(ForeverGearboxDB.installed, "1.2.0", "Gearbox keeps its install version")
eq(ns.modules.Journal.db.sort, "kills", "a Codex module's setting is untouched")
eq(ns.modules.MinimapButton.db.angle, ns.modules.MinimapButton.defaults.angle, "Codex's old button is forgotten")
eq(ForeverCodexDB.seenModules.MinimapButton, nil, "with its NEW label mark")
check(ForeverCodexMinimapButton ~= nil and ForeverCodexMinimapButton:IsShown(), "Codex's own button")
finish()
