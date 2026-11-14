--[[
    Forever Tweaks - tests/stubs/chat.lua
    The stand-in game's chat window (Blizzard_ChatFrameBase): ChatFrame1 with its button strip,
    tab and input box, and Blizzard's fades, which set what Mainline's FloatingChatFrame.lua does
    at their end. W.ChatMouse(over) moves the mouse onto or off the chat.
]]

CHAT_FRAME_FADE_OUT_TIME = 2.0
CHAT_FRAME_BUTTON_FRAME_MIN_ALPHA = 0.2
CHAT_FRAMES = { "ChatFrame1" }

local chat = W.NewFrame("ScrollingMessageFrame", "ChatFrame1", UIParent)
chat.buttonFrame = W.NewFrame("Frame", "ChatFrame1ButtonFrame", chat)
chat.editBox = W.NewFrame("EditBox", "ChatFrame1EditBox", chat)
chat.editBox.chatFrame = chat
-- Its buttons, children of the strip (ChatFrameMenuButton, ChatFrameChannelButton).
W.NewFrame("Button", "ChatFrameMenuButton", chat.buttonFrame)
W.NewFrame("Button", "ChatFrameChannelButton", chat.buttonFrame)
W.chatHover = false
function chat:IsMouseOver() return W.chatHover end
local tab = W.NewFrame("Button", "ChatFrame1Tab", UIParent)
chat._fading, chat._timeVisible = false, 120
function chat:GetFading() return self._fading end
function chat:SetFading(v) self._fading = v end
function chat:GetTimeVisible() return self._timeVisible end
function chat:SetTimeVisible(v) self._timeVisible = v end
function chat.editBox:HasFocus() return self._focus or false end
function chat.editBox:Deactivate() self._focus = false; self:SetAlpha(0.35) end

W.tabAlerting = false
ChatFrameUtil.IsTabAlerting = function() return W.tabAlerting end
ChatFrameUtil.GetTabAlphas = function(tab) assert(tab, "GetTabAlphas: no tab") return 1, 0.4 end
-- Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua: typing starts and ends.
function ChatFrameUtil.ActivateChat(box) box._focus = true; box:Show(); box:SetAlpha(1) end
function ChatFrameUtil.DeactivateChat(box) box:Deactivate() end

-- ChatFrame1 is docked (the dock's first window): Blizzard leaves its buttons alone when fading.
chat.isDocked = true
function FCF_FadeInChatFrame(chatFrame)
    chatFrame.hasBeenFaded = true
    if not chatFrame.isDocked then chatFrame.buttonFrame:SetAlpha(1) end
    _G[chatFrame:GetName() .. "Tab"]:SetAlpha(1)
end
function FCF_FadeOutChatFrame(chatFrame)
    chatFrame.hasBeenFaded = nil
    if not chatFrame.isDocked then chatFrame.buttonFrame:SetAlpha(CHAT_FRAME_BUTTON_FRAME_MIN_ALPHA) end
    _G[chatFrame:GetName() .. "Tab"]:SetAlpha(0.4)
end
function FCFTab_UpdateAlpha(chatFrame)
    _G[chatFrame:GetName() .. "Tab"]:SetAlpha(chatFrame.hasBeenFaded and 1 or 0.4)
end
function FCF_OpenTemporaryWindow() end
function FCF_SetChatWindowFontSize() end

-- The window's lines (ScrollingMessageFrame): W.ChatLines() reads them back as shown. A line from
-- an event carries its chat type id (GetChatTypeIndex), as Blizzard's AddMessage passes it.
NUM_CHAT_WINDOWS = 10
COMBATLOG = W.NewFrame("ScrollingMessageFrame", "ChatFrame2", UIParent)
chat._fontFile, chat._fontSize = "Fonts\\ARIALN.TTF", 14
chat._lines = {}
local TYPE_IDS = { SAY = 1, WHISPER = 7, WHISPER_INFORM = 8, BN_WHISPER = 51, BN_WHISPER_INFORM = 52, CHANNEL = 17 }
function GetChatTypeIndex(chatType) return TYPE_IDS[chatType] end
function chat:AddMessage(text, r, g, b, chatTypeID) table.insert(self._lines, { text, r or 1, g or 1, b or 1, chatTypeID }) end
function chat:GetNumMessages() return #self._lines end
function chat:GetMessageInfo(i) return unpack(self._lines[i]) end
function chat:TransformMessages(test, rewrite)
    for _, line in ipairs(self._lines) do
        if test(line[1]) then line[1] = rewrite(line[1]) end
    end
end
for _, method in ipairs({ "AddMessage", "GetNumMessages", "GetMessageInfo", "TransformMessages" }) do
    COMBATLOG[method] = chat[method]
end
COMBATLOG._lines = {}
-- The other numbered windows exist too (the game makes all ten), empty and closed.
for i = 3, NUM_CHAT_WINDOWS do
    local other = W.NewFrame("ScrollingMessageFrame", "ChatFrame" .. i, UIParent)
    for _, method in ipairs({ "AddMessage", "GetNumMessages", "GetMessageInfo", "TransformMessages" }) do
        other[method] = chat[method]
    end
    other._lines = {}
end
function W.ChatLines()
    local list = {}
    for i, line in ipairs(chat._lines) do list[i] = line[1] end
    return list
end
-- Blizzard's AddMessage for a chat event: the line, then the hooks a frame later (W.RunTimers).
function W.ChatSay(text, chatType) chat:AddMessage(text, 1, 1, 1, TYPE_IDS[chatType or "SAY"]) end

-- The input box: the alt arrow key mode, the header while typing ("[2. Trade]: ").
local box = chat.editBox
box._altArrows = true
function box:GetAltArrowKeyMode() return self._altArrows end
function box:SetAltArrowKeyMode(on) self._altArrows = on end
box.header = W.NewFrame("FontString", "ChatFrame1EditBoxHeader", box)
box.headerSuffix = W.NewFrame("FontString", "ChatFrame1EditBoxHeaderSuffix", box)
box._chatType, box._insets, box._cursor = "SAY", { 60, 0, 0, 0 }, 0
function box:GetChatType() return self._chatType end
function box:GetChannelTarget() return self._channelTarget end
function box:GetTextInsets() return unpack(self._insets) end
function box:SetTextInsets(...) self._insets = { ... } end
function box:GetCursorPosition() return self._cursor end
function box:SetCursorPosition(at) self._cursor = at end
function box:UpdateHeader() end
W.channels = { [2] = "Trade - City" }
function GetChannelName(id)
    local name = W.channels[id]
    if name then return id, name, 0 end
    return 0, nil, 0
end
CHAT_GUILD_GET = "|Hchannel:GUILD|h[Guild]|h %s: "
CHAT_PARTY_GET = "|Hchannel:PARTY|h[Party]|h %s: "
CHAT_OFFICER_GET = "|Hchannel:OFFICER|h[Officer]|h %s: "
CHAT_PARTY_LEADER_GET = "|Hchannel:PARTY|h[Party Leader]|h %s: "
CHAT_PARTY_GUIDE_GET = "|Hchannel:PARTY|h[Dungeon Guide]|h %s: "
CHAT_RAID_GET = "|Hchannel:RAID|h[Raid]|h %s: "
CHAT_RAID_LEADER_GET = "|Hchannel:RAID|h[Raid Leader]|h %s: "
CHAT_RAID_WARNING_GET = "[Raid Warning] %s: "
CHAT_INSTANCE_CHAT_GET = "|Hchannel:INSTANCE_CHAT|h[Instance]|h %s: "
CHAT_INSTANCE_CHAT_LEADER_GET = "|Hchannel:INSTANCE_CHAT|h[Instance Leader]|h %s: "
CHAT_GUILD_SEND = "Guild: "
CHAT_PARTY_SEND = "Party: "

-- The buttons beside the window, the social button above it, and the chat alerts on it.
QuickJoinToastButton = W.NewFrame("Button", "QuickJoinToastButton", UIParent)
QuickJoinToastButton:SetPoint("BOTTOMLEFT", chat, "TOPLEFT", -2, 30)
ChatFrameToggleVoiceMuteButton = W.NewFrame("Button", "ChatFrameToggleVoiceMuteButton", chat.buttonFrame)
ChatFrameToggleVoiceMuteButton:Hide()
ChatFrameToggleVoiceDeafenButton = W.NewFrame("Button", "ChatFrameToggleVoiceDeafenButton", chat.buttonFrame)
ChatFrameToggleVoiceDeafenButton:Hide()
ChatAlertFrame = W.NewFrame("Frame", "ChatAlertFrame", UIParent)
ChatAlertFrame.alertFrameSubSystems = {}
function ChatAlertFrame:UpdateAnchors() end

-- Addon links clicked in chat (SetItemRef), through EventRegistry: W.ClickLink(link) clicks one.
EventRegistry = { callbacks = {} }
function EventRegistry:RegisterCallback(event, fn, owner)
    self.callbacks[event] = self.callbacks[event] or {}
    table.insert(self.callbacks[event], { fn, owner })
end
function W.ClickLink(link)
    for _, cb in ipairs(EventRegistry.callbacks.SetItemRef or {}) do cb[1](cb[2], link, link, "LeftButton", chat) end
end
SELECTED_CHAT_FRAME = chat

-- The friends and who lists, and the guild roster (Chat Levels).
W.friends, W.who, W.guild = {}, {}, {}
C_FriendList = {
    GetNumFriends = function() return #W.friends end,
    GetFriendInfoByIndex = function(i) return W.friends[i] end,
    GetNumWhoResults = function() return #W.who end,
    GetWhoInfo = function(i) return W.who[i] end,
}
function GetNumGuildMembers() return #W.guild end
function GetGuildRosterInfo(i) local m = W.guild[i]; return m.name, nil, nil, m.level end
function GetNumGroupMembers() return 0 end
function GetQuestDifficultyColor(level) return level >= 60 and { r = 1, g = 0.1, b = 0.1 } or { r = 0.25, g = 0.75, b = 0.25 } end

-- The mouse onto or off the chat, and Blizzard's fade that follows.
function W.ChatMouse(over)
    W.chatHover = over
    if over then FCF_FadeInChatFrame(chat) else FCF_FadeOutChatFrame(chat) end
end

-- The addon channel: what was sent ({ prefix, text, channel } each), and the guild and group.
W.addonMessages, W.inGuild, W.group = {}, false, nil -- W.group: nil, "party", "raid" or "instance"
W.messagingLockdown = false
C_ChatInfo = C_ChatInfo or {}
C_ChatInfo.RegisterAddonMessagePrefix = function(prefix) W.addonPrefix = prefix; return true end
C_ChatInfo.SendAddonMessage = function(prefix, text, channel)
    W.addonMessages[#W.addonMessages + 1] = { prefix = prefix, text = text, channel = channel }
end
C_ChatInfo.InChatMessagingLockdown = function() return W.messagingLockdown end
LE_PARTY_CATEGORY_HOME, LE_PARTY_CATEGORY_INSTANCE = 1, 2
function IsInGuild() return W.inGuild end
function IsInRaid() return W.group == "raid" end
function IsInGroup(category)
    if category == LE_PARTY_CATEGORY_INSTANCE then return W.group == "instance" end
    return W.group ~= nil
end
