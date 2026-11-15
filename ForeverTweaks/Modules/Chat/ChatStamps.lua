--[[
    Forever Tweaks - Click Timestamps
    The timestamp Blizzard puts on each chat line (when Timestamps are on in its chat settings)
    becomes a link: clicking it shows that line in a box, as plain text ready to copy. Blizzard adds
    the stamp itself, so the finished line is rewritten (Lib/Chat.lua's Transform) a frame after it
    arrives; the link is the stamp's own text in the line's color, so nothing looks different. A
    click on an addon link goes to EventRegistry's "SetItemRef". Turned off, the stamps stay links
    (rewriting lines again would bring back every line that had faded) and a click does nothing.
    Left to Forever++'s Chat Copy while its Click Timestamps is on. Adapted from Forever++'s Chat
    Copy by xIGBClutchIx (MIT License).
]]

local _, ns = ...
local L = ns.L

local pairs, type, time, find, match, sub = pairs, type, time, string.find, string.match, string.sub
local Chat, OtherAddons, Plain = ns.Chat, ns.OtherAddons, ns.Plain

local COVERS = { { "ForeverPlusPlus", "ChatCopy" } }
-- The number tells the lines apart: this session's start time, then a count (Chat History brings
-- back lines from before).
local LINK_PREFIX = "addon:ForeverTweaks:stamp:"
local SESSION = time() .. "."

local M = ns:NewModule("ChatStamps", {
    title = L.CHATSTAMPS_TITLE,
    category = "chat",
    description = L.CHATSTAMPS_DESC,
    added = "2.2.0",
    defaults = { enabled = false },
})

M.notice = OtherAddons.CoveredNotices(M, COVERS, L.CHATSTAMPS_WHAT)

local function inCharge() return M.active and not OtherAddons.CoveredBy(M, COVERS) end

local lastStamp = 0
local pending = {} -- chat window -> true while it has lines to link

-- Makes the timestamp of each line in a window that has none yet a link.
local function linkStamps(frame)
    local stampFormat = Chat.TimestampFormat()
    if not stampFormat then return end
    local pattern = Chat.TimestampPattern(stampFormat)
    Chat.Transform(frame, function(message)
        return find(message, pattern) ~= nil
    end, function(message)
        local _, finish = find(message, pattern)
        local stamp, space = match(sub(message, 1, finish), "^(.-)(%s*)$") -- the space stays outside
        lastStamp = lastStamp + 1
        return "|H" .. LINK_PREFIX .. SESSION .. lastStamp .. "|h" .. stamp .. "|h" .. space .. sub(message, finish + 1)
    end)
end

local function linkPending()
    for frame in pairs(pending) do
        pending[frame] = nil
        if inCharge() then linkStamps(frame) end
    end
end

local function onMessage(_, frame)
    if not inCharge() then return end
    pending[frame] = true
    M:Soon(linkPending)
end

-- A click on a stamp: its line in a box to copy.
local function onClick(_, _, link, _, button, frame) -- (module, callback owner, ...)
    if not (inCharge() and type(link) == "string" and button == "LeftButton") then return end
    local id = match(link, "^" .. LINK_PREFIX .. "([%d%.]+)$")
    if not id then return end
    frame = frame or SELECTED_CHAT_FRAME
    local wanted = "|H" .. LINK_PREFIX .. id .. "|h"
    for i = 1, frame:GetNumMessages() do
        local text = Plain(frame:GetMessageInfo(i))
        if type(text) == "string" and find(text, wanted, 1, true) == 1 then
            return ns:ShowCopyText("CHATSTAMPS_LINE", L.CHATSTAMPS_PROMPT, ns.TooltipKit.StripCodes(text))
        end
    end
end

function M:OnEnable()
    Chat.EachWindow(self, function(frame)
        self:Hook(frame, "AddMessage", onMessage)
        if inCharge() then linkStamps(frame) end
    end)
    self:HookCallback(EventRegistry, "SetItemRef", function(hook)
        EventRegistry:RegisterCallback("SetItemRef", hook, M)
    end, onClick)
end

function M:OnDisable() pending = {} end
