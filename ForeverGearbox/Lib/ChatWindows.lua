--[[
    Forever Gearbox - Lib/ChatWindows.lua
    What the chat modules (Chat Tabs, Chat Input, Fade Chat Messages) share about Blizzard's chat
    windows: each window, its tab, whether the mouse is on it, and whether Chattynator (which
    replaces the chat window) is loaded, when they stand down.
]]

local _, ns = ...

local pairs = pairs

local ChatWindows = {}
ns.ChatWindows = ChatWindows

ChatWindows.TOP_EDGE = 28 -- the tabs above a window count as on it (FCF_OnUpdate's topOffset)

function ChatWindows.Each(fn)
    for _, name in pairs(CHAT_FRAMES) do
        local frame = _G[name]
        if frame then fn(frame) end
    end
end

function ChatWindows.TabOf(chatFrame) return _G[chatFrame:GetName() .. "Tab"] end

-- The mouse is away from the window: Blizzard has faded it (hasBeenFaded is set while it's in).
function ChatWindows.FadedOut(chatFrame) return not chatFrame.hasBeenFaded end

-- Whether the mouse is on a window (its tabs, buttons and input box too), or you're typing in it.
function ChatWindows.MouseOn(chatFrame)
    local box, strip, tab = chatFrame.editBox, chatFrame.buttonFrame, ChatWindows.TabOf(chatFrame)
    return chatFrame:IsMouseOver(ChatWindows.TOP_EDGE, -2, -2, 2) or (strip and strip:IsMouseOver())
        or (tab and tab:IsMouseOver()) or (box and (box:HasFocus() or box:IsMouseOver())) or false
end

function ChatWindows.Chattynator() return ns.OtherAddons.Loaded("Chattynator") end

-- The notice each chat module shows while Chattynator replaces the chat window.
function ChatWindows.ChattynatorNotice()
    local L = ns.L
    return { text = L.CHAT_CHATTYNATOR, shown = ChatWindows.Chattynator, addon = "Chattynator",
        advice = L.CHAT_ADVICE_CHATTYNATOR }
end
