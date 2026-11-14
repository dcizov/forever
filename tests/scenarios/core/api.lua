--[[
    Forever Tweaks - tests/scenarios/core/api.lua
    The public API, its callbacks, and the Profiler.
    Run by tests/run.lua (lua5.1 tests/run.lua api), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root
local ns

W.Strict()
ns = W.LoadAddon(root, "ForeverTweaks")
local api = ForeverTweaksAPI.v1
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

local heard = {}
api.RegisterCallback("OPTION_CHANGED", function(_, name, key, value) heard[#heard + 1] = { name, key, value } end)
api.RegisterCallback("MODULE_TOGGLED", function(_, name, on) heard[#heard + 1] = { name, "toggled", on } end)
ns:SetOption("Performance", "colors", false)
eq(heard[1] and heard[1][2], "colors", "OPTION_CHANGED")
eq(heard[1] and heard[1][3], false, "with the new value")
ns:SetEnabled("LayerInfo", false)
eq(heard[2] and heard[2][1], "LayerInfo", "MODULE_TOGGLED")
eq(heard[2] and heard[2][3], false, "off")
eq(api.GetLayer(), nil, "no layer while Layer Info is off")
eq(api.GetErrorCount(), nil, "GetErrorCount stays in v1, always nil since the Error Catcher went in 1.6.0")
-- Defaults tells about the modules it really turned back on or off, and nothing else.
heard = {}
ns:ResetAll()
local toggled = {}
for _, h in ipairs(heard) do if h[2] == "toggled" then toggled[#toggled + 1] = h[1] end end
eq(#toggled, 1, "only one module changed state")
eq(toggled[1], "LayerInfo", "the one that was off")

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

-- An error of ours gives the caller nil and is reported like any other.
local real = ns.modules.Performance.GetNumbers
ns.modules.Performance.GetNumbers = function() error("our bug") end
eq(api.GetPerformance(), nil, "nil to the caller")
check(W.errors[1] and W.errors[1]:find("our bug", 1, true) ~= nil, "and reported")
W.errors = {}
ns.modules.Performance.GetNumbers = real

-- The Profiler times calls without changing what they return.
ns.Profiler.Start()
W.Fire("PLAYER_TARGET_CHANGED")
W.RunTimers()
local results = { ns.Run({ name = "Test" }, "test", function() return 1, 2, 3, 4, 5, 6 end) }
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
