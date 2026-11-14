--[[
    Forever Tweaks - tests/scenarios/core/commands.lua
    The /ft subcommands.
    Run by tests/run.lua (lua5.1 tests/run.lua commands), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root
local ns

W.Strict()
ns = W.LoadAddon(root, "ForeverTweaks")
login()
W.Slash("/ft list")
check(W.ChatHas("ButtonBag"), "/ft list")
W.Slash("/ft options button bag")
check(W.ChatHas("columns"), "/ft options")
W.Slash("/ft set buttonbag columns 99")
eq(ns.modules.ButtonBag.db.columns, 12, "/ft set clamps a number")
W.Slash("/ft set buttonbag closedelay 1.27")
eq(ns.modules.ButtonBag.db.closeDelay, 1.3, "/ft set keeps a slider's precision, as its box does")
W.Slash("/ft set buttonbag closedelay 2,5")
eq(ns.modules.ButtonBag.db.closeDelay, 2.5, "/ft set reads a comma decimal, as the Settings box does")
W.Slash("/ft options buttonbag")
local closeDelay
for _, option in ipairs(ns.modules.ButtonBag.options) do
    if option.key == "closeDelay" then closeDelay = option end
end
check(W.ChatHas(ns.Options.SliderText(closeDelay, 2.5)), "/ft options shows a slider as its label does")
W.Slash("/ft set performance latency local")
eq(ns.modules.Performance.db.latency, "home", "/ft set a choice by label")
W.Slash("/ft set performance latency nonsense")
local labels = {}
for _, option in ipairs(ns.modules.Performance.options) do
    if option.key == "latency" then
        for _, choice in ipairs(option.choices) do labels[#labels + 1] = choice[2] end
    end
end
check(W.LastChat():find(ns.L.CMD_WANT_CHOICE:format(table.concat(labels, ", ")), 1, true) ~= nil,
    "/ft set says the choices")
W.Slash("/ft set performance")
check(W.LastChat():find(ns.L.CMD_NO_OPTION:format("", ns.modules.Performance.title), 1, true) ~= nil,
    "/ft set <module> with no option: says the option is missing, not the module")
W.Slash("/ft set nosuchthing latency 1")
check(W.LastChat():find(ns.L.CMD_NO_MODULE:format("nosuchthing"), 1, true) ~= nil, "/ft set unknown module")
W.Slash("/ft toggle performance colors")
eq(ns.modules.Performance.db.colors, false, "/ft toggle an option")
W.Slash("/ft set performance colors on")
eq(ns.modules.Performance.db.colors, true, "/ft set on")
W.Slash("/ft toggle layer")
eq(ns.modules.LayerInfo.db.enabled, false, "/ft toggle a module by title")
W.Slash("/ft toggle nosuchthing")
check(W.LastChat():find(ns.L.CMD_NO_MODULE:format("nosuchthing"), 1, true) ~= nil, "/ft unknown module")
ns:SetEnabled("GatherSession", false)
W.Slash("/ft session")
check(W.LastChat():find(ns.L.CMD_MODULE_OFF:format(ns.modules.GatherSession.title, "/ft", "gathersession"), 1, true) ~= nil,
    "/ft session says the module is off")
ns:SetEnabled("GatherSession", true)
W.Slash("/ft options perf")
check(W.ChatHas("latency"), "/ft options by the start of a module's name")
W.Slash("/ft help")
check(W.ChatHas("/ft set"), "/ft help lists commands")
W.Slash("/ft button bag")
eq(W.opened, ns.member.short, "/ft <module> opens the Forever Tweaks page on it")
-- /forevertweaks works too.
W.Slash("/forevertweaks list")
finish()
