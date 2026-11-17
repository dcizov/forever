--[[
    Forever Gearbox - tests/scenarios/tweaks/chat.lua
    The chat modules: Hide Chat Tabs (after Blizzard's fade to Faded Tabs, a flashing tab staying,
    Always Hidden even when Blizzard shows them), Hide Chat Input (While Typing, On Hover with Hide
    Delay), Fade Chat Messages (off by default; Forever++'s Keep Chat Visible wins); Blizzard's look
    back when each is turned off; nothing while Chattynator is loaded; and the chat buttons left to
    Forever++'s Hide Chat Buttons.
    Run by tests/run.lua (lua5.1 tests/run.lua chat), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverGearbox")
login()
-- Forever++ Integration on: what this checks works with Forever++ (Core/Plugin.lua).
ns:SetEnabled("ForeverPlusPlus", true)
W.RunTimers()
local tabs, input, fade = ns.modules.ChatTabs, ns.modules.ChatInput, ns.modules.ChatFade
check(tabs.active and input.active, "Hide Chat Tabs and Hide Chat Input on by default")
eq(fade.active, false, "Fade Chat Messages off by default")
local chat, tab, box, menu = ChatFrame1, ChatFrame1Tab, ChatFrame1EditBox, ChatFrameMenuButton

-- The buttons are Forever++'s (its Hide Chat Buttons): ours is only for Forever Gearbox on its own.
eq(ns.modules.HideChatButtons, nil, "no Hide Chat Buttons of ours beside Forever++'s")
eq(menu._ignoreParentAlpha, nil, "the chat buttons are left alone")

-- Input While Typing (the default): hidden until chat starts, hidden again when it ends.
eq(box:IsShown(), false, "the input box is hidden while you're not typing")
ChatFrameUtil.ActivateChat(box)
check(box:IsShown(), "it shows when you start typing")
ChatFrameUtil.DeactivateChat(box)
W.RunTimers()
eq(box:IsShown(), false, "and goes when you're done")

-- Tabs: after Blizzard's fade, to Faded Tabs; a flashing tab stays.
W.ChatMouse(true)
W.ChatMouse(false)
W.Advance(2.2)
eq(tab._alpha, 0, "the tab fades all the way after Blizzard's fade")
W.ChatMouse(true)
W.tabAlerting = true
W.ChatMouse(false)
W.Advance(2.2)
eq(tab._alpha, 0.4, "a tab flashing for a new message isn't faded")
W.tabAlerting = false
ns:SetOption("ChatTabs", "faded", 0.5)
FCFTab_UpdateAlpha(chat)
eq(tab._alpha, 0.5, "once read, to Faded Tabs")

-- Always Hidden: hidden, even when Blizzard shows it again.
ns:SetOption("ChatTabs", "never", true)
eq(tab:IsShown(), false, "Always Hidden: the tab is hidden")
tab:Show()
eq(tab:IsShown(), false, "and stays hidden when Blizzard shows it")
ns:SetEnabled("ChatTabs", false)
check(tab:IsShown(), "off: the tab is back")
eq(tab._alpha, 0.4, "at Blizzard's own alpha")
ns:SetEnabled("ChatTabs", true)
ns:SetOption("ChatTabs", "never", false)

-- Input On Hover: shown while you point at the chat, gone Hide Delay after.
ns:SetOption("ChatInput", "show", "hover")
check(box:IsShown(), "On Hover: the input box is there")
W.ChatMouse(true)
W.Advance(0.1)
eq(box._alpha, 1, "pointing at the chat shows it")
W.ChatMouse(false)
W.Advance(0.5)
eq(box._alpha, 1, "it waits for Hide Delay")
W.Advance(1)
eq(box._alpha, 0, "and goes with the mouse")
ns:SetOption("ChatInput", "show", "typing")
eq(box:IsShown(), false, "While Typing again: hidden")
ns:SetEnabled("ChatInput", false)
check(box:IsShown(), "off: the input box is back")
eq(box._alpha, 0.35, "at Blizzard's idle alpha")
ns:SetEnabled("ChatInput", true)

-- A window without a tab is put back without asking for its tab's alphas.
local savedTab = _G.ChatFrame1Tab
_G.ChatFrame1Tab = false -- (nil would read as a global the game lacks)
chat.hasBeenFaded = nil
ns:SetEnabled("ChatTabs", false)
eq(#W.errors, 0, "no error for a window without a tab")
_G.ChatFrame1Tab = savedTab
ns:SetEnabled("ChatTabs", true)

-- Messages: on, they fade after the chosen time; off, the window's own timing.
eq(chat:GetFading(), false, "messages keep Blizzard's timing by default")
ns:SetEnabled("ChatFade", true)
eq(chat:GetFading(), true, "Fade Chat Messages on: lines fade")
eq(chat:GetTimeVisible(), 25, "after 25 seconds, as Chattynator does")

-- Forever++'s Keep Chat Visible wins.
ForeverPlusPlusAPI = { v1 = { IsModuleEnabled = function(name) return name == "PersistentChat" end } }
ns:SetOption("ChatFade", "messageTime", 30)
eq(chat:GetFading(), false, "Forever++'s Keep Chat Visible on: messages left to it")
eq(chat:GetTimeVisible(), 120, "with the window's own time")
ForeverPlusPlusAPI = nil
ns:SetEnabled("ChatFade", false)

-- Chattynator loaded: nothing.
W.loaded.Chattynator = true
ns:SetOption("ChatTabs", "never", true)
check(tab:IsShown(), "with Chattynator, Hide Chat Tabs leaves the chat alone")
ns:SetOption("ChatInput", "show", "hover")
ns:SetOption("ChatInput", "show", "typing")
check(box:IsShown(), "and Hide Chat Input too")
check(tabs.notice[1].shown(tabs.db), "and the page says why")

finish()
