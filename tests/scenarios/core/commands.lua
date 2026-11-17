--[[
    Forever Gearbox - tests/scenarios/core/commands.lua
    The /fg subcommands: options read and set through Forever++'s profile; turning a module on
    and off, and /fg <module>, open Forever++'s Modules page.
    Run by tests/run.lua (lua5.1 tests/run.lua commands), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root
local ns

W.Strict()
ns = W.LoadAddon(root, "ForeverGearbox")
login()
W.Slash("/fg list")
check(W.ChatHas("ButtonBag"), "/fg list")
W.Slash("/fg options button bag")
check(W.ChatHas("columns"), "/fg options")
W.Slash("/fg set buttonbag columns 99")
eq(ns.modules.ButtonBag.db.columns, 12, "/fg set clamps a number")
W.Slash("/fg set buttonbag closedelay 1.27")
eq(ns.modules.ButtonBag.db.closeDelay, 1.3, "/fg set keeps a slider's precision, as its box does")
W.Slash("/fg set buttonbag closedelay 2,5")
eq(ns.modules.ButtonBag.db.closeDelay, 2.5, "/fg set reads a comma decimal, as the Settings box does")
W.Slash("/fg options buttonbag")
local closeDelay
for _, option in ipairs(ns.modules.ButtonBag.options) do
    if option.key == "closeDelay" then closeDelay = option end
end
check(W.ChatHas(ns.Options.SliderText(closeDelay, 2.5)), "/fg options shows a slider as its label does")
W.Slash("/fg set performance latency local")
eq(ns.modules.Performance.db.latency, "home", "/fg set a choice by label")
W.Slash("/fg set performance latency nonsense")
local labels = {}
for _, option in ipairs(ns.modules.Performance.options) do
    if option.key == "latency" then
        for _, choice in ipairs(option.choices) do labels[#labels + 1] = choice[2] end
    end
end
check(W.LastChat():find(ns.L.CMD_WANT_CHOICE:format(table.concat(labels, ", ")), 1, true) ~= nil,
    "/fg set says the choices")
W.Slash("/fg set performance")
check(W.LastChat():find(ns.L.CMD_NO_OPTION:format("", ns.modules.Performance.title, "/fg"), 1, true) ~= nil,
    "/fg set <module> with no option: says the option is missing, not the module")
W.Slash("/fg set nosuchthing latency 1")
check(W.LastChat():find(ns.L.CMD_NO_MODULE:format("nosuchthing", "/fg"), 1, true) ~= nil, "/fg set unknown module")
W.Slash("/fg toggle performance colors")
eq(ns.modules.Performance.db.colors, false, "/fg toggle an option")
W.Slash("/fg set performance colors on")
eq(ns.modules.Performance.db.colors, true, "/fg set on")
eq(ForeverGearboxDB.settings.Performance.colors, true, "saved in Gearbox' own")
local layerOn = ns.modules.LayerInfo.db.enabled
W.Slash("/fg toggle layer")
eq(ns.modules.LayerInfo.db.enabled, not layerOn, "/fg toggle a module: turned on or off here")
eq(W.FPP.opened, nil, "nothing opened in Forever++")
W.Slash("/fg toggle layer")
eq(ns.modules.LayerInfo.db.enabled, layerOn, "and back")
W.Slash("/fg toggle nosuchthing")
check(W.LastChat():find(ns.L.CMD_NO_MODULE:format("nosuchthing", "/fg"), 1, true) ~= nil, "/fg unknown module")
ns:SetEnabled("Fishing", false) -- a section on Forever++'s Fishing Cast page: its own checkbox there
W.Slash("/fg fishing")
check(W.LastChat():find(ns.L.CMD_MODULE_OFF:format(ns.modules.Fishing.title, "/fg", "fishing"), 1, true) ~= nil,
    "/fg fishing says the module is off")
ns:SetEnabled("Fishing", true)
check(ns.modules.Fishing.active, "its checkbox turns it on again (Fishing Cast is on)")
W.Slash("/fg options perf")
check(W.ChatHas("latency"), "/fg options by the start of a module's name")
W.Slash("/fg help")
check(W.ChatHas("/fg set"), "/fg help lists commands")
W.Slash("/fg button bag")
eq(W.opened, ns.title, "/fg <module> opens Gearbox' own settings on it")
-- /fg reset puts options back, not modules' on/off.
ns:SetOption("Performance", "size", 20)
W.Slash("/fg reset")
W.Accept()
eq(ns.modules.Performance.db.size, 12, "/fg reset: options back to their defaults")
eq(ns.modules.LayerInfo.db.enabled, layerOn, "modules stay as they are")
-- /forevergearbox works too.
W.Slash("/forevergearbox list")
finish()
