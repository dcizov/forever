--[[
    Forever Tweaks - Lib/ItemStats.lua
    Which stat a line of an item's tooltip is about ("+6 Spirit", "Equip: Increases your hit by
    1%."), in short keys (STR, SP, HIT, ...), by the client's own strings so it works in any
    language; an Equip: line worded as a spell's is told by its number among the item's stats
    (C_Item.GetItemStats, which on Forever carries the Equip: effects too). And a color for each
    stat, for Item Tooltips' Stat Colors. Ratings count as percent at Forever's level 60 rates.
    Adapted from Forever++'s Lib/ItemStats.lua and Lib/Colors.lua by xIGBClutchIx (MIT License).
]]

local _, ns = ...

local _G, pairs, ipairs, type, sort, tonumber, pcall = _G, pairs, ipairs, type, table.sort, tonumber, pcall
local gmatch, match, abs = string.gmatch, string.match, math.abs
local Plain = ns.Plain

local ItemStats = {}
ns.ItemStats = ItemStats

-- The game's stat keys (C_Item.GetItemStats) and ours; a key giving more than one of ours is a list.
ItemStats.KEYS = {
    ITEM_MOD_STRENGTH_SHORT = "STR",
    ITEM_MOD_AGILITY_SHORT = "AGI",
    ITEM_MOD_STAMINA_SHORT = "STA",
    ITEM_MOD_INTELLECT_SHORT = "INT",
    ITEM_MOD_SPIRIT_SHORT = "SPI",
    ITEM_MOD_HEALTH_SHORT = "HEALTH",
    ITEM_MOD_MANA_SHORT = "MANA",
    ITEM_MOD_ATTACK_POWER_SHORT = "AP",
    ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "RAP",
    ITEM_MOD_SPELL_POWER_SHORT = { "SP", "HEAL" },
    ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "SP",
    ITEM_MOD_SPELL_HEALING_DONE_SHORT = "HEAL",
    ITEM_MOD_MANA_REGENERATION_SHORT = "MP5",
    ITEM_MOD_POWER_REGEN0_SHORT = "MP5",
    ITEM_MOD_HEALTH_REGEN_SHORT = "HP5",
    ITEM_MOD_HEALTH_REGENERATION_SHORT = "HP5",
    ITEM_MOD_HIT_RATING_SHORT = { "HIT", "SPELLHIT" },
    ITEM_MOD_HIT_MELEE_RATING_SHORT = "HIT",
    ITEM_MOD_HIT_RANGED_RATING_SHORT = "HIT",
    ITEM_MOD_HIT_SPELL_RATING_SHORT = "SPELLHIT",
    ITEM_MOD_CRIT_RATING_SHORT = { "CRIT", "SPELLCRIT" },
    ITEM_MOD_CRIT_MELEE_RATING_SHORT = "CRIT",
    ITEM_MOD_CRIT_RANGED_RATING_SHORT = "CRIT",
    ITEM_MOD_CRIT_SPELL_RATING_SHORT = "SPELLCRIT",
    ITEM_MOD_HASTE_RATING_SHORT = "HASTE",
    ITEM_MOD_HASTE_MELEE_RATING_SHORT = "HASTE",
    ITEM_MOD_HASTE_RANGED_RATING_SHORT = "HASTE",
    ITEM_MOD_HASTE_SPELL_RATING_SHORT = "HASTE",
    ITEM_MOD_EXPERTISE_RATING_SHORT = "EXPERTISE",
    ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "ARMORPEN",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "DEF",
    ITEM_MOD_DODGE_RATING_SHORT = "DODGE",
    ITEM_MOD_PARRY_RATING_SHORT = "PARRY",
    ITEM_MOD_BLOCK_RATING_SHORT = "BLOCK",
    ITEM_MOD_BLOCK_VALUE_SHORT = "BLOCKVALUE",
    ITEM_MOD_EXTRA_ARMOR_SHORT = "ARMOR",
    RESISTANCE0_NAME = "ARMOR",
    RESISTANCE2_NAME = "RES_FIRE",
    RESISTANCE3_NAME = "RES_NATURE",
    RESISTANCE4_NAME = "RES_FROST",
    RESISTANCE5_NAME = "RES_SHADOW",
    RESISTANCE6_NAME = "RES_ARCANE",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "DPS",
}

-- Ratings: our key, the game's combat rating, and how many points make 1% at level 60 on Forever.
local RATINGS = {
    HIT = { "CR_HIT_MELEE", 10 },
    SPELLHIT = { "CR_HIT_SPELL", 10 },
    CRIT = { "CR_CRIT_MELEE", 14 },
    SPELLCRIT = { "CR_CRIT_SPELL", 14 },
    HASTE = { "CR_HASTE_MELEE", 10 },
    EXPERTISE = { "CR_EXPERTISE", 10 },
    DODGE = { "CR_DODGE", 12 },
    PARRY = { "CR_PARRY", 15 },
    BLOCK = { "CR_BLOCK", 5 },
}

-- What one rating point gives in percent.
local RATES = {}
for key, rating in pairs(RATINGS) do RATES[key] = 1 / rating[2] end

-- A color for each stat: our own palette, light enough to read on a tooltip.
ItemStats.COLORS = {
    STR = { 1, 0.42, 0.32 },
    AGI = { 1, 0.8, 0.28 },
    STA = { 0.42, 0.86, 0.38 },
    INT = { 0.38, 0.66, 1 },
    SPI = { 0.82, 0.72, 1 },
    HEALTH = { 0.42, 0.86, 0.38 },
    MANA = { 0.38, 0.66, 1 },
    AP = { 1, 0.58, 0.46 },
    RAP = { 1, 0.66, 0.42 },
    HIT = { 0.36, 0.94, 0.84 },
    CRIT = { 1, 0.48, 0.72 },
    HASTE = { 1, 0.94, 0.56 },
    EXPERTISE = { 0.9, 0.76, 0.56 },
    ARMORPEN = { 0.86, 0.62, 0.52 },
    SP = { 0.68, 0.48, 1 },
    HEAL = { 0.56, 1, 0.8 },
    SPELLHIT = { 0.36, 0.94, 0.84 },
    SPELLCRIT = { 1, 0.48, 0.72 },
    MP5 = { 0.56, 0.84, 1 },
    HP5 = { 0.64, 0.94, 0.56 },
    ARMOR = { 0.8, 0.7, 0.56 },
    DEF = { 0.56, 0.7, 0.92 },
    DODGE = { 0.62, 0.76, 0.96 },
    PARRY = { 0.68, 0.72, 0.88 },
    BLOCK = { 0.76, 0.72, 0.66 },
    BLOCKVALUE = { 0.76, 0.72, 0.66 },
    RES_FIRE = { 1, 0.52, 0.22 },
    RES_NATURE = { 0.48, 0.9, 0.3 },
    RES_FROST = { 0.52, 0.86, 1 },
    RES_SHADOW = { 0.68, 0.48, 0.88 },
    RES_ARCANE = { 1, 0.66, 1 },
}

-- Our key for a game key; a folded one (hit for melee and spells) gives its first.
local function ourKey(gameKey)
    local ours = ItemStats.KEYS[gameKey]
    if type(ours) == "table" then
        return ours[1]
    end
    return ours
end

-- Keys an Equip: line can carry. The five attributes, armor, and resistances always have a
-- "+6 Spirit" line of their own, so a number that matches one of them isn't the Equip: line's.
local EQUIP_KEYS = {
    AP = true, RAP = true, SP = true, HEAL = true, HIT = true, CRIT = true, HASTE = true,
    SPELLHIT = true, SPELLCRIT = true, MP5 = true, HP5 = true, EXPERTISE = true, ARMORPEN = true,
    DEF = true, DODGE = true, PARRY = true, BLOCK = true, BLOCKVALUE = true,
}

local linePatterns, lineNames -- { pattern, key } from the client's long strings; short name -> key

-- Built from the client's strings the first time a line is read, so they match in any language:
-- each short key's long string ("%c%s Spirit", "Increases your hit by %s.") as a pattern, and
-- each short name ("Spirit", "Fire Resistance") for a "+6 <name>" line no long string fits.
local function buildLinePatterns()
    linePatterns, lineNames = {}, {}
    for gameKey in pairs(ItemStats.KEYS) do
        local key = ourKey(gameKey)
        local long = _G[(gameKey:gsub("_SHORT$", ""))]
        if key ~= "DPS" and gameKey:find("_SHORT$") and type(long) == "string" then
            local pattern = ns.TooltipKit.FormatPattern((long:gsub("%%c", "\2")))
            pattern = "^" .. pattern:gsub("\2", "[%%+%%-]") .. "$"
            -- A string with a format we don't turn into a pattern (%.1f) would throw: skip it.
            if pcall(match, "", pattern) then
                linePatterns[#linePatterns + 1] = { pattern, key }
            end
        end
        local short = _G[gameKey]
        if key ~= "DPS" and type(short) == "string" and short ~= "" then
            lineNames[short] = key
        end
    end
    -- Longest first, so "Increases your hit by %s." can't win over a longer string it's part of.
    sort(linePatterns, function(a, b)
        return #a[1] > #b[1]
    end)
end

-- The one Equip: key among the item's stats whose value is a number in the line (raw, or as
-- percent for a rating), or nil when none or more than one is.
local function equipKeyByNumber(text, raw)
    if type(raw) ~= "table" then
        return nil
    end
    local numbers = {}
    for number in gmatch(text, "%d+%.?%d*") do
        numbers[#numbers + 1] = tonumber(number)
    end
    if #numbers == 0 then
        return nil
    end
    local rates = RATES
    local found
    for gameKey, value in pairs(raw) do
        local key = Plain(gameKey) and type(Plain(value)) == "number" and ourKey(gameKey)
        if key and EQUIP_KEYS[key] then
            local percent = rates[key] and value * rates[key]
            for _, number in ipairs(numbers) do
                if number == value or (percent and abs(number - percent) < 0.05) then
                    if found and found ~= key then
                        return nil
                    end
                    found = key
                end
            end
        end
    end
    return found
end

function ItemStats.LineStat(text, raw)
    if type(text) ~= "string" or text == "" then
        return nil
    end
    if not linePatterns then
        buildLinePatterns()
    end
    local equip = ITEM_SPELL_TRIGGER_ONEQUIP
    local effect
    if type(equip) == "string" and equip ~= "" and text:sub(1, #equip) == equip then
        effect = text:sub(#equip + 1):gsub("^%s+", "")
    end
    local body = effect or text
    for _, entry in ipairs(linePatterns) do
        if match(body, entry[1]) then
            return entry[2], effect
        end
    end
    if effect then
        local key = equipKeyByNumber(effect, raw)
        return key, key and effect or nil
    end
    local name = match(text, "^[%+%-]%d+%s+(.+)$")
    return name and lineNames[name] or nil
end
