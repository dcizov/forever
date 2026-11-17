--[[
    Forever Gearbox - UI/ForeverPage.lua
    While Forever++ Integration is on (Core/Plugin.lua): a "Forever Gearbox" section at the end of
    the page of each Forever++ module ours go with (Core/Attach.lua: Quest Markers on Quest
    Nameplates' page, Fishing on Fishing Cast's, Upgrade Arrows in Baganator on Upgrade Arrows'),
    the way OpenMap Tweaks heads its options in OpenMap's menu. Each is a checkbox row with its
    title (its own on/off, the same as on Forever Gearbox' own page), then its notices, options and
    buttons in Forever++'s own rows (UI/ForeverRows.lua), greyed while it's off.

    No Forever++ file is touched and nothing of its is called but GetModuleInfo: its Modules page
    is the frame it gives Blizzard's Settings (Settings.RegisterCanvasLayoutCategory, hooked as
    it's called at Forever++'s PLAYER_LOGIN, after this file loads), and a module's page is one of
    the frames it makes as one is first shown, found by shape (stacks like Kit.NewStack: `entries`
    laid out top down) and its heading (the module's title). Our rows go into the stack's entries,
    so Forever++'s own layout places them. A section is added when its page is first made, so
    turning the integration on shows them after a /reload; a Forever++ that builds its pages another
    way just shows none.
    Layout and approach adapted from Forever++'s Settings/Settings.lua by xIGBClutchIx (MIT License).
]]

local _, ns = ...
local L, Kit, Rows = ns.L, ns.Kit, ns.ForeverRows

local ipairs, pairs, type, select = ipairs, pairs, type, select

local Page = {}
ns.ForeverPage = Page

local owner = { name = "Forever++ page" } -- what this file's work is charged to
local HOST = "ForeverPlusPlus"

local function api()
    local fpp = _G.ForeverPlusPlusAPI
    return fpp and fpp.v1
end

local looked = setmetatable({}, { __mode = "k" }) -- a page Forever++ made -> true once looked at
local sections = {} -- page -> its section's view (Rows.NewView)
local content -- Forever++'s pane that holds the selected module's page
local laying = false

-- One of ours: its checkbox row, then its rows.
local function addModule(section, mod)
    local function on() return mod.db.enabled and not mod.locked and true or false end
    local row = Rows.AddRow(section, mod.title, 0)
    local box = Kit.NewCheckbox(row, 30, function(checked) ns:SetEnabled(mod.name, checked) end)
    box:SetPoint("LEFT", Rows.CONTROL_LEFT, 0)
    section.updates[#section.updates + 1] = function() box:SetChecked(mod.db.enabled and true or false) end
    Kit.AddTooltip(row, mod.title, mod.description, box)
    Rows.AddBody(section, mod, { moduleOn = on, sectionFont = "GameFontHighlight", sectionGap = 8,
        after = function() Page.Refresh() end })
end

-- The heading of one of Forever++'s module pages: its first font string.
local function headingOf(view)
    for i = 1, select("#", view:GetRegions()) do
        local region = select(i, view:GetRegions())
        if region.GetObjectType and region:GetObjectType() == "FontString" then return region:GetText() end
    end
end

-- The Forever++ module whose title `text` is, among those ours go with, or nil.
local function moduleTitled(text)
    local fpp = api()
    if not (fpp and text) then return nil end
    for _, name in ipairs(ns.order) do
        local target = ns.Attach.Target(ns.modules[name])
        local info = target and fpp.GetModuleInfo(target)
        if info and info.title == text then return target end
    end
end

-- Our section on a page Forever++ just made, when it's one ours go with.
local function lookAt(view)
    looked[view] = true
    local target = moduleTitled(headingOf(view))
    if not target then return end
    local section = Rows.NewView(view)
    Rows.AddLine(section, "GameFontHighlightLarge", L.PLUGIN_SECTION)
    for _, mod in ipairs(ns.Attach.On(target)) do
        -- One for an addon that isn't loaded isn't there (that can't change without a reload).
        if ns.Attach.Available(mod) then addModule(section, mod) end
    end
    sections[view] = section
    view:HookScript("OnShow", function() Page.Refresh() end)
end

-- Draws our rows from what's saved, and lays the page out again with them.
local function refreshView(view, section)
    Rows.Update(section)
    Kit.Layout(view)
    if view:IsShown() and content then
        laying = true
        content:SetHeight(view:GetHeight())
        laying = false
    end
end

function Page.Refresh()
    for view, section in pairs(sections) do refreshView(view, section) end
end

-- Forever++ sizes its pane to the page it shows, once it's laid out: any page not looked at yet
-- is one it just made.
local function onPaneSized()
    if laying then return end
    for i = 1, select("#", content:GetChildren()) do
        local view = select(i, content:GetChildren())
        if type(view.entries) == "table" and not looked[view] then
            ns.ChargedCall(owner, "page", lookAt, view)
            if sections[view] then refreshView(view, sections[view]) end
        end
    end
end

-- The Modules page, once Forever++ has filled it: the pane beside its list is the scroll frame
-- whose content isn't a stack.
local function onModulesShown(frame)
    if content or not ns.Plugin.Integrated() then return end
    for i = 1, select("#", frame:GetChildren()) do
        local child = select(i, frame:GetChildren())
        local inner = child:GetObjectType() == "ScrollFrame" and child:GetScrollChild()
        if inner and type(inner.entries) ~= "table" then content = inner end
    end
    if not content then return end
    hooksecurefunc(content, "SetHeight", function() ns.ChargedCall(owner, "pane", onPaneSized) end)
    onPaneSized()
end

-- Forever++'s Modules page, as it gives it to Blizzard's Settings (by its title).
hooksecurefunc(Settings, "RegisterCanvasLayoutCategory", function(frame, name)
    if name ~= C_AddOns.GetAddOnMetadata(HOST, "Title") or type(frame) ~= "table" then return end
    frame:HookScript("OnShow", function(self) ns.ChargedCall(owner, "modules page", onModulesShown, self) end)
end)

-- Our rows follow our settings.
ns:OnChanged(owner, function(_, name)
    local mod = ns.modules[name]
    if mod and mod.attach then Page.Refresh() end
end)
