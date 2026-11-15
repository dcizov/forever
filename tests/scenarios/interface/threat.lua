--[[
    Forever Tweaks - tests/scenarios/interface/threat.lua
    Threat: the line shows your threat on an enemy target in its status colour, "Tanking" while it
    attacks you, nothing without threat, a friendly target or a secret value; a hostile creature's
    tooltip gives its aggro range by Classic's rule, a neutral one's and a player's none.
    Run by tests/run.lua (lua5.1 tests/run.lua threat), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverTweaks")
login()
local M = ns.modules.Threat
local L = ns.L
local function line()
    for _, f in ipairs(W.frames) do
        if rawget(f, "_name") == "ForeverTweaksThreat" then return f:IsShown() and M.parts[1]:GetLine() or nil end
    end
end

eq(line(), nil, "no target: nothing")
W.unitInfo.target = { name = "Kobold", reaction = 2, level = 10 }
W.targetEnemy = true
W.threat = { false, 1, 87.4, 70 }
W.Fire("UNIT_THREAT_LIST_UPDATE", "target")
eq(line(), string.format(L.THREAT_LINE, "|cffffff78" .. "87%|r"), "your threat, yellow: close to pulling it")
ns:SetOption("Threat", "raw", true)
eq(line(), string.format(L.THREAT_LINE, "|cffffff78" .. "70%|r"), "Raw Threat: the share of the top")
ns:ResetOption("Threat", "raw")
W.threat = { true, 3, 100, 100 }
W.Fire("UNIT_THREAT_SITUATION_UPDATE", "player")
eq(line(), string.format(L.THREAT_LINE, "|cffff0000" .. L.THREAT_TANKING .. "|r"), "tanking: red")
W.secrets[100] = true
W.Fire("UNIT_THREAT_LIST_UPDATE", "target")
eq(line(), nil, "the game keeps it secret: nothing")
W.secrets[100] = nil
W.threat = nil
W.Fire("UNIT_THREAT_LIST_UPDATE", "target")
eq(line(), nil, "no threat: nothing")
W.targetEnemy = false
W.threat = { false, 0, 10, 10 }
W.Fire("PLAYER_TARGET_CHANGED")
eq(line(), nil, "a target you can't attack: nothing")

-- Aggro range: 20 yards at your level, a yard a level, 5 to 45.
eq(M.AggroRange(12, 10), 22, "two levels above you: 22 yards")
eq(M.AggroRange(1, 30), 5, "far below: 5 at least")
eq(M.AggroRange(-1, 30), 45, "a skull: 45")
W.unitInfo.player = { name = "Me", player = true, level = 10 }
W.unitInfo.mouseover = { name = "Kobold", reaction = 2, level = 13 }
local tip = W.UnitTooltip("Creature-0-1-0-1-6-0000000001", "mouseover")
local found
for _, l in ipairs(tip) do if l.text == string.format(L.THREAT_AGGRO_LINE, 23) then found = true end end
check(found, "a hostile creature's tooltip: its aggro range")
W.unitInfo.mouseover.reaction = 4
tip = W.UnitTooltip("Creature-0-1-0-1-6-0000000001", "mouseover")
found = false
for _, l in ipairs(tip) do if tostring(l.text):find("Aggro", 1, true) then found = true end end
check(not found, "a neutral one doesn't attack on sight: none")
eq(#W.errors, 0, "no errors")
finish()
