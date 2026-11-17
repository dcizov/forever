--[[
    Forever suite - tests/scenarios/core/alone.lua
    Forever Codex with only what it needs (Forever Gearbox, which brings Forever++; 3.1.0 made
    Gearbox a dependency): it loads and starts, its pages open, /codex works, and its minimap button's
    click opens the journal. Forever Core's saved
    settings from 2.x (ForeverCoreDB) come over once: chat, the window's place, the minimap button.
    Run by tests/run.lua (lua5.1 tests/run.lua alone), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, openEverything, root = T.check, T.eq, T.login, T.finish, T.openEverything, T.root

W.Strict()
ForeverCodexDB = { version = 2, settings = { Journal = { sounds = false } }, data = {} }
ForeverCoreDB = { version = 13, quiet = true, windowScale = 1.1, window = { point = "LEFT", x = 10, y = 0 },
    settings = { MinimapButton = { angle = 90 }, Updates = { enabled = false }, FullBags = { enabled = true } },
    data = { Updates = { newest = { version = "2.9.0" } } }, seenModules = { MinimapButton = "2.0.0" } }
local ns = W.LoadAddon(root, "ForeverCodex")
login()
check(W.loaded.ForeverGearbox and W.loaded.ForeverPlusPlus, "Forever Gearbox loaded first, with Forever++")
eq(#ns.members, 1, "its own member only (each addon its own namespace)")
eq(ForeverCodexDB.version, ns.member.layout, "its saved variables brought up to date")
eq(ForeverCoreDB, nil, "Forever Core's are cleared")
eq(ns.db.quiet, true, "Mute All Chat Messages came over")
eq(ns.db.windowScale, 1.1, "the window's size")
eq(ns.db.window.point, "LEFT", "and its place")
eq(ns.modules.MinimapButton.db.angle, 90, "the minimap button's place")
check(not ns.modules.Updates.active, "the Update Notice, off as it was")
eq(ns.modules.Updates.db.newest.version, "2.9.0", "with what it had heard")
eq(ns.modules.Journal.db.sounds, false, "Codex's own settings kept")
check(ForeverCodexDB.settings.FullBags == nil, "a Gearbox module's settings don't come")
check(ns.modules.MinimapButton.active, "its own minimap button on")
openEverything(ns)
W.chat = {}
W.Slash("/codex list")
check(W.ChatHas("(MinimapButton)"), "/codex lists its modules")
if rawget(_G, "ForeverCodexSettingsFrame") then ForeverCodexSettingsFrame:Hide() end
ForeverCodexMinimapButton:Fire("OnClick", "LeftButton")
check(ForeverCodexJournal:IsShown(), "a click opens the journal")
eq(#W.errors, 0, "no errors")
finish()
