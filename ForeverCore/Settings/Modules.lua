--[[
    Forever Core - Settings/Modules.lua
    Settings > AddOns > Forever. The top page is Settings (Settings/General.lua: the suite's own
    settings and every "settings" module). Under it, one Modules page per member addon (Tweaks,
    Compendium: Settings/ModulesPage.lua), each member's own pages (ns:AddSettingsPage: Tweaks
    for Addons), About (Settings/About.lua), Debug and Changelog. This file registers them,
    redraws a member's page when one of its modules' settings change, and opens the page a
    module is on.
]]

local _, ns = ...
local Kit, ModulesPage, L = ns.Kit, ns.ModulesPage, ns.L

local ipairs = ipairs

local top               -- the top page's Settings category (Settings), once registered
local categories = {}   -- member name -> its Modules page's category
local pageCategories = {} -- a member page (ns:AddSettingsPage) -> its category
local modulesPages = {} -- member name -> its Modules page's controller (Settings/ModulesPage.lua)

ns:OnChanged(Kit.owner, function(_, name)
    local mod = ns.modules[name]
    local controller = mod and modulesPages[mod.member.name]
    if controller and SettingsPanel:IsShown() then controller.Changed(name) end
end)

---------------------------------------------------------------------------
-- Registration and opening
---------------------------------------------------------------------------

function ns:RegisterSettings()
    for _, name in ipairs(ns.order) do ModulesPage.Index(ns.modules[name]) end
    top = Settings.RegisterCanvasLayoutCategory(Kit.CanvasFrame(ns.BuildGeneralPage), ns.title)
    for _, member in ipairs(ns.members) do
        local controller = ModulesPage.New(member)
        if member ~= ns.member and controller.Group() then
            modulesPages[member.name] = controller
            categories[member.name] = Settings.RegisterCanvasLayoutSubcategory(top, controller.Frame(), member.short)
        end
        for _, page in ipairs(member.pages) do
            pageCategories[page] = Settings.RegisterCanvasLayoutSubcategory(top, Kit.CanvasFrame(page.build), page.label)
        end
    end
    Settings.RegisterCanvasLayoutSubcategory(top, Kit.CanvasFrame(ns.BuildAboutPage), L.ABOUT)
    Settings.RegisterCanvasLayoutSubcategory(top, Kit.CanvasFrame(ns.BuildDebugPage), L.DEBUG)
    Settings.RegisterCanvasLayoutSubcategory(top, Kit.CanvasFrame(ns.BuildChangelogPage), L.CHANGELOG)
    Settings.RegisterAddOnCategory(top)
end

-- Opens the page module `name` is on, with it selected: its member's Modules page, the
-- Settings page for the "settings" modules, or the member's own page for its category (Tweaks
-- for Addons). Without a name, the Settings page. Core and the modules call it only once
-- everything has loaded (this file loads before any module).
function ns:OpenSettings(name)
    if not top then return end
    local mod = name and ns.modules[name]
    if not mod or ns:CategoryOf(mod) == "settings" then return Kit.Open(top) end
    local page = ns:PageOf(mod)
    if page then return Kit.Open(pageCategories[page]) end
    local controller = modulesPages[mod.member.name]
    if not controller then return Kit.Open(top) end
    controller.Select(name)
    Kit.Open(categories[mod.member.name])
end

-- Opens member's Modules page (the Settings page for the core, or a member without modules).
function ns:OpenMember(member)
    if not top then return end
    local category = categories[member.name]
    Kit.Open(category or top)
end
