--[[
    Forever Tweaks - Core/Migrations.lua
    The steps that bring an older layout of Forever Tweaks' saved variables (ForeverTweaksDB,
    ForeverTweaksCharDB) up to date: Part.lua's layout and charLayout are the newest. How steps
    run is in Forever Core's Core/Store.lua. A step reads only the saved tables and what it's
    written with, never the modules as they are now: it must do the same thing in every later
    release.
]]

local _, ns = ...

local pairs, ipairs, type = pairs, ipairs, type

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

-- 2.0.0 split the suite: Forever Core keeps the addon's own settings (Mute All Chat Messages,
-- Show Log in Chat) and the Minimap Button and Update Notice, which moved there. What Forever
-- Tweaks kept for them goes into Forever Core's table, where it isn't set there already.
local MOVED = { "MinimapButton", "Updates" }

local function fill(into, from)
    for key, value in pairs(from) do
        if into[key] == nil then into[key] = value end
    end
end

ns:Migrate(10, function(db, coreDB)
    for _, key in ipairs({ "quiet", "debug" }) do
        if coreDB[key] == nil then coreDB[key] = db[key] end
        db[key] = nil
    end
    for _, name in ipairs(MOVED) do
        for _, kind in ipairs({ "settings", "data" }) do
            local old = db[kind] and db[kind][name]
            if type(old) == "table" then fill(child(child(coreDB, kind), name), old) end
        end
        if db.seenModules and db.seenModules[name] then
            child(coreDB, "seenModules")[name] = db.seenModules[name]
        end
    end
    forgetModules(db, MOVED)
end)

-- 2.1.0 removed the Forever Bestiary module: Forever Compendium does what Forever Bestiary did.
-- Bestiary's own settings stay as the player left them; only what this addon kept for it goes.
ns:Migrate(11, function(db) forgetModules(db, { "Bestiary" }) end)
