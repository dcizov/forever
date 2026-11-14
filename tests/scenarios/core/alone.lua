--[[
    Forever suite - tests/scenarios/core/alone.lua
    Forever Core with every member turned off: it loads and starts, its pages open, /forever
    works, and the minimap button's click opens the settings (no member has anything to open).
    Run by tests/run.lua (lua5.1 tests/run.lua alone), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, openEverything, root = T.check, T.eq, T.login, T.finish, T.openEverything, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverCore")
login()
eq(#ns.members, 1, "only the core")
eq(ForeverCoreDB.version, ns.member.layout, "its saved variables made")
check(ns.modules.MinimapButton.active and ns.modules.Updates.active, "its own modules on")
openEverything(ns)
W.Slash("/forever list")
check(W.ChatHas(ns.modules.MinimapButton.title), "/forever lists its modules")
W.opened = nil
ForeverTweaksMinimapButton:Fire("OnClick", "LeftButton")
eq(W.opened, ns.title, "a click opens the settings")
finish()
