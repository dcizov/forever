--[[
    Forever Gearbox - tests/scenarios/core/removed.lua
    What removed modules left behind is cleared; their CVars are left as the player had them.
    3.0.0's (the modules Forever++ has too) go the same way, and none of them is registered.
    Run by tests/run.lua (lua5.1 tests/run.lua removed), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root
local ns

-- Saved by 1.1.1 (layout 4), with Status Text and Mute Error Speech, removed in 1.2.0, View
-- Distance & Detail, removed in 1.4.0, and (as if updated since) modules removed in 1.6.0, Vendor
-- with Autobuy off but Repair on, and Quest Items with only its tooltip lines on.
local GONE_1_6 = { "ErrorCatcher", "GameTweaks", "WorldMap", "UpgradeArrows", "NameplateQuests", "GatherTracking",
    "Durability", "MacroDrawer", "PetFood", "ErrorMessages", "CastBar", "FiveSecondRule", "CursorGlow",
    "RangeIndicator", "TargetCombat", "RotateMinimap" }
ForeverGearboxDB = {
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
        ChatHistory = { enabled = true }, ClassColors = { enabled = true }, GatherMap = { minimap = false },
        CombatErrors = { enabled = true, range = false },
        -- Removed in 3.3.0 (step 18).
        MapPanZoom = { enabled = true, maxZoom = 6 }, MeleeRange = { combatOnly = true }, KeepWindowsOpen = { enabled = true },
        Tracker = { fadeCompleted = true }, DialogueKeys = { confirm = "space" },
    },
    data = {
        StatusText = { saved = { statusText = "0" } },
        MuteErrorSpeech = { saved = { Sound_EnableErrorSpeech = "1" } },
        ViewDistance = { saved = { farclip = "1000" } },
        ErrorCatcher = { errors = { { message = "old" } } },
        GameTweaks = { saved = { cameraDistanceMaxZoomFactor = "2.0" } },
        GatherMap = { nodes = { { 1, 2 } } }, ChatHistory = { lines = { "hello" } },
    },
    seenModules = { StatusText = "1.1.1", MuteErrorSpeech = "1.1.1", ViewDistance = "1.1.1", Performance = "1.1.1" },
}
W.cvars.statusText, W.cvars.statusTextDisplay, W.cvars.Sound_EnableErrorSpeech = "1", "PERCENT", "0"
W.cvars.farclip = "7000" -- what View Distance had set
W.cvars.cameraDistanceMaxZoomFactor = "2.6" -- what Game Gearbox had set
W.cvars.rotateMinimap = "1" -- what Rotate Minimap had set
ForeverGearboxCharDB = { data = { GatherTracking = { tracked = { 2383 } }, Vendor = { buy = { [2512] = 1000 } } } }
W.Strict()
ns = W.LoadAddon(root, "ForeverGearbox")
login()
local db = ForeverGearboxDB
eq(db.version, ns.member.layout, "layout version")
for _, name in ipairs({ "StatusText", "MuteErrorSpeech", "ViewDistance" }) do
    eq(db.settings[name], nil, name .. " settings gone")
    eq(db.data[name], nil, name .. " data gone")
    eq(db.seenModules[name], nil, name .. " seen gone")
end
for _, name in ipairs({ "MapPanZoom", "MeleeRange", "KeepWindowsOpen", "Tracker", "DialogueKeys" }) do
    eq(db.settings[name], nil, name .. " (3.3.0) settings gone")
    eq(ns.modules[name], nil, name .. " (3.3.0) not a module")
end
for _, name in ipairs(GONE_1_6) do
    eq((db.movedSettings or {})[name], nil, name .. " settings gone")
    eq(db.data[name], nil, name .. " data gone")
end
-- 3.0.0: the modules Forever++ has too (Rotate Minimap, back in 2.6.0, is its Console Variables'
-- rotateMinimap again; the console variable stays as the player has it).
eq(W.cvars.rotateMinimap, "1", "rotateMinimap left as it was")
for _, name in ipairs({ "ChatHistory", "ClassColors", "GatherMap", "RotateMinimap", "CombatErrors" }) do
    eq(db.data[name], nil, name .. " data gone")
    eq((db.enabledDefaults or {})[name], nil, name .. ": nothing told to Forever++")
    check(ns.modules[name] == nil and W.FPP.Module(name) == nil, name .. ": no module")
end
eq(ForeverGearboxCharDB.data.GatherTracking, nil, "a removed module's character data gone")
eq(ns.modules.Vendor.db.buy[2512], 1000, "Autobuy's list kept")
eq(ns.modules.Vendor.db.enabled, false, "Autobuy was off: Vendor is off")
local own = db.settings
eq(own.Vendor.repair, nil, "Repair's setting gone")
eq(own.Vendor.sellJunk, nil, "Sell Junk's setting gone")
eq(ns.modules.QuestItems.db.enabled, false, "Quest Items had only its tooltip lines on: off")
eq(own.QuestItems.tooltip, nil, "its tooltip setting gone")
eq(W.cvars.cameraDistanceMaxZoomFactor, "2.6", "Game Gearbox' CVar left as the player has it")
eq(W.cvars.rotateMinimap, "1", "the minimap keeps turning")
eq(ns.modules.Performance.db.latency, "home", "other modules' settings kept")
eq(db.seenModules.Performance, "1.1.1", "other modules' seen kept")
eq(W.cvars.statusText, "1", "Status Text CVar left as the player had it")
eq(W.cvars.statusTextDisplay, "PERCENT", "Status Text display left as the player had it")
eq(W.cvars.Sound_EnableErrorSpeech, "0", "Error Speech left as the player had it")
eq(W.cvars.farclip, "7000", "View Distance left as the player had it")
finish()
