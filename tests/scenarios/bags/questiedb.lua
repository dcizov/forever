--[[
    Forever Gearbox - tests/scenarios/bags/questiedb.lua
    Quest Items and Full Bags need QuestieDB, as Forever++'s Quest Pins does (Shared/Lib/QuestieDB.lua):
    installed and loaded on demand, it's loaded once a module asks, and they run; missing, both
    are red (Problem) and locked off on Gearbox' own page, say why, and never run, even ticked.
    Run by tests/run.lua (lua5.1 tests/run.lua questiedb), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
W.addonInfo.QuestieDB = nil -- not installed
local ns = W.LoadAddon(root, "ForeverGearbox")
login()
for _, name in ipairs({ "QuestItems", "FullBags" }) do
    local mod = ns.modules[name]
    eq(ns.QuestieDB.Status(), "missing", "QuestieDB missing")
    check(mod.locked, name .. ": locked")
    check(mod.Problem(), name .. ": red on Gearbox' page")
    check(not mod.active, name .. ": not running, though on by default")
    ns:SetEnabled(name, true)
    check(not mod.active, name .. ": nor when ticked")
    local said = false
    for _, row in ipairs(mod.notice) do
        if row.text == ns.L.QUESTIEDB_NEEDED and row.shown(mod.db) then said = true end
    end
    check(said, name .. ": its page says it needs QuestieDB")
end
eq(#W.errors, 0, "no errors")
finish()
