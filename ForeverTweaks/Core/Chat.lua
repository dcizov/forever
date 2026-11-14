--[[
    Forever Tweaks - Core/Chat.lua
    What the Chat modules share: the chat windows, each one now and as they come, rewriting the
    lines a window shows, and Blizzard's chat timestamps. Adapted from Forever++'s Lib/Chat.lua by
    xIGBClutchIx (MIT License).
]]

local _, ns = ...

local _G, ipairs, type, find, sub, concat = _G, ipairs, type, string.find, string.sub, table.concat

local Chat = {}
ns.Chat = Chat

-- The chat windows that exist, in order: the numbered ones (ChatFrame1 to 10), then (unless
-- `numbered`) the temporary ones Blizzard makes for a whisper popped out into its own tab
-- (CHAT_FRAMES).
function Chat.Frames(numbered)
    local frames, seen = {}, {}
    local function add(frame)
        if type(frame) == "table" and not seen[frame] then
            seen[frame] = true
            frames[#frames + 1] = frame
        end
    end
    for i = 1, NUM_CHAT_WINDOWS do add(_G["ChatFrame" .. i]) end
    if not numbered then
        for _, name in ipairs(CHAT_FRAMES) do add(_G[name]) end
    end
    return frames
end

-- fn(frame) for each chat window now, and again for every window when windows are added or reset
-- (a popped-out whisper comes with no event, so its hook runs it for all). Call from OnEnable;
-- the events and hook are the module's, so it stops with it.
function Chat.EachWindow(mod, fn)
    local function all()
        for _, frame in ipairs(Chat.Frames()) do fn(frame) end
    end
    all()
    mod:RegisterEvent("UPDATE_CHAT_WINDOWS", all)
    mod:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS", all)
    mod:Hook("FCF_OpenTemporaryWindow", all)
end

-- Rewrites the lines a window already shows: each line test(line) accepts becomes rewrite(line),
-- its color and links kept. A secret line is left alone. Each rewritten line counts as new (it
-- shows again if it had faded), so rewrite only what needs it.
function Chat.Transform(frame, test, rewrite)
    frame:TransformMessages(function(message)
        return ns.Plain(message) ~= nil and type(message) == "string" and test(message)
    end, function(message, ...)
        return rewrite(message), ...
    end)
end

-- The chat timestamp format the player picked (Blizzard's chat settings), or nil while off.
function Chat.TimestampFormat()
    local stampFormat = ChatFrameUtil.GetTimestampFormat()
    if type(stampFormat) == "string" and stampFormat ~= "" then return stampFormat end
end

-- A pattern finding a chat timestamp at the start of a line in `stampFormat` ("%I:%M ",
-- "[%H:%M:%S] ", "%I:%M %p "): its numbers can be any digits, so it finds the stamp of any time.
function Chat.TimestampPattern(stampFormat)
    local pieces, i = { "^" }, 1
    while i <= #stampFormat do
        local c = sub(stampFormat, i, i)
        local spec = c == "%" and sub(stampFormat, i + 1, i + 1) or ""
        if spec == "p" then
            pieces[#pieces + 1] = "[^%s%d]+" -- AM or PM in the player's language
            i = i + 2
        elseif spec == "%" then
            pieces[#pieces + 1] = "%%"
            i = i + 2
        elseif spec ~= "" then
            pieces[#pieces + 1] = "%d+"
            i = i + 2
        else
            pieces[#pieces + 1] = find(c, "[%^%$%(%)%%%.%[%]%*%+%-%?]") and "%" .. c or c
            i = i + 1
        end
    end
    return concat(pieces)
end
