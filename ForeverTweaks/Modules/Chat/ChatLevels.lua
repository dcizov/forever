--[[
    Forever Tweaks - Chat Levels
    A player's level before their name in chat, [60:Name], in the color of that level against
    yours, as a quest's is colored. The level is the last one seen, kept for the account so it
    shows for people far away too: from your group, guild and friends lists, /who results you
    asked for, and players you target, mouse over or see a nameplate of. A player is known by
    their first name (on Forever the part after a "-" is a surname, not a realm); one unseen for
    MAX_AGE is forgotten at login.
    Blizzard builds the name link itself, so the finished line is rewritten (Lib/Chat.lua's
    Transform) a frame after it arrives; turning this off takes the levels out again. Secret lines
    and values are left alone. Left to Forever++'s Chat Levels while that's on. Adapted from
    Forever++ by xIGBClutchIx (MIT License).
]]

local _, ns = ...
local L = ns.L

local pairs, ipairs, type, time, format = pairs, ipairs, type, time, string.format
local find, match, gsub, lower, floor = string.find, string.match, string.gsub, string.lower, math.floor
local Chat, OtherAddons, Plain = ns.Chat, ns.OtherAddons, ns.Plain

local COVERS = { { "ForeverPlusPlus", "ChatLevels" } }
local MAX_AGE = 60 * 24 * 60 * 60 -- seconds unseen before a player is forgotten
-- Blizzard's name link: |Hplayer:Name-Surname:lineID:CHANNEL:target|h[Name]|h.
local LINK = "(|Hplayer:([^|]*)|h%[)"
-- Our level in a link, to take it out again: a color code, digits, |r and a colon.
local TAGGED = "(|Hplayer:[^|]*|h%[)|c%x%x%x%x%x%x%x%x%d+|r:"

local M = ns:NewModule("ChatLevels", {
    title = L.CHATLEVELS_TITLE,
    category = "chat",
    description = L.CHATLEVELS_DESC,
    added = "2.2.0",
    defaults = {
        enabled = false,
        levels = {}, -- data: first name (lowercased) -> { level, time() last seen }
    },
})

M.notice = OtherAddons.CoveredNotices(M, COVERS, L.CHATLEVELS_WHAT)

local function inCharge() return M.active and not OtherAddons.CoveredBy(M, COVERS) end

---------------------------------------------------------------------------
-- Levels seen
---------------------------------------------------------------------------

local function keyOf(name)
    name = Plain(name)
    if type(name) ~= "string" or name == "" then return nil end
    return lower(match(name, "^[^%-%s]+") or name)
end

local function learn(name, level)
    local key = keyOf(name)
    level = Plain(level)
    if key and type(level) == "number" and level > 0 then M.db.levels[key] = { level, time() } end
end

local function learnUnit(unit)
    if Plain(UnitIsPlayer(unit)) then learn(UnitName(unit), UnitLevel(unit)) end
end

local function learnGroup()
    local raid = IsInRaid()
    for i = 1, raid and GetNumGroupMembers() or 4 do learnUnit((raid and "raid" or "party") .. i) end
end

local function learnGuild()
    if not IsInGuild() then return end
    for i = 1, GetNumGuildMembers() do
        local name, _, _, level = GetGuildRosterInfo(i)
        learn(name, level)
    end
end

local function learnFriends()
    for i = 1, C_FriendList.GetNumFriends() do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.connected then learn(info.name, info.level) end -- offline: no level sent
    end
end

local function learnWho()
    for i = 1, C_FriendList.GetNumWhoResults() do
        local info = C_FriendList.GetWhoInfo(i)
        if info then learn(info.fullName, info.level) end
    end
end

local function forgetOld()
    local now = time()
    for key, seen in pairs(M.db.levels) do
        if type(seen) ~= "table" or now - (seen[2] or 0) > MAX_AGE then M.db.levels[key] = nil end
    end
end

local LEARN_EVENTS = {
    GROUP_ROSTER_UPDATE = function(self) self:Soon(learnGroup) end,
    GUILD_ROSTER_UPDATE = function(self) self:Soon(learnGuild) end,
    FRIENDLIST_UPDATE = function(self) self:Soon(learnFriends) end,
    WHO_LIST_UPDATE = function(self) self:Soon(learnWho) end,
    PLAYER_TARGET_CHANGED = function() learnUnit("target") end,
    UPDATE_MOUSEOVER_UNIT = function() learnUnit("mouseover") end,
    NAME_PLATE_UNIT_ADDED = function(_, _, unit) learnUnit(unit) end,
}

---------------------------------------------------------------------------
-- Tagging chat lines
---------------------------------------------------------------------------

local function tag(level)
    local color = GetQuestDifficultyColor(level)
    return format("|cff%02x%02x%02x%d|r:", floor(color.r * 255), floor(color.g * 255), floor(color.b * 255), level)
end

-- A line with a level put in each player link that has none yet, where it's known.
local function rewrite(text)
    return (gsub(text, LINK, function(open, data)
        local seen = M.db.levels[keyOf(match(data, "^([^:]*)"))]
        if seen then return open .. tag(seen[1]) end
    end))
end

local function tagged(text) return find(text, TAGGED) ~= nil end

local pending = {} -- chat window -> { [lineID] = true }, its lines since the last pass

local function tagPending()
    for frame, lines in pairs(pending) do
        pending[frame] = nil
        Chat.Transform(frame, function(message)
            local id = match(message, "|Hplayer:[^:|]*:(%d+)")
            return id ~= nil and lines[id] and not tagged(message) and rewrite(message) ~= message
        end, rewrite)
    end
end

local function onMessage(_, frame, text)
    text = Plain(text)
    if type(text) ~= "string" or not inCharge() then return end
    local id = match(text, "|Hplayer:[^:|]*:(%d+)")
    if not id then return end
    local lines = pending[frame] or {}
    lines[id] = true
    pending[frame] = lines
    M:Soon(tagPending)
end

function M:OnEnable()
    forgetOld()
    for event, fn in pairs(LEARN_EVENTS) do self:RegisterEvent(event, fn) end
    Chat.EachWindow(self, function(frame) self:Hook(frame, "AddMessage", onMessage) end)
    learnGroup()
    learnGuild()
end

-- Lines already tagged lose their levels again.
function M:OnDisable()
    pending = {}
    for _, frame in ipairs(Chat.Frames()) do
        Chat.Transform(frame, tagged, function(message) return (gsub(message, TAGGED, "%1")) end)
    end
end

function M:DebugLine()
    local count = 0
    for _ in pairs(self.db.levels) do count = count + 1 end
    return format(L.CHATLEVELS_DEBUG, count)
end
