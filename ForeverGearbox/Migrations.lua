--[[
    Forever Gearbox - Migrations.lua
    The steps that bring an older layout of Forever Gearbox' saved variables (ForeverGearboxDB,
    ForeverGearboxCharDB; ForeverTweaksDB and ForeverTweaksCharDB until 3.3.0, taken over as they are
    by Store.Init before these run) up to date: Part.lua's layout and charLayout are the newest. How steps
    run is in Shared/Core/Store.lua. A step reads only the saved tables and what it's
    written with, never the modules as they are now: it must do the same thing in every later
    release.
]]

local _, ns = ...

local pairs, ipairs, type, next, tonumber = pairs, ipairs, type, next, tonumber
local match = string.match

-- 0.1 to 0.9 kept each module's table flat in db.modules (settings and data together), and
-- 0.5 to 0.9 dropped values equal to their default (db.layout 2 and 3). Split them, keeping
-- only keys the module still has, by the schema below. Error Speech became Mute Error Speech (a
-- new name, so its old setting is left behind on purpose); Console Variables is gone. (Status
-- Text is left out too: step 5 removes it.)
local SCHEMA_4 = { -- module -> key -> the type of its setting, or "data"
    ViewDistance = { enabled = "boolean", farclip = "number", groundEffectDensity = "number",
        lodObjectCullSize = "number", lodObjectFadeScale = "number", ResampleAlwaysSharpen = "boolean",
        saved = "data" },
    Performance = { enabled = "boolean", fps = "boolean", latency = "string", colors = "boolean",
        size = "number", outline = "boolean", x = "number", y = "number" },
    LayerInfo = { enabled = "boolean", chat = "boolean", size = "number", outline = "boolean",
        x = "number", y = "number" },
    ButtonBag = { enabled = "boolean", columns = "number", autoHide = "boolean", closeDelay = "number",
        icon = "string", angle = "number", ignored = "data" },
    MinimapButton = { enabled = "boolean", where = "string", angle = "number" },
    RotateMinimap = { enabled = "boolean", saved = "data" },
}

ns:Migrate(4, function(db)
    local old = db.modules
    db.settings, db.data = db.settings or {}, db.data or {}
    for name, saved in pairs(old or {}) do
        local schema = SCHEMA_4[name]
        if schema and type(saved) == "table" then
            local settings, data = {}, {}
            for key, value in pairs(saved) do
                local kind = schema[key]
                if kind == "data" then
                    if type(value) == "table" then data[key] = value end
                elseif kind ~= nil and type(value) == kind then
                    settings[key] = value
                end
            end
            db.settings[name], db.data[name] = settings, data
        end
    end
    db.modules, db.layout = nil, nil
    -- Someone updating from before 1.0.0: what's new since then gets a NEW label.
    db.installed = db.installed or "0.9.0"
end)

-- What the addon kept for modules that were removed: their settings, data and NEW-label marks.
-- (Only what's saved is read, so a step calling it does the same in every release.)
local function forgetModules(db, names)
    for _, name in ipairs(names) do
        if db.settings then db.settings[name] = nil end
        if db.data then db.data[name] = nil end
        if db.seenModules then db.seenModules[name] = nil end
    end
end

-- 1.2.0 removed Status Text and Mute Error Speech: the game's own Options set both. Their
-- console variables stay as the player left them; only what the addon kept for them goes.
ns:Migrate(5, function(db) forgetModules(db, { "StatusText", "MuteErrorSpeech" }) end)

-- 1.3.0 moved the Error Catcher's session number from the core's own keys into its data. The
-- Error Catcher is gone (step 8 forgets its data), so only the old key is dropped.
ns:Migrate(6, function(db) db.errorSession = nil end)

-- 1.4.0 removed View Distance & Detail: the game's Graphics options and other addons' console
-- variable editors set the same values. Its console variables stay as the player has them now;
-- only what the addon kept for it goes. (MapZoom only ever existed in a test build.)
ns:Migrate(7, function(db) forgetModules(db, { "ViewDistance", "MapZoom" }) end)

-- 1.6.0 removed what the player's other addons already do (Forever++, WilduTools, Plumber, OpenMap,
-- Pawn, Questie, BugSack), Rotate Minimap included (Forever++'s Console Variables sets it). Console variables stay as the player has them. Vendor kept only
-- Autobuy, so its Autobuy checkbox becomes whether the module is on; Quest Items lost its tooltip
-- lines, and is off when none of its marks is left ticked.
ns:Migrate(8, function(db)
    forgetModules(db, { "ErrorCatcher", "GameTweaks", "WorldMap", "UpgradeArrows", "NameplateQuests",
        "GatherTracking", "Durability", "MacroDrawer", "PetFood", "ErrorMessages", "CastBar", "FiveSecondRule",
        "CursorGlow", "RangeIndicator", "TargetCombat", "RotateMinimap" })
    local vendor = db.settings and db.settings.Vendor
    if vendor then
        if vendor.autobuy == false then vendor.enabled = false elseif vendor.autobuy then vendor.enabled = nil end
        vendor.autobuy, vendor.repair, vendor.guildRepair, vendor.sellJunk = nil, nil, nil, nil
    end
    local items = db.settings and db.settings.QuestItems
    if items then
        if items.markNeeded == false and items.markStarts == false and items.markLeftover == false then
            items.enabled = false
        end
        items.tooltip, items.withQuestie = nil, nil
    end
end)

-- 1.8.1 folded Profession Outfits into Fishing as its Fishing Outfit: Combat Weapons moves with
-- it (off if the module was off). Which outfit a character has on is character data: character
-- step 1 below moves it.
ns:Migrate(9, function(db)
    local old = db.settings and db.settings.ProfessionOutfits
    if old then
        local combat = old.combatWeapons
        if old.enabled == false then combat = false end
        if combat ~= nil then
            db.settings.Fishing = db.settings.Fishing or {}
            db.settings.Fishing.combatWeapons = combat
        end
    end
    forgetModules(db, { "ProfessionOutfits" })
end)

-- A table that t[key] holds, made when it isn't one.
local function child(t, key)
    local value = t[key]
    if type(value) ~= "table" then
        value = {}
        t[key] = value
    end
    return value
end

-- Character 1 (1.8.1): Profession Outfits' character data (which outfit is on) is Fishing's when
-- that outfit was Fishing's (skill line 356); another profession's outfit has no Fishing state.
ns:MigrateChar(1, function(charDB)
    local data = charDB.data
    local outfits = data and data.ProfessionOutfits
    if type(outfits) == "table" and type(outfits.state) == "table" and outfits.state.wearing == 356 then
        local fishing = child(data, "Fishing")
        fishing.state = fishing.state or outfits.state
    end
end)

-- 2.0.0 split the suite: Forever Core kept the addon's own settings (Mute All Chat Messages,
-- Show Log in Chat) and the Minimap Button and Update Notice, which moved there.
local MOVED = { "MinimapButton", "Updates" }

-- (3.0.0: Forever Compendium has the minimap button and the Update Notice now, and reads
-- ForeverCoreDB itself; this step only forgets them here.)
ns:Migrate(10, function(db)
    db.quiet, db.debug = nil, nil
    forgetModules(db, MOVED)
end)

-- 2.1.0 removed the Forever Bestiary module: Forever Compendium does what Forever Bestiary did.
-- Bestiary's own settings stay as the player left them; only what this addon kept for it goes.
ns:Migrate(11, function(db) forgetModules(db, { "Bestiary" }) end)

-- 2.4.0 keeps what disenchanting showed as { n, items = { [id] = { times, low, high } } } per
-- bracket, not each material as a "times:min:max" string beside n. A bracket or material that
-- doesn't read is dropped: it's learned again from the next disenchant.
ns:Migrate(12, function(db)
    local data = db.data and db.data.ItemTooltips
    local old = data and data.disenchanted
    if type(old) ~= "table" then return end
    local new = {}
    for key, tally in pairs(old) do
        local n = type(tally) == "table" and tonumber(tally.n)
        if n and n >= 1 then
            local items = {}
            for id, text in pairs(tally) do
                local times, low, high = match(type(text) == "string" and text or "", "^(%d+):(%d+):(%d+)$")
                if type(id) == "number" and times then
                    items[id] = { times = tonumber(times), low = tonumber(low), high = tonumber(high) }
                end
            end
            if next(items) then new[key] = { n = n, items = items } end
        end
    end
    data.disenchanted = new
end)

-- 2.6.0 removed the Fishing Outfit (Combat Weapons with it) and Quest Nameplates' green check
-- for a finished creature (Keep a Check When Done): their settings go. Character step 2 below
-- takes which outfit was on.
ns:Migrate(13, function(db)
    local settings = db.settings
    if type(settings) ~= "table" then return end
    if type(settings.Fishing) == "table" then settings.Fishing.combatWeapons = nil end
    if type(settings.QuestNameplates) == "table" then settings.QuestNameplates.completed = nil end
end)

-- Character 2 (2.6.0): the Fishing Outfit's state (which outfit is on) goes with it.
ns:MigrateChar(2, function(charDB)
    local fishing = type(charDB.data) == "table" and charDB.data.Fishing
    if type(fishing) == "table" then fishing.state = nil end
end)

-- 3.0.0 made Forever Tweaks a Forever++ companion. The modules Forever++ has too are gone (it
-- always has them now), and Forever++ keeps the rest's on/off and settings in its profiles:
-- the settings are kept aside (movedSettings) until Forever++ has loaded its own, then moved
-- into them (Core/Plugin.lua); each module's on/off becomes the default Forever++ is told of
-- (enabledDefaults), since only the player can switch a module there. Combat Error Filter went to
-- Forever++'s Hide Error Messages, Rotate Minimap (again, as in 1.6.0) to its Console Variables
-- (rotateMinimap, which it can lock); the console variable stays as the player has it. New in
-- Forever, Object Names, Threat and Gathering Session went too (Forever++'s Forever Quest Icons,
-- Plumber's object names, and Forever++'s own gathering and tooltips cover what's left of them).
local FORMER_3 = { "ChatArrowKeys", "ChatFont", "ChatHistory", "ChatLevels", "QuestLinks", "ShortChannelNames",
    "SocialButton", "ChatStamps", "Tooltips", "ItemTooltips", "ProfessionTooltips", "ClassColors", "MovableWindows",
    "GatherMap", "QuestNameplates", "LootSparkle", "FishingCast", "DurabilityWarning", "Repair", "GatheringTracking",
    "CombatErrors", "RotateMinimap", "ForeverMarks", "ObjectNames", "Threat", "GatherSession" }

ns:Migrate(14, function(db)
    forgetModules(db, FORMER_3)
    local enabled = {}
    for name, settings in pairs(db.settings or {}) do
        if type(settings) == "table" and type(settings.enabled) == "boolean" then enabled[name] = settings.enabled end
    end
    db.enabledDefaults = enabled
    db.movedSettings = db.settings
    db.settings = nil
end)

-- 3.3.0 split Chat Window (ChatFade) into Hide Chat Tabs, Hide Chat Input and Fade Chat Messages
-- (ChatFade's key stays with the messages) and dropped its Show Buttons: Forever++'s Hide Chat
-- Buttons does that. Its settings are in Forever++'s profiles (every one of them), under the name
-- Forever++ had for it then; Forever++ reads them only at PLAYER_LOGIN, after this, so they're
-- split here, under the names of that time too, which Forever++'s plugins list learns, for
-- Core/Plugin.lua's oldNames to carry over with the rest. Show Tabs Always and Show Input Box
-- Always were the game's own look: the new module is off. Fade Messages becomes whether Fade Chat
-- Messages is on.
local OLD_PREFIX = "ForeverTweaks"

local function splitChatWindow(byName)
    local old = type(byName) == "table" and byName[OLD_PREFIX .. "ChatFade"]
    if type(old) ~= "table" then return end
    local off = old.enabled == false
    local tabs = { never = old.tabs == "never" or nil }
    if off or old.tabs == "always" then tabs.enabled = false end
    if type(old.tabsFaded) == "number" then tabs.faded = old.tabsFaded end
    local input = { show = old.input == "hover" and "hover" or nil }
    if off or old.input == "always" then input.enabled = false end
    if type(old.hideDelay) == "number" then input.hideDelay = old.hideDelay end
    byName[OLD_PREFIX .. "ChatTabs"] = byName[OLD_PREFIX .. "ChatTabs"] or tabs
    byName[OLD_PREFIX .. "ChatInput"] = byName[OLD_PREFIX .. "ChatInput"] or input
    byName[OLD_PREFIX .. "ChatFade"] = { enabled = not off and old.messages == true,
        messageTime = type(old.messageTime) == "number" and old.messageTime or nil }
end

ns:Migrate(15, function()
    local fpp = _G.ForeverPlusPlusDB
    if type(fpp) ~= "table" then return end
    splitChatWindow(fpp.settings)
    for _, profile in pairs(type(fpp.profiles) == "table" and fpp.profiles or {}) do
        if type(profile) == "table" then splitChatWindow(profile.settings) end
    end
    if type(fpp.plugins) == "table" and fpp.plugins[OLD_PREFIX .. "ChatFade"] then
        fpp.plugins[OLD_PREFIX .. "ChatTabs"], fpp.plugins[OLD_PREFIX .. "ChatInput"] = true, true
    end
end)

-- 3.3.0 took Loot Sparkles out of Visuals (now Advanced Graphics): Forever++'s Quest Item Sparkles
-- does it. Protect Values would otherwise keep putting back the sparkle and the Outline Mode it
-- set with it, so they go from what it keeps; the console variables stay as they are now.
local SPARKLES = { "outlineModeShowLootEffectWhenDisabled", "graphicsOutlineMode", "OutlineEngineMode",
    "raidGraphicsOutlineMode", "RAIDOutlineEngineMode" }

ns:Migrate(16, function(db)
    local visuals = type(db.data) == "table" and db.data.Visuals
    if type(visuals) ~= "table" then return end
    for _, part in ipairs({ "values", "original" }) do
        local kept = visuals[part]
        if type(kept) == "table" then
            for _, cvar in ipairs(SPARKLES) do kept[cvar] = nil end
        end
    end
end)

-- 3.3.0 took out what was ported from Forever++ for Forever Gearbox on its own: Hide Chat Buttons,
-- and Upgrade Arrows in Baganator's own Show Downgrades and Percentage (it follows Forever++'s
-- Upgrade Arrows, and is there only with Forever++). What they kept goes.
ns:Migrate(17, function(db)
    local settings = type(db.settings) == "table" and db.settings
    if not settings then return end
    settings.HideChatButtons = nil
    local arrows = settings.BaganatorUpgrades
    if type(arrows) == "table" then arrows.downgrades, arrows.percent = nil, nil end
end)

-- 3.3.0 also removed Map Pan & Zoom, Melee Range and Keep Windows Open (the user's call). What
-- they kept goes; Blizzard's map and windows are as the game has them again after a reload.
ns:Migrate(18, function(db) forgetModules(db, { "MapPanZoom", "MeleeRange", "KeepWindowsOpen" }) end)

-- 3.3.0 also removed the Tracker and Dialogue Keys (the user's call). What they kept goes; quests
-- the Tracker untracked stay as they are (track them again in the quest log).
ns:Migrate(19, function(db) forgetModules(db, { "Tracker", "DialogueKeys" }) end)

-- 3.3.0 made Forever Gearbox an addon of its own again: what Forever++ kept for its modules while
-- they were its plugin modules is taken back once, from the profile the character logging in uses
-- (Init.lua, Core/Plugin.lua's TakeOver: the modules have their settings then).
ns:Migrate(20, function(db) db.takeOverFpp = true end)

-- 3.3.0 sky gradient decoupling: the static alpha was folded into a dedicated intensity slider and
-- the night-only gate moved to its own setting, so older saved values are carried over once.
ns:Migrate(21, function(db)
    local visuals = type(db.data) == "table" and db.data.Visuals
    if type(visuals) ~= "table" then return end
    if visuals.skyGradientIntensity == nil and visuals.skyGradientAlpha ~= nil then
        visuals.skyGradientIntensity = visuals.skyGradientAlpha
    end
    visuals.skyGradientAlpha = nil
    if visuals.skyNightOnly == nil then visuals.skyNightOnly = true end
end)
