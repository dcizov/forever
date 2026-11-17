--[[
    Forever Gearbox - Hide Chat Input (module key ChatInput)
    The box you type in out of sight while you don't use it, as Chattynator offers (no code from
    it): While Typing, it's shown by ChatFrameUtil.ActivateChat (Enter) and hidden again by
    DeactivateChat; On Hover, it's also there while the mouse is on the chat, and goes Hide Delay
    after it leaves (read twenty times a second, as Blizzard's FCF_OnUpdate does). Turned off,
    Blizzard's "im" style is back: shown at 0.35 while you're not typing
    (ChatFrameEditBoxMixin:Deactivate). With Chattynator loaded this does nothing.
]]

local _, ns = ...
local L = ns.L
local Chat = ns.ChatWindows

local INPUT_IDLE_ALPHA = 0.35 -- Blizzard's input box while you're not typing (Deactivate)
local TICK = 0.05             -- how often the mouse is checked On Hover

local M = ns:NewModule("ChatInput", {
    title = L.CHATINPUT_TITLE,
    category = "chat",
    description = L.CHATINPUT_DESC,
    added = "3.3.0",
    defaults = { enabled = true, show = "typing", hideDelay = 1 },
    options = {
        { key = "show", type = "dropdown", label = L.CHATINPUT_SHOW, tooltip = L.CHATINPUT_SHOW_TIP,
          choices = { { "typing", L.CHATINPUT_TYPING }, { "hover", L.CHATINPUT_HOVER } } },
        { key = "hideDelay", type = "slider", label = L.CHATINPUT_DELAY, tooltip = L.CHATINPUT_DELAY_TIP,
          min = 0, max = 5, step = 0.5, format = function(v) return L.CHAT_SECONDS_DECIMAL:format(v) end,
          shown = function(db) return db.show == "hover" end },
    },
    notice = { Chat.ChattynatorNotice() },
})

local function inCharge() return M.active and not Chat.Chattynator() end

-- While Typing: shown when chat activates, hidden when it's done (and once more on the next frame,
-- as Blizzard may show it again on the way out) ---------------------------------------------------

local function hideIdle(box)
    if inCharge() and M.db.show == "typing" and box and not box:HasFocus() then box:Hide() end
end

-- Every window's idle input box hidden (one function, so a burst of deactivations is one redo).
local function hideIdleBoxes()
    Chat.Each(function(chatFrame) hideIdle(chatFrame.editBox) end)
end

local function onDeactivate(_, box)
    hideIdle(box)
    M:Soon(hideIdleBoxes)
end

local function onActivate(_, box)
    if inCharge() and M.db.show == "typing" then box:Show() end
end

-- On Hover: there while the mouse is on the chat, gone Hide Delay after it left -------------------

local lastOn = setmetatable({}, { __mode = "k" }) -- window -> when the mouse was last on it

local function tick()
    if not inCharge() then return end
    local now = GetTime()
    Chat.Each(function(chatFrame)
        local box = chatFrame.editBox
        if not (chatFrame:IsShown() and box) then return end
        if Chat.MouseOn(chatFrame) or not lastOn[chatFrame] then lastOn[chatFrame] = now end
        if not box:HasFocus() then box:SetAlpha(now - lastOn[chatFrame] <= M.db.hideDelay and 1 or 0) end
    end)
end

local ticker

-- The mouse is read only while On Hover is chosen.
local function syncTicker()
    local want = inCharge() and M.db.show == "hover"
    if want and not M:IsPending(ticker) then
        ticker = M:NewTicker(TICK, tick)
    elseif not want then
        M:CancelTimer(ticker)
    end
end

-- Putting it into effect ----------------------------------------------------------------------

-- Every input box as Blizzard would have it: at its idle alpha, the primary one shown.
local function restoreAll()
    Chat.Each(function(chatFrame)
        local box = chatFrame.editBox
        if box and not box:HasFocus() then box:SetAlpha(INPUT_IDLE_ALPHA) end
    end)
    local box = ChatFrame1.editBox
    if box and not box:IsShown() then box:Show() end
end

local function applyAll()
    restoreAll()
    if inCharge() then hideIdleBoxes() end
    syncTicker()
    tick()
end

function M:OnEnable()
    self:Hook(ChatFrameUtil, "DeactivateChat", onDeactivate)
    self:Hook(ChatFrameUtil, "ActivateChat", onActivate)
    -- A whisper window made later gets the same.
    self:Hook("FCF_OpenTemporaryWindow", function() self:Soon(applyAll) end)
    applyAll()
end

function M:OnDisable()
    lastOn = setmetatable({}, { __mode = "k" })
    restoreAll()
end

function M:OnSettingChanged() applyAll() end
