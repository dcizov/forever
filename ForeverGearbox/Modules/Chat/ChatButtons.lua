--[[
    Forever Gearbox - Hide Chat Buttons (module key ChatButtons)
    The buttons beside the chat (each window's button strip: scrolling, the chat menu, channels,
    voice; and the social button over the first window) fade out with Blizzard's own fade of the
    chat once the mouse leaves it, to Faded Buttons, and come back as it fades in again. Our own
    code (nothing of Forever++'s): Blizzard's fade-in and fade-out are hooked as Hide Chat Tabs
    hooks them (Blizzard_ChatFrameBase FloatingChatFrame.lua), and the strips are faded with plain
    SetAlpha steps of ours, never UIFrameFade (its shared list would spread taint). With
    Chattynator loaded (it replaces the chat window) this does nothing.
]]

local _, ns = ...

local L = ns.L
local Chat = ns.ChatWindows

local pairs, next, math = pairs, next, math

local STEP = 0.03       -- seconds between fade steps
local FADE_IN = 0.15    -- seconds to come back
local FADE_OUT = 0.4    -- seconds to fade, once Blizzard has faded the window

local M = ns:NewModule("ChatButtons", {
    title = L.CHATBUTTONS_TITLE,
    category = "chat",
    description = L.CHATBUTTONS_DESC,
    added = "3.3.0",
    defaults = { enabled = true, faded = 0 },
    options = {
        { key = "faded", type = "slider", label = L.CHATBUTTONS_FADED, tooltip = L.CHATBUTTONS_FADED_TIP,
          min = 0, max = 1, step = 0.05, format = function(v) return L.CHAT_PERCENT:format(v * 100) end },
    },
    notice = { Chat.ChattynatorNotice() },
})

local function inCharge() return M.active and not Chat.Chattynator() end

local targets = {}  -- frame -> the alpha it's fading to
local ticker

-- The frames a window's fade carries: its button strip, and the social button with the first.
local function framesOf(chatFrame)
    local list = { chatFrame.buttonFrame }
    if chatFrame == ChatFrame1 and QuickJoinToastButton then list[2] = QuickJoinToastButton end
    return list
end

local function step()
    local busy = false
    for frame, target in pairs(targets) do
        local now = frame:GetAlpha()
        local speed = STEP / (target > now and FADE_IN or FADE_OUT)
        local nextAlpha = target > now and math.min(target, now + speed) or math.max(target, now - speed)
        frame:SetAlpha(nextAlpha)
        if nextAlpha == target then targets[frame] = nil else busy = true end
    end
    if not busy and ticker then
        M:CancelTimer(ticker)
        ticker = nil
    end
end

local function fadeTo(chatFrame, alpha)
    for _, frame in pairs(framesOf(chatFrame)) do
        if frame:GetAlpha() ~= alpha then targets[frame] = alpha end
    end
    if not ticker and next(targets) then ticker = M:NewTicker(STEP, step) end
end

local function onFadeIn(_, chatFrame)
    if inCharge() then fadeTo(chatFrame, 1) end
end

local function onFadeOut(_, chatFrame)
    if not inCharge() then return end
    M:After(CHAT_FRAME_FADE_OUT_TIME, function()
        if inCharge() and Chat.FadedOut(chatFrame) then fadeTo(chatFrame, M.db.faded) end
    end)
end

-- Every window's buttons as they should be now: faded where the window is, else shown.
local function applyAll()
    Chat.Each(function(chatFrame)
        local faded = inCharge() and Chat.FadedOut(chatFrame) and not Chat.MouseOn(chatFrame)
        for _, frame in pairs(framesOf(chatFrame)) do
            targets[frame] = nil
            frame:SetAlpha(faded and M.db.faded or 1)
        end
    end)
end

function M:OnEnable()
    self:Hook("FCF_FadeInChatFrame", onFadeIn)
    self:Hook("FCF_FadeOutChatFrame", onFadeOut)
    self:Hook("FCF_OpenTemporaryWindow", function() self:Soon(applyAll) end)
    applyAll()
end

function M:OnDisable()
    ticker = nil
    applyAll()
end

function M:OnSettingChanged() applyAll() end
