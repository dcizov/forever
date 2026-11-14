--[[
    Forever Tweaks - tests/scenarios/tweaks/djcolors.lua
    Dungeon Journal Skin's palette follows Panels: rows are filled while the pet list's row art
    isn't there, and clear over it once Panels is ticked (DungeonJournal's window isn't made here,
    so Panels never takes effect on its own).
    Run by tests/run.lua (lua5.1 tests/run.lua djcolors), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
W.loaded.ForeverDungeonJournal = true
local hall = { row = { 0.2, 0.1, 0.05, 0.9 } }
ForeverDungeonJournal_NS = { THEMES = { ["Hall of Thanes"] = hall } }
ForeverDungeonJournalFrame = false -- not made yet

local ns = W.LoadAddon(root, "ForeverTweaks")
login()
check(ns.modules.DungeonJournalSkin.active, "on")
eq(hall.row[4], 0, "Panels ticked: rows are clear, for their art")
ns:SetOption("DungeonJournalSkin", "panels", false)
eq(hall.row[4], 0.90, "Panels off before it took effect: rows get the palette's fill")
ns:SetOption("DungeonJournalSkin", "panels", true)
eq(hall.row[4], 0, "and clear again once it's ticked")
ns:SetOption("DungeonJournalSkin", "colors", false)
eq(hall.row[4], 0.9, "Colors off: DungeonJournal's own row colour back")
finish()
