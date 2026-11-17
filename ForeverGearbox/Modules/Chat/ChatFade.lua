--[[
    Forever Gearbox - Fade Chat Messages (module key ChatFade)
    Chat lines fade after a time, as Chattynator offers (no code from it): the windows'
    ScrollingMessageFrame SetFading and SetTimeVisible (Chattynator's default is 25 s), and each
    window's own timing back when turned off. Keeping them on screen for good is Forever++'s Keep
    Chat Visible: while that's on, this leaves messages to it (its description says so). With Chattynator loaded this does
    nothing. (Until 3.3.0 this was Chat Window, with the buttons, tabs and input box too: Forever++'s
    Hide Chat Buttons, Hide Chat Tabs and Hide Chat Input have those now.)
]]

local _, ns = ...
local L = ns.L
local Chat = ns.ChatWindows

-- Whether Forever++'s Keep Chat Visible is on.
local function keepChatVisible() return ns.OtherAddons.ForeverPlusPlusOn("PersistentChat") == true end

local M = ns:NewModule("ChatFade", {
    title = L.CHATFADE_TITLE,
    category = "chat",
    description = L.CHATFADE_DESC,
    added = "1.8.0",
    defaults = { enabled = false, messageTime = 25 },
    options = {
        { key = "messageTime", type = "slider", label = L.CHATFADE_MESSAGE_TIME, min = 5, max = 300, step = 5,
          format = function(v) return L.CHAT_SECONDS:format(v) end, tooltip = L.CHATFADE_MESSAGE_TIME_TIP },
    },
    notice = { Chat.ChattynatorNotice() },
})

local ownTiming = setmetatable({}, { __mode = "k" }) -- window -> { fading, seconds } before this

local function apply()
    local want = M.active and not Chat.Chattynator() and not keepChatVisible()
    Chat.Each(function(frame)
        if want then
            if not ownTiming[frame] then ownTiming[frame] = { frame:GetFading(), frame:GetTimeVisible() } end
            frame:SetFading(true)
            frame:SetTimeVisible(M.db.messageTime)
        elseif ownTiming[frame] then
            frame:SetFading(ownTiming[frame][1])
            frame:SetTimeVisible(ownTiming[frame][2])
            ownTiming[frame] = nil
        end
    end)
end

function M:OnEnable()
    -- A whisper window made later gets the same.
    self:Hook("FCF_OpenTemporaryWindow", function() self:Soon(apply) end)
    apply()
end

function M:OnDisable() apply() end

function M:OnSettingChanged() apply() end
