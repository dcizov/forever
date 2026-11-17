--[[
    Forever Gearbox - Settings/Alone.lua
    Forever Gearbox' own entry in Settings > AddOns (with Forever++ installed or not), in Forever++'s
    look and no window of its own: the Modules page
    (Settings/AlonePage.lua) and, under it while the module is on, Advanced Graphics
    (Modules/Interface/VisualsPage.lua). Made at login (Init.lua). /fg, its subcommands and the
    modules' Settings buttons open it here (ns:OpenSettings, ns:OpenMember).
]]

local _, ns = ...

local Kit = ns.Kit

local category -- the entry, once made

function ns:RegisterSettings()
    category = Settings.RegisterCanvasLayoutCategory(ns.AlonePage.Frame(), ns.title)
    ns.VisualsPage.UseHost(category, 0)
    Settings.RegisterAddOnCategory(category)
end

-- Opens the entry on module `name` (or on the module shown last).
function ns:OpenSettings(name)
    if not category then return end
    if name and ns.modules[name] then ns.AlonePage.Select(name) end
    Kit.Open(category)
end

function ns:OpenMember() ns:OpenSettings() end
