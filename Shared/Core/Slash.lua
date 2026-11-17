--[[
    Forever runtime - Shared/Core/Slash.lua
    Slash commands added and taken away live. A command is the SLASH_<key>n globals and
    SlashCmdList[key]. A slash another addon already answers to is left to that addon; the
    caller is given the ones it got (ns:RegisterSlash tells the player about the rest). Chat caches a command's function the first time it's typed
    (hash_SlashCmdList), so taking one away clears that too.

    Adapted from Forever++ by xIGBClutchIx (MIT License).
]]

local _, ns = ...

local pairs, ipairs, _G = pairs, ipairs, _G

local Slash = {}
ns.Slash = Slash

local added = {} -- key -> { slashes }

-- Whether a command other than `key` already answers to `slash`.
local function taken(slash, key)
    slash = slash:upper()
    local hash = _G.hash_SlashCmdList
    if hash and hash[slash] and hash[slash] ~= SlashCmdList[key] then return true end
    for other in pairs(SlashCmdList) do
        if other ~= key then
            for i = 1, 20 do
                local name = _G["SLASH_" .. other .. i]
                if not name then break end
                if name:upper() == slash then return true end
            end
        end
    end
    return false
end

-- Adds /slash... for fn(msg). Returns the slashes it got.
function Slash.Add(key, slashes, fn)
    Slash.Remove(key)
    local got = {}
    for _, slash in ipairs(slashes) do
        if taken(slash, key) then
            ns:Debug("slash taken by another addon:", slash)
        else
            got[#got + 1] = slash
            _G["SLASH_" .. key .. #got] = slash
        end
    end
    if #got > 0 then
        SlashCmdList[key] = fn
        added[key] = got
    end
    return got
end

function Slash.Remove(key)
    local got = added[key]
    if not got then return end
    local hash = _G.hash_SlashCmdList
    for i, slash in ipairs(got) do
        _G["SLASH_" .. key .. i] = nil
        if hash then hash[slash:upper()] = nil end
    end
    SlashCmdList[key] = nil
    added[key] = nil
end
