--[[
    Forever Tweaks - tests/scenarios/tweaks/chatfeatures.lua
    The chat features from Forever++: Arrow Keys, Chat Font, Chat History (whispers and secret
    lines left out, brought back at login), Chat Levels (tagged and untagged), Quest Links, Short
    Channel Names (lines and the input box's header), Social Button, Click Timestamps, Chat
    Window's Keep Messages, and each leaving its feature to Forever++'s own while that's on.
    Run by tests/run.lua (lua5.1 tests/run.lua chatfeatures), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverTweaks")
login()
local L = ns.L
local chat, box = ChatFrame1, ChatFrame1.editBox
local function last() local lines = W.ChatLines() return lines[#lines] end

-- Arrow Keys: on by default, Alt no longer needed; given back when off.
eq(box:GetAltArrowKeyMode(), false, "arrow keys: no Alt needed")
ns:SetEnabled("ChatArrowKeys", false)
eq(box:GetAltArrowKeyMode(), true, "off: the box's own mode back")

-- Chat Font: the chosen file at the window's own size, the input box too; given back when off.
ns:SetEnabled("ChatFont", true)
ns:SetOption("ChatFont", "font", "Fonts\\MORPHEUS.TTF")
local file, size = chat:GetFont()
eq(file, "Fonts\\MORPHEUS.TTF", "chat font: the window's font")
eq(size, 14, "its size kept")
eq((box:GetFont()), "Fonts\\MORPHEUS.TTF", "and the input box's")
ns:SetOption("ChatFont", "inputBox", false)
eq((box:GetFont()), "Fonts\\FRIZQT__.TTF", "Input Box off: the box's own back")
ns:SetEnabled("ChatFont", false)
eq((chat:GetFont()), "Fonts\\ARIALN.TTF", "off: the window's own back")

-- Quest Links: Questie's plain text becomes a quest link a frame later; off puts it back.
W.ChatSay("Anyone for [[34] A Grim Task (304)]?")
W.RunTimers()
eq(last(), "Anyone for |cffffff00|Hquest:304:34|h[[34] A Grim Task]|h|r?", "quest links: a link")
ns:SetEnabled("QuestLinks", false)
eq(last(), "Anyone for [[34] A Grim Task (304)]?", "off: plain text again")

-- Short Channel Names: off by default; then the channel and guild prefixes.
ns:SetEnabled("ShortChannelNames", true)
W.ChatSay("|Hchannel:channel:2|h[2. Trade - City]|h Bob: WTS")
eq(last(), "|Hchannel:channel:2|h[2. T]|h Bob: WTS", "short channel: number and initials")
W.ChatSay("|Hchannel:GUILD|h[Guild]|h Ann: hi")
eq(last(), "|Hchannel:GUILD|h[GD]|h Ann: hi", "and the guild's")
box._chatType, box._channelTarget = "CHANNEL", 2
box.header:SetText("[2. Trade - City]: ")
box:UpdateHeader()
eq(box.header._text, "[2. T]: ", "the input box's header too")
ns:SetEnabled("ShortChannelNames", false)
eq(W.ChatLines()[#W.ChatLines() - 1], "|Hchannel:channel:2|h[2. Trade - City]|h Bob: WTS", "off: full names back")

-- Chat Levels: a known player's level before their name, in its color; off takes it out.
ns:SetEnabled("ChatLevels", true)
W.guild = { { name = "Ann-Smith", level = 12 } }
W.inGuild = true
W.Fire("GUILD_ROSTER_UPDATE")
W.RunTimers()
W.ChatSay("|Hplayer:Ann-Smith:77:GUILD|h[Ann]|h: hi")
W.RunTimers()
eq(last(), "|Hplayer:Ann-Smith:77:GUILD|h[|cff3fbf3f12|r:Ann]|h: hi", "chat levels: the level, colored")
W.ChatSay("|Hplayer:Stranger:78:SAY|h[Stranger]|h: hey")
W.RunTimers()
eq(last(), "|Hplayer:Stranger:78:SAY|h[Stranger]|h: hey", "an unknown player: as it was")
ns:SetEnabled("ChatLevels", false)
eq(W.ChatLines()[#W.ChatLines() - 1], "|Hplayer:Ann-Smith:77:GUILD|h[Ann]|h: hi", "off: levels taken out")

-- Click Timestamps: the stamp a link; a click shows the line to copy.
ChatFrameUtil.GetTimestampFormat = function() return "%H:%M " end
ns:SetEnabled("ChatStamps", true)
W.ChatSay("12:34 Bob says: copy me")
W.RunTimers()
check(last():find("^|Haddon:ForeverTweaks:stamp:[%d%.]+|h12:34|h Bob says: copy me$") ~= nil, "timestamps: the stamp a link")
local link = last():match("^|H([^|]+)|h")
W.ClickLink(link)
check(W.popups[#W.popups] ~= nil, "a click shows the line to copy")

-- Social Button: off by default; on, under the channel button; off, back where it was.
local before = { QuickJoinToastButton:GetPoint() }
ns:SetEnabled("SocialButton", true)
local point, relativeTo = QuickJoinToastButton:GetPoint()
eq(point, "TOP", "social button: in the column")
eq(relativeTo, ChatFrameChannelButton, "under the channel button")
QuickJoinToastButton:SetPoint("CENTER", UIParent, "CENTER") -- Blizzard moving it
eq((select(2, QuickJoinToastButton:GetPoint())), ChatFrameChannelButton, "put back when Blizzard moves it")
-- The chat alerts stacked on it go to the alerts' base; one whose anchor is secret (a voice
-- chat alert's can be) is left alone instead of erroring in SetPoint.
local alert = W.NewFrame("Button", nil, UIParent)
alert:SetPoint("BOTTOMLEFT", QuickJoinToastButton, "TOPLEFT", 0, 4)
local voice = W.NewFrame("Button", nil, UIParent)
local secretPoint = "BOTTOMLEFT-secret"
W.secrets[secretPoint] = true
voice._point = { secretPoint, QuickJoinToastButton, "TOPLEFT", 0, 0 }
ChatAlertFrame.alertFrameSubSystems = { { anchorFrame = voice }, { anchorFrame = alert } }
ChatAlertFrame:UpdateAnchors()
eq(select(2, alert:GetPoint()), ChatAlertFrame, "an alert on the button goes to the alerts' base")
eq(select(5, alert:GetPoint()), 4, "keeping its offset")
eq(voice._point[1], secretPoint, "a secret anchor is left as it was")
ChatAlertFrame.alertFrameSubSystems = {}
ns:SetEnabled("SocialButton", false)
eq(select(2, QuickJoinToastButton:GetPoint()), before[2], "off: back where it was")

-- Chat History: kept at logout (not whispers or secret lines), back at the next login.
ns:SetEnabled("ChatHistory", true)
chat._lines = {}
W.ChatSay("hello there")
W.ChatSay("psst", "WHISPER")
local secret = "a secret line"
W.secrets[secret] = true
W.ChatSay(secret)
W.Fire("PLAYER_LOGOUT")
local saved = ForeverTweaksCharDB.data.ChatHistory.saved[1]
eq(saved and #saved, 1, "history: one line kept")
eq(saved and saved[1][1], "hello there", "not the whisper or the secret line")
chat._lines = {}
W.Fire("PLAYER_ENTERING_WORLD", false, true)
eq(W.ChatLines()[1], "hello there", "brought back after a reload")
eq(W.ChatLines()[2], L.CHATHISTORY_DIVIDER, "with the earlier-chat line")

-- Chat Window's Keep Messages: messages never fade.
ns:SetOption("ChatFade", "keepMessages", true)
eq(chat:GetFading(), false, "keep messages: no fading")

-- Each leaves its feature to Forever++'s own while that's on.
W.loaded.ForeverPlusPlus = true
ForeverPlusPlusAPI = { v1 = { IsModuleEnabled = function() return true end } }
ns:SetEnabled("ChatArrowKeys", false)
ns:SetEnabled("ChatArrowKeys", true)
eq(box:GetAltArrowKeyMode(), true, "Forever++'s Arrow Keys on: left to it")
finish()
