--[[
    Forever Compendium - Lib/Transport.lua
    How Compendium players send each other tables (Sharing's creatures and quests, Badges'
    shown badges): addon messages under one prefix, in pieces small enough for one message each,
    sent a few at a time so the game's own limits are never hit (and held during an encounter's
    chat lockdown), and put back together on the other side.

    The wire format is Lib/Codec.lua's, read without running any code. A message
    whose pieces don't add up, or that doesn't read back as a table with a known kind, is dropped.

      Transport.Start(mod) / Transport.Stop(mod)     -- from the module's OnEnable / OnDisable
      Transport.Send(mod, kind, data, channel, target) -- channel "WHISPER" (target a name),
                                                       -- "PARTY" or "RAID"
      Transport.Listen(mod, kind, fn)                -- fn(sender, data) for each one received
    Sending and listening are Transport's own, shared by the modules that started it: the prefix
    is registered and CHAT_MSG_ADDON heard while any of them is on, and nothing once all are off;
    a module turned off loses its pieces not sent yet, and the others' go on.
]]

local _, ns = ...

local type, tonumber, pairs, ipairs, next, format, sub, concat, math =
    type, tonumber, pairs, ipairs, next, string.format, string.sub, table.concat, math
local Plain = ns.Plain

local Transport = {}
ns.Transport = Transport

local PREFIX = "FCompendium"
local PIECE = 230         -- bytes of data in one message (255 at most, less the piece header)
local PER_TICK, TICK = 4, 0.25
local MAX_PIECES = 400    -- a message longer than this is refused either way

-- Tables as text: Lib/Codec.lua's format.
Transport.Encode, Transport.Decode = ns.Codec.Encode, ns.Codec.Decode

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------

-- Transport's own owner: its sending and listening serve every module that started it, so they
-- belong to none of them (turning one off doesn't stall the others' messages).
local transport = { name = "Compendium messages" }
local started = {} -- module -> true while it uses Transport (Start to Stop)
local queue = {} -- { prefix text, channel, target, module } waiting to go
local pumping = false
local nextID = 0

-- Sends a few pieces, and again a moment later while any wait.
local function pump()
    if not C_ChatInfo.InChatMessagingLockdown() then -- in an encounter: later
        for _ = 1, PER_TICK do
            local piece = table.remove(queue, 1)
            if not piece then break end
            C_ChatInfo.SendAddonMessage(PREFIX, piece[1], piece[2], piece[3])
        end
    end
    pumping = #queue > 0
    if pumping then ns:After(transport, TICK, pump) end
end

-- Sends `data` as a message of `kind` from module `mod` to `target` on `channel` ("WHISPER" with
-- a name, "PARTY" or "RAID"), in pieces. `data` is left as it is (the kind goes on a copy).
-- False when it's too long to send.
function Transport.Send(mod, kind, data, channel, target)
    local message = { kind = kind }
    for k, v in pairs(data) do
        if k ~= "kind" then message[k] = v end
    end
    local text = Transport.Encode(message)
    local count = math.ceil(#text / PIECE)
    if count > MAX_PIECES then return false end
    nextID = nextID % 999 + 1
    for i = 1, count do
        queue[#queue + 1] = { format("%d:%d:%d:", nextID, i, count) .. sub(text, (i - 1) * PIECE + 1, i * PIECE), channel, target, mod }
    end
    if not pumping then
        pumping = true
        ns:After(transport, TICK, pump)
    end
    return true
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------

local listeners = {} -- kind -> { module, fn }
local partial = {} -- sender:id -> { count, pieces = {} }

function Transport.Listen(mod, kind, fn) listeners[kind] = { mod, fn } end

local function deliver(sender, text)
    local data = Transport.Decode(text)
    local heard = data and listeners[data.kind]
    if heard and heard[1].active then ns.ChargedCall(heard[1], "addon message", heard[2], sender, data) end
end

local function onMessage(_, _, prefix, text, _, sender)
    prefix, text, sender = Plain(prefix), Plain(text), Plain(sender)
    if prefix ~= PREFIX or type(text) ~= "string" or type(sender) ~= "string" then return end
    if sender == UnitName("player") or Ambiguate(sender, "none") == UnitName("player") then return end
    local id, i, count, body = text:match("^(%d+):(%d+):(%d+):(.*)$")
    i, count = tonumber(i), tonumber(count)
    if not (id and i and count) or count > MAX_PIECES or i > count then return end
    local key = sender .. ":" .. id
    local message = partial[key]
    if not message or message.count ~= count then
        message = { count = count, pieces = {}, have = 0 }
        partial[key] = message
    end
    if not message.pieces[i] then
        message.pieces[i] = body
        message.have = message.have + 1
    end
    if message.have == count then
        partial[key] = nil
        deliver(Ambiguate(sender, "none"), concat(message.pieces))
    end
end

-- Module `mod` uses Transport from now on (its OnEnable): the prefix is registered and messages
-- are listened for, once, however many modules start it.
function Transport.Start(mod)
    if not next(started) then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
        ns:On("CHAT_MSG_ADDON", transport, onMessage)
    end
    started[mod] = true
end

-- Module `mod` is done with it (its OnDisable): its pieces not sent yet are dropped, and once no
-- module uses Transport nothing is listened for (an off module has no events running).
function Transport.Stop(mod)
    started[mod] = nil
    local kept = {}
    for _, piece in ipairs(queue) do
        if piece[4] ~= mod then kept[#kept + 1] = piece end
    end
    queue = kept
    for kind, heard in pairs(listeners) do
        if heard[1] == mod then listeners[kind] = nil end
    end
    if not next(started) then
        ns:Off("CHAT_MSG_ADDON", transport)
        partial = {}
    end
end

-- For tests and debugging: how many pieces wait to go.
function Transport.Waiting() return #queue end
