--[[
    Forever suite - tests/scenarios/core/standalone.lua
    Forever Gearbox without Forever++: it loads and starts on its own, its modules turn on by their
    own defaults (the ones attached to Forever++'s modules too, as modules of their own), settings
    are kept in ForeverGearboxDB, 1.x settings Forever++ would have taken come in, and none of
    Forever++'s own modules are copied for it. /fg opens its own entry in Settings > AddOns, drawn
    as Forever++'s Modules page (no window of its own; Codex keeps its window): the module list,
    its checkboxes, a module's rows, the search, a module's own part (Vendor's list) and Advanced
    Graphics under the entry while it's on.
    Run by tests/run.lua (lua5.1 tests/run.lua standalone), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, openEverything, root = T.check, T.eq, T.login, T.finish, T.openEverything, T.root

W.Strict()
W.withoutForeverPlusPlus = true
-- 1.x settings kept aside for Forever++ (Migrations.lua step 14), which never came.
-- And what the Forever++ ports it had until 3.3.0 kept (Migrations.lua step 17).
ForeverGearboxDB = { version = 15, data = {},
    settings = { HideChatButtons = { enabled = true }, BaganatorUpgrades = { downgrades = false, percent = true } },
    movedSettings = { Performance = { size = 16 } }, enabledDefaults = { LayerInfo = false } }
local ns = W.LoadAddon(root, "ForeverGearbox")
local fc = W.LoadAddon(root, "ForeverCodex")
login()
eq(W.loaded.ForeverPlusPlus, nil, "no Forever++")
eq(ns.Plugin.Integrated(), false, "Forever Gearbox on its own")
for _, name in ipairs(ns.order) do
    local mod = ns.modules[name]
    if not mod.locked and not mod.addon then
        eq(mod.active and true or false, mod.defaults.enabled and name ~= "LayerInfo" or false, name .. ": on as its default says")
    end
end
ns:SetEnabled("QuestMarkers", false)
ns:SetEnabled("QuestMarkers", true)
check(ns.modules.QuestMarkers.active, "Quest Markers (attached to Forever++'s Quest Nameplates) is a module of its own")
eq(ns.modules.Performance.db.size, 16, "a 1.x setting Forever++ never took is the module's")
eq(ns.modules.LayerInfo.active, false, "and its 1.x on/off")

-- Settings are kept in its own saved variables.
ns:SetOption("Performance", "size", 18)
eq(ForeverGearboxDB.settings.Performance.size, 18, "saved in ForeverGearboxDB")
ns:SetEnabled("ChatFade", true)
check(ns.modules.ChatFade.active, "a module turns on from here")
eq(ForeverGearboxDB.settings.ChatFade.enabled, true, "and stays on")
ns:SetEnabled("ChatFade", false)
eq(ns.modules.ChatFade.active, false, "and off")

-- Nothing ported from Forever++, nor what they kept.
eq(ForeverGearboxDB.settings.HideChatButtons, nil, "Hide Chat Buttons' settings gone")
eq(ForeverGearboxDB.settings.BaganatorUpgrades and ForeverGearboxDB.settings.BaganatorUpgrades.percent, nil,
    "Upgrade Arrows in Baganator's own Percentage gone")
eq(ns.modules.HideChatButtons, nil, "no Hide Chat Buttons ported from Forever++")

-- Hide Chat Buttons, our own, only without Forever++: the strip fades with the chat.
local strip = ChatFrame1.buttonFrame
check(ns.modules.ChatButtons ~= nil and ns.modules.ChatButtons.active, "Hide Chat Buttons is on without Forever++")
W.ChatMouse(false)
W.Advance(CHAT_FRAME_FADE_OUT_TIME + 1)
eq(strip:GetAlpha(), 0, "the mouse away: the buttons fade out")
eq(QuickJoinToastButton:GetAlpha(), 0, "the social button too")
W.ChatMouse(true)
W.Advance(0.5)
eq(strip:GetAlpha(), 1, "over the chat: back")
ns:SetOption("ChatButtons", "faded", 0.5)
W.ChatMouse(false)
W.Advance(CHAT_FRAME_FADE_OUT_TIME + 1)
eq(strip:GetAlpha(), 0.5, "to Faded Buttons")
ns:SetEnabled("ChatButtons", false)
eq(strip:GetAlpha(), 1, "off: shown")
W.ChatMouse(true)
check(ns.modules.BaganatorUpgrades ~= nil, "Upgrade Arrows in Baganator without Forever++ too")
eq(ns.modules.ForeverPlusPlus.locked or not ns.OtherAddons.Loaded("ForeverPlusPlus"), true, "Forever++ Integration offered only with Forever++")
eq(rawget(_G, "ForeverGearboxSettingsFrame"), nil, "no settings window")

-- Its own entry in Settings, in Forever++'s look.
local entry = W.categories[ns.title]
check(entry ~= nil, "Forever Gearbox has its entry in Settings > AddOns")
W.Slash("/fg")
eq(W.opened, ns.title, "/fg opens it")
check(ns.AlonePage ~= nil, "its Modules page")
ns:OpenSettings("Performance")
eq(W.opened, ns.title, "a module's page: the entry")

-- The page: built as Settings shows it.
local canvas = entry.frame
check(canvas:IsShown(), "shown")
local function find(frame, test)
    if test(frame) then return frame end
    for _, child in ipairs(frame._children or {}) do
        local got = find(child, test)
        if got then return got end
    end
end
local function texted(text) return function(f) return f._kind == "FontString" and f._text == text end end
local function checkIn(row)
    for _, child in ipairs(row._children or {}) do
        if child._kind == "CheckButton" then return child end
    end
end
local function click(box, on)
    box:SetChecked(on)
    box:Click()
end
check(find(canvas, texted(ns:CategoryLabel("chat"))) ~= nil, "a category's label in the list")
local fade = ns.modules.ChatFade
local label = find(canvas, function(f) return f._kind == "FontString" and f._text == fade.title and f._parent._kind == "Button" end)
check(label ~= nil, "Fade Chat's row in the list")
local row = label._parent
click(checkIn(row), true)
check(fade.active, "its checkbox turns it on")
eq(ForeverGearboxDB.settings.ChatFade.enabled, true, "kept in ForeverGearboxDB")
click(checkIn(row), false)
eq(fade.active, false, "and off")

-- Clicking a row shows the module on the right, its rows in Forever++'s layout.
row:Click()
local enabled = find(canvas, texted(ns.L.ALONE_ENABLED))
check(enabled ~= nil, "its Enabled row")
local function optionRow(option)
    return find(canvas, function(f) return f._kind == "FontString" and f._text == option.label and f._parent._kind == "Frame" end)
end
check(optionRow(fade.options[1]) ~= nil, "its first option's row")

-- A module's own part (Vendor's list) under its options.
ns:OpenSettings("Vendor")
check(find(canvas, texted(ns.L.VENDOR_LIST_HEADER)) ~= nil, "Vendor's Autobuy list on its page")

-- The search narrows the list.
local search
for _, child in ipairs(canvas._children) do
    if child._kind == "EditBox" then search = child end
end
search:SetText("zzzz-nothing")
search:Fire("OnTextChanged")
check(find(canvas, texted(ns.L.NO_MODULES_MATCH:format("zzzz-nothing"))) ~= nil, "nothing matches")
search:SetText("")
search:Fire("OnTextChanged")

-- Advanced Graphics and Dynamic Light: under the entry while Visuals is on.
local function hasPage(name)
    for _, sub in ipairs(entry:GetSubcategories()) do
        if sub.name == name then return true end
    end
    return false
end
ns:SetEnabled("Visuals", false)
eq(hasPage(ns.L.VISUALS_TITLE), false, "Advanced Graphics isn't listed while it's off")
eq(hasPage(ns.L.DLIGHT_TITLE), false, "Dynamic Light isn't listed while it's off")
ns:SetEnabled("Visuals", true)
check(hasPage(ns.L.VISUALS_TITLE), "Advanced Graphics under Forever Gearbox while it's on")
eq(hasPage(ns.L.DLIGHT_TITLE), false, "Dynamic Light stays hidden while it is off")
ns:SetOption("Visuals", "dynamic", true)
check(hasPage(ns.L.DLIGHT_TITLE), "Dynamic Light under Forever Gearbox while it is on")
ns:SetOption("Visuals", "dynamic", false)
eq(hasPage(ns.L.DLIGHT_TITLE), false, "Dynamic Light leaves the sidebar when turned off")
ns.VisualsPage.Open()
eq(W.opened, ns.L.VISUALS_TITLE, "its button opens it there, not in a window")
ns:SetEnabled("Visuals", false)
ns:SetEnabled("ChatFade", false)
openEverything(ns)
openEverything(fc)
check(rawget(_G, "ForeverCodexSettingsFrame") ~= nil, "Codex keeps its window")
eq(#W.errors, 0, "no errors")
finish()
