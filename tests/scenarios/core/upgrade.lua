--[[
    Forever Tweaks - tests/scenarios/core/upgrade.lua
    0.9.0's saved variables moved to today's layout.
    Run by tests/run.lua (lua5.1 tests/run.lua upgrade), which passes its helpers in.
]]

local T = ...
local under = T.under -- every frame under one that passes a test (tests/run.lua)
local check, eq, login, finish, openEverything, root = T.check, T.eq, T.login, T.finish, T.openEverything, T.root
local ns

-- Saved by 0.9.0: everything flat in db.modules, defaults left out (layout 3).
ForeverTweaksDB = {
    layout = 3, debug = false,
    modules = {
        ViewDistance = { enabled = true, farclip = 7000, saved = { farclip = "1000" } },
        ButtonBag = { columns = 8, ignored = { SomeAddon = true } },
        StatusText = { display = "PERCENT", saved = { statusText = "0" } },
        Performance = { latency = "both", size = 14, x = 20, bogus = 1, colors = "yes" },
        ErrorSpeech = { enabled = true },
        ConsoleVariables = { enabled = true },
    },
}
W.Strict()
ns = W.LoadAddon(root, "ForeverTweaks")
-- A module older than the 0.9.0 install, for the NEW labels.
ns:NewModule("TestOld", {
    category = "map", added = "0.5.0", -- older than the 0.9.0 install: no NEW label
    defaults = { enabled = true, size = 10 },
    options = { { key = "size", type = "slider", label = "Size", min = 5, max = 20, step = 1 } },
})
login()
local db = ForeverTweaksDB
eq(db.version, ns.member.layout, "layout version")
eq(db.modules, nil, "old modules table gone")
eq(db.layout, nil, "old layout key gone")
eq(db.installed, "0.9.0", "an upgrade counts as installed at 0.9.0")
eq(db.settings.ButtonBag.columns, 8, "setting carried over")
eq(db.data.ButtonBag.ignored.SomeAddon, true, "data carried over")
eq(db.settings.ViewDistance, nil, "View Distance (removed in 1.4.0) gone")
eq(db.settings.Performance.bogus, nil, "unknown key dropped")
eq(db.settings.Performance.colors, nil, "wrong type dropped")
eq(ns.modules.Performance.db.latency, "both", "module reads its setting")
eq(ns.modules.Performance.db.fps, true, "module reads a default")
eq(W.cvars.statusText, "0", "a removed module leaves its CVar alone")
check(ns.member.db.seenModules ~= nil, "seenModules made")
check(ns:IsNewer("1.0.0", "0.9.0") and not ns:IsNewer("0.9.0", "1.0.0") and ns:IsNewer("1.10.0", "1.9.2"), "IsNewer")

-- Displays and Edit Mode.
local perf = ns.modules.Performance
W.RunTimers()
check(ForeverTweaksPerformance ~= nil, "FPS display made")
EditModeManagerFrame:EnterEditMode()
check(ns.EditMode.IsActive(), "Edit Mode active")
EditModeManagerFrame:ExitEditMode()
ns:SetOption("Performance", "x", 50)
eq(perf.db.x, 50, "x slider")
ns:ResetOption("Performance", "x")
check(perf.db.x ~= 50 and ns.Store.IsDefault(perf, "x"), "x reset to default")

-- NEW labels: on what's newer than the version the player last saw it in (here the 0.9.0
-- install), until its page has been built.
eq(ns.member.db.seenModules.FullBags, nil, "Full Bags (1.3.0) not seen yet")

-- Settings pages and the Debug report.
openEverything(ns)
local function hasNewLabel(page, title)
    -- (Its title is there twice: its row in the list and its pane's header.)
    local titles = under(W.categories[page].frame, function(f) return f._kind == "FontString" and f._text == title end)
    if #titles == 0 then return nil end
    for _, text in ipairs(titles) do
        for _, sibling in ipairs({ text:GetParent():GetChildren() }) do
            if sibling._template == "NewFeatureLabelTemplate" then return true end
        end
    end
    return false
end
eq(hasNewLabel(ns.member.short, ns.modules.FullBags.title), true, "a module added since the install: NEW")
eq(hasNewLabel(ns.member.short, "TestOld"), false, "one older than the install: no NEW")
eq(ns.member.db.seenModules.FullBags, ns.version, "a module shown is marked seen")
check(not ns:IsNewer(ns.modules.FullBags.added, ns.member.db.seenModules.FullBags), "so its NEW label goes next time")
local info = ns:DebugInfo()
check(info:find("TestOld", 1, true) ~= nil, "debug info lists modules")
check(info:find("\n\nLog:\n", 1, true) ~= nil, "a blank line before the log")
-- A module whose DebugLine errors doesn't stop the report.
local bag = ns.modules.ButtonBag
local realLine = bag.DebugLine
bag.DebugLine = function() error("line broke") end
info = ns:DebugInfo()
check(info:find("DebugLine failed", 1, true) ~= nil and info:find("Log:", 1, true) ~= nil, "a failing DebugLine is marked and the report goes on")
check(W.errors[#W.errors] and W.errors[#W.errors]:find("line broke", 1, true) ~= nil, "and its error reported")
W.errors = {}
bag.DebugLine = realLine
finish()
