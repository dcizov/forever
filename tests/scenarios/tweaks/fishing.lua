--[[
    Forever Tweaks - tests/scenarios/tweaks/fishing.lua
    Fishing: the line shown only with a pole in hand (skill, bonus, the zone's skill, lure
    countdown, a full rank), the no-lure warning (only with a lure in the bags, once a minute), the
    skill-too-low warning (once a zone), the lure-running-out warning (once a lure), and the
    once-a-second clock running only while a pole is in hand.
    Run by tests/run.lua (lua5.1 tests/run.lua fishing), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
W.items["[Strong Fishing Pole]"] = { id = 6365, class = 2, subclass = 20 }
W.items["[Short Sword]"] = { id = 2131, class = 2, subclass = 7 }
W.profs[4] = { name = "Fishing", rank = 150, maxRank = 225, modifier = 5, line = 356 }
W.mapID = 1429 -- Elwynn Forest: needs 1
W.items["[Shiny Bauble]"] = { id = 6529, stack = 20, class = 0 }

local ns = W.LoadAddon(root, "ForeverTweaks")
login()
local mod = ns.modules.Fishing
check(mod.active, "on by default")
local display = _G.ForeverTweaksFishing
local function line() return display.display:GetLine() end
local function changeGear(slot, item)
    W.equipped[slot] = item
    W.Fire("PLAYER_EQUIPMENT_CHANGED", slot)
    W.RunTimers()
end

eq(display.display.wantShown, false, "no pole: no line")
-- Whether any of Fishing's timers runs: a few seconds pass with the Profiler recording, and only
-- timers run then, so anything charged to Fishing is one of its timers.
local function fishingTicks()
    ns.Profiler.Start()
    W.Advance(3)
    ns.Profiler.Stop()
    return ns.Profiler.Report():find("Fishing:", 1, true) ~= nil
end
changeGear(16, 2131)
eq(display.display.wantShown, false, "a sword isn't a pole")
eq(fishingTicks(), false, "and nothing ticks")

changeGear(16, 6365)
eq(display.display.wantShown, true, "a pole in hand: the line shows")
check(fishingTicks(), "and its clock ticks")
check(line():find("Fishing 150 +5 (155)", 1, true), "skill, bonus and both together")
check(line():find("No lure", 1, true), "says there's no lure")
check(line():find("|cff808080No lure", 1, true), "in gray: there's none in the bags")
check(line():find("|cff20ff20Zone 1|r", 1, true), "Elwynn's water needs 1: green")

-- Casting without a lure warns only with one in the bags, at most once a minute.
W.Fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-0", 7620)
eq(#W.uiErrors, 0, "no lure to put on: no warning")
W.owned[6529] = 5
W.Fire("BAG_UPDATE_DELAYED")
W.RunTimers()
check(line():find("|cffff2020No lure", 1, true), "a lure in the bags: the line says so in red")
W.Fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-1", 7620)
eq(W.uiErrors[#W.uiErrors], ns.L.FISHING_NO_LURE_WARNING:format("Shiny Bauble"), "fishing without a lure warns, naming it")
W.Fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-2", 7620)
eq(#W.uiErrors, 1, "not again within the minute")
W.Fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-3", 133)
eq(#W.uiErrors, 1, "another spell doesn't warn")

-- A lure: its countdown, and one warning as it runs out.
W.lure = 600000
W.profs[4].modifier = 30
W.Fire("UNIT_INVENTORY_CHANGED", "player")
W.RunTimers()
check(line():find("Lure 10:00", 1, true), "the lure's time left")
check(line():find("+30 (180)", 1, true), "the bonus the game counts with it")
W.Advance(61)
W.Fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-4", 7620)
eq(#W.uiErrors, 1, "with a lure on, casting doesn't warn")
W.lure = 25000
W.Advance(1)
eq(W.uiErrors[#W.uiErrors], ns.L.FISHING_LURE_ENDING:format("0:25"), "running out warns")
local count = #W.uiErrors
W.lure = 20000
W.Advance(2)
eq(#W.uiErrors, count, "once per lure")
W.lure = nil
W.Advance(1)
W.lure = 600000
W.Advance(1)
W.lure = 10000
W.Advance(1)
eq(#W.uiErrors, count + 1, "the next lure gets its own warning")

-- A lure whose time the game keeps secret: on, time unknown, no warning.
W.lure = 9999
W.secrets[9999] = true
count = #W.uiErrors
W.Advance(1)
check(line():find(ns.L.FISHING_LURE_ON, 1, true), "a secret lure time still says a lure is on")
eq(#W.uiErrors, count, "and doesn't warn")
W.lure = nil

-- The zone's skill, through a subzone's map, and the warning once a zone.
W.lure = nil
W.maps[9001] = 1434 -- a subzone map in Stranglethorn Vale (130 inland, 205 on the coast)
W.mapID = 9001
W.Fire("ZONE_CHANGED")
W.RunTimers()
check(line():find("|cffffd100Zone 130/205|r", 1, true), "180 is enough inland, not on the coast: yellow")
W.mapID = 1425 -- The Hinterlands: 205
W.Fire("ZONE_CHANGED_NEW_AREA")
W.RunTimers()
check(line():find("|cffff2020Zone 205|r", 1, true), "too little: red")
count = #W.uiErrors
W.Advance(61)
W.owned[6529] = nil
W.Fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-5", 7620)
eq(W.uiErrors[#W.uiErrors], ns.L.FISHING_ZONE_WARNING:format(205, 180), "casting with too little skill warns")
W.Fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-6", 7620)
eq(#W.uiErrors, count + 1, "once in the zone")
W.mapID = 1423 -- Eastern Plaguelands: 330
W.Fire("ZONE_CHANGED_NEW_AREA")
W.RunTimers()
W.Fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-7", 7620)
eq(#W.uiErrors, count + 2, "a new zone warns again")
W.mapID = 1418 -- Badlands: no water
W.Fire("ZONE_CHANGED_NEW_AREA")
W.RunTimers()
check(not line():find("Zone", 1, true), "a zone with no fishing data: nothing")
ns:SetOption("Fishing", "zone", false)
W.mapID = 1429
W.Fire("ZONE_CHANGED_NEW_AREA")
W.RunTimers()
check(not line():find("Zone", 1, true), "Zone's Skill off")
ns:SetOption("Fishing", "zone", true)

-- A full rank.
W.profs[4].rank = 225
W.Fire("SKILL_LINES_CHANGED")
W.RunTimers()
check(line():find(ns.L.FISHING_RANK_CAP, 1, true), "a full rank says to train the next")

-- Pole off: the line goes and the clock stops.
changeGear(16, 2131)
eq(display.display.wantShown, false, "pole off: the line goes")
eq(fishingTicks(), false, "and the clock stops")

-- Info off keeps the warnings.
ns:SetOption("Fishing", "info", false)
changeGear(16, 6365)
eq(display.display.wantShown, false, "Fishing Line off: no line")
check(mod.active, "the warnings keep the module on")

finish()
