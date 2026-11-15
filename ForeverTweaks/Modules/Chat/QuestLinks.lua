--[=[
    Forever Tweaks - Quest Links
    A quest someone typed the way Questie writes one, [[34] A Grim Task (304)], becomes one of
    Blizzard's own quest links, [[34] A Grim Task], which shows the quest when clicked. Questie
    links a quest as its own hyperlink, which the server turns into plain text for everyone else,
    so only players with Questie could click it; the ID in it is all a quest link needs, so no
    quest database is needed. A line is rewritten (Lib/Chat.lua's Transform) a frame after it
    arrives; text already inside a link (Questie's own, when it's loaded) and secret lines are left
    alone, and turning this off puts the plain text back. Left to Forever++'s Quest Links while
    that's on. Adapted from Forever++ by xIGBClutchIx (MIT License).
]=]

local _, ns = ...
local L = ns.L

local pairs, ipairs, type, setmetatable = pairs, ipairs, type, setmetatable
local tonumber, gsub, find, sub, format = tonumber, string.gsub, string.find, string.sub, string.format
local Chat, OtherAddons, Plain = ns.Chat, ns.OtherAddons, ns.Plain

local COVERS = { { "ForeverPlusPlus", "QuestLinks" } }
-- Questie's text: [[level] name (id)], the level maybe with a letter or + after it (34+ elite,
-- 34D dungeon). The position is to skip one already inside a link.
local PLAIN = "()%[%[(%d+[^%]]*)%] ([^%]|]-) %((%d+)%)%]"
-- Our link, to take it out again: the color, quest:id:level, and the shown text.
local LINK = "|cffffff00|Hquest:(%d+):%d+|h%[%[([^%]]*)%] ([^%]|]-)%]|h|r"

local M = ns:NewModule("QuestLinks", {
    title = L.QUESTLINKS_TITLE,
    category = "chat",
    description = L.QUESTLINKS_DESC,
    added = "2.2.0",
})

M.notice = OtherAddons.CoveredNotices(M, COVERS, L.QUESTLINKS_WHAT)

-- A line with each of Questie's plain quests made a quest link.
local function rewrite(text)
    if not find(text, "[[", 1, true) then return text end
    return (gsub(text, PLAIN, function(at, level, name, id)
        if sub(text, at - 2, at - 1) == "|h" then return nil end -- already a link's text
        return format("|cffffff00|Hquest:%s:%d|h[[%s] %s]|h|r", id, tonumber(level:match("%d+")), level, name)
    end))
end

-- A line with our links back as the plain text they came from.
local function restore(text) return (gsub(text, LINK, "[[%2] %3 (%1)]")) end

-- Whether a line has a plain quest left to link (our links' text has no ID, so a linked line
-- doesn't match again).
local function linkable(message) return find(message, "[[", 1, true) ~= nil and rewrite(message) ~= message end

local pending = setmetatable({}, { __mode = "k" }) -- chat window -> true while it has a line to link

local function linkPending()
    for frame in pairs(pending) do
        pending[frame] = nil
        Chat.Transform(frame, linkable, rewrite)
    end
end

local function onMessage(_, frame, text)
    text = Plain(text)
    if type(text) ~= "string" or rewrite(text) == text or OtherAddons.CoveredBy(M, COVERS) then return end
    pending[frame] = true
    M:Soon(linkPending)
end

function M:OnEnable()
    Chat.EachWindow(self, function(frame) self:Hook(frame, "AddMessage", onMessage) end)
end

function M:OnDisable()
    pending = setmetatable({}, { __mode = "k" })
    for _, frame in ipairs(Chat.Frames()) do
        Chat.Transform(frame, function(message) return restore(message) ~= message end, restore)
    end
end
