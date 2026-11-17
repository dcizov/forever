--[[
    Forever Gearbox - tests/scenarios/interface/combathelpers.lua
    The combat helpers that WilduTools also has: Five-Second Rule (a spark after a mana cast), Cast Bar
    (timer inside and back, simple look and back, channel ticks), and each left to WilduTools.
    Run by tests/run.lua (lua5.1 tests/run.lua combathelpers), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverGearbox")
login()

-- Five-Second Rule: a spark after a spell that costs mana, none after a free one.
ns:SetEnabled("FiveSecond", true)
W.powerCost[133] = 50
W.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 31)
check(ns.modules.FiveSecond:DebugLine() ~= nil, "a free spell: nothing to say")
W.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 133)
local spark
for _, f in ipairs(W.frames) do
    if rawget(f, "_texture") == "Interface\\CastingBar\\UI-CastingBar-Spark" then spark = f end
end
check(spark and spark:IsShown(), "a mana spell: the spark runs")

-- Cast Bar: timer inside and back, simple look and back, ticks on a channel.
local bar = PlayerCastingBarFrame
ns:SetEnabled("PlayerCastBar", true) -- Forever++'s Modules page turns it on; ticking a part doesn't
ns:SetOption("PlayerCastBar", "timerInside", true)
eq(bar.CastTimeText._point[1], "RIGHT", "the timer inside the bar")
ns:SetOption("PlayerCastBar", "timerInside", false)
eq(bar.CastTimeText._point[1], "LEFT", "back beside it, as Blizzard's XML has it")
ns:SetOption("PlayerCastBar", "simple", true)
eq(bar.Text._point[1], "CENTER", "the spell name in the bar")
check(not bar.TextBorder:IsShown(), "without the box under it")
bar:SetLook("UNITFRAME") -- Edit Mode lays it out again
eq(bar.Text._point[1], "CENTER", "kept when Blizzard lays it out again")
ns:SetOption("PlayerCastBar", "simple", false)
eq(bar.Text._point[1], "TOP", "back under the bar")
check(bar.TextBorder:IsShown(), "with its box")
W.spells[5143] = "Arcane Missiles"
W.spells[25345] = "Arcane Missiles"
ns:SetOption("PlayerCastBar", "ticks", true)
W.Fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast", 25345)
local ticks = 0
for _, f in ipairs(W.frames) do
    if rawget(f, "_parent") == bar and rawget(f, "_color") and f:IsShown() then ticks = ticks + 1 end
end
eq(ticks, 4, "Arcane Missiles (any rank): 4 lines between its 5 ticks")
W.Fire("UNIT_SPELLCAST_CHANNEL_STOP", "player")
eq(#W.errors, 0, "no errors")
finish()
