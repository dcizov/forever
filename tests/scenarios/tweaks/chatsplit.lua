--[[
    Forever Gearbox - tests/scenarios/tweaks/chatsplit.lua
    3.3.0 split Chat Window into Hide Chat Tabs, Hide Chat Input and Fade Chat Messages: its
    settings, in every Forever++ profile, go to the module that has them now, Show Buttons is
    dropped (Forever++'s Hide Chat Buttons), and a choice that was the game's own look leaves its
    new module off.
    Forever Gearbox then takes the settings of the Forever++ profile this character uses into its
    own, under either name (Core/Plugin.lua's TakeOver, 3.3.0).
    Run by tests/run.lua (lua5.1 tests/run.lua chatsplit), which passes its helpers in.
]]

local T = ...
local eq, login, finish, root = T.eq, T.login, T.finish, T.root

-- Saved by Forever Tweaks 3.2.0: its saved variables under its old name.
ForeverTweaksDB = { version = 14, settings = {}, data = {}, quiet = true }
ForeverTweaksCharDB = { version = 2, data = {} }
ForeverPlusPlusDB = {
    plugins = { ForeverTweaksChatFade = true },
    settings = { ForeverTweaksChatFade = { buttons = "never", tabs = "never", tabsFaded = 0.3,
        input = "hover", hideDelay = 2, messages = true, messageTime = 40 } },
    profiles = { Other = { settings = { ForeverTweaksChatFade = { enabled = false, messages = true } } } },
}
W.Strict()
local ns = W.LoadAddon(root, "ForeverGearbox")
login()
eq(ForeverGearboxDB.quiet, true, "Forever Tweaks' saved variables taken over")
eq(ForeverTweaksDB, nil, "and cleared under the old name")
eq(ForeverTweaksCharDB, nil, "the character's too")
eq(ForeverGearboxDB.version, ns.member.layout, "brought up to date")
local tabs, input, fade = ns.modules.ChatTabs.db, ns.modules.ChatInput.db, ns.modules.ChatFade.db
eq(tabs.never, true, "Show Tabs Never: Always Hidden")
eq(tabs.faded, 0.3, "Faded Tabs carried over")
eq(input.show, "hover", "Show Input Box On Hover carried over")
eq(input.hideDelay, 2, "and Hide Delay")
eq(fade.enabled, true, "Fade Messages on: Fade Chat Messages on")
eq(fade.messageTime, 40, "with its time")
eq(fade.buttons, nil, "Show Buttons gone")
eq(ForeverGearboxDB.settings.ChatTabs.never, true, "taken from Forever++'s profile into Gearbox' own (3.3.0)")
finish()
