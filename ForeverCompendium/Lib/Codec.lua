--[[
    Forever Compendium - Lib/Codec.lua
    Tables as text and back, read without running any code: Sharing's addon messages
    (Lib/Transport.lua), and the Archive's exports and backups (Archive.lua).

    The format: a table is "{", then each key and value, then "}"; a string is "s", its length,
    ":" and its bytes; a number "n" and its digits up to ";"; true and false "T" and "F".
    Anything else (functions, odd keys) is left out.

      Codec.Encode(table) -> text            Codec.Decode(text) -> table, or nil
      Codec.Armor(text)   -> "FC1:<checksum>:<base64>": safe to paste in a chat edit box (no "|",
                             no line breaks), and checked when read back
      Codec.Unarmor(text) -> text; or nil and why: "header" (not armored text at all) or
                             "damaged" (cut short or changed: the checksum or base64 is wrong)
]]

local _, ns = ...

local type, tonumber, pairs, format, sub, find, byte, char, concat, floor =
    type, tonumber, pairs, string.format, string.sub, string.find, string.byte, string.char, table.concat, math.floor

local Codec = {}
ns.Codec = Codec

local MAX_DEPTH = 20
local HEADER = "FC1:"

---------------------------------------------------------------------------
-- Tables
---------------------------------------------------------------------------

local function write(value, out)
    local t = type(value)
    if t == "table" then
        out[#out + 1] = "{"
        for k, v in pairs(value) do
            if (type(k) == "string" or type(k) == "number") and type(v) ~= "function" then
                write(k, out)
                write(v, out)
            end
        end
        out[#out + 1] = "}"
    elseif t == "string" then
        out[#out + 1] = "s" .. #value .. ":" .. value
    elseif t == "number" then
        out[#out + 1] = "n" .. format("%.17g", value) .. ";"
    elseif t == "boolean" then
        out[#out + 1] = value and "T" or "F"
    end
end

function Codec.Encode(value)
    local out = {}
    write(value, out)
    return concat(out)
end

-- Reads one value at `pos`: the value and the position after it, or nil.
local function read(text, pos, depth)
    if depth > MAX_DEPTH then return nil end
    local c = sub(text, pos, pos)
    if c == "T" then return true, pos + 1 end
    if c == "F" then return false, pos + 1 end
    if c == "n" then
        local stop = find(text, ";", pos, true)
        local n = stop and tonumber(sub(text, pos + 1, stop - 1))
        if not n then return nil end
        return n, stop + 1
    end
    if c == "s" then
        local colon = find(text, ":", pos, true)
        local length = colon and tonumber(sub(text, pos + 1, colon - 1))
        if not length or colon + length > #text then return nil end
        return sub(text, colon + 1, colon + length), colon + length + 1
    end
    if c == "{" then
        local t = {}
        pos = pos + 1
        while sub(text, pos, pos) ~= "}" do
            if pos > #text then return nil end
            local k, v
            k, pos = read(text, pos, depth + 1)
            if k == nil then return nil end
            v, pos = read(text, pos, depth + 1)
            if v == nil then return nil end
            t[k] = v
        end
        return t, pos + 1
    end
    return nil
end

function Codec.Decode(text)
    if type(text) ~= "string" then return nil end
    local value, pos = read(text, 1, 0)
    if type(value) ~= "table" or pos ~= #text + 1 then return nil end
    return value
end

---------------------------------------------------------------------------
-- Armor: base64 with a checksum (arithmetic only: no bit library needed)
---------------------------------------------------------------------------

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local DIGIT = {}
for i = 1, 64 do DIGIT[sub(ALPHABET, i, i)] = i - 1 end

-- Adler-32 of `text`, as 8 hex digits.
local function checksum(text)
    local a, b = 1, 0
    for i = 1, #text do
        a = (a + byte(text, i)) % 65521
        b = (b + a) % 65521
    end
    return format("%08x", b * 65536 + a)
end

local function toBase64(text)
    local out = {}
    for i = 1, #text, 3 do
        local x, y, z = byte(text, i, i + 2)
        local n = x * 65536 + (y or 0) * 256 + (z or 0)
        local c1, c2 = floor(n / 262144) % 64, floor(n / 4096) % 64
        local c3, c4 = floor(n / 64) % 64, n % 64
        out[#out + 1] = sub(ALPHABET, c1 + 1, c1 + 1) .. sub(ALPHABET, c2 + 1, c2 + 1)
            .. (y and sub(ALPHABET, c3 + 1, c3 + 1) or "=") .. (z and sub(ALPHABET, c4 + 1, c4 + 1) or "=")
    end
    return concat(out)
end

local function fromBase64(text)
    if #text % 4 ~= 0 then return nil end
    local out = {}
    for i = 1, #text, 4 do
        local n, pad = 0, 0
        for j = i, i + 3 do
            local c = sub(text, j, j)
            local d = DIGIT[c]
            if c == "=" then
                pad, d = pad + 1, 0
            elseif not d or pad > 0 then
                return nil
            end
            n = n * 64 + d
        end
        local x, y, z = floor(n / 65536) % 256, floor(n / 256) % 256, n % 256
        out[#out + 1] = pad == 0 and char(x, y, z) or pad == 1 and char(x, y) or char(x)
    end
    return concat(out)
end

function Codec.Armor(text)
    return HEADER .. checksum(text) .. ":" .. toBase64(text)
end

function Codec.Unarmor(text)
    if type(text) ~= "string" then return nil, "header" end
    text = text:gsub("%s", "")
    if sub(text, 1, #HEADER) ~= HEADER then return nil, "header" end
    local sum, body = text:match("^(%x%x%x%x%x%x%x%x):(.*)$", #HEADER + 1)
    local plain = body and fromBase64(body)
    if not plain or checksum(plain) ~= sum then return nil, "damaged" end
    return plain
end
