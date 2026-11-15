--[[
    Forever Tweaks - Lib/Disenchant.lua
    What disenchanting an item gives: which items can be disenchanted (the game's own brackets by
    quality, weapon or armor, and item level, from the client's tables for build 1.60.1.70938),
    the materials each gives with its chance and amount, and what that's worth at given prices.
    What a bracket gives isn't in the client: the rows below are Classic Era 1.x's, unverified on
    Forever and kept only for brackets whose edges the tables confirm; every other bracket (and one
    play proves wrong) gives what the player's own disenchants showed (Disenchant.Learn), kept for
    the account in Item Tooltips' data. Adapted from Forever++'s Lib/Disenchant.lua and
    Lib/DisenchantBrackets.lua by xIGBClutchIx (MIT License).
]]

local _, ns = ...

local ipairs, pairs, type = ipairs, pairs, type
local format, sort, min, max = string.format, table.sort, math.min, math.max

local Disenchant = {}
ns.Disenchant = Disenchant

-- Materials. Classic Era 1.x item IDs, written from general game knowledge, UNVERIFIED on
-- Forever; Self Test lists any the client doesn't have.
local STRANGE_DUST = 10940
local SOUL_DUST = 11083
local VISION_DUST = 11137
local DREAM_DUST = 11176
local ILLUSION_DUST = 16204
local LESSER_MAGIC = 10938
local GREATER_MAGIC = 10939
local LESSER_ASTRAL = 10998
local GREATER_ASTRAL = 11082
local LESSER_MYSTIC = 11134
local GREATER_MYSTIC = 11135
local LESSER_NETHER = 11174
local GREATER_NETHER = 11175
local LESSER_ETERNAL = 16202
local GREATER_ETERNAL = 16203
local SMALL_GLIMMERING = 10978
local LARGE_GLIMMERING = 11084
local SMALL_GLOWING = 11138
local LARGE_GLOWING = 11139
local SMALL_RADIANT = 11177
local LARGE_RADIANT = 11178
local SMALL_BRILLIANT = 14343
local LARGE_BRILLIANT = 14344
local NEXUS_CRYSTAL = 20725

-- Enum.ItemQuality and Enum.ItemClass values, as numbers so the rules need no client.
local UNCOMMON, RARE, EPIC = 2, 3, 4
local WEAPON, ARMOR = 2, 4

-- The game's brackets: { quality, class, lowest item level, highest }.
local BRACKETS = {
    { 2, 2, 5, 15 }, -- uncommon weapon
    { 2, 2, 16, 20 }, -- uncommon weapon
    { 2, 2, 21, 25 }, -- uncommon weapon
    { 2, 2, 26, 30 }, -- uncommon weapon
    { 2, 2, 31, 35 }, -- uncommon weapon
    { 2, 2, 36, 40 }, -- uncommon weapon
    { 2, 2, 41, 45 }, -- uncommon weapon
    { 2, 2, 46, 50 }, -- uncommon weapon
    { 2, 2, 51, 55 }, -- uncommon weapon
    { 2, 2, 56, 60 }, -- uncommon weapon
    { 2, 2, 61, 99 }, -- uncommon weapon
    { 2, 4, 5, 15 }, -- uncommon armor
    { 2, 4, 16, 20 }, -- uncommon armor
    { 2, 4, 21, 25 }, -- uncommon armor
    { 2, 4, 26, 30 }, -- uncommon armor
    { 2, 4, 31, 35 }, -- uncommon armor
    { 2, 4, 36, 40 }, -- uncommon armor
    { 2, 4, 41, 45 }, -- uncommon armor
    { 2, 4, 46, 50 }, -- uncommon armor
    { 2, 4, 51, 55 }, -- uncommon armor
    { 2, 4, 56, 60 }, -- uncommon armor
    { 2, 4, 61, 99 }, -- uncommon armor
    { 3, 2, 5, 15 }, -- rare weapon
    { 3, 2, 16, 20 }, -- rare weapon
    { 3, 2, 21, 25 }, -- rare weapon
    { 3, 2, 26, 30 }, -- rare weapon
    { 3, 2, 31, 35 }, -- rare weapon
    { 3, 2, 36, 40 }, -- rare weapon
    { 3, 2, 41, 45 }, -- rare weapon
    { 3, 2, 46, 50 }, -- rare weapon
    { 3, 2, 51, 55 }, -- rare weapon
    { 3, 2, 56, 60 }, -- rare weapon
    { 3, 2, 61, 99 }, -- rare weapon
    { 3, 4, 5, 15 }, -- rare armor
    { 3, 4, 16, 20 }, -- rare armor
    { 3, 4, 21, 25 }, -- rare armor
    { 3, 4, 26, 30 }, -- rare armor
    { 3, 4, 31, 35 }, -- rare armor
    { 3, 4, 36, 40 }, -- rare armor
    { 3, 4, 41, 45 }, -- rare armor
    { 3, 4, 46, 50 }, -- rare armor
    { 3, 4, 51, 55 }, -- rare armor
    { 3, 4, 56, 60 }, -- rare armor
    { 3, 4, 61, 99 }, -- rare armor
    { 4, 2, 40, 45 }, -- epic weapon
    { 4, 2, 46, 50 }, -- epic weapon
    { 4, 2, 51, 55 }, -- epic weapon
    { 4, 2, 56, 60 }, -- epic weapon
    { 4, 2, 61, 99 }, -- epic weapon
    { 4, 4, 40, 45 }, -- epic armor
    { 4, 4, 46, 50 }, -- epic armor
    { 4, 4, 51, 55 }, -- epic armor
    { 4, 4, 56, 60 }, -- epic armor
    { 4, 4, 61, 99 }, -- epic armor
}

-- Uncommon: { low, high, dust, essence, shard }, each { item, min, max }. Armor gives mostly dust,
-- weapons mostly essence; `chances` is { major, minor, shard } for the bracket. No row for 61-99,
-- which Forever's tables have and Classic had no such items for (the old row said 61-65).
local CHANCES = { 0.75, 0.20, 0.05 }
local UNCOMMON_ROWS = {
    { 5, 15, { STRANGE_DUST, 1, 2 }, { LESSER_MAGIC, 1, 2 }, nil, { 0.80, 0.20, 0 } },
    { 16, 20, { STRANGE_DUST, 2, 3 }, { GREATER_MAGIC, 1, 2 }, { SMALL_GLIMMERING, 1, 1 } },
    { 21, 25, { STRANGE_DUST, 4, 6 }, { LESSER_ASTRAL, 1, 2 }, { SMALL_GLIMMERING, 1, 1 },
        { 0.75, 0.15, 0.10 } },
    { 26, 30, { SOUL_DUST, 1, 2 }, { GREATER_ASTRAL, 1, 2 }, { LARGE_GLIMMERING, 1, 1 } },
    { 31, 35, { SOUL_DUST, 2, 5 }, { LESSER_MYSTIC, 1, 2 }, { SMALL_GLOWING, 1, 1 } },
    { 36, 40, { VISION_DUST, 1, 2 }, { GREATER_MYSTIC, 1, 2 }, { LARGE_GLOWING, 1, 1 } },
    { 41, 45, { VISION_DUST, 2, 5 }, { LESSER_NETHER, 1, 2 }, { SMALL_RADIANT, 1, 1 } },
    { 46, 50, { DREAM_DUST, 1, 2 }, { GREATER_NETHER, 1, 2 }, { LARGE_RADIANT, 1, 1 } },
    { 51, 55, { DREAM_DUST, 2, 5 }, { LESSER_ETERNAL, 1, 2 }, { SMALL_BRILLIANT, 1, 1 } },
    { 56, 60, { ILLUSION_DUST, 1, 2 }, { GREATER_ETERNAL, 1, 2 }, { LARGE_BRILLIANT, 1, 1 } },
}

-- Rare, weapons and armor alike: { low, high, outcomes }. The old 11-25 row is split at the
-- tables' edges (16-20, 21-25); their 5-15 starts lower than it did, so it's learned. So is 61-99
-- (the old row was 56-65).
local RARE_ROWS = {
    { 16, 20, { { SMALL_GLIMMERING, 1, 1, 1 } } },
    { 21, 25, { { SMALL_GLIMMERING, 1, 1, 1 } } },
    { 26, 30, { { LARGE_GLIMMERING, 1, 1, 1 } } },
    { 31, 35, { { SMALL_GLOWING, 1, 1, 1 } } },
    { 36, 40, { { LARGE_GLOWING, 1, 1, 1 } } },
    { 41, 45, { { SMALL_RADIANT, 1, 1, 1 } } },
    { 46, 50, { { LARGE_RADIANT, 1, 1, 1 } } },
    { 51, 55, { { SMALL_BRILLIANT, 1, 1, 1 } } },
    { 56, 60, { { LARGE_BRILLIANT, 0.995, 1, 1 }, { NEXUS_CRYSTAL, 0.005, 1, 1 } } },
}

-- Epic, weapons and armor alike. 61-99 is learned (the old row was 61-80).
local EPIC_ROWS = {
    { 40, 45, { { SMALL_RADIANT, 1, 2, 4 } } },
    { 46, 50, { { LARGE_RADIANT, 1, 2, 4 } } },
    { 51, 55, { { SMALL_BRILLIANT, 1, 2, 4 } } },
    { 56, 60, { { NEXUS_CRYSTAL, 1, 1, 1 } } },
}

-- What disenchanting showed, by bracket (Disenchant.Key): { n = disenchants counted, items =
-- { [material item ID] = { times, low, high } } }: how many of them gave it, and the fewest and
-- most it gave. (Before layout 12, each material was a "times:min:max" string beside n.)
local learned = {} -- Item Tooltips' data (Disenchant.Attach)

-- What play showed is kept in `data`, the owning module's own table.
function Disenchant.Attach(data) learned = data end

function Disenchant.Bracket(quality, itemLevel, isWeapon)
    if type(itemLevel) ~= "number" then
        return nil
    end
    local class = isWeapon and WEAPON or ARMOR
    for _, bracket in ipairs(BRACKETS) do
        if bracket[1] == quality and bracket[2] == class and itemLevel >= bracket[3]
            and itemLevel <= bracket[4] then
            return bracket
        end
    end
end

function Disenchant.Key(bracket)
    return format("%d:%d:%d", bracket[1], bracket[2], bracket[3])
end

local function outcome(material, chance)
    return { item = material[1], chance = chance, min = material[2], max = material[3] }
end

-- The hand-kept row for exactly this bracket's edges, or nil.
local function handRow(rows, bracket)
    for _, entry in ipairs(rows) do
        if entry[1] == bracket[3] and entry[2] == bracket[4] then
            return entry
        end
    end
end

-- What the hand-kept rows say a bracket gives, or nil when they don't know it.
local function fromRows(bracket)
    local isWeapon = bracket[2] == WEAPON
    if bracket[1] == UNCOMMON then
        local entry = handRow(UNCOMMON_ROWS, bracket)
        if not entry then
            return nil
        end
        local chances = entry[6] or CHANCES
        local major, minor = entry[3], entry[4] -- armor: dust first
        if isWeapon then
            major, minor = minor, major
        end
        local list = { outcome(major, chances[1]), outcome(minor, chances[2]) }
        if entry[5] and chances[3] > 0 then
            list[3] = outcome(entry[5], chances[3])
        end
        return list
    end
    local entry = handRow(bracket[1] == RARE and RARE_ROWS or bracket[1] == EPIC and EPIC_ROWS or {}, bracket)
    if not entry then
        return nil
    end
    local list = {}
    for i, each in ipairs(entry[3]) do
        list[i] = { item = each[1], chance = each[2], min = each[3], max = each[4] }
    end
    return list
end

-- What play showed a bracket gives, most often first, each with `seen` (how many disenchants it
-- comes from); nil before any.
local function fromPlay(bracket)
    local tally = learned[Disenchant.Key(bracket)]
    if not tally then
        return nil
    end
    local n, list = tally.n, {}
    for id, seen in pairs(tally.items) do
        list[#list + 1] = { item = id, chance = seen.times / n, min = seen.low, max = seen.high, seen = n }
    end
    if not list[1] then
        return nil
    end
    sort(list, function(a, b)
        if a.chance ~= b.chance then
            return a.chance > b.chance
        end
        return a.item < b.item
    end)
    return list
end

-- Whether play showed a material the rows don't give, which proves the rows wrong.
local function contradicts(rows, played)
    local known = {}
    for _, each in ipairs(rows) do
        known[each.item] = true
    end
    for _, each in ipairs(played) do
        if not known[each.item] then
            return true
        end
    end
    return false
end

function Disenchant.Outcomes(quality, itemLevel, isWeapon)
    local bracket = Disenchant.Bracket(quality, itemLevel, isWeapon)
    if not bracket then
        return nil
    end
    local rows, played = fromRows(bracket), fromPlay(bracket)
    if rows and not (played and contradicts(rows, played)) then
        return rows
    end
    return played
end

function Disenchant.ForItem(classID, quality, equipLoc, itemLevel)
    if classID ~= WEAPON and classID ~= ARMOR then
        return nil
    end
    if equipLoc == "INVTYPE_BODY" or equipLoc == "INVTYPE_TABARD" then
        return nil
    end
    local bracket = Disenchant.Bracket(quality, itemLevel, classID == WEAPON)
    if not bracket then
        return nil
    end
    return Disenchant.Outcomes(quality, itemLevel, classID == WEAPON), bracket
end

function Disenchant.Learn(bracket, items)
    if type(bracket) ~= "table" or type(items) ~= "table" or not items[1] then
        return false
    end
    -- One disenchant: a material's amounts added up, should it fill two slots. Read whole before
    -- anything is kept, so a bad entry leaves the tally as it was.
    local got = {}
    for _, each in ipairs(items) do
        local id, count = each.id, each.count
        if type(id) ~= "number" or type(count) ~= "number" or count < 1 then
            return false
        end
        got[id] = (got[id] or 0) + count
    end
    local key = Disenchant.Key(bracket)
    local tally = learned[key] or { n = 0, items = {} }
    learned[key] = tally
    tally.n = tally.n + 1
    for id, count in pairs(got) do
        local seen = tally.items[id]
        if seen then
            seen.times, seen.low, seen.high = seen.times + 1, min(seen.low, count), max(seen.high, count)
        else
            tally.items[id] = { times = 1, low = count, high = count }
        end
    end
    return true
end

function Disenchant.Value(outcomes, priceFn)
    local total, missing = 0, 0
    for _, each in ipairs(outcomes) do
        local price = priceFn(each.item)
        if price then
            total = total + each.chance * (each.min + each.max) / 2 * price
        else
            missing = missing + 1
        end
    end
    return total, missing
end
