--[[
    Forever Tweaks - API.lua
    The public API for other addons: ForeverTweaksAPI.v1. Since the suite split it covers every
    Forever addon's modules (Forever Core's Minimap Button and Update Notice, Forever Tweaks', and
    Forever Compendium's when it's loaded): module names are unique across the suite, and each
    row and module callback says which addon a module belongs to. Read-only: it never changes a module
    or an option (those are the player's), returns copies rather than our tables, and every call
    is wrapped so an error of ours returns nil (and is reported) instead of breaking the caller.
    v1 only grows: nothing is renamed, removed or changes meaning; a breaking change would be a
    v2 beside it.

      local api = ForeverTweaksAPI and ForeverTweaksAPI.v1
      api.GetVersion()                 -> "1.0.0"
      api.GetModules()                 -> { { name, title, category, enabled, addon }, ... } (addon: the
                                          Forever addon's folder, "ForeverTweaks", "ForeverCore", ...)
      api.IsModuleEnabled(name)        -> boolean: the player's on/off choice (a module whose start
                                          failed this session still reads true)
      api.GetOption(name, key)         -> value (tables are copied)
      api.GetLayer()                   -> zoneUID, novaWorldBuffsNumber, stale (nil while Layer Info is off)
      api.GetPerformance()             -> fps, localMs, worldMs (whether or not FPS & Latency is on:
                                          the game's own numbers, read when asked)
      api.GetErrorCount()              -> always nil since 1.6.0 (the Error Catcher was removed)
      api.RegisterCallback(event, fn)  -> true, or nil for an event not listed here; fn(event, ...) for:
          "READY"                         settings are loaded and modules started
          "MODULE_TOGGLED"  name, on, addon
          "OPTION_CHANGED"  name, key, value, addon: a setting changed. Only settings: the data tables
                            GetOption can also read (lists a module keeps) are a snapshot
                            when read, with no change event
          "LAYER_CHANGED"   zoneUID, novaWorldBuffsNumber: when the layer changes from one known
                            layer to another (the first reading of a session isn't a change:
                            call api.GetLayer() for it)
      api.UnregisterCallback(event, fn)
    A callback is another addon's code: it runs through OtherAddons.Call, so an error in it is
    logged (/forever debug) rather than reported as ours, and never stops the other callbacks.
]]

local _, ns = ...

local pairs, ipairs, type, next = pairs, ipairs, type, next

-- event -> { fn = true }. A set is replaced, never changed (copy on write), so fire() walks a
-- snapshot and a callback may register or unregister while it runs.
local callbacks = {}

local function copy(value)
    if type(value) ~= "table" then return value end
    local t = {}
    for k, v in pairs(value) do t[k] = copy(v) end
    return t
end

-- The events RegisterCallback takes (v1 only grows: a new one is added here when it ships).
local EVENTS = { READY = true, MODULE_TOGGLED = true, OPTION_CHANGED = true, LAYER_CHANGED = true }

-- Wrapped: an error of ours returns nil to the caller, and is reported like any other error of
-- ours (to the error handler, so BugSack or Forever++'s Error Catcher sees it).
local function export(fn)
    return function(...) return ns.SafeCall(fn, ...) end
end

local function fire(event, ...)
    for fn in pairs(callbacks[event] or {}) do ns.OtherAddons.Call(nil, "API callback " .. event, fn, event, ...) end
end

-- The addon's and modules' news (ns:Announce), passed on to the callbacks for it.
ns:OnNews({ name = "API" }, function(_, event, ...) fire(event, ...) end)

local v1 = {
    GetVersion = export(function() return ns.version end),
    GetModules = export(function()
        local list = {}
        for _, name in ipairs(ns.order) do
            local mod = ns.modules[name]
            list[#list + 1] = { name = name, title = mod.title, category = ns:CategoryOf(mod), enabled = mod.db.enabled,
                addon = mod.member.name }
        end
        return list
    end),
    IsModuleEnabled = export(function(name)
        local mod = ns.modules[name]
        return mod and mod.db.enabled or false
    end),
    GetOption = export(function(name, key)
        local mod = ns.modules[name]
        return mod and copy(mod.db[key])
    end),
    GetLayer = export(function() return ns.modules.LayerInfo:GetLayer() end),
    GetPerformance = export(function() return ns.modules.Performance:GetNumbers() end),
    -- The Error Catcher was removed in 1.6.0 (Forever++ and BugSack catch errors); kept, as the API
    -- is append-only, and always nil now: no count is known.
    GetErrorCount = export(function() return nil end),
    RegisterCallback = export(function(event, fn)
        if not EVENTS[event] or type(fn) ~= "function" then return end
        local set = copy(callbacks[event] or {})
        set[fn] = true
        callbacks[event] = set
        return true
    end),
    UnregisterCallback = export(function(event, fn)
        if not (callbacks[event] and callbacks[event][fn]) then return end
        local set = copy(callbacks[event])
        set[fn] = nil
        callbacks[event] = next(set) and set or nil
    end),
}

ForeverTweaksAPI = { v1 = v1 }

ns:OnChanged({ name = "API" }, function(_, name, key)
    local mod = ns.modules[name]
    if not mod then return end
    if key == "enabled" then
        fire("MODULE_TOGGLED", name, mod.db.enabled, mod.member.name)
    else
        fire("OPTION_CHANGED", name, key, copy(mod.db[key]), mod.member.name)
    end
end)
