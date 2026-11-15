--[[
    Forever Tweaks - tests/scenarios/tweaks/gathering.lua
    The Gathering page: Gathering Session (nodes, fish, items, value, per hour, skill-ups, pause
    and start again).
    Run by tests/run.lua (lua5.1 tests/run.lua gathering), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverTweaks")
login()
local sessionMod = ns.modules.GatherSession
check(sessionMod.active, "on by default")

-- The session: nothing until something is gathered.
local display = _G.ForeverTweaksGatherSession
eq(display:IsShown(), false, "nothing gathered yet: no panel")
W.items["[Peacebloom]"] = { id = 2447, sell = 5 }
W.items["[Raw Brilliant Smallfish]"] = { id = 6291, sell = 1 }
W.lootSource = "GameObject-0-1-0-1-1617-0000000001"
W.loot = { { link = "[Peacebloom]", count = 3 } }
W.OpenLoot()
W.TakeLoot(1)
W.CloseLoot()
check(display:IsShown(), "a herb gathered: the panel shows")
local function line() return display.display:GetLine() end
check(line():find("1 nodes", 1, true) and line():find("3 items", 1, true), "one node, three items")
W.OpenLoot() -- the same node again: not counted twice
W.CloseLoot()
W.lootSource = "Creature-0-1-0-1-3296-0000000009"
W.loot = { { link = "[Peacebloom]", count = 1 } }
W.OpenLoot()
W.TakeLoot(1)
W.CloseLoot()
check(line():find("1 nodes", 1, true) and line():find("3 items", 1, true), "a mob's loot isn't gathering")
W.fishing = true
W.loot = { { link = "[Raw Brilliant Smallfish]", count = 1 } }
W.OpenLoot()
W.TakeLoot(1)
W.CloseLoot()
W.fishing = false
W.Fire("CHAT_MSG_SKILL", "Your skill in Herbalism has increased to 2.")
check(line():find("1 fish", 1, true), "one fish")
check(line():find("16c", 1, true), "worth 3 x 5c + 1c")
check(line():find("+1 skill", 1, true), "one skill-up")
W.Advance(125)
check(line():find("2:05", 1, true), "the clock runs")
check(line():find("/h", 1, true), "and after a minute, per hour")

-- Pause and start again (the right-click menu).
display:Fire("OnMouseUp", "RightButton")
W.menu:Find(ns.L.GATHERSESSION_PAUSE).fn()
W.Advance(60)
check(line():find("2:05", 1, true) and line():find(ns.L.GATHERSESSION_PAUSED, 1, true), "paused: the clock stops")
W.Slash("/ft session")
check(W.ChatHas("1 x [Raw Brilliant Smallfish]"), "/ft session lists the items")
-- The Gathering window: the session, Fishing and the items, from the menu or the command.
display:Fire("OnMouseUp", "RightButton")
W.menu:Find(ns.L.GATHERWINDOW_OPEN).fn()
local window = ForeverTweaksGatherWindow
check(window:IsShown(), "the menu opens the Gathering window")
local function windowHas(part)
    for _, f in ipairs(W.frames) do
        if f._kind == "FontString" and type(f._text) == "string" and f._text:find(part, 1, true) and f:IsVisible() then return true end
    end
end
check(windowHas("[Raw Brilliant Smallfish]  x1"), "every item gathered, with how many")
check(windowHas(string.format(ns.L.GATHERWINDOW_COUNTS, 0, 1, 1)) or windowHas(ns.L.GATHERWINDOW_TIME:sub(1, 5)), "the session's counts")
W.Slash("/ft session window")
check(not window:IsShown(), "/ft session window closes it again")
W.Slash("/ft session reset")
eq(display:IsShown(), false, "started again: hidden until the next gather")

-- Hidden in combat, back after.
W.lootSource = "GameObject-0-1-0-1-1617-0000000002"
W.loot = { { link = "[Peacebloom]", count = 1 } }
W.OpenLoot()
W.CloseLoot()
W.combat = true
W.Fire("PLAYER_REGEN_DISABLED")
eq(display:IsShown(), false, "hidden in combat")
W.combat = false
W.Fire("PLAYER_REGEN_ENABLED")
check(display:IsShown(), "back after combat")
ns:SetEnabled("GatherSession", false)
eq(display:IsShown(), false, "off: hidden")
finish()
