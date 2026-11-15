--[[
    Forever Tweaks - tests/scenarios/core/isolation.lua
    Errors in one handler, timer or hook don't stop the others; module timers, hooks, news
    and option checks.
    Run by tests/run.lua (lua5.1 tests/run.lua isolation), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root
local ns

W.Strict()
ns = W.LoadAddon(root, "ForeverTweaks")
login()
-- An error in one handler doesn't stop the next one.
local a, b = { name = "A" }, { name = "B" }
local reached
ns:On("PLAYER_TARGET_CHANGED", a, function() error("handler A broke") end)
ns:On("PLAYER_TARGET_CHANGED", b, function() reached = true end)
W.Fire("PLAYER_TARGET_CHANGED")
check(reached, "second handler still ran")
check(W.errors[1] and W.errors[1]:find("handler A broke", 1, true), "error reported")
W.errors = {}
ns:Off("PLAYER_TARGET_CHANGED", a)
ns:Off("PLAYER_TARGET_CHANGED", b)
eq(ns:On("NO_SUCH_EVENT", a, function() end), false, "an unknown event isn't registered")
-- A module's timers stop when it turns off; its hooks do nothing.
local mod = ns:NewModule("TestModule", { defaults = { enabled = true, flag = false } })
ns.Store.Attach(mod)
mod:SetActive(true)
local ticks, hooked = 0, 0
mod:NewTicker(1, function() ticks = ticks + 1 end)
local heard, changed = 0, 0
mod:OnNews(function(self, event) if self == mod and event == "TEST_NEWS" then heard = heard + 1 end end)
mod:OnChanged(function(self, name) if self == mod and name == "Other" then changed = changed + 1 end end)
ns:Announce("TEST_NEWS")
ns:NotifyChanged("Other", "x")
TestTarget = { Run = function() end }
mod:Hook(TestTarget, "Run", function() hooked = hooked + 1 end)
mod:Hook(TestTarget, "Run", function() hooked = hooked + 1 end)
W.RunTimers()
TestTarget.Run()
eq(ticks, 1, "ticker ran")
eq(hooked, 1, "hook installed once")
mod:SetActive(false)
W.RunTimers()
TestTarget.Run()
eq(ticks, 1, "ticker stopped")
eq(hooked, 1, "hook idle while off")
ns:Announce("TEST_NEWS")
ns:NotifyChanged("Other", "x")
eq(heard .. "/" .. changed, "1/1", "news and setting changes heard while on, not while off")
-- A module whose OnEnable errors is turned off again: no events left, OnDisable run, error reported.
do
    local broken = ns:NewModule("BrokenEnable", { defaults = { enabled = true } })
    ns.Store.Attach(broken)
    local disabled = false
    function broken:OnEnable()
        self:RegisterEvent("PLAYER_TARGET_CHANGED", function() end)
        error("enable broke")
    end
    function broken:OnDisable() disabled = true end
    local before = #W.errors
    broken:SetActive(true)
    eq(broken.active, false, "an OnEnable error turns the module off again")
    eq(next(broken.events), nil, "with its events unregistered")
    check(disabled, "and OnDisable run")
    eq(#W.errors, before + 1, "the error is reported")
    W.errors[#W.errors] = nil
end
-- Profiler.Wrap isolates errors even while not recording.
do
    local wrapped = ns.Profiler.Wrap({ name = "Wrapped" }, "test", function() error("wrapped broke") end)
    local before = #W.errors
    local ok = pcall(wrapped)
    check(ok, "a wrapped error doesn't escape")
    eq(#W.errors, before + 1, "and is reported")
    W.errors[#W.errors] = nil
end
-- Soon runs once however often it's asked before the next frame; IsPending and CancelTimer.
mod:SetActive(true)
local soon = 0
local function bump() soon = soon + 1 end
mod:Soon(bump)
mod:Soon(bump)
W.RunTimers()
eq(soon, 1, "Soon: once per frame")
mod:Soon(bump)
W.RunTimers()
eq(soon, 2, "Soon: again on a later frame")
local ticker = mod:NewTicker(1, function() end)
check(mod:IsPending(ticker), "a running ticker is pending")
mod:CancelTimer(ticker)
check(not mod:IsPending(ticker), "cancelled: not pending")
ticker = mod:NewTicker(1, function() end)
mod:Soon(bump)
mod:SetActive(false)
check(not mod:IsPending(ticker), "turning off ends every timer")
W.RunTimers()
eq(soon, 2, "a pending Soon is cancelled with the module")
mod:SetActive(true)
mod:Soon(bump)
W.RunTimers()
eq(soon, 3, "and can be asked again once back on")
-- Delays are kept: an After runs when it's due, a ticker every interval, Soon on the next frame.
do
    local fired, ticks, soonRan = false, 0, false
    mod:After(5, function() fired = true end)
    local ticker = mod:NewTicker(1, function() ticks = ticks + 1 end)
    mod:Soon(function() soonRan = true end)
    W.Advance(0)
    check(soonRan, "Soon: on the next frame")
    W.Advance(4.9)
    check(not fired, "After(5): not before 5 seconds")
    eq(ticks, 4, "a 1 second ticker: 4 ticks in 4.9 seconds")
    W.Advance(0.2)
    check(fired, "After(5): at 5 seconds")
    eq(ticks, 5, "and its 5th tick")
    mod:CancelTimer(ticker)
    W.Advance(3)
    eq(ticks, 5, "a cancelled ticker stops")
end
-- HookCallback: installed once per target and key, idle while off.
local registry, calls, heard = {}, 0, nil
local function install(hook)
    calls = calls + 1
    registry.hook = hook
end
mod:HookCallback(registry, "cb", install, function(owner, value) heard = owner == mod and value end)
mod:HookCallback(registry, "cb", install, function() end)
eq(calls, 1, "HookCallback installs once")
registry.hook(7)
eq(heard, 7, "and runs with the module as owner")
mod:SetActive(false)
heard = nil
registry.hook(8)
eq(heard, nil, "idle while off")
eq(mod:Hook(TestTarget, "Missing", function() end), false, "nothing to hook: false")
eq(mod:HookScript(nil, "OnShow", function() end), false, "no frame to hook: false")
-- Option mistakes are caught when the module is made.
local ok, err = pcall(ns.NewModule, ns, "BadSlider", { defaults = { x = 1 },
    options = { { key = "x", type = "slider", label = "X" } } })
check(not ok and err:find("numeric min and max", 1, true), "a slider without a range is refused")
ok, err = pcall(ns.NewModule, ns, "BadDefault", { defaults = {},
    options = { { key = "y", type = "checkbox", label = "Y" } } })
check(not ok and err:find("boolean default", 1, true), "an option without its default is refused")
local function refused(name, info, text, what)
    local fine, msg = pcall(ns.NewModule, ns, name, info)
    check(not fine and tostring(msg):find(text, 1, true), what)
end
refused("BadRequires", { defaults = { a = true },
    options = { { key = "a", type = "checkbox", label = "A", requires = "nope" } } },
    "isn't a checkbox option", "requires naming no option is refused")
refused("LoopRequires", { defaults = { a = true, b = true },
    options = { { key = "a", type = "checkbox", label = "A", requires = "b" },
        { key = "b", type = "checkbox", label = "B", requires = "a" } } },
    "loop", "a loop of requires is refused")
refused("BadPair", { defaults = { a = true, b = true },
    options = { { key = "a", type = "checkbox", label = "A", slider = "b" },
        { key = "b", type = "checkbox", label = "B" } } },
    "must name a slider", "a slider pair that isn't a slider is refused")
refused("BadConflict", { defaults = { a = true },
    options = { { key = "a", type = "checkbox", label = "A", conflicts = { { key = "zz", when = function() end } } } } },
    "conflict", "a conflict naming no option is refused")
refused("BadCategory", { category = "nowhere" }, "unknown category", "an unknown category is refused")
refused("BadChoice", { defaults = { d = "c" }, options = { { key = "d", type = "dropdown", label = "D",
    choices = { { "a", "A" }, { "b", "B" } } } } }, "isn't one of its values", "a dropdown default that isn't a choice is refused")
refused("NumberChoices", { defaults = { d = 1 }, options = { { key = "d", type = "dropdown", label = "D",
    choices = { { 1, "One" }, { 2, "Two" } } } } }, "string values", "a dropdown's choices must be strings")
refused("BadRange", { defaults = { n = 50 }, options = { { key = "n", type = "slider", label = "N", min = 1, max = 10 } } },
    "isn't one of its values", "a slider default out of range is refused")
-- A timer for code that isn't a module runs through ns.ChargedHandler, with its owner.
local owner, got = { name = "Page" }, nil
ns:After(owner, 0, function(o) got = o end)
W.RunTimers()
eq(got, owner, "ns:After hands the owner to its function")
-- ns:Soon runs once on the next frame however often it's asked before then.
local soonRuns = 0
local function onceSoon(o) soonRuns = soonRuns + 1; got = o end
ns:Soon(owner, onceSoon)
ns:Soon(owner, onceSoon)
W.RunTimers()
eq(soonRuns, 1, "ns:Soon twice before the next frame: once")
ns:Soon(owner, onceSoon)
W.RunTimers()
eq(soonRuns, 2, "and again when asked after it ran")
-- A module's event: registering the same handler again or unregistering one it doesn't hear does
-- nothing; a handler must be a function.
local heard = 0
local function onTarget() heard = heard + 1 end
check(mod:RegisterEvent("PLAYER_TARGET_CHANGED", onTarget), "registers")
check(mod:RegisterEvent("PLAYER_TARGET_CHANGED", onTarget), "registering again is fine")
W.Fire("PLAYER_TARGET_CHANGED")
eq(heard, 1, "heard once, not twice")
mod:UnregisterEvent("PLAYER_TARGET_CHANGED")
mod:UnregisterEvent("PLAYER_TARGET_CHANGED")
W.Fire("PLAYER_TARGET_CHANGED")
eq(heard, 1, "not heard once unregistered")
check(not pcall(mod.RegisterEvent, mod, "PLAYER_TARGET_CHANGED", "OnTarget"), "a method name is refused")
-- Combat waits.
W.combat = true
local ran
ns:Off("PLAYER_TARGET_CHANGED", mod)
ns.Profiler.Start()
ns:AfterCombat({ name = "Waiter" }, function() ran = true end)
ns:AfterCombat({ name = "Waiter" }, function() error("queued broke") end)
check(not ran, "waits for combat to end")
W.combat = false
W.Fire("PLAYER_REGEN_ENABLED")
check(ran, "runs after combat")
check(W.errors[#W.errors] and W.errors[#W.errors]:find("queued broke", 1, true) ~= nil, "an error in queued work is reported")
W.errors = {}
ns.Profiler.Stop()
check(ns.Profiler.Report():find("Waiter: ", 1, true) ~= nil, "and the work is charged to its owner")
finish()
