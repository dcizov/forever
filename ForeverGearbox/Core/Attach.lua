--[[
    Forever Gearbox - Core/Attach.lua
    A module that goes with one of Forever++'s own (`attach = "<Forever++ module>"`: Quest Markers
    with Quest Nameplates, Fishing with Fishing Cast, Upgrade Arrows in Baganator with Upgrade
    Arrows) is a module of Forever Gearbox' like any other: its own on/off and settings. While
    Forever++ Integration is on (Core/Plugin.lua) it's also a "Forever Gearbox" section on that
    module's page in Forever++'s Settings (UI/ForeverPage.lua).
]]

local _, ns = ...

local ipairs = ipairs

local Attach = {}
ns.Attach = Attach

local function api()
    local fpp = _G.ForeverPlusPlusAPI
    return fpp and fpp.v1
end

-- The Forever++ module `mod` goes with, while Forever++ Integration is on and Forever++ has it; else nil.
function Attach.Target(mod)
    local name, fpp = mod and mod.attach, api()
    if not (name and fpp and ns.Plugin.Integrated()) then return nil end
    return fpp.IsModuleEnabled(name) ~= nil and name or nil
end

-- The modules that go with Forever++ module `target`, in load order.
function Attach.On(target)
    local list = {}
    for _, name in ipairs(ns.order) do
        local mod = ns.modules[name]
        if Attach.Target(mod) == target then list[#list + 1] = mod end
    end
    return list
end

-- Whether its addon (`addon`) is there, when it names one.
function Attach.Available(mod)
    return not mod.addon or ns.OtherAddons.Loaded(mod.addon)
end
