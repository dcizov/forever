--[[
    Forever Tweaks - tests/scenarios/quests/questplates.lua
    Quest Nameplates: a creature in your log gets its icon and count (each can go, the count on
    any side of the icon, the pair left, right or above and nudged), a done one nothing, a
    group's progress added up or the lowest, nothing on players or while the game won't say, and
    nothing while Forever++ or Plumber does it, and on the nameplate itself when a nameplate
    addon (Platynator) hides Blizzard's. Object Names: a soft-targeted chest's name, gray
    out of reach, and its objective from its tooltip.
    Run by tests/run.lua (lua5.1 tests/run.lua questplates), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverTweaks")
login()
local LINE = Enum.TooltipDataLineType

-- The box Quest Nameplates drew on a unit's plate, and its text.
local function box(unit)
    local frame = C_NamePlate.GetNamePlateForUnit(unit).UnitFrame
    for _, child in ipairs({ frame:GetChildren() }) do
        if rawget(child, "icon") and rawget(child, "text") then return child end
    end
end
local function shown(unit)
    local b = box(unit)
    return b and b:IsShown() and b.text:GetText() or nil
end

W.quests = { { title = "Boar Hunt", questID = 1, objectives = { { type = "monster", text = "Mottled Boar slain: 3/8" } } } }
W.unitTips.nameplate1 = { { LINE.None, "Mottled Boar" }, { LINE.QuestTitle, "Boar Hunt" }, { LINE.QuestObjective, "Mottled Boar slain: 3/8" } }
W.plates.nameplate1 = {}
W.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
eq(shown("nameplate1"), "3/8", "a quest creature: its count")
eq(box("nameplate1").icon._atlas, "Crosshair_Attack_32", "with the kill icon")
ns:SetOption("QuestNameplates", "progress", "remaining")
eq(shown("nameplate1"), "5", "how many more")
ns:SetOption("QuestNameplates", "progress", "count")

-- Progress: the next look after the quest log changes.
W.unitTips.nameplate1[3] = { LINE.QuestObjective, "Mottled Boar slain: 8/8" }
W.Fire("QUEST_LOG_UPDATE")
W.RunTimers()
eq(shown("nameplate1"), nil, "done: nothing more to do, so nothing shows")
W.unitTips.nameplate1[3] = { LINE.QuestObjective, "Mottled Boar slain: 3/8" }
W.Fire("QUEST_LOG_UPDATE")
W.RunTimers()
eq(shown("nameplate1"), "3/8", "back in progress: shown again")

-- The icon and the count each on their own, the count beside the icon, the pair moved.
local b1 = box("nameplate1")
ns:SetOption("QuestNameplates", "icon", "quest")
eq(b1.icon._atlas, "QuestNormal", "Quest (!): the quest giver's mark")
ns:SetOption("QuestNameplates", "icon", "off")
check(not b1.icon:IsShown() and shown("nameplate1") == "3/8", "no icon: the count alone")
ns:SetOption("QuestNameplates", "progress", "off")
check(not b1:IsShown(), "no icon and no count: nothing")
ns:SetOption("QuestNameplates", "progress", "count")
ns:SetOption("QuestNameplates", "icon", "kind")
check(b1.icon:IsShown(), "the icon back")
ns:SetOption("QuestNameplates", "textAt", "right")
local point, rel, relPoint = b1.text:GetPoint(1)
check(point == "LEFT" and rel == b1.icon and relPoint == "RIGHT", "the count right of the icon")
ns:SetOption("QuestNameplates", "side", "top")
ns:SetOption("QuestNameplates", "x", 10)
ns:SetOption("QuestNameplates", "y", -5)
local p, _, rp, x, y = b1:GetPoint(1)
check(p == "BOTTOM" and rp == "TOP" and x == 10 and y == -3, "above the name, nudged by the offsets")
for _, key in ipairs({ "textAt", "side", "x", "y" }) do ns:ResetOption("QuestNameplates", key) end
W.unitTips.nameplate1[3] = { LINE.QuestObjective, "Mottled Boar slain: 8/8" }
W.Fire("QUEST_LOG_UPDATE")
W.RunTimers()

-- A group: your line and a member's.
W.unitTips.nameplate2 = { { LINE.None, "Kobold" }, { LINE.QuestTitle, "Kobold Camp" },
    { LINE.QuestPlayer, "Orgrimmar Grunt" }, { LINE.QuestObjective, "Kobold slain: 6/10" },
    { LINE.QuestPlayer, "Friend" }, { LINE.QuestObjective, "Kobold slain: 2/10" } }
W.plates.nameplate2 = {}
W.Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
eq(shown("nameplate2"), "8/20", "combined: everyone's added up")
ns:SetOption("QuestNameplates", "party", "lowest")
eq(shown("nameplate2"), "2/10", "lowest: whoever has most left")
ns:SetOption("QuestNameplates", "party", "own")
eq(shown("nameplate2"), "6/10", "own: yours only")

-- Not on players; and a secret line leaves the plate as it was.
W.plates.nameplate3 = { player = true }
W.unitTips.nameplate3 = W.unitTips.nameplate1
W.Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
eq(box("nameplate3"), nil, "a player gets nothing")
local secret = "Kobold slain: 7/10"
W.secrets[secret] = true
W.unitTips.nameplate2[4] = { LINE.QuestObjective, secret }
W.Fire("QUEST_LOG_UPDATE")
W.RunTimers()
eq(shown("nameplate2"), "6/10", "the game won't say: keeps what it showed")
W.secrets[secret] = nil

-- Forever++'s Quest Nameplates on: ours goes.
W.loaded.ForeverPlusPlus = true
ForeverPlusPlusAPI = { v1 = { IsModuleEnabled = function(name) return name == "QuestNameplates" end } }
W.Fire("QUEST_LOG_UPDATE")
W.RunTimers()
eq(shown("nameplate1"), nil, "left to Forever++")
W.loaded.ForeverPlusPlus, ForeverPlusPlusAPI = nil, nil
W.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
check(not box("nameplate1"):IsShown(), "a plate that goes away hides its box")

-- A nameplate addon that draws its own plate (Platynator) parents Blizzard's UnitFrame to a
-- hidden frame: the box goes on the nameplate itself, where it shows.
local function boxOn(frame)
    for _, child in ipairs({ frame:GetChildren() }) do
        if rawget(child, "icon") and rawget(child, "text") then return child end
    end
end
W.plates.nameplate4 = {}
W.unitTips.nameplate4 = { { LINE.None, "Mottled Boar" }, { LINE.QuestTitle, "Boar Hunt" },
    { LINE.QuestObjective, "Mottled Boar slain: 3/8" } }
local plate4 = C_NamePlate.GetNamePlateForUnit("nameplate4")
local hidden = W.NewFrame("Frame", nil, UIParent)
hidden:Hide()
plate4.UnitFrame:SetParent(hidden)
W.Fire("NAME_PLATE_UNIT_ADDED", "nameplate4")
local onPlate = boxOn(plate4)
check(onPlate ~= nil and onPlate:IsVisible(), "Platynator: the box on the nameplate, shown")
eq(onPlate and onPlate.text:GetText(), "3/8", "with its count")
eq(boxOn(plate4.UnitFrame), nil, "not on the hidden UnitFrame")

-- Object Names: a chest under the soft target, then out of reach, then its objective.
W.softObject = { name = "Battered Chest" }
W.plates.softinteract = {}
W.cursorTip = { { LINE.None, "Battered Chest" }, { LINE.QuestObjective, "Gold Pickup: 1/4" } }
W.Fire("PLAYER_SOFT_INTERACT_CHANGED")
W.RunTimers()
eq(ns.modules.ObjectNames:DebugLine(), "Battered Chest", "a chest under the soft target")
local soft = C_NamePlate.GetNamePlateForUnit("softinteract").UnitFrame
local display
for _, f in ipairs(W.frames) do if rawget(f, "title") and rawget(f, "_parent") == soft then display = f end end
check(display and display:IsShown(), "its name shows on its plate")
eq(display.title:GetText(), "Battered Chest", "the name")
eq(display.title._textColor[1], 1, "yellow in reach")
eq(display.sub:GetText(), "Gold Pickup: 1/4", "and its objective")
W.cursorTip[2] = { LINE.QuestObjective, "Gold Pickup: 2/4" }
W.Advance(0.3)
eq(display.sub:GetText(), "Gold Pickup: 2/4", "the count follows as you loot")
W.softObject.unable = true
W.Fire("PLAYER_SOFT_INTERACT_CHANGED")
W.RunTimers()
eq(display.title._textColor[1], 0.6, "gray out of reach")
W.softObject = nil
W.Fire("PLAYER_SOFT_INTERACT_CHANGED")
W.RunTimers()
check(not display:IsShown(), "gone with the target")
eq(#W.errors, 0, "no errors")
finish()
