--[[
    Forever Core - Update Notice
    Says in chat when a newer Forever suite is out (every member addon ships at the suite's
    version). The game gives addons no way online, so an
    addon can't ask GitHub for its releases; this learns of a release from other players instead,
    as Deadly Boss Mods and BigWigs do (no code from them): each copy says its version on the
    addon channel (C_ChatInfo.SendAddonMessage) to your guild at login and to a group you join,
    and answers an older copy it hears so that one learns of the newer too.

    What another player sends is only their word: a version more than one major release ahead of
    this one is ignored, one player's claim is told for this session only, and a version is kept
    for the account (so the notice comes again at each login until you update) once CONFIRMED
    different players have said it.
    Where to get it is the TOC's X-Website (the GitHub releases page once there is one), where a
    manager like WowUp, which does read GitHub releases, updates it; releases also go to
    CurseForge (.github/workflows/release.yml), for the CurseForge app.

    Nothing is sent in combat or while the game locks addon messages (C_ChatInfo.
    InChatMessagingLockdown: in instances during encounters), and at most once a minute per
    channel. A category "settings" module: its section is on the Settings page, under the Minimap
    Button's (Settings/General.lua).
]]

local addonName, ns = ...
local L = ns.L

local format, match, type, pairs, tonumber, GetTime = string.format, string.match, type, pairs, tonumber, GetTime
local C_ChatInfo = C_ChatInfo

local PREFIX = "ForeverTweaks"   -- the addon channel (16 characters at most); Forever Tweaks'
                                 -- from before the suite, so copies of it still hear of the suite
local MESSAGE = "v:%s"           -- what's sent: the version
local SEND_EVERY = 60            -- seconds between two messages on one channel
local LOGIN_DELAY = 15           -- seconds after login before telling the guild (it's busy then)
local CONFIRMED = 2              -- players who must say a version before it's kept for the account

local M = ns:NewModule("Updates", {
    title = L.UPDATES_TITLE,
    category = "settings",
    description = L.UPDATES_DESC,
    added = "1.8.1",
    defaults = { enabled = true, share = true, newest = {} },
    options = {
        { key = "share", type = "checkbox", label = L.UPDATES_SHARE, tooltip = L.UPDATES_SHARE_TIP },
    },
})

local lastSent = {}  -- channel -> GetTime() of our last message there
local told = false   -- the notice was given this session
local heardFrom = {} -- version -> { [sender] = true }, this session
local heardNewest    -- the newest version heard this session, from anyone

-- The newer version heard of (kept for the account, or heard this session), or nil while this
-- one is the newest.
function M:NewerVersion()
    local newest = M.db.newest.version
    if ns:IsNewer(heardNewest, newest) then newest = heardNewest end
    return newest and ns:IsNewer(newest, ns.version) and newest or nil
end

-- Whether a version could be real: at most one major release ahead of this one.
local function plausible(version)
    local major, mine = tonumber(match(version, "^(%d+)")), tonumber(match(ns.version, "^(%d+)")) or 0
    return major ~= nil and major <= mine + 1
end

-- A newer version `sender` says is out.
local function hearNewer(version, sender)
    if not plausible(version) then return M:Debug("ignored version", version, "from", tostring(sender)) end
    local senders = heardFrom[version] or {}
    heardFrom[version] = senders
    senders[sender or "?"] = true
    if ns:IsNewer(version, heardNewest) then heardNewest = version end
    local count = 0
    for _ in pairs(senders) do count = count + 1 end
    if count >= CONFIRMED and ns:IsNewer(version, M.db.newest.version) then M.db.newest.version = version end
end

local function website() return C_AddOns.GetAddOnMetadata(addonName, "X-Website") end

local function announceNewer()
    local newer = M:NewerVersion()
    if not newer or told then return end
    told = true
    local where = website()
    M:Print(format(L.UPDATES_NEWER, newer, ns.version))
    M:Print(where and format(L.UPDATES_WHERE_LINK, where) or L.UPDATES_WHERE)
end

local function canSend(channel)
    if not M.db.share or InCombatLockdown() or C_ChatInfo.InChatMessagingLockdown() then return false end
    local last = lastSent[channel]
    return not last or GetTime() - last >= SEND_EVERY
end

local function send(channel)
    if not canSend(channel) then return end
    lastSent[channel] = GetTime()
    C_ChatInfo.SendAddonMessage(PREFIX, format(MESSAGE, ns.version), channel)
end

local function groupChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

local function sayToGroup()
    local channel = groupChannel()
    if channel then send(channel) end
end

local ANSWERED = { GUILD = true, PARTY = true, RAID = true, INSTANCE_CHAT = true }

local function onMessage(_, _, prefix, text, channel, sender)
    prefix, text = ns.Plain(prefix), ns.Plain(text)
    if prefix ~= PREFIX or type(text) ~= "string" then return end
    local version = match(text, "^v:([%d%.]+)$")
    if not version then return end
    if ns:IsNewer(version, ns.version) then
        hearNewer(version, sender)
        announceNewer()
    elseif ns:IsNewer(ns.version, version) and ANSWERED[channel] then
        send(channel) -- an older copy: it learns of ours
    end
end

function M:OnEnable()
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    self:RegisterEvent("CHAT_MSG_ADDON", onMessage)
    self:RegisterEvent("GROUP_JOINED", function() M:After(5, sayToGroup) end)
    self:After(LOGIN_DELAY, function()
        if IsInGuild() then send("GUILD") end
        sayToGroup()
    end)
    announceNewer()
end

function M:DebugLine()
    return format(L.UPDATES_DEBUG, ns.version, tostring(M.db.newest.version))
end
