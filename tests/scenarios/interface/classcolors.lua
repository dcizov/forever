--[[
    Forever Tweaks - tests/scenarios/interface/classcolors.lua
    Class Colors: a player target's bar, name and name background in its class colour, an NPC's
    bar by its reaction, a friendly one's left green; Blizzard's colours remembered and put back
    when a frame is turned off or the module is; nothing while Forever++'s own is on.
    Run by tests/run.lua (lua5.1 tests/run.lua classcolors), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
-- Blizzard's target frame: its health bar, name and name background, on "target".
TargetFrame = W.NewFrame("Frame", "TargetFrame")
TargetFrame.unit = "target"
TargetFrame.healthbar = W.NewFrame("StatusBar", nil, TargetFrame)
TargetFrame.healthbar.unit, TargetFrame.healthbar.unitFrame = "target", TargetFrame
TargetFrame.name = TargetFrame:CreateFontString()
TargetFrame.nameBackground = TargetFrame:CreateTexture()
TargetFrame.healthbar:SetStatusBarColor(0, 1, 0)
TargetFrame.name:SetTextColor(1, 0.82, 0)
TargetFrame.nameBackground:SetVertexColor(0, 0, 1)

local ns = W.LoadAddon(root, "ForeverTweaks")
login()
local M = ns.modules.ClassColors
local bar, name, back = TargetFrame.healthbar, TargetFrame.name, TargetFrame.nameBackground
check(M.active, "on by default")

-- A player target: their class colour (the stand-in's is 0.5, 0.5, 1).
W.unitInfo.target = { name = "Thrall", player = true, class = "SHAMAN" }
UnitFrame_Update(TargetFrame)
eq(bar._barColor[3], 1, "a player's bar in their class colour")
check(bar._barDesaturated, "the green art desaturated to take it")
eq(name._textColor[1], 0.5, "their name too")
eq(back._vertexColor[1], 0.5, "and the bar behind it")

-- Blizzard sets the bar again: remembered, painted over.
bar:SetStatusBarColor(0.2, 0.2, 0.2)
eq(bar._barColor[3], 1, "painted over what Blizzard sets")

-- NPCs: hostile red, neutral yellow, tapped grey, friendly Blizzard's.
W.unitInfo.target = { name = "Boar", reaction = 2 }
UnitFrame_Update(TargetFrame)
check(bar._barColor[1] == 1 and bar._barColor[2] == 0, "a hostile creature: red")
W.unitInfo.target = { name = "Boar", reaction = 4 }
UnitFrame_Update(TargetFrame)
check(bar._barColor[1] == 1 and bar._barColor[2] == 1, "neutral: yellow")
W.unitInfo.target = { name = "Boar", reaction = 2, tapped = true }
UnitFrame_Update(TargetFrame)
eq(bar._barColor[1], 0.5, "tapped by someone else: grey")
W.unitInfo.target = { name = "Guard", reaction = 6 }
UnitFrame_Update(TargetFrame)
eq(bar._barColor[1], 0.2, "friendly: back to what Blizzard last set")
check(not bar._barDesaturated, "and its art as it was")
eq(name._textColor[2], 0.82, "the name back to Blizzard's")

-- The Target checkbox off: left to Blizzard.
W.unitInfo.target = { name = "Thrall", player = true, class = "SHAMAN" }
ns:SetOption("ClassColors", "target", false)
eq(bar._barColor[1], 0.2, "Target off: Blizzard's colour")
ns:SetOption("ClassColors", "target", true)
eq(bar._barColor[3], 1, "back on: the class colour")

-- Forever++'s Class Colors on: ours steps aside at the next look.
W.loaded.ForeverPlusPlus = true
ForeverPlusPlusAPI = { v1 = { IsModuleEnabled = function(n) return n == "ClassColors" end } }
UnitFrame_Update(TargetFrame)
eq(bar._barColor[1], 0.2, "left to Forever++")
W.loaded.ForeverPlusPlus, ForeverPlusPlusAPI = nil, nil
UnitFrame_Update(TargetFrame)

-- Off: everything back as Blizzard had it.
ns:SetEnabled("ClassColors", false)
eq(bar._barColor[1], 0.2, "off: Blizzard's bar")
eq(back._vertexColor[3], 1, "Blizzard's name background")
eq(#W.errors, 0, "no errors")
finish()
