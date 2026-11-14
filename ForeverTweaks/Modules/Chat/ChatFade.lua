--[[
    Forever Tweaks - Chat Window (module key ChatFade)
    Blizzard's chat window with Chattynator's choices (no code from it):

      * Show Buttons: Always (at full, where Blizzard dims them to 0.2 when the mouse leaves),
        On Hover (faded to Faded Buttons while the mouse is away, back when you point at the
        chat) or Never. The buttons are the children of each window's button strip; they ignore
        the strip's alpha (SetIgnoreParentAlpha), which Blizzard fades (FCF_FadeOutChatFrame,
        Blizzard_ChatFrameBase/Mainline/FloatingChatFrame.lua) and never fades back for a docked
        window. Whether the mouse is on a window is read here twenty times a second while On Hover
        is used (its own fade, Hide Delay after the mouse leaves), as Blizzard's FCF_OnUpdate does.
      * Show Tabs: Always (Blizzard's), On Hover (after Blizzard's fade-out, to Faded Tabs; its
        fade-in brings them back) or Never. A tab flashing for a new message stays as it is.
      * Show Input Box: Always (Blizzard's "im" style: 0.35 while you're not typing,
        ChatFrameEditBoxMixin:Deactivate), On Hover, or While Typing (shown by
        ChatFrameUtil.ActivateChat, hidden again by DeactivateChat, as Chattynator does).
      * Fade Messages after a time (the windows' ScrollingMessageFrame SetFading and
        SetTimeVisible; Chattynator's default is 25 s), or Keep Messages: they never fade (as
        Forever++'s Keep Chat Visible does). While Forever++'s is on, this leaves messages to it.

    Blizzard keeps the tab alphas out of addon reach on purpose (ChatFrameUtil.GetTabAlphas: they
    feed UIFrameFade, whose shared list taint would spread through), so nothing here writes the
    CHAT_FRAME_* constants or calls Blizzard's fade functions: hooks, and plain SetAlpha, Hide and
    Show on the frames. With Chattynator loaded (it replaces the chat window) this does nothing.
]]

local _, ns = ...
local L = ns.L

local pairs, ipairs, math = pairs, ipairs, math

local INPUT_IDLE_ALPHA = 0.35 -- Blizzard's input box while you're not typing (Deactivate)
local AFTER_FADE = 0.1        -- past the end of Blizzard's fade-out, so its last step is done
local TICK = 0.05             -- how often the mouse is checked while On Hover is used
local FADE_IN, FADE_OUT = 0.15, 0.5 -- seconds, as Blizzard's CHAT_FRAME_FADE_TIME and a softer out
local TOP_EDGE = 28           -- the tabs above a window count as on it (FCF_OnUpdate's topOffset)

-- Whether Forever++'s Keep Chat Visible is on.
local function keepChatVisible() return ns.OtherAddons.ForeverPlusPlusOn("PersistentChat") == true end

local function chattynator() return ns.OtherAddons.Loaded("Chattynator") end

local SHOW_CHOICES = { { "always", L.CHATFADE_ALWAYS }, { "hover", L.CHATFADE_HOVER }, { "never", L.CHATFADE_NEVER } }
local function percent(v) return L.CHATFADE_PERCENT:format(v * 100) end

local M = ns:NewModule("ChatFade", {
    title = L.CHATFADE_TITLE,
    category = "chat",
    description = L.CHATFADE_DESC,
    added = "1.8.0",
    defaults = { enabled = true, buttons = "hover", buttonsFaded = 0, tabs = "hover", tabsFaded = 0,
        hideDelay = 1, input = "typing", messages = false, messageTime = 25, keepMessages = false },
    options = {
        { key = "buttons", type = "dropdown", label = L.CHATFADE_BUTTONS, tooltip = L.CHATFADE_BUTTONS_TIP,
          choices = SHOW_CHOICES, section = L.CHATFADE_SECTION_WINDOW },
        { key = "buttonsFaded", type = "slider", label = L.CHATFADE_BUTTONS_FADED, tooltip = L.CHATFADE_FADED_TIP,
          min = 0, max = 1, step = 0.05, format = percent, shown = function(db) return db.buttons == "hover" end },
        { key = "tabs", type = "dropdown", label = L.CHATFADE_TABS, tooltip = L.CHATFADE_TABS_TIP,
          choices = SHOW_CHOICES },
        { key = "tabsFaded", type = "slider", label = L.CHATFADE_TABS_FADED, tooltip = L.CHATFADE_FADED_TIP,
          min = 0, max = 1, step = 0.05, format = percent, shown = function(db) return db.tabs == "hover" end },
        { key = "hideDelay", type = "slider", label = L.CHATFADE_DELAY, tooltip = L.CHATFADE_DELAY_TIP,
          min = 0, max = 5, step = 0.5, format = function(v) return L.CHATFADE_SECONDS_DECIMAL:format(v) end,
          shown = function(db) return db.buttons == "hover" or db.input == "hover" end },
        { key = "input", type = "dropdown", label = L.CHATFADE_INPUT, tooltip = L.CHATFADE_INPUT_TIP,
          choices = { { "always", L.CHATFADE_ALWAYS }, { "hover", L.CHATFADE_HOVER }, { "typing", L.CHATFADE_TYPING } } },
        { key = "messages", type = "checkbox", label = L.CHATFADE_MESSAGES, tooltip = L.CHATFADE_MESSAGES_TIP,
          slider = "messageTime", section = L.CHATFADE_SECTION_MESSAGES },
        { key = "messageTime", type = "slider", label = L.CHATFADE_MESSAGE_TIME, min = 5, max = 300, step = 5,
          format = function(v) return L.CHATFADE_SECONDS:format(v) end, tooltip = L.CHATFADE_MESSAGE_TIME_TIP },
        { key = "keepMessages", type = "checkbox", label = L.CHATFADE_KEEP, tooltip = L.CHATFADE_KEEP_TIP, added = "2.2.0",
          conflicts = { { key = "messages", when = function(db) return db.keepMessages and db.messages end,
              text = L.CHATFADE_KEEP_CONFLICT } } },
    },
    notice = {
        { text = L.CHATFADE_CHATTYNATOR, shown = chattynator, addon = "Chattynator", advice = L.CHATFADE_ADVICE_CHATTYNATOR },
        { text = L.CHATFADE_KEEP_VISIBLE, shown = function(db) return (db.messages or db.keepMessages) and keepChatVisible() end,
          addon = "ForeverPlusPlus", advice = L.CHATFADE_ADVICE_KEEP_VISIBLE,
          button = L.OPEN_FOREVERPP, fn = function() ns.OtherAddons.OpenForeverPlusPlus("PersistentChat") end },
    },
})

local function eachWindow(fn)
    for _, name in pairs(CHAT_FRAMES) do
        local frame = _G[name]
        if frame then fn(frame) end
    end
end

local function tabOf(chatFrame) return _G[chatFrame:GetName() .. "Tab"] end

-- The mouse is away from the window: Blizzard has faded it (hasBeenFaded is set while it's in).
local function fadedOut(chatFrame) return not chatFrame.hasBeenFaded end

-- Whether this does anything now: on, and Chattynator not replacing the chat window.
local function inCharge() return M.active and not chattynator() end

-- Never: hidden, and hidden again whenever Blizzard shows it --------------------------------------

local hiddenByUs = setmetatable({}, { __mode = "k" }) -- frame -> true while we keep it hidden

-- hide: hidden, and kept hidden; false: shown again if it was us who hid it.
local function setHiddenByUs(frame, hide)
    if not frame then return end
    if hide then
        hiddenByUs[frame] = true
        frame:Hide()
    elseif hiddenByUs[frame] then
        hiddenByUs[frame] = nil
        frame:Show()
    end
end

local function onShown(_, frame)
    if hiddenByUs[frame] and inCharge() then frame:Hide() end
end

local function guardShow(frame)
    if not frame then return end
    M:Hook(frame, "Show", onShown)
    M:Hook(frame, "SetShown", onShown)
end

-- The buttons: free of the strip's alpha, at full (Always) or faded by the mouse (On Hover) --------

local freed = setmetatable({}, { __mode = "k" }) -- button -> true while it ignores the strip's alpha

local function eachButton(chatFrame, fn)
    local strip = chatFrame.buttonFrame
    if not strip then return end
    for _, button in ipairs({ strip:GetChildren() }) do fn(button) end
end

local function setButtons(chatFrame, alpha)
    eachButton(chatFrame, function(button)
        if not freed[button] then
            freed[button] = true
            button:SetIgnoreParentAlpha(true)
        end
        button:SetAlpha(alpha)
    end)
end

local function releaseButtons(chatFrame)
    eachButton(chatFrame, function(button)
        if freed[button] then
            freed[button] = nil
            button:SetIgnoreParentAlpha(false)
            button:SetAlpha(1)
        end
    end)
end

-- Whether the mouse is on a window (its tabs, buttons and input box too), or you're typing in it.
local function mouseOn(chatFrame)
    local box, strip, tab = chatFrame.editBox, chatFrame.buttonFrame, tabOf(chatFrame)
    return chatFrame:IsMouseOver(TOP_EDGE, -2, -2, 2) or (strip and strip:IsMouseOver())
        or (tab and tab:IsMouseOver()) or (box and (box:HasFocus() or box:IsMouseOver())) or false
end

local fade = setmetatable({}, { __mode = "k" }) -- window -> { alpha, lastOn }

-- One step of a window's hover fade: toward full while the mouse is on it, toward the faded
-- alpha Hide Delay after it left.
local function stepHover(chatFrame, now)
    local state = fade[chatFrame]
    if not state then
        state = { alpha = 1, lastOn = now }
        fade[chatFrame] = state
    end
    if mouseOn(chatFrame) then state.lastOn = now end
    local on = now - state.lastOn <= M.db.hideDelay
    local floor = M.db.buttonsFaded
    local target = on and 1 or floor
    if state.alpha < target then
        state.alpha = math.min(target, state.alpha + TICK / FADE_IN)
    elseif state.alpha > target then
        state.alpha = math.max(target, state.alpha - TICK / FADE_OUT)
    end
    if M.db.buttons == "hover" then setButtons(chatFrame, state.alpha) end
    local box = chatFrame.editBox
    if M.db.input == "hover" and box and not box:HasFocus() then box:SetAlpha(on and 1 or 0) end
end

local ticker

local function tick()
    if not inCharge() then return end
    local now = GetTime()
    eachWindow(function(chatFrame)
        if chatFrame:IsShown() then stepHover(chatFrame, now) end
    end)
end

-- The mouse is read only while something follows it.
local function syncTicker()
    local want = inCharge() and (M.db.buttons == "hover" or M.db.input == "hover")
    if want and not M:IsPending(ticker) then
        ticker = M:NewTicker(TICK, tick)
    elseif not want then
        M:CancelTimer(ticker)
    end
end

-- Tabs: the rest of the way after Blizzard's fade ------------------------------------------------

local function finishTab(chatFrame)
    if not inCharge() or M.db.tabs ~= "hover" or not fadedOut(chatFrame) then return end
    local tab = tabOf(chatFrame)
    if tab and not ChatFrameUtil.IsTabAlerting(tab) then tab:SetAlpha(M.db.tabsFaded) end
end

local function onFadeOut(_, chatFrame)
    M:After(CHAT_FRAME_FADE_OUT_TIME + AFTER_FADE, function() finishTab(chatFrame) end)
end

-- A tab redrawn (selected, a message read): back to faded if the window is faded out.
local function onTabUpdate(_, chatFrame) finishTab(chatFrame) end

-- The input box While Typing: shown when chat activates, hidden when it's done (and once more
-- on the next frame, as Blizzard may show it again on the way out) -------------------------------

local function hideIdle(box)
    if inCharge() and M.db.input == "typing" and box and not box:HasFocus() then box:Hide() end
end

-- Every window's idle input box hidden (one function, so a burst of deactivations is one redo).
local function hideIdleBoxes()
    eachWindow(function(chatFrame) hideIdle(chatFrame.editBox) end)
end

local function onDeactivate(_, box)
    hideIdle(box)
    M:Soon(hideIdleBoxes)
end

local function onActivate(_, box)
    if inCharge() and M.db.input == "typing" then box:Show() end
end

-- Messages ----------------------------------------------------------------------------------------

local ownTiming = setmetatable({}, { __mode = "k" }) -- window -> { fading, seconds } before this

local function applyMessages()
    local mine = inCharge() and not keepChatVisible()
    local keep = mine and M.db.keepMessages
    local want = mine and (keep or M.db.messages)
    eachWindow(function(frame)
        if want then
            if not ownTiming[frame] then ownTiming[frame] = { frame:GetFading(), frame:GetTimeVisible() } end
            frame:SetFading(not keep)
            if not keep then frame:SetTimeVisible(M.db.messageTime) end
        elseif ownTiming[frame] then
            frame:SetFading(ownTiming[frame][1])
            frame:SetTimeVisible(ownTiming[frame][2])
            ownTiming[frame] = nil
        end
    end)
end

-- Putting it into effect ----------------------------------------------------------------------

-- Every window as Blizzard would have it: shown, the buttons following their strip again, tabs at
-- their own alphas, the primary input box shown at its idle alpha.
local function restoreAll()
    eachWindow(function(chatFrame)
        setHiddenByUs(chatFrame.buttonFrame, false)
        setHiddenByUs(tabOf(chatFrame), false)
        releaseButtons(chatFrame)
        if not fadedOut(chatFrame) then return end
        local tab = tabOf(chatFrame)
        if tab then
            local _, noMouse = ChatFrameUtil.GetTabAlphas(tab)
            if noMouse then tab:SetAlpha(noMouse) end
        end
        local box = chatFrame.editBox
        if box and not box:HasFocus() then box:SetAlpha(INPUT_IDLE_ALPHA) end
    end)
    local box = ChatFrame1.editBox
    if box and not box:IsShown() then box:Show() end
end

local function applyAll()
    restoreAll()
    if inCharge() then
        eachWindow(function(chatFrame)
            guardShow(chatFrame.buttonFrame)
            guardShow(tabOf(chatFrame))
            setHiddenByUs(chatFrame.buttonFrame, M.db.buttons == "never")
            setHiddenByUs(tabOf(chatFrame), M.db.tabs == "never")
            if M.db.buttons == "always" then setButtons(chatFrame, 1) end
            hideIdle(chatFrame.editBox)
            finishTab(chatFrame)
        end)
    end
    syncTicker()
    tick()
    applyMessages()
end

function M:OnEnable()
    self:Hook("FCF_FadeOutChatFrame", onFadeOut)
    self:Hook("FCFTab_UpdateAlpha", onTabUpdate)
    self:Hook(ChatFrameUtil, "DeactivateChat", onDeactivate)
    self:Hook(ChatFrameUtil, "ActivateChat", onActivate)
    -- A whisper window made later gets the same.
    self:Hook("FCF_OpenTemporaryWindow", function() self:Soon(applyAll) end)
    applyAll()
end

function M:OnDisable()
    fade = setmetatable({}, { __mode = "k" })
    restoreAll()
    applyMessages()
end

function M:OnSettingChanged()
    applyAll()
end
