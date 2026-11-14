--[[
    Forever suite - tests/scenarios/core/migrate.lua
    Saved variables from before the suite (Forever Tweaks 1.10.0, Forever Compendium 0.3.0) carry
    over: the chat settings and Tweaks' Minimap Button and Update Notice move to Forever Core's
    table, Compendium's own button and Tweaks' Forever Bestiary module (removed in 2.1.0) go,
    and nothing else changes.
    Run by tests/run.lua (lua5.1 tests/run.lua migrate), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

ForeverTweaksDB = {
    version = 9, installed = "1.2.0", quiet = true, debug = true,
    settings = {
        MinimapButton = { where = "both", angle = 123 },
        Updates = { share = false },
        Performance = { size = 20 },
        Bestiary = { window = false, bannerX = 10 }, -- removed in 2.1.0
    },
    data = { Updates = { newest = { version = "1.11.0" } } },
    seenModules = { MinimapButton = "1.5.0", Performance = "1.5.0" },
}
ForeverCompendiumDB = {
    version = 1, installed = "0.1.0", quiet = false,
    settings = { MinimapButton = { where = "compartment", angle = 210 }, Journal = { sort = "kills" } },
    data = {}, seenModules = { MinimapButton = "0.1.0", Journal = "0.3.0" },
}

W.Strict()
local ns = W.LoadAddon(root, "ForeverCompendium") -- Compendium first, as the game would (by name)
W.LoadAddon(root, "ForeverTweaks")
login()
local core = ForeverCore

eq(ForeverTweaksDB.version, 11, "Tweaks: at the newest layout")
eq(ForeverCompendiumDB.version, 2, "Compendium: at the newest layout")

-- Forever Tweaks' choices are the suite's.
eq(core.db.quiet, true, "Mute All Chat Messages carried over from Tweaks")
eq(core.db.debug, true, "Show Log in Chat carried over")
eq(ForeverTweaksDB.quiet, nil, "and gone from Tweaks' table")
eq(core.modules.MinimapButton.db.where, "both", "the minimap button keeps where it was")
eq(core.modules.MinimapButton.db.angle, 123, "and its place")
eq(core.modules.Updates.db.share, false, "Share Your Version off stays off")
eq(core.modules.Updates.db.newest.version, "1.11.0", "the version heard of is kept")
eq(ForeverCoreDB.seenModules.MinimapButton, "1.5.0", "its NEW label stays seen")
eq(ForeverTweaksDB.settings.MinimapButton, nil, "Tweaks' table forgets the button")
eq(ForeverTweaksDB.data.Updates, nil, "and the Update Notice")

eq(ForeverTweaksDB.settings.Bestiary, nil, "the removed Forever Bestiary module's settings are forgotten")

-- The rest stays where it was.
eq(core.modules.Performance.db.size, 20, "a Tweaks module's setting is untouched")
eq(ForeverTweaksDB.installed, "1.2.0", "Tweaks keeps its install version")
eq(ns.modules.Journal.db.sort, "kills", "a Compendium module's setting is untouched")
eq(ForeverCompendiumDB.settings.MinimapButton, nil, "Compendium's own button is forgotten")
eq(ForeverCompendiumDB.seenModules.MinimapButton, nil, "with its NEW label mark")
eq(ForeverCompendiumDB.quiet, nil, "Compendium's chat setting goes (the suite's is Tweaks')")
check(ForeverTweaksMinimapButton ~= nil and ForeverTweaksMinimapButton:IsShown(), "the suite's button, with Tweaks' name")
finish()
