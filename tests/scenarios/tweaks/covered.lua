--[[
    Forever Tweaks - tests/scenarios/tweaks/covered.lua
    The features Forever Tweaks shares with Forever++, WilduTools and Plumber, and the ones that
    do them: Repair & Sell Junk at a merchant, Durability Warning, Gathering Tracking. Each works
    on its own, and stays out of the way (with a notice saying so) while the other addon's own is on.
    Run by tests/run.lua (lua5.1 tests/run.lua covered), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverTweaks")
login()
local L = ns.L
local repair = ns.modules.Repair

local function noticeShown(mod, folder)
    local title = ns.OtherAddons.Title(folder)
    for _, n in ipairs(mod.notice) do
        if n.text:find(title, 1, true) == 1 and n.shown() then return true end
    end
    return false
end

-- Repair: at a merchant who can, from your own money.
W.canRepair, W.repairCost, W.money = true, 500, 10000
W.OpenMerchant()
eq(W.repaired[1], "own", "repaired with your own money")
eq(W.money, 9500, "and paid for")
check(W.LastChat():find("Repaired for 500c", 1, true) ~= nil, "says what it cost")
W.CloseMerchant()
-- Shift held skips the visit.
W.repaired, W.repairCost, W.shift = {}, 300, true
W.OpenMerchant()
eq(#W.repaired, 0, "Shift skips it")
W.shift = false
W.CloseMerchant()
-- Guild First: the guild bank pays when it can; over its limit, your own money a moment later.
W.inGuild, W.canGuildRepair, W.guildLimit = true, true, 100
W.repaired = {}
W.OpenMerchant()
eq(#W.repaired, 1, "the guild can't pay this much: one repair")
eq(W.repaired[1], "own", "from your own money")
W.CloseMerchant()
W.repaired, W.repairCost, W.guildLimit = {}, 300, -1
W.OpenMerchant()
eq(W.repaired[1], "guild", "the guild bank pays")
W.Fire("UPDATE_INVENTORY_DURABILITY")
check(W.LastChat():find("guild bank", 1, true) ~= nil, "says so once the repair shows")
W.CloseMerchant()

-- Sell Junk: off by default; on, the merchant's own Sell All Junk.
W.items["[Broken Fang]"] = { id = 5, sell = 7 }
W.bags[0] = { { link = "[Broken Fang]", count = 2, quality = 0 } }
W.OpenMerchant()
eq(W.junkSold, 0, "Sell Junk is off by default")
W.CloseMerchant()
ns:SetOption("Repair", "sellJunk", true)
W.OpenMerchant()
eq(W.junkSold, 1, "on: the junk is sold")
check(W.LastChat():find("Sold 1 junk items for 14c", 1, true) ~= nil, "and what it sold for")
W.CloseMerchant()

-- Forever++ doing it: Forever Tweaks leaves it alone and says so.
W.loaded.ForeverPlusPlus = true
local fpp = { AutoRepair = true }
ForeverPlusPlusAPI = { v1 = { IsModuleEnabled = function(name) return fpp[name] end, OpenSettings = function() end } }
W.repaired, W.repairCost, W.junkSold = {}, 200, 0
W.OpenMerchant()
eq(#W.repaired, 0, "Forever++'s Auto Repair on: no repair from us")
eq(W.junkSold, 1, "its Auto Sell Junk off: ours still sells")
check(noticeShown(repair, "ForeverPlusPlus"), "the page says Forever++ does it")
W.CloseMerchant()
fpp.AutoRepair = false
W.OpenMerchant()
eq(W.repaired[1], "guild", "turned off there: ours repairs again")
W.CloseMerchant()
-- WilduTools' Auto Repair, from its saved settings for this character.
W.loaded["!WilduTools"] = true
WilduToolsDB = { profileKeys = { ["Orgrimmar Grunt Kazran"] = "Default" },
    profiles = { Default = { automation_autoRepairEnabled = true } } }
W.repaired, W.repairCost = {}, 200
W.OpenMerchant()
eq(#W.repaired, 0, "WilduTools' Auto Repair on: none from us")
check(noticeShown(repair, "!WilduTools"), "the page says WilduTools does it")
W.CloseMerchant()
WilduToolsDB = nil
W.loaded["!WilduTools"], W.loaded.ForeverPlusPlus, ForeverPlusPlusAPI = nil, nil, nil

-- Durability Warning: once below the threshold, again when broken, again after a repair.
local before = #W.uiErrors
W.durability = { [5] = { 50, 100 } }
W.Advance(6) -- the first look after login
eq(#W.uiErrors, before, "gear fine: nothing")
W.durability[5] = { 20, 100 }
W.Fire("UPDATE_INVENTORY_DURABILITY")
W.Fire("UPDATE_INVENTORY_DURABILITY")
W.Advance(1.5)
eq(#W.uiErrors, before + 1, "below 25%: one warning for the burst")
check(W.uiErrors[#W.uiErrors]:find("20%", 1, true) ~= nil, "saying how worn")
W.durability[5] = { 10, 100 }
W.Fire("UPDATE_INVENTORY_DURABILITY")
W.Advance(1.5)
eq(#W.uiErrors, before + 1, "lower still: no second warning")
W.durability[5] = { 0, 100 }
W.Fire("UPDATE_INVENTORY_DURABILITY")
W.Advance(1.5)
eq(#W.uiErrors, before + 2, "broken: warned once more")
W.durability[5] = { 100, 100 }
W.Fire("UPDATE_INVENTORY_DURABILITY")
W.Advance(1.5)
W.durability[5] = { 20, 100 }
W.Fire("UPDATE_INVENTORY_DURABILITY")
W.Advance(1.5)
eq(#W.uiErrors, before + 3, "after a repair, the next drop warns again")

-- Gathering Tracking: turned back on after dying, never while busy, refused once and then quiet.
W.tracking = { { spellID = 2580 }, { spellID = 2383 } }
W.Fire("PLAYER_ALIVE")
W.Advance(1.5)
eq(W.tracking[1].active, true, "Find Minerals back on")
W.tracking[1].active = false
W.casting = "Mining"
W.Fire("PLAYER_UNGHOST")
W.Advance(1.5)
eq(W.tracking[1].active, false, "not while casting")
W.casting = nil
W.Advance(2.5)
eq(W.tracking[1].active, true, "once the cast is over")
W.Advance(15)
ns:SetOption("GatheringTracking", "swap", true)
W.Advance(10.5)
eq(W.tracking[2].active, true, "swapped to Find Herbs")
ns:SetOption("GatheringTracking", "swap", false)
W.tracking[1].active, W.tracking[2].active = false, false
W.trackingRefused = true
local chat = #W.chat
W.Fire("PLAYER_ALIVE")
W.Advance(1.5)
check(W.LastChat():find("didn't let", 1, true) ~= nil, "a refusal is said once")
W.Fire("PLAYER_ALIVE")
W.Advance(15)
eq(#W.chat, chat + 1, "and then it stops")
eq(#W.errors, 0, "no errors")
finish()
