--[[
    Forever Tweaks - tests/scenarios/interface/combathelpers.lua
    The combat helpers that WilduTools also has: Melee Range (shown out of reach of an enemy
    target, on the spellbook's melee spell), Five-Second Rule (a spark after a mana cast), Combat
    Error Filter (kinds hidden in combat, shown after, never one the game hides itself), Cast Bar
    (timer inside and back, simple look and back, channel ticks), and each left to WilduTools.
    Run by tests/run.lua (lua5.1 tests/run.lua combathelpers), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverTweaks")
login()

-- Melee Range: off by default; on, the spellbook's melee spell is checked against an enemy target.
W.spellbook = { { spellID = 133, harmful = true, maxRange = 30 }, { spellID = 78, harmful = true, maxRange = 5 } }
ns:SetEnabled("MeleeRange", true)
local display = ForeverTweaksMeleeRange
W.Creature = W.Creature
W.unitExists.target, W.targetEnemy, W.inRange[78] = true, true, false
W.Fire("PLAYER_TARGET_CHANGED")
eq(W.rangeChecks[78], true, "the melee spell (not the ranged one) is range-checked")
check(display:IsShown(), "an enemy out of reach: Too far")
W.Fire("SPELL_RANGE_CHECK_UPDATE", 78, true, true)
check(not display:IsShown(), "in reach: gone")
W.Fire("SPELL_RANGE_CHECK_UPDATE", 78, false, true)
check(display:IsShown(), "out again: back")
W.targetDead = true
W.Fire("UNIT_HEALTH", "target")
check(not display:IsShown(), "a dead target: nothing")
W.targetDead = false
W.Fire("UNIT_HEALTH", "target")
ns:SetOption("MeleeRange", "combatOnly", true)
check(not display:IsShown(), "Only in Combat, out of combat: nothing")
-- Combat starting: the game's lockdown turns on only after PLAYER_REGEN_DISABLED, so the warning
-- has to come from the event itself.
W.combat = false
W.Fire("PLAYER_REGEN_DISABLED")
check(display:IsShown(), "Only in Combat: shown as combat starts, before the lockdown")
W.Fire("PLAYER_REGEN_ENABLED")
check(not display:IsShown(), "and gone as it ends")
ns:SetOption("MeleeRange", "combatOnly", false)
W.loaded["!WilduTools"] = true
WilduToolsDB = { profiles = { Default = { wilduUI_rangeMeleeIndicator = true } } }
W.Fire("SPELL_RANGE_CHECK_UPDATE", 78, false, true)
check(not display:IsShown(), "WilduTools' own on: ours stays hidden")
WilduToolsDB, W.loaded["!WilduTools"] = nil, nil
ns:SetEnabled("MeleeRange", false)
eq(W.rangeChecks[78], nil, "off: the range check is turned off again")

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

-- Combat Error Filter: in combat only, the game's own hidden kind left hidden.
ns:SetEnabled("CombatErrors", true)
eq(BLACK_LISTED_MESSAGE_TYPES[LE_GAME_ERR_OUT_OF_RAGE], nil, "out of combat: shown")
W.Fire("PLAYER_REGEN_DISABLED")
eq(BLACK_LISTED_MESSAGE_TYPES[LE_GAME_ERR_OUT_OF_RAGE], true, "in combat: Not enough rage hidden")
eq(BLACK_LISTED_MESSAGE_TYPES[LE_GAME_ERR_OUT_OF_RANGE], true, "and Out of range")
W.Fire("PLAYER_REGEN_ENABLED")
eq(BLACK_LISTED_MESSAGE_TYPES[LE_GAME_ERR_OUT_OF_RAGE], false, "after combat: shown again")
eq(BLACK_LISTED_MESSAGE_TYPES[LE_GAME_ERR_SPELL_FAILED_ANOTHER_IN_PROGRESS], true, "the game's own stays hidden")
ns:SetOption("CombatErrors", "range", false)
ns:SetOption("CombatErrors", "always", true)
eq(BLACK_LISTED_MESSAGE_TYPES[LE_GAME_ERR_OUT_OF_RAGE], true, "Out of Combat Too: hidden now")
eq(BLACK_LISTED_MESSAGE_TYPES[LE_GAME_ERR_OUT_OF_RANGE], false, "a kind unticked stays shown")
ns:SetEnabled("CombatErrors", false)
eq(BLACK_LISTED_MESSAGE_TYPES[LE_GAME_ERR_OUT_OF_RAGE], false, "off: everything shown again")

-- Cast Bar: timer inside and back, simple look and back, ticks on a channel.
local bar = PlayerCastingBarFrame
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
