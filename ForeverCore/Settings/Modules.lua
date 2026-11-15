--[[
    Forever Core - Settings/Modules.lua
    The suite's settings pages, shown in the Forever window (Settings/Window.lua): Settings
    (Settings/General.lua: the suite's own settings and every "settings" module), one Modules
    page per member addon (Tweaks, Compendium: Settings/ModulesPage.lua), each member's own pages
    (ns:AddSettingsPage: Tweaks for Addons), About (Settings/About.lua), Debug and Changelog.
    Settings > AddOns > Forever is a short page whose button opens the window. This file makes
    the pages, redraws a member's page when one of its modules' settings change, and opens the
    page a module is on.
]]

local _, ns = ...
local Kit, ModulesPage, L = ns.Kit, ns.ModulesPage, ns.L

local ipairs = ipairs

local Window = ns.SettingsWindow

local registered        -- the pages are made (ns:RegisterSettings ran)
local memberPages = {}  -- member name -> its Modules page's key in the window
local pageKeys = {}     -- a member page (ns:AddSettingsPage) -> its key in the window
local modulesPages = {} -- member name -> its Modules page's controller (Settings/ModulesPage.lua)

ns:OnChanged(Kit.owner, function(_, name)
    local mod = ns.modules[name]
    local controller = mod and modulesPages[mod.member.name]
    if controller and Window.IsShown() then controller.Changed(name) end
end)

-- Settings > AddOns > Forever: what the suite is and a button opening its window.
local function buildLauncher(frame)
    local stack = Kit.NewRowPage(frame, ns.title)
    Kit.AddTextRow(stack, L.LAUNCHER_TEXT)
    Kit.AddButtonRow(stack, L.LAUNCHER_OPEN, L.OPEN, function()
        HideUIPanel(SettingsPanel)
        Window.Open()
    end, L.LAUNCHER_OPEN_TIP)
    Kit.Layout(stack)
end

---------------------------------------------------------------------------
-- Registration and opening
---------------------------------------------------------------------------

-- Pages are keyed by their label (ns.title for Settings).
function ns:RegisterSettings()
    for _, name in ipairs(ns.order) do ModulesPage.Index(ns.modules[name]) end
    Window.AddPage(ns.title, L.SETTINGS, Kit.CanvasFrame(ns.BuildGeneralPage))
    for _, member in ipairs(ns.members) do
        local controller = ModulesPage.New(member)
        if member ~= ns.member and controller.Group() then
            modulesPages[member.name] = controller
            memberPages[member.name] = member.short
            Window.AddPage(member.short, member.short, controller.Frame())
        end
        for _, page in ipairs(member.pages) do
            pageKeys[page] = page.label
            Window.AddPage(page.label, page.label, Kit.CanvasFrame(page.build))
        end
    end
    Window.AddPage(L.ABOUT, L.ABOUT, Kit.CanvasFrame(ns.BuildAboutPage))
    Window.AddPage(L.DEBUG, L.DEBUG, Kit.CanvasFrame(ns.BuildDebugPage))
    Window.AddPage(L.CHANGELOG, L.CHANGELOG, Kit.CanvasFrame(ns.BuildChangelogPage))
    Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(Kit.CanvasFrame(buildLauncher), ns.title))
    registered = true
end

-- Opens the window on page `key` (the Settings page without one).
function ns:OpenPage(key)
    if registered then Window.Open(key or ns.title) end
end

-- Opens the page module `name` is on, with it selected: its member's Modules page, the
-- Settings page for the "settings" modules, or the member's own page for its category (Tweaks
-- for Addons). Without a name, the Settings page. Core and the modules call it only once
-- everything has loaded (this file loads before any module).
-- The key binding (Core/Bindings.lua) opens the Settings page.
ns:AddBinding(nil, "FOREVER_SETTINGS", function() ns:OpenSettings() end)

function ns:OpenSettings(name)
    if not registered then return end
    local mod = name and ns.modules[name]
    if not mod or ns:CategoryOf(mod) == "settings" then return ns:OpenPage() end
    local page = ns:PageOf(mod)
    if page then return ns:OpenPage(pageKeys[page]) end
    local controller = modulesPages[mod.member.name]
    if not controller then return ns:OpenPage() end
    controller.Select(name)
    ns:OpenPage(memberPages[mod.member.name])
end

-- Opens member's Modules page (the Settings page for the core, or a member without modules).
function ns:OpenMember(member)
    ns:OpenPage(memberPages[member.name])
end
