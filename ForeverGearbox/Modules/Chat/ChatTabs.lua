--[[
    Forever Gearbox - Hide Chat Tabs (module key ChatTabs)
    The chat tabs gone while the mouse is away from the chat, as Chattynator offers (no code from
    it): after Blizzard's own fade-out (FCF_FadeOutChatFrame, Blizzard_ChatFrameBase/Mainline/
    FloatingChatFrame.lua) the rest of the way, to Faded Tabs; its fade-in brings them back. A tab
    flashing for a new message stays as it is. Always Hidden hides them for good, and again
    whenever Blizzard shows them.

    Blizzard keeps the tab alphas out of addon reach on purpose (ChatFrameUtil.GetTabAlphas: they
    feed UIFrameFade, whose shared list taint would spread through), so nothing here writes the
    CHAT_FRAME_* constants or calls Blizzard's fade functions: hooks, and plain SetAlpha, Hide and
    Show on the tabs. With Chattynator loaded (it replaces the chat window) this does nothing.
]]

local _, ns = ...
local L = ns.L
local Chat = ns.ChatWindows

local AFTER_FADE = 0.1 -- past the end of Blizzard's fade-out, so its last step is done

local M = ns:NewModule("ChatTabs", {
    title = L.CHATTABS_TITLE,
    category = "chat",
    description = L.CHATTABS_DESC,
    added = "3.3.0",
    defaults = { enabled = true, never = false, faded = 0 },
    options = {
        { key = "never", type = "checkbox", label = L.CHATTABS_NEVER, tooltip = L.CHATTABS_NEVER_TIP },
        { key = "faded", type = "slider", label = L.CHATTABS_FADED, tooltip = L.CHATTABS_FADED_TIP,
          min = 0, max = 1, step = 0.05, format = function(v) return L.CHAT_PERCENT:format(v * 100) end,
          shown = function(db) return not db.never end },
    },
    notice = { Chat.ChattynatorNotice() },
})

-- Whether this does anything now: on, and Chattynator not replacing the chat window.
local function inCharge() return M.active and not Chat.Chattynator() end

-- Always Hidden: hidden, and hidden again whenever Blizzard shows it ------------------------------

local hiddenByUs = setmetatable({}, { __mode = "k" }) -- tab -> true while we keep it hidden

local function setHidden(tab, hide)
    if not tab then return end
    if hide then
        hiddenByUs[tab] = true
        tab:Hide()
    elseif hiddenByUs[tab] then
        hiddenByUs[tab] = nil
        tab:Show()
    end
end

local function onShown(_, tab)
    if hiddenByUs[tab] and inCharge() then tab:Hide() end
end

local function guardShow(tab)
    if not tab then return end
    M:Hook(tab, "Show", onShown)
    M:Hook(tab, "SetShown", onShown)
end

-- Faded: the rest of the way after Blizzard's fade ------------------------------------------------

local function finishTab(chatFrame)
    if not inCharge() or M.db.never or not Chat.FadedOut(chatFrame) then return end
    local tab = Chat.TabOf(chatFrame)
    if tab and not ChatFrameUtil.IsTabAlerting(tab) then tab:SetAlpha(M.db.faded) end
end

local function onFadeOut(_, chatFrame)
    M:After(CHAT_FRAME_FADE_OUT_TIME + AFTER_FADE, function() finishTab(chatFrame) end)
end

-- A tab redrawn (selected, a message read): back to faded if the window is faded out.
local function onTabUpdate(_, chatFrame) finishTab(chatFrame) end

-- Putting it into effect ----------------------------------------------------------------------

-- Every tab as Blizzard would have it: shown, at its own alpha.
local function restoreAll()
    Chat.Each(function(chatFrame)
        local tab = Chat.TabOf(chatFrame)
        setHidden(tab, false)
        if tab and Chat.FadedOut(chatFrame) then
            local _, noMouse = ChatFrameUtil.GetTabAlphas(tab)
            if noMouse then tab:SetAlpha(noMouse) end
        end
    end)
end

local function applyAll()
    restoreAll()
    if not inCharge() then return end
    Chat.Each(function(chatFrame)
        local tab = Chat.TabOf(chatFrame)
        guardShow(tab)
        setHidden(tab, M.db.never)
        finishTab(chatFrame)
    end)
end

function M:OnEnable()
    self:Hook("FCF_FadeOutChatFrame", onFadeOut)
    self:Hook("FCFTab_UpdateAlpha", onTabUpdate)
    -- A whisper window made later gets the same.
    self:Hook("FCF_OpenTemporaryWindow", function() self:Soon(applyAll) end)
    applyAll()
end

function M:OnDisable() restoreAll() end

function M:OnSettingChanged() applyAll() end
