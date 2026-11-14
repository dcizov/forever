--[[
    Forever Tweaks - tests/scenarios/tweaks/chatfade.lua
    Chat Window (the ChatFade module): buttons free of Blizzard's dimming, at full (Always) or
    faded by the mouse with Hide Delay and Faded Buttons (On Hover), hidden (Never); tabs after
    Blizzard's fade to Faded Tabs, a flashing tab staying; the input box While Typing and On Hover;
    message fading and Forever++'s Keep Chat Visible; Blizzard's look back when turned off; and
    nothing while Chattynator is loaded.
    Run by tests/run.lua (lua5.1 tests/run.lua chatfade), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverTweaks")
login()
local mod = ns.modules.ChatFade
check(mod.active, "on by default")
local chat, tab, box, menu = ChatFrame1, ChatFrame1Tab, ChatFrame1EditBox, ChatFrameMenuButton

-- While Typing (the default): hidden until chat starts, hidden again when it ends.
eq(box:IsShown(), false, "the input box is hidden while you're not typing")
ChatFrameUtil.ActivateChat(box)
check(box:IsShown(), "it shows when you start typing")
ChatFrameUtil.DeactivateChat(box)
W.RunTimers()
eq(box:IsShown(), false, "and goes when you're done")

-- Buttons On Hover (the default): free of Blizzard's dimming, following the mouse.
eq(menu._ignoreParentAlpha, true, "the buttons don't follow Blizzard's dimming of their strip")
W.ChatMouse(true)
W.Advance(0.5)
eq(menu._alpha, 1, "pointing at the chat: the buttons at full")
W.ChatMouse(false)
W.Advance(0.5)
eq(menu._alpha, 1, "they wait for Hide Delay after the mouse leaves")
W.Advance(1.5)
eq(menu._alpha, 0, "then fade all the way")
ns:SetOption("ChatFade", "buttonsFaded", 0.3)
W.Advance(1)
check(math.abs(menu._alpha - 0.3) < 0.001, "or to Faded Buttons")
W.ChatMouse(true)
W.Advance(0.3)
eq(menu._alpha, 1, "and come back when you point at the chat")

-- Tabs On Hover: after Blizzard's fade, to Faded Tabs; a flashing tab stays.
W.ChatMouse(false)
W.Advance(2.2)
eq(tab._alpha, 0, "the tab fades all the way after Blizzard's fade")
W.ChatMouse(true)
W.tabAlerting = true
W.ChatMouse(false)
W.Advance(2.2)
eq(tab._alpha, 0.4, "a tab flashing for a new message isn't faded")
W.tabAlerting = false
ns:SetOption("ChatFade", "tabsFaded", 0.5)
FCFTab_UpdateAlpha(chat)
eq(tab._alpha, 0.5, "once read, to Faded Tabs")

-- Input On Hover: shown while you point at the chat.
ns:SetOption("ChatFade", "input", "hover")
check(box:IsShown(), "On Hover: the input box is there")
W.ChatMouse(true)
W.Advance(0.1)
eq(box._alpha, 1, "pointing at the chat shows it")
W.ChatMouse(false)
W.Advance(2)
eq(box._alpha, 0, "and it goes with the mouse")

-- Always: the buttons at full, though Blizzard dims their strip.
ns:SetOption("ChatFade", "buttons", "always")
eq(menu._alpha, 1, "Always: the buttons at full")
eq(menu._ignoreParentAlpha, true, "whatever Blizzard does to their strip")

-- Never: hidden, even when Blizzard shows them again.
ns:SetOption("ChatFade", "buttons", "never")
eq(chat.buttonFrame:IsShown(), false, "Never: the buttons are hidden")
chat.buttonFrame:Show()
eq(chat.buttonFrame:IsShown(), false, "and stay hidden when Blizzard shows them")
ns:SetOption("ChatFade", "tabs", "never")
eq(tab:IsShown(), false, "Never: the tab is hidden")
ns:SetOption("ChatFade", "tabs", "always")
check(tab:IsShown(), "Always: the tab is back")

-- Messages: off by default; on, they fade after the chosen time.
eq(chat:GetFading(), false, "messages keep Blizzard's timing by default")
ns:SetOption("ChatFade", "messages", true)
eq(chat:GetFading(), true, "Fade Messages on: lines fade")
eq(chat:GetTimeVisible(), 25, "after 25 seconds, as Chattynator does")

-- Forever++'s Keep Chat Visible wins.
ForeverPlusPlusAPI = { v1 = { IsModuleEnabled = function(name) return name == "PersistentChat" end } }
ns:SetOption("ChatFade", "messageTime", 30)
eq(chat:GetFading(), false, "Forever++'s Keep Chat Visible on: messages left to it")
eq(chat:GetTimeVisible(), 120, "with the window's own time")
check(mod.notice[2].shown(mod.db), "and the page says why")
ForeverPlusPlusAPI = nil

-- A window without a tab is put back without asking for its tab's alphas.
local savedTab = _G.ChatFrame1Tab
_G.ChatFrame1Tab = false -- (nil would read as a global the game lacks)
chat.hasBeenFaded = nil
ns:SetEnabled("ChatFade", false)
eq(#W.errors, 0, "no error for a window without a tab")
_G.ChatFrame1Tab = savedTab
ns:SetEnabled("ChatFade", true)

-- Turned off: Blizzard's look back.
ns:SetEnabled("ChatFade", false)
check(chat.buttonFrame:IsShown(), "off: the buttons are back")
eq(menu._ignoreParentAlpha, false, "following their strip again")
check(box:IsShown(), "and the input box")
ns:SetEnabled("ChatFade", true)

-- Chattynator loaded: nothing.
W.loaded.Chattynator = true
ns:SetOption("ChatFade", "buttons", "hover")
check(chat.buttonFrame:IsShown(), "with Chattynator, Chat Window leaves the chat alone")
check(mod.notice[1].shown(mod.db), "and the page says why")

finish()
