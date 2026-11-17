--[[
    Forever suite - tests/scenarios/core/settings.lua
    Forever Codex's settings window: option controls (value boxes, checkboxes, undo arrows,
    dropdowns, groups), requires and shown, perCharacter data, the sidebar and its launcher, the
    Modules page's list, selection and search, a pane's extra (BuildPage), the Settings page,
    Defaults, and features modules. Two test modules use every option feature.
    Run by tests/run.lua (lua5.1 tests/run.lua settings), which passes its helpers in.
]]

local T = ...
local under = T.under -- every frame under one that passes a test (tests/run.lua)
local check, eq, login, finish, openEverything, root = T.check, T.eq, T.login, T.finish, T.openEverything, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverCodex")
local KINDS = { label = "Kinds", format = "%d kinds", tooltip = "Which kinds." }
local test = ns:NewModule("TestOptions", {
    title = "Test Options",
    category = "journal",
    defaults = { master = false, child = 1, hidden = false, notes = {}, farclip = 7000, colors = true,
        latency = "both", size = 12, kindA = true, kindB = true, kindC = false },
    perCharacter = { notes = true },
    options = {
        { key = "farclip", type = "slider", input = true, label = "View Distance", min = 500, max = 10000, step = 250 },
        { key = "size", type = "slider", label = "Size", min = 8, max = 30, step = 1 },
        { key = "colors", type = "checkbox", label = "Colors" },
        { key = "latency", type = "dropdown", label = "Latency", choices = { { "both", "Both" }, { "home", "Home" } } },
        { key = "master", type = "checkbox", label = "Master" },
        { key = "child", type = "slider", label = "Child", min = 1, max = 5, step = 1, requires = "master" },
        { key = "hidden", type = "checkbox", label = "Hidden", shown = function(db) return db.master end },
        { key = "kindA", type = "checkbox", label = "Kind A", group = KINDS },
        { key = "kindB", type = "checkbox", label = "Kind B", group = KINDS },
        { key = "kindC", type = "checkbox", label = "Kind C", group = KINDS },
    },
})
function test:BuildPage(stack) ns.Kit.AddHeaderRow(stack, "Extra List") end
local features = ns:NewModule("TestFeatures", {
    title = "Test Features",
    category = "map",
    defaults = { a = true, b = false, other = true },
    options = {
        { key = "a", type = "checkbox", label = "Feature A" },
        { key = "b", type = "checkbox", label = "Feature B" },
        { key = "other", type = "checkbox", label = "Not a Feature" },
    },
    features = { "a", "b" },
})
login()
-- A module first picked in the list once the window is open (its options built after the window
-- inked the page): its words in the parchment's ink too, not the game's gold.
ns:OpenSettings("TestFeatures")
local modulesPage = ns.SettingsWindow.Page(ns.member.short).frame
for _, row in ipairs(under(modulesPage, function(f) return f.isSelected ~= nil end)) do
    for _, child in ipairs(row._children or {}) do
        if child._text == "Test Options" then row:Fire("OnClick") end
    end
end
local colorsLabel
for _, f in ipairs(W.frames) do
    if f._kind == "FontString" and f._text == "Colors" and f:IsVisible() then colorsLabel = f end
end
check(colorsLabel and colorsLabel._textColor and colorsLabel._textColor[1] < 0.5, "an option's label in the parchment's ink")
-- A dropdown answering as a plain Button (as WowStyle1DropdownTemplate can) keeps its own text:
-- in the parchment's dark ink it couldn't be read on the dropdown's black.
local holder = W.NewFrame("Frame")
local dropdown = W.NewFrame("Button", nil, holder)
rawset(dropdown, "SetupMenu", function() end)
local choice = dropdown:CreateFontString()
choice:SetText("Both")
ns.JournalKit.InkTree(holder)
eq(choice._textColor, nil, "a dropdown's chosen value left in the game's colour")
openEverything(ns)
local Window = ns.SettingsWindow

-- Typing in a slider's value box.
ns:OpenSettings("TestOptions")
local box
for _, f in ipairs(W.frames) do
    if f._template == "InputBoxTemplate" and f._text == "7000" then box = f end
end
check(box ~= nil, "an input slider has a value box showing 7000")
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
-- Only sliders that ask for one get a box.
ns:SetOption("TestOptions", "size", 17)
W.RunTimers()
for _, f in ipairs(W.frames) do
    check(not (f._template == "InputBoxTemplate" and f._text == "17"), "Size has no value box")
end

-- The option controls change what's saved, and the undo arrow forgets it.
local function rowOf(label)
    for i = #W.frames, 1, -1 do
        local f = W.frames[i]
        if f._kind == "FontString" and f._text == label then return f:GetParent() end
    end
end
local function childOf(row, fn)
    for _, c in ipairs(row and row._children or {}) do
        if fn(c) then return c end
    end
end
local colorsRow = rowOf("Colors")
local colors = childOf(colorsRow, function(c) return c._kind == "CheckButton" end)
colors:SetChecked(false)
colors:Fire("OnClick")
eq(test.db.colors, false, "a checkbox sets its option")
W.RunTimers()
local undo = childOf(colorsRow, function(c) return c._kind == "Button" end)
check(undo:IsShown(), "the undo arrow shows for a saved choice")
undo:Fire("OnClick")
check(ns.Store.IsDefault(test, "colors"), "the undo arrow forgets it")
eq(test.db.colors, true, "back to the default")
local dropdown = childOf(rowOf("Latency"), function(c) return c._kind == "DropdownButton" end)
MenuUtil.CreateContextMenu(dropdown, dropdown._menu)
local choice = W.menu:Find("Home")
choice.set(choice.data)
eq(test.db.latency, "home", "a dropdown sets its option")

-- requires greys an option out until what it needs is on; shown hides one; perCharacter
-- data goes to the character's own table.
local slider = childOf(rowOf("Child"), function(c) return c._template == "MinimalSliderWithSteppersTemplate" end)
eq(slider:IsEnabled(), false, "an option is greyed while what it requires is off")
eq(rowOf("Hidden"):IsShown(), false, "an option with shown() false is hidden")
ns:SetOption("TestOptions", "master", true)
W.RunTimers()
eq(slider:IsEnabled(), true, "and usable once it's on")
eq(rowOf("Hidden"):IsShown(), true, "and shown once shown() is true")
test.db.notes.seen = true
eq(ForeverCodexCharDB.data.TestOptions.notes.seen, true, "perCharacter data is the character's")
eq(ForeverCodexDB.data.TestOptions.notes, nil, "and not the account's")

-- An option group is one dropdown row.
local kinds = childOf(rowOf("Kinds"), function(c) return c._kind == "DropdownButton" end)
check(kinds ~= nil, "a group is one dropdown")
eq(kinds and kinds:GetSelectionText(), "2 kinds", "counting the ticked ones")
eq(rowOf("Kind A"), nil, "no row of their own")

-- A features module that's off: its features can be ticked (that turns it on), its other
-- options are greyed like any module's.
ns:SetEnabled("TestFeatures", false)
ns:OpenSettings("TestFeatures")
W.RunTimers()
local function checkboxOf(label) return childOf(rowOf(label), function(c) return c._kind == "CheckButton" end) end
eq(checkboxOf("Feature B"):IsEnabled(), true, "off: a feature can still be ticked")
eq(checkboxOf("Not a Feature"):IsEnabled(), false, "but an option that isn't a feature is greyed")
ns:SetEnabled("TestFeatures", true)
W.RunTimers()
eq(checkboxOf("Not a Feature"):IsEnabled(), true, "and usable once it's on")
-- It runs while any feature is ticked.
ns:SetOption("TestFeatures", "a", false)
eq(features.active, false, "none ticked: the module is off")
ns:SetOption("TestFeatures", "b", true)
check(features.active, "one ticked again: on")
eq(features.db.a, false, "and only that one")
ns:SetEnabled("TestFeatures", false)
eq(features.db.b, false, "turned off as a whole (/codex): its features are unticked")
ns:SetEnabled("TestFeatures", true)
eq(features.db.a, true, "turned on with none ticked: its default features")

-- The sidebar: Settings, the Codex page (its modules), About, Debug and Changelog; no page
-- for a category or a module.
for _, page in ipairs({ ns.title, ns.member.short, ns.L.ABOUT, ns.L.DEBUG, ns.L.CHANGELOG }) do
    check(Window.Page(page) ~= nil, "a sidebar page: " .. page)
end
eq(Window.Page(ns:CategoryLabel("journal")), nil, "no page of its own for a category")
eq(Window.Page(test.title), nil, "nor for a module")
-- Settings > AddOns has a launcher; the window keeps its place.
check(W.categories[ns.title] ~= nil and W.categories[ns.member.short] == nil, "one launcher page in Settings > AddOns")
local launcher = W.categories[ns.title].frame
launcher:Show()
local openButton = under(launcher, function(f) return f._kind == "Button" and f._text == ns.L.OPEN end)[1]
openButton:Fire("OnClick")
check(Window.IsShown(), "its button opens the window")
local frame = ForeverCodexSettingsFrame
local moved = false
frame.StopMovingOrSizing = function() moved = true end
frame.GetPoint = function() return "TOPLEFT", UIParent, "TOPLEFT", 40, -50 end
frame:Fire("OnDragStop")
check(moved and ns.db.window.x == 40 and ns.db.window.y == -50, "dragged: its place kept")
local escapes = false
for _, name in ipairs(UISpecialFrames) do if name == "ForeverCodexSettingsFrame" then escapes = true end end
check(escapes, "Escape closes it")
ns:OpenSettings()
eq(Window.Current(), ns.title, "no module: the Settings page")
ns:OpenSettings("MinimapButton")
eq(Window.Current(), ns.title, "the Minimap Button opens on the Settings page")

local page = Window.Page(ns.member.short).frame
Window.Open(ns.member.short) -- the window shows one page at a time
local function shownText(text)
    return #under(page, function(f) return f._text == text and f:IsVisible() end) > 0
end
local function listRow(title)
    for _, row in ipairs(under(page, function(f) return f.isSelected ~= nil end)) do
        for _, child in ipairs(row._children or {}) do
            if child._text == title then return row end
        end
    end
end

-- The list: every module under its category's label, each with its checkbox.
for _, name in ipairs(ns.order) do
    if ns:CategoryOf(ns.modules[name]) ~= "settings" then
        check(listRow(ns.modules[name].title) ~= nil, "listed: " .. name)
    end
end
check(shownText(ns:CategoryLabel("journal")), "a label per category")
eq(listRow(ns.modules.MinimapButton.title), nil, "the Settings page's modules aren't listed")
local settingsPage = Window.Page(ns.title).frame
check(#under(settingsPage, function(f) return f._text == ns.modules.MinimapButton.title end) > 0,
    "they're on the Settings page")

-- Opening a module selects it: its options on the right, and only its.
ns:OpenSettings("TestOptions")
eq(Window.Current(), ns.member.short, "a module opens on the Codex page")
check(listRow(test.title).isSelected(), "selected in the list")
check(shownText("Latency"), "its options show")
check(shownText("Extra List"), "with what its BuildPage adds")
eq(shownText("Not a Feature"), false, "another module's don't")
listRow(features.title):Fire("OnClick")
check(shownText("Not a Feature"), "clicking a row shows that module")
eq(shownText("Latency"), false, "and no longer the other's")
-- A row's checkbox turns the module on and off.
local testBox = under(listRow(test.title), function(f) return f._kind == "CheckButton" end)[1]
testBox:SetChecked(false)
testBox:Fire("OnClick")
eq(test.db.enabled, false, "the list's checkbox turns it off")
ns:SetEnabled("TestOptions", true)

-- The search narrows the list and keeps a match shown.
local search = under(page, function(f) return f._template == "SearchBoxTemplate" end)[1]
search:SetText("latency")
search:Fire("OnTextChanged")
check(listRow(test.title):IsShown(), "the search keeps a module by its option")
eq(listRow(features.title):IsShown(), false, "and hides what doesn't match")
search:SetText("zzzz")
search:Fire("OnTextChanged")
check(shownText(string.format(ns.L.NO_MODULES_MATCH, "zzzz")), "nothing matches: says so")
search:SetText("")
search:Fire("OnTextChanged")
check(listRow(features.title):IsShown(), "cleared: everything listed again")

-- Defaults resets only the module shown.
ns:SetOption("TestOptions", "size", 20)
ns:SetOption("TestFeatures", "other", false)
ns:OpenSettings("TestFeatures")
for _, f in ipairs(under(page, function(f) return f._text == SETTINGS_DEFAULTS end)) do f:Fire("OnClick") end
W.Accept()
eq(features.db.other, true, "Defaults resets the module shown")
eq(test.db.size, 20, "and leaves the others alone")

Window.Open(ns.L.ABOUT)
check(Window.Page(ns.L.ABOUT).frame:IsShown(), "the About page opens")
eq(#W.errors, 0, "no errors")
finish()
