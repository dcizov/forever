--[[
    Forever Gearbox - Locales/enUS_Quests.lua
    The strings of the Quests modules (Quest Markers), in English. The
    other modules' are in Locales/enUS_Modules.lua (and enUS_Shared.lua, enUS_Interface.lua); the
    addon's own in enUS.lua.
]]

local _, ns = ...
local L = ns:NewLocale("enUS")

-- Quest Markers (Modules/Quests/QuestMarkers.lua), on Forever++'s Quest Nameplates page
L.QMARK_TITLE = "Quest Markers"
L.QMARK_DESC = "Mark quest creatures the way nameplate addons do, on Blizzard's nameplates and on a nameplate addon's own such as Platynator: a quest marker beside the nameplate or over its name, and its progress on your target, on hover or always, as Plumber shows it."
L.QMARK_SIDE = "Side"
L.QMARK_SIDE_TIP = "Where the marker goes. Left or right of the nameplate, with the progress on the outer side, as Plumber has it; or over the name, with the progress under it, as Platynator has it."
L.QMARK_SIDE_LEFT = "Left"
L.QMARK_SIDE_RIGHT = "Right"
L.QMARK_SIDE_TOP = "Over the Name"
L.QMARK_COLOR = "Progress Color"
L.QMARK_COLOR_TIP = "The color of the progress, like 3/8: white, as Plumber draws it, or gold, as Forever++ does."
L.QMARK_COLOR_WHITE = "White"
L.QMARK_COLOR_GOLD = "Gold"
L.QMARK_SIZE = "Size"
L.QMARK_SIZE_TIP = "How big the mark and its count are."
L.QMARK_PARTY = "Show Party Member's Quest"
L.QMARK_PARTY_TIP = "Mark a creature one of your group still needs for a quest, in grey, with the progress of whoever has the most left."
L.QMARK_PROGRESS = "Progress"
L.QMARK_ALWAYS = "Always Show Progress"
L.QMARK_ALWAYS_TIP = "Show how far along the objective is beside every mark."
L.QMARK_ON_TARGET = "Show Progress on Target"
L.QMARK_ON_TARGET_TIP = "Show the progress on your target's nameplate."
L.QMARK_ON_HOVER = "Show Progress on Hover"
L.QMARK_ON_HOVER_TIP = "Show the progress while the mouse is over the creature or its nameplate."
L.QMARK_ON_ALT = "Show Progress While Holding Alt"
L.QMARK_ON_ALT_TIP = "Show every mark's progress while you hold Alt."
L.QMARK_FORMAT = "Progress Format"
L.QMARK_FORMAT_TIP = "Show the progress as done and needed, like 3/8, or as what's left, like 5."
L.QMARK_FORMAT_DONE = "Completed/Required"
L.QMARK_FORMAT_LEFT = "Remaining"
L.QMARK_X = "X Offset"
L.QMARK_X_TIP = "Move the marker and its progress left (below 0) or right, from where they sit by the nameplate. For nameplate addons such as Platynator, whose nameplates are shaped unlike Blizzard's."
L.QMARK_Y = "Y Offset"
L.QMARK_Y_TIP = "Move the marker and its progress down (below 0) or up, from where they sit by the nameplate."
L.QMARK_NEEDS_PLATES = "Quest creatures are enemies or neutral: their marks need enemy nameplates on."
L.QMARK_DEBUG = "%d quest markers shown"
