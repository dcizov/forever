--[[
    Forever Gearbox - tests/scenarios/core/api.lua
    The public API, its callbacks, and the Profiler.
    Run by tests/run.lua (lua5.1 tests/run.lua api), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root
local ns

W.Strict()
ns = W.LoadAddon(root, "ForeverGearbox")
local api = ForeverGearboxAPI.v1
check(ForeverTweaksAPI == ForeverGearboxAPI, "the API answers under its old name too")
local ready = false
api.RegisterCallback("READY", function() ready = true end)
login()
check(ready, "READY once modules have started")
eq(api.GetVersion(), W.metadata.Version, "API version")
eq(api.IsModuleEnabled("Performance"), true, "API module state")
eq(api.GetOption("Performance", "latency"), "world", "API option")
local saved = api.GetOption("ButtonBag", "ignored")
saved.Test = true
eq(ns.modules.ButtonBag.db.ignored.Test, nil, "tables come back as copies")
eq(api.GetPerformance(), 58.4, "API performance numbers")
eq(api.RegisterCallback("NO_SUCH_EVENT", function() end), nil, "an event the API doesn't have is refused")

-- Gearbox' modules, each with the addon it belongs to.
local addonOf = {}
for _, row in ipairs(api.GetModules()) do addonOf[row.name] = row.addon end
eq(addonOf.Performance, "ForeverGearbox", "a Gearbox module says it's Forever Gearbox'")
eq(addonOf.MinimapButton, nil, "Forever Codex's aren't listed")

local heard = {}
api.RegisterCallback("OPTION_CHANGED", function(_, name, key, value, addon) heard[#heard + 1] = { name, key, value, addon } end)
api.RegisterCallback("MODULE_TOGGLED", function(_, name, on) heard[#heard + 1] = { name, "toggled", on } end)
ns:SetOption("Performance", "colors", false)
eq(heard[1] and heard[1][2], "colors", "OPTION_CHANGED")
eq(heard[1] and heard[1][3], false, "with the new value")
eq(heard[1] and heard[1][4], "ForeverGearbox", "and the addon the module belongs to")
ns:SetEnabled("LayerInfo", false) -- on Forever Gearbox' own page
eq(heard[2] and heard[2][1], "LayerInfo", "MODULE_TOGGLED")
eq(heard[2] and heard[2][3], false, "off")
eq(api.GetLayer(), nil, "no layer while Layer Info is off")
eq(api.GetErrorCount(), nil, "GetErrorCount stays in v1, always nil since the Error Catcher went in 1.6.0")
-- Defaults (/fg reset) tells about the options it put back, and a module turned back on.
heard = {}
ns:ResetAll()
local toggled, colors = 0, false
for _, h in ipairs(heard) do
    if h[2] == "toggled" then toggled = toggled + 1 end
    if h[1] == "Performance" and h[2] == "colors" then colors = true end
end
eq(toggled, 1, "Layer Info back on, its default")
check(colors, "the option changed is told of")

-- A callback may register and unregister callbacks while they're being called.
local late = 0
local function lateFn() late = late + 1 end
local function selfRemoving(event)
    api.RegisterCallback(event, lateFn)
    api.UnregisterCallback(event, selfRemoving)
end
api.RegisterCallback("OPTION_CHANGED", selfRemoving)
ns:SetOption("Performance", "colors", false)
eq(late, 0, "a callback added while firing waits for the next event")
ns:SetOption("Performance", "colors", true)
eq(late, 1, "and hears the next one")

-- An error in another addon's callback is theirs: logged, not reported, and the rest still run.
local after = 0
api.RegisterCallback("MODULE_TOGGLED", function() error("their bug") end)
api.RegisterCallback("MODULE_TOGGLED", function() after = after + 1 end)
ns:SetEnabled("LayerInfo", false)
eq(#W.errors, 0, "a callback's error isn't reported as ours")
eq(after, 1, "and the other callbacks still hear it")

-- An error of ours gives the caller nil and is reported like any other.
local real = ns.modules.Performance.GetNumbers
ns.modules.Performance.GetNumbers = function() error("our bug") end
eq(api.GetPerformance(), nil, "nil to the caller")
check(W.errors[1] and W.errors[1]:find("our bug", 1, true) ~= nil, "and reported")
W.errors = {}
ns.modules.Performance.GetNumbers = real

-- The Profiler times calls without changing what they return.
ns:SetEnabled("LayerInfo", true)
ns.Profiler.Start()
W.Fire("PLAYER_TARGET_CHANGED")
W.RunTimers()
local results = { ns.ChargedHandler({ name = "Test" }, "test", function() return 1, 2, 3, 4, 5, 6 end) }
-- A popup's answer is the asker's code.
ns:Confirm({ name = "Asker" }, "TEST", "Sure?", function() end)
W.Accept()
eq(#results, 6, "a profiled call hands back every result")
ns.Profiler.Stop()
local report = ns.Profiler.Report()
check(report:find("Test: ", 1, true) ~= nil, "the report charges the call to its owner")
check(report:find("LayerInfo", 1, true) ~= nil, "and a module's event handler to the module")
check(report:find("Asker: ", 1, true) ~= nil, "and a popup's answer to whoever asked")
finish()
