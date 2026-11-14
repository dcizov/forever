--[[
    Forever Tweaks - tests/scenarios/core/removed.lua
    What removed modules left behind is cleared; their CVars are left as the player had them.
    Run by tests/run.lua (lua5.1 tests/run.lua removed), which passes its helpers in.
]]

local T = ...
local eq, login, finish, openEverything, root = T.eq, T.login, T.finish, T.openEverything, T.root
local ns

-- Saved by 1.1.1 (layout 4), with Status Text and Mute Error Speech, removed in 1.2.0, View
-- Distance & Detail, removed in 1.4.0, and (as if updated since) modules removed in 1.6.0, Vendor
-- with Autobuy off but Repair on, and Quest Items with only its tooltip lines on.
local GONE_1_6 = { "ErrorCatcher", "GameTweaks", "WorldMap", "UpgradeArrows", "NameplateQuests", "GatherTracking",
    "Durability", "MacroDrawer", "PetFood", "ErrorMessages", "CastBar", "FiveSecondRule", "CursorGlow",
    "RangeIndicator", "TargetCombat", "RotateMinimap" }
ForeverTweaksDB = {
    version = 4, installed = "1.0.0",
    settings = {
        StatusText = { enabled = true, display = "PERCENT" },
        MuteErrorSpeech = { enabled = true },
        ViewDistance = { enabled = true, farclip = 7000 },
        Performance = { latency = "home" },
        CastBar = { scaleOn = true, scale = 1.5 },
        GameTweaks = { enabled = true },
        RotateMinimap = { enabled = true },
        Vendor = { enabled = true, autobuy = false, repair = true, guildRepair = false, sellJunk = true },
        QuestItems = { enabled = true, tooltip = true, withQuestie = true, markNeeded = false, markStarts = false,
            markLeftover = false },
    },
    data = {
        StatusText = { saved = { statusText = "0" } },
        MuteErrorSpeech = { saved = { Sound_EnableErrorSpeech = "1" } },
        ViewDistance = { saved = { farclip = "1000" } },
        ErrorCatcher = { errors = { { message = "old" } } },
        GameTweaks = { saved = { cameraDistanceMaxZoomFactor = "2.0" } },
    },
    seenModules = { StatusText = "1.1.1", MuteErrorSpeech = "1.1.1", ViewDistance = "1.1.1", Performance = "1.1.1" },
}
W.cvars.statusText, W.cvars.statusTextDisplay, W.cvars.Sound_EnableErrorSpeech = "1", "PERCENT", "0"
W.cvars.farclip = "7000" -- what View Distance had set
W.cvars.cameraDistanceMaxZoomFactor = "2.6" -- what Game Tweaks had set
W.cvars.rotateMinimap = "1" -- what Rotate Minimap had set
ForeverTweaksCharDB = { data = { GatherTracking = { tracked = { 2383 } }, Vendor = { buy = { [2512] = 1000 } } } }
W.Strict()
ns = W.LoadAddon(root, "ForeverTweaks")
login()
local db = ForeverTweaksDB
eq(db.version, ns.member.layout, "layout version")
for _, name in ipairs({ "StatusText", "MuteErrorSpeech", "ViewDistance" }) do
    eq(db.settings[name], nil, name .. " settings gone")
    eq(db.data[name], nil, name .. " data gone")
    eq(db.seenModules[name], nil, name .. " seen gone")
end
for _, name in ipairs(GONE_1_6) do
    eq(db.settings[name], nil, name .. " settings gone")
    eq(db.data[name], nil, name .. " data gone")
end
eq(ForeverTweaksCharDB.data.GatherTracking, nil, "a removed module's character data gone")
eq(ns.modules.Vendor.db.buy[2512], 1000, "Autobuy's list kept")
eq(ns.modules.Vendor.db.enabled, false, "Autobuy was off: Vendor is off")
eq(db.settings.Vendor.repair, nil, "Repair's setting gone")
eq(db.settings.Vendor.sellJunk, nil, "Sell Junk's setting gone")
eq(ns.modules.QuestItems.db.enabled, false, "Quest Items had only its tooltip lines on: off")
eq(db.settings.QuestItems.tooltip, nil, "its tooltip setting gone")
eq(W.cvars.cameraDistanceMaxZoomFactor, "2.6", "Game Tweaks' CVar left as the player has it")
eq(W.cvars.rotateMinimap, "1", "the minimap keeps turning")
eq(ns.modules.Performance.db.latency, "home", "other modules' settings kept")
eq(db.seenModules.Performance, "1.1.1", "other modules' seen kept")
eq(W.cvars.statusText, "1", "Status Text CVar left as the player had it")
eq(W.cvars.statusTextDisplay, "PERCENT", "Status Text display left as the player had it")
eq(W.cvars.Sound_EnableErrorSpeech, "0", "Error Speech left as the player had it")
eq(W.cvars.farclip, "7000", "View Distance left as the player had it")
openEverything(ns)
finish()
