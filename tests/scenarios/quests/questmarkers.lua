--[[
    Forever Gearbox - tests/scenarios/quests/questmarkers.lua
    Quest Markers (a section on Forever++'s Quest Nameplates page): a quest creature's marker and
    progress, white by default (gold if asked); left of the plate with the progress left of the
    marker, right with it right, or over the name with it under; shown always, on the target, the
    mouseover or with Alt; Forever++'s own mark on that plate hidden while ours shows and given
    back after; nothing on a done creature or a player; on the nameplate itself under Platynator;
    moved by X and Y Offset; off with Quest Nameplates.
    Run by tests/run.lua (lua5.1 tests/run.lua questmarkers), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverGearbox")
local LINE = Enum.TooltipDataLineType
W.quests = { { title = "Boar Hunt", questID = 1, objectives = { { type = "monster", text = "Mottled Boar slain: 3/8" } } } }
W.unitTips.nameplate1 = { { LINE.None, "Mottled Boar" }, { LINE.QuestTitle, "Boar Hunt" },
    { LINE.QuestObjective, "Mottled Boar slain: 3/8" } }
W.plates.nameplate1 = {}
local plate1 = C_NamePlate.GetNamePlateForUnit("nameplate1")
local frame1 = plate1.UnitFrame
-- Forever++'s own mark on Blizzard's plate: a frame of just an icon and a text.
local theirs = W.NewFrame("Frame", nil, frame1)
theirs.icon, theirs.text = theirs:CreateTexture(), theirs:CreateFontString()
login()
-- Forever++ Integration on: what this checks works with Forever++ (Core/Plugin.lua).
ns:SetEnabled("ForeverPlusPlus", true)
W.RunTimers()
local M = ns.modules.QuestMarkers
check(M.active, "on by default, with Quest Nameplates")

local function markOn(frame)
    for _, child in ipairs({ frame:GetChildren() }) do
        if rawget(child, "icon") and rawget(child, "count") then return child end
    end
end
W.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
local mark = markOn(frame1)
check(mark and mark:IsShown(), "a quest creature: marked")
eq(mark.icon._atlas, "QuestNormal", "with the quest giver's !")
eq(mark.count:GetText(), "", "its progress only on target, on hover or with Alt, as Plumber shows it")
ns:SetOption("QuestMarkers", "always", true)
eq(mark.count:GetText(), "3/8", "Always Show Progress: its progress")
eq(mark.count._textColor[1] .. mark.count._textColor[3], "11", "white, as Plumber draws it")
eq(theirs:GetAlpha(), 0, "Forever++'s mark there steps aside")

-- Sides: the progress on the outer side.
local p, rel, rp = mark.count:GetPoint(1)
check(p == "RIGHT" and rel == mark.icon and rp == "LEFT", "left: the progress left of the marker")
ns:SetOption("QuestMarkers", "side", "right")
p, rel, rp = mark.count:GetPoint(1)
check(p == "LEFT" and rel == mark.icon and rp == "RIGHT", "right: the progress right of the marker")
eq(mark:GetPoint(1), "LEFT", "and the marker right of the plate")
ns:SetOption("QuestMarkers", "side", "top")
p, rel, rp = mark.count:GetPoint(1)
check(p == "TOP" and rel == mark.icon and rp == "BOTTOM", "over the name: the progress under it")
ns:SetOption("QuestMarkers", "color", "gold")
eq(mark.count._textColor[3], 0, "gold, if asked")
ns:ResetOption("QuestMarkers", "side")

-- Progress Format: what's left.
ns:SetOption("QuestMarkers", "format", "left")
eq(mark.count:GetText(), "5", "Remaining: what's left")
ns:ResetOption("QuestMarkers", "format")

-- Progress on the target, on hover, with Alt; the mark itself always.
ns:SetOption("QuestMarkers", "always", false)
check(mark:IsShown() and mark.count:GetText() == "", "not targeted: the mark, no progress")
W.unitIs.target = "nameplate1"
W.Fire("PLAYER_TARGET_CHANGED")
eq(mark.count:GetText(), "3/8", "targeted: its progress")
W.unitIs.target = nil
W.Fire("PLAYER_TARGET_CHANGED")
eq(mark.count:GetText(), "", "target gone: no progress")
W.unitIs.mouseover = "nameplate1"
W.Advance(0.3)
eq(mark.count:GetText(), "3/8", "under the mouse: its progress")
W.unitIs.mouseover = nil
W.Advance(0.3)
eq(mark.count:GetText(), "", "and gone once the mouse leaves (no event says so)")
ns:SetOption("QuestMarkers", "onAlt", true)
W.alt = true
W.Fire("MODIFIER_STATE_CHANGED", "LALT", 1)
eq(mark.count:GetText(), "3/8", "While Holding Alt: shown with Alt")
W.alt = false
W.Fire("MODIFIER_STATE_CHANGED", "LALT", 0)
eq(mark.count:GetText(), "", "hidden without")
ns:SetOption("QuestMarkers", "always", true)
eq(theirs:GetAlpha(), 0, "Forever++'s mark stays aside meanwhile")

-- Done: nothing, Forever++'s back.
W.unitTips.nameplate1[3] = { LINE.QuestObjective, "Mottled Boar slain: 8/8" }
W.Fire("QUEST_LOG_UPDATE")
W.RunTimers()
check(not mark:IsShown(), "done: nothing")
eq(theirs:GetAlpha(), 1, "and Forever++'s mark given back")
-- Show Party Member's Quest: done for you, a group member still needs it: a grey mark.
W.unitTips.nameplate1[4] = { LINE.QuestPlayer, "Thrall" }
W.unitTips.nameplate1[5] = { LINE.QuestObjective, "Mottled Boar slain: 2/8" }
W.Fire("QUEST_LOG_UPDATE")
W.RunTimers()
check(mark:IsShown() and mark.icon._desaturated, "a party member's quest: a grey mark")
eq(mark.count:GetText(), "2/8", "with their progress")
ns:SetOption("QuestMarkers", "party", false)
check(not mark:IsShown(), "Show Party Member's Quest off: nothing")
ns:ResetOption("QuestMarkers", "party")
W.unitTips.nameplate1[4], W.unitTips.nameplate1[5] = nil, nil
W.unitTips.nameplate1[3] = { LINE.QuestObjective, "Mottled Boar slain: 3/8" }

-- Platynator takes Blizzard's UnitFrame off the plate: the mark goes on the nameplate.
W.plates.nameplate4 = {}
W.unitTips.nameplate4 = W.unitTips.nameplate1
local plate4 = C_NamePlate.GetNamePlateForUnit("nameplate4")
local hidden = W.NewFrame("Frame", nil, UIParent)
hidden:Hide()
plate4.UnitFrame:SetParent(hidden)
W.Fire("NAME_PLATE_UNIT_ADDED", "nameplate4")
local onPlate = markOn(plate4)
check(onPlate ~= nil and onPlate:IsVisible(), "Platynator: on the nameplate, shown")
-- X and Y Offset move the marker and its progress (Platynator's plate is shaped its own way).
ns:SetOption("QuestMarkers", "x", 12)
ns:SetOption("QuestMarkers", "y", -7)
local _, _, _, x, y = onPlate:GetPoint(1)
eq(x, -4 + 12, "X Offset moves it along")
eq(y, -7, "Y Offset up or down")
ns:SetOption("QuestMarkers", "side", "top")
_, _, _, x = onPlate:GetPoint(1)
eq(x, 12, "over the name too")
for _, key in ipairs({ "x", "y", "side" }) do ns:ResetOption("QuestMarkers", key) end

-- Forever++ Integration off: Forever++'s own mark is left alone; Quest Markers is its own.
ns:SetEnabled("ForeverPlusPlus", false)
W.Fire("QUEST_LOG_UPDATE")
W.RunTimers()
eq(theirs:GetAlpha(), 1, "integration off: Forever++'s mark left as it is")
W.FPP.SetOwn("QuestNameplates", false)
check(M.active, "Forever++'s Quest Nameplates off: Quest Markers stays on, its own module")
ns:SetEnabled("QuestMarkers", false)
check(not onPlate:IsShown(), "off: nothing shown")
eq(#W.errors, 0, "no errors")
finish()
