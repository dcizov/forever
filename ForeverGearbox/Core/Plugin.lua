--[[
    Forever Gearbox - Core/Plugin.lua
    Forever Gearbox is an addon of its own: its settings in ForeverGearboxDB, its own entry in
    Settings > AddOns (Settings/Alone.lua), its modules turned on and off there, with Forever++
    installed or not. Forever++ is touched only while Forever++ Integration is on (a module of
    its own, off by default, offered while Forever++ is loaded: Modules/Addons/ForeverPlusPlus.lua):

      * Upgrade Arrows in Baganator judges gear by Forever++'s Upgrade Arrows instead of its own.
      * Quest Markers, Fishing and Upgrade Arrows in Baganator are also a "Forever Gearbox"
        section on the page of the Forever++ module they go with (Core/Attach.lua,
        UI/ForeverPage.lua), and Quest Markers hides Forever++'s own nameplate mark.
      * Advanced Graphics is listed under Forever++ in Settings too (VisualsPage.lua).
      * A console variable a module asks for gets a button finding it in Forever++'s Console
        Variables, and what other modules ask of Forever++ (Lib/OtherAddons.lua) is answered.
    Plugin.Integrated() says whether all that is on now.

    Until 3.3.0 Forever Gearbox was a Forever++ plugin whose settings lived in Forever++'s
    profiles: Plugin.TakeOver brings those of the profile this character uses back once
    (Migrations.lua), and Plugin.SettleAlone the 1.x settings Migrations.lua kept for Forever++.
]]

local addonName, ns = ...

local ipairs, pairs, type = ipairs, pairs, type

local Plugin = {}
ns.Plugin = Plugin

local PREFIX = addonName              -- Forever++ module names were "ForeverGearbox<Name>"
local FORMER_PREFIX = "ForeverTweaks" -- and "ForeverTweaks<Name>" before 3.3.0

-- Whether Forever++ is loaded (its API answers).
function Plugin.Loaded()
    local fpp = _G.ForeverPlusPlusAPI
    return type(fpp) == "table" and type(fpp.v1) == "table"
end

-- Whether Forever++ Integration is on (and Forever++ there).
-- function Plugin.Integrated()
--     local mod = ns.modules.ForeverPlusPlus
--     return Plugin.Loaded() and mod ~= nil and mod.active and true or false
-- end

function Plugin.Integrated()
    local mod = ns.modules.ForeverPlusPlus
    return Plugin.Loaded() and mod ~= nil and mod.active and true or false
end

-- Whether `value` can be module `mod`'s setting `key` (its option's choices and range).
function Plugin.Fits(mod, key, value)
    local default = mod.defaults[key]
    if key == "enabled" then return type(value) == "boolean" end
    if default == nil or type(default) == "table" or type(value) ~= type(default) then return false end
    for _, option in ipairs(mod.options) do
        if option.key == key then return ns.Options.Fits(option, value) end
    end
    return true
end

-- Puts `from`'s fitting values into module `mod`'s settings where it has none.
local function fill(mod, from)
    local settings = mod.settings
    if not (settings and type(from) == "table") then return end
    for key, value in pairs(from) do
        if settings[key] == nil and Plugin.Fits(mod, key, value) then settings[key] = value end
    end
end

-- The 1.x settings Migrations.lua kept aside for Forever++ (movedSettings) and each module's
-- on/off then (enabledDefaults) are the module's own settings instead, where it has none.
function Plugin.SettleAlone(db)
    local moved, enabled = db.movedSettings or {}, db.enabledDefaults or {}
    for _, name in ipairs(ns.order) do
        local mod = ns.modules[name]
        fill(mod, moved[name])
        if mod.settings and mod.settings.enabled == nil and type(enabled[name]) == "boolean" then
            mod.settings.enabled = enabled[name]
        end
    end
    db.movedSettings, db.enabledDefaults = nil, nil
end

-- What Forever++ kept for each of our modules while Forever Gearbox was its plugin, in the
-- profile this character uses (ForeverPlusPlusCharDB.profile; Default is the account's own).
function Plugin.TakeOver()
    local fpp, char = _G.ForeverPlusPlusDB, _G.ForeverPlusPlusCharDB
    if type(fpp) ~= "table" then return end
    local id = type(char) == "table" and char.profile or nil
    local profile = id and type(fpp.profiles) == "table" and fpp.profiles[id] or fpp
    local saved = type(profile) == "table" and type(profile.settings) == "table" and profile.settings or {}
    for _, name in ipairs(ns.order) do
        local mod = ns.modules[name]
        fill(mod, saved[PREFIX .. name])
        fill(mod, saved[FORMER_PREFIX .. name])
    end
end
