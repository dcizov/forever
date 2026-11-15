--[[
    Forever Tweaks - tests/scenarios/core/settings.lua
    The Settings pages: option controls (value boxes, checkboxes, undo arrows, dropdowns, groups),
    requires and shown, perCharacter data, the sidebar, the Forever Tweaks page's module list,
    selection and search, the Settings page, and Defaults.
    Run by tests/run.lua (lua5.1 tests/run.lua settings), which passes its helpers in.
]]

local T = ...
local under = T.under -- every frame under one that passes a test (tests/run.lua)
local check, eq, login, finish, openEverything, root = T.check, T.eq, T.login, T.finish, T.openEverything, T.root
local ns

W.Strict()
ns = W.LoadAddon(root, "ForeverTweaks")
-- A module using the option features no shipped module does yet.
local test = ns:NewModule("TestOptions", {
    defaults = { master = false, child = 1, hidden = false, notes = {}, farclip = 7000 },
    perCharacter = { notes = true },
    options = {
        { key = "farclip", type = "slider", input = true, label = "View Distance",
          min = 500, max = 10000, step = 250 },
        { key = "master", type = "checkbox", label = "Master" },
        { key = "child", type = "slider", label = "Child", min = 1, max = 5, step = 1, requires = "master" },
        { key = "hidden", type = "checkbox", label = "Hidden", shown = function(db) return db.master end },
    },
})
login()
openEverything(ns)

-- Typing in a slider's value box.
ns:OpenSettings("TestOptions")
local box
for _, f in ipairs(W.frames) do
    if f._template == "InputBoxTemplate" and f._text == "7000" then box = f end
end
check(box ~= nil, "an input slider has a value box showing 7000")
if box then
    box:SetText("7350")
    box:Fire("OnEnterPressed")
    eq(test.db.farclip, 7350, "typed value between steps kept")
    eq(box:GetText(), "7350", "box shows the value")
    box:SetText("99999 yd")
    box:Fire("OnEnterPressed")
    eq(test.db.farclip, 10000, "typed value kept in range")
    box:SetText("far")
    box:Fire("OnEnterPressed")
    eq(test.db.farclip, 10000, "text without a number ignored")
    eq(box:GetText(), "10000", "box back to the saved value")
end
-- Only sliders that ask for one get a box.
ns:OpenSettings("ButtonBag")
ns:SetOption("ButtonBag", "columns", 7)
W.RunTimers()
for _, f in ipairs(W.frames) do
    check(not (f._template == "InputBoxTemplate" and f._text == "7"), "Buttons per Row has no value box")
end
ns:OpenSettings("Performance")
ns:SetOption("Performance", "x", -12)
W.RunTimers()
box = nil
for _, f in ipairs(W.frames) do
    if f._template == "InputBoxTemplate" and f._text == "-12" then box = f end
end
check(box ~= nil, "Horizontal Position has a value box")
if box then
    box:SetText("-40,4")
    box:Fire("OnEnterPressed")
    eq(ns.modules.Performance.db.x, -40, "negative typed value, rounded to whole pixels")
end
-- The option controls change what's saved, and the undo arrow forgets it.
local function rowOf(label)
    for i = #W.frames, 1, -1 do
        local f = W.frames[i]
        if f._kind == "FontString" and f._text == label then return f:GetParent() end
    end
end
local function childOf(row, test)
    for _, c in ipairs(row and row._children or {}) do
        if test(c) then return c end
    end
end
local L = ns.L
ns:OpenSettings("Performance")
local colorsRow = rowOf(L.PERF_COLORS)
local box = childOf(colorsRow, function(c) return c._kind == "CheckButton" end)
box:SetChecked(false)
box:Fire("OnClick")
eq(ns.modules.Performance.db.colors, false, "a checkbox sets its option")
W.RunTimers()
local undo = childOf(colorsRow, function(c) return c._kind == "Button" end)
check(undo:IsShown(), "the undo arrow shows for a saved choice")
undo:Fire("OnClick")
check(ns.Store.IsDefault(ns.modules.Performance, "colors"), "the undo arrow forgets it")
eq(ns.modules.Performance.db.colors, true, "back to the default")
local dropdown = childOf(rowOf(L.PERF_LATENCY), function(c) return c._kind == "DropdownButton" end)
MenuUtil.CreateContextMenu(dropdown, dropdown._menu)
local choice = W.menu:Find(L.PERF_LOCAL)
choice.set(choice.data)
eq(ns.modules.Performance.db.latency, "home", "a dropdown sets its option")

-- requires greys an option out until what it needs is on; shown hides one; perCharacter
-- data goes to the character's own table.
ns:OpenSettings("TestOptions")
W.RunTimers()
local slider = childOf(rowOf("Child"), function(c) return c._template == "MinimalSliderWithSteppersTemplate" end)
eq(slider:IsEnabled(), false, "an option is greyed while what it requires is off")
eq(rowOf("Hidden"):IsShown(), false, "an option with shown() false is hidden")
ns:SetOption("TestOptions", "master", true)
W.RunTimers()
eq(slider:IsEnabled(), true, "and usable once it's on")
eq(rowOf("Hidden"):IsShown(), true, "and shown once shown() is true")
-- A features module that's off: its features can be ticked (that turns it on), its other options
-- are greyed like any module's.
ns:SetEnabled("Fishing", false)
ns:OpenSettings("Fishing")
W.RunTimers()
local function checkboxOf(label) return childOf(rowOf(label), function(c) return c._kind == "CheckButton" end) end
eq(checkboxOf(L.FISHING_INFO):IsEnabled(), true, "Fishing off: a feature can still be ticked")
eq(checkboxOf(L.FISHING_SOUND):IsEnabled(), false, "but an option that isn't a feature is greyed")
ns:SetEnabled("Fishing", true)
W.RunTimers()
eq(checkboxOf(L.FISHING_SOUND):IsEnabled(), true, "and usable once it's on")
test.db.notes.seen = true
eq(ForeverTweaksCharDB.data.TestOptions.notes.seen, true, "perCharacter data is the character's")
eq(ForeverTweaksDB.data.TestOptions.notes, nil, "and not the account's")

-- The sidebar: the Forever page (Settings), the Tweaks page (its modules), Tweaks for Addons,
-- About, Debug and Changelog; no page for any other category or a module.
for _, page in ipairs({ ns.title, ns.member.short, L.CATEGORY_ADDONS, L.ABOUT, L.DEBUG, L.CHANGELOG }) do
    check(ForeverCore.SettingsWindow.Page(page) ~= nil, "a sidebar page: " .. page)
end
for _, key in ipairs(ns.member.categories) do
    if key ~= "settings" and key ~= "addons" then
        eq(ForeverCore.SettingsWindow.Page(ns:CategoryLabel(key)), nil, "no page of its own for " .. key)
    end
end
eq(ForeverCore.SettingsWindow.Page(ns.modules.FullBags.title), nil, "no page of its own for a module")
-- The Forever window: Settings > AddOns > Forever is a launcher; the window keeps its place.
local Window = ForeverCore.SettingsWindow
check(W.categories[ns.title] ~= nil and W.categories[ns.member.short] == nil, "one launcher page in Settings > AddOns")
local launcher = W.categories[ns.title].frame
launcher:Show()
local openButton = under(launcher, function(f) return f._kind == "Button" and f._text == L.OPEN end)[1]
openButton:Fire("OnClick")
check(Window.IsShown(), "its button opens the Forever window")
local frame = ForeverSettingsFrame
local moved = false
frame.StopMovingOrSizing = function() moved = true end
frame.GetPoint = function() return "TOPLEFT", UIParent, "TOPLEFT", 40, -50 end
frame:Fire("OnDragStop")
check(moved and ns.db.window.x == 40 and ns.db.window.y == -50, "dragged: its place kept")
local escapes = false
for _, name in ipairs(UISpecialFrames) do if name == "ForeverSettingsFrame" then escapes = true end end
check(escapes, "Escape closes it")
ns:OpenSettings()
eq(ForeverCore.SettingsWindow.Current(), ns.title, "no module: the Forever page")
ns:OpenSettings("MinimapButton")
eq(ForeverCore.SettingsWindow.Current(), ns.title, "the Minimap Button opens on the Settings page (the top one)")
ns:OpenSettings("DungeonJournalSkin")
eq(ForeverCore.SettingsWindow.Current(), L.CATEGORY_ADDONS, "an addon's tweak opens on Tweaks for Addons")

local page = ForeverCore.SettingsWindow.Page(ns.member.short).frame
ForeverCore.SettingsWindow.Open(ns.member.short) -- the window shows one page at a time
local function shownText(text)
    return #under(page, function(f) return f._text == text and f:IsVisible() end) > 0
end
-- The list row (a sidebar-style button) for a module's title.
local function listRow(title)
    for _, row in ipairs(under(page, function(f) return f.isSelected ~= nil end)) do
        for _, child in ipairs(row._children or {}) do
            if child._text == title then return row end
        end
    end
end

-- The list: every module under its category's label, each with its checkbox.
for _, name in ipairs(ns.order) do
    local mod = ns.modules[name]
    local category = ns:CategoryOf(mod)
    if category ~= "settings" and category ~= "addons" then
        check(listRow(mod.title) ~= nil, "listed: " .. name)
    end
end
check(shownText(ns:CategoryLabel("bags")), "a label per category")
check(shownText(ns.L.GROUP_FISHING), "related modules under their group's heading")
-- Grouped modules sit together after their category's ungrouped ones.
check(listRow(ns.modules.Fishing.title) ~= nil and listRow(ns.modules.GatherMap.title) ~= nil, "both groups listed")
eq(listRow(ns.modules.MinimapButton.title), nil, "the Settings page's modules aren't listed")
eq(listRow(ns.modules.DungeonJournalSkin.title), nil, "nor Tweaks for Addons' modules")
-- The Settings page draws every module of the "settings" category, by category.
local settingsPage = ForeverCore.SettingsWindow.Page(ns.title).frame
for _, name in ipairs(ns.order) do
    local mod = ns.modules[name]
    if ns:CategoryOf(mod) == "settings" then
        check(#under(settingsPage, function(f) return f._text == mod.title end) > 0, "on the Settings page: " .. name)
    end
end

-- Opening a module selects it: its options on the right, and only its.
ns:OpenSettings("Performance")
eq(ForeverCore.SettingsWindow.Current(), ns.member.short, "a module opens on the Forever Tweaks page")
check(listRow(ns.modules.Performance.title).isSelected(), "selected in the list")
check(shownText(L.PERF_LATENCY), "its options show")
eq(shownText(L.FULL_COINS), false, "another module's don't")
-- Clicking a row shows that module.
listRow(ns.modules.FullBags.title):Fire("OnClick")
check(shownText(L.FULL_COINS), "clicking Full Bags shows its options")
eq(shownText(L.PERF_LATENCY), false, "and no longer FPS & Latency's")
check(shownText(L.FULL_KEEP_HEADER), "with what its BuildPage adds")
-- A row's checkbox turns the module on and off.
local layerRow = listRow(L.LAYER_TITLE)
local layerBox = under(layerRow, function(f) return f._kind == "CheckButton" end)[1]
local before = ns.modules.LayerInfo.db.enabled and true or false
layerBox:SetChecked(not before)
layerBox:Fire("OnClick")
eq(ns.modules.LayerInfo.db.enabled and true or false, not before, "the list's checkbox turns it on or off")
ns:SetEnabled("LayerInfo", before)

-- The search narrows the list and keeps a match shown.
local search = under(page, function(f) return f._template == "SearchBoxTemplate" end)[1]
search:SetText("coin")
search:Fire("OnTextChanged")
check(listRow(ns.modules.FullBags.title):IsShown(), "the search keeps Full Bags (its coin option)")
eq(listRow(L.LAYER_TITLE):IsShown(), false, "and hides what doesn't match")
search:SetText("zzzz")
search:Fire("OnTextChanged")
check(shownText(string.format(L.NO_MODULES_MATCH, "zzzz")), "nothing matches: says so")
search:SetText("")
search:Fire("OnTextChanged")
check(listRow(L.LAYER_TITLE):IsShown(), "cleared: everything listed again")

-- Defaults resets only the module shown.
ns:SetOption("Performance", "size", 20)
ns:SetOption("FullBags", "maxQuality", 1)
ns:OpenSettings("FullBags")
for _, f in ipairs(under(page, function(f) return f._text == SETTINGS_DEFAULTS end)) do f:Fire("OnClick") end
W.Accept()
eq(ns.modules.FullBags.db.maxQuality, ns.modules.FullBags.defaults.maxQuality, "Defaults resets the module shown")
eq(ns.modules.Performance.db.size, 20, "and leaves the others alone")

-- A one-feature module's header has its checkbox in front; a features module's has none.
local function headerOf(title)
    for _, f in ipairs(under(page, function(f) return f._kind == "FontString" and f._text == title and f:IsVisible() end)) do
        local row = f:GetParent()
        if not row.isSelected then return row end
    end
end
ns:OpenSettings("LayerInfo")
check(under(headerOf(L.LAYER_TITLE), function(c) return c._kind == "CheckButton" end)[1] ~= nil,
    "a one-feature module's header has its checkbox")
ns:OpenSettings("QuestItems")
check(headerOf(L.QUESTITEMS_TITLE) ~= nil, "the selected module's header")
eq(under(headerOf(L.QUESTITEMS_TITLE), function(c) return c._kind == "CheckButton" end)[1], nil,
    "a features module's header has none")

-- An option group is one dropdown row: Full Bags' kinds to keep.
ns:OpenSettings("FullBags")
W.RunTimers()
local keepRow = rowOf(L.FULL_KEEP_KINDS)
local keepDropdown = childOf(keepRow, function(c) return c._kind == "DropdownButton" end)
check(keepDropdown ~= nil, "Kinds to Keep is one dropdown")
eq(keepDropdown and keepDropdown:GetSelectionText(), string.format(L.FULL_KEEP_KINDS_COUNT, 4), "four kinds kept by default")
eq(rowOf(L.FULL_KEEP_REAGENTS), nil, "no row of their own")

-- A features module runs while any feature is ticked.
local items = ns.modules.QuestItems
ns:SetOption("QuestItems", "markNeeded", false)
check(items.active, "one feature off: still on")
ns:SetOption("QuestItems", "markStarts", false)
ns:SetOption("QuestItems", "markLeftover", false)
check(items.active, "the tooltip still on: still on")
ns:SetOption("QuestItems", "tooltip", false)
eq(items.active, false, "all off: the module is off")
ns:SetOption("QuestItems", "markLeftover", true)
check(items.active, "one ticked again: on")
eq(items.db.markNeeded, false, "and only that one")
ns:SetEnabled("QuestItems", false)
eq(items.db.markLeftover, false, "turned off as a whole (/ft): its features are unticked")
ns:SetEnabled("QuestItems", true)
eq(items.db.markNeeded and items.db.markStarts and items.db.markLeftover and items.db.tooltip, true,
    "turned on with none ticked: its default features")
ForeverCore.SettingsWindow.Open(L.ABOUT)
check(ForeverCore.SettingsWindow.Page(L.ABOUT).frame:IsShown(), "the About page opens")
finish()
