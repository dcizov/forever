--[[
    Forever Gearbox - Lib/ItemStats.lua
    An item's stats in short keys (STR, SP, HIT, DPS, ...), read from the game's stat table
    (C_Item.GetItemStats, which on Forever carries the Equip: effects too), with its slot and level
    requirement; ratings turned into percent (the client's conversion where it answers, Forever's
    level 60 table otherwise); what one point of an attribute gives this character (the
    functions the character sheet uses); and the arithmetic of a stat weight score. For Upgrade
    Arrows in Baganator's own judgement (Lib/Upgrades.lua). An item the game hasn't cached yet
    gives nil and its ID, so the caller can look again at GET_ITEM_INFO_RECEIVED.
    Adapted from Forever++'s Lib/ItemStats.lua by xIGBClutchIx (MIT License).
]]

local _, ns = ...

local _G, pairs, ipairs, type, pcall, floor = _G, pairs, ipairs, type, pcall, math.floor
local Plain = ns.Plain

local ItemStats = {}
ns.ItemStats = ItemStats

local function isNumber(value) return type(Plain(value)) == "number" end
local function isText(value) return type(Plain(value)) == "string" and value ~= "" end

-- The game's stat keys and ours. Forever's "Hit" and "Critical Strike" count for spells too, and
-- Spell Power is damage and healing, so those give two of ours.
local KEYS = {
    ITEM_MOD_STRENGTH_SHORT = "STR", ITEM_MOD_AGILITY_SHORT = "AGI", ITEM_MOD_STAMINA_SHORT = "STA",
    ITEM_MOD_INTELLECT_SHORT = "INT", ITEM_MOD_SPIRIT_SHORT = "SPI", ITEM_MOD_HEALTH_SHORT = "HEALTH",
    ITEM_MOD_MANA_SHORT = "MANA", ITEM_MOD_ATTACK_POWER_SHORT = "AP", ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "RAP",
    ITEM_MOD_SPELL_POWER_SHORT = { "SP", "HEAL" }, ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "SP",
    ITEM_MOD_SPELL_HEALING_DONE_SHORT = "HEAL", ITEM_MOD_MANA_REGENERATION_SHORT = "MP5",
    ITEM_MOD_POWER_REGEN0_SHORT = "MP5", ITEM_MOD_HEALTH_REGEN_SHORT = "HP5", ITEM_MOD_HEALTH_REGENERATION_SHORT = "HP5",
    ITEM_MOD_HIT_RATING_SHORT = { "HIT", "SPELLHIT" }, ITEM_MOD_HIT_MELEE_RATING_SHORT = "HIT",
    ITEM_MOD_HIT_RANGED_RATING_SHORT = "HIT", ITEM_MOD_HIT_SPELL_RATING_SHORT = "SPELLHIT",
    ITEM_MOD_CRIT_RATING_SHORT = { "CRIT", "SPELLCRIT" }, ITEM_MOD_CRIT_MELEE_RATING_SHORT = "CRIT",
    ITEM_MOD_CRIT_RANGED_RATING_SHORT = "CRIT", ITEM_MOD_CRIT_SPELL_RATING_SHORT = "SPELLCRIT",
    ITEM_MOD_HASTE_RATING_SHORT = "HASTE", ITEM_MOD_HASTE_MELEE_RATING_SHORT = "HASTE",
    ITEM_MOD_HASTE_RANGED_RATING_SHORT = "HASTE", ITEM_MOD_HASTE_SPELL_RATING_SHORT = "HASTE",
    ITEM_MOD_EXPERTISE_RATING_SHORT = "EXPERTISE", ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "ARMORPEN",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "DEF", ITEM_MOD_DODGE_RATING_SHORT = "DODGE",
    ITEM_MOD_PARRY_RATING_SHORT = "PARRY", ITEM_MOD_BLOCK_RATING_SHORT = "BLOCK",
    ITEM_MOD_BLOCK_VALUE_SHORT = "BLOCKVALUE", ITEM_MOD_EXTRA_ARMOR_SHORT = "ARMOR", RESISTANCE0_NAME = "ARMOR",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "DPS",
}
ItemStats.KEYS = KEYS

-- Ratings: the game's combat rating (a CR_* global) and the points that make 1% at level 60 on
-- Forever when the client can't say (hit 10, crit 14, haste 10, expertise 10, dodge 12, parry 15,
-- block 5).
local RATINGS = {
    HIT = { "CR_HIT_MELEE", 10 }, SPELLHIT = { "CR_HIT_SPELL", 10 }, CRIT = { "CR_CRIT_MELEE", 14 },
    SPELLCRIT = { "CR_CRIT_SPELL", 14 }, HASTE = { "CR_HASTE_MELEE", 10 }, EXPERTISE = { "CR_EXPERTISE", 10 },
    DODGE = { "CR_DODGE", 12 }, PARRY = { "CR_PARRY", 15 }, BLOCK = { "CR_BLOCK", 5 },
}

-- What one rating point gives in percent, from the player's rating and what it gives now; nil
-- while the player has none.
local function clientRate(index)
    local points, given = Plain(GetCombatRating(index)), Plain(GetCombatRatingBonus(index))
    if type(points) == "number" and type(given) == "number" and points > 0 and given > 0 then
        return given / points
    end
end

local ratingLevel, ratingRates

-- Our rating keys -> percent per point, read again when the level changes.
function ItemStats.RatingRates()
    local level = Plain(UnitLevel("player"))
    if ratingRates and level == ratingLevel then return ratingRates end
    ratingLevel, ratingRates = level, {}
    for key, rating in pairs(RATINGS) do
        local index = _G[rating[1]]
        ratingRates[key] = isNumber(index) and clientRate(index) or 1 / rating[2]
    end
    return ratingRates
end

-- The game's stat table in our keys, numbers only, ratings as percent.
function ItemStats.Normalize(raw)
    local stats = {}
    if type(raw) ~= "table" then return stats end
    local rates = ItemStats.RatingRates()
    local function add(ours, value) stats[ours] = (stats[ours] or 0) + value * (rates[ours] or 1) end
    for key, value in pairs(raw) do
        local ours = Plain(key) and KEYS[key]
        if ours and isNumber(value) then
            if type(ours) == "table" then
                for _, each in ipairs(ours) do add(each, value) end
            else
                add(ours, value)
            end
        end
    end
    return stats
end

local cache, cacheLevel = {}, nil -- link -> info, and the level it was read at (ratings change)

-- What an item link is: { id, slot (INVTYPE_*), classID, subclassID, minLevel, stats }, kept per
-- link. Nil and the item's ID while the game hasn't cached it; nil alone for what isn't an item.
function ItemStats.Get(link)
    if not isText(link) then return nil end
    local level = Plain(UnitLevel("player"))
    if level ~= cacheLevel then cache, cacheLevel = {}, level end
    local info = cache[link]
    if info then return info end
    local itemID, _, _, equipLoc, _, classID, subclassID = C_Item.GetItemInfoInstant(link)
    if not isNumber(itemID) then return nil end
    local name, _, _, _, minLevel = C_Item.GetItemInfo(link)
    if not isText(name) then
        C_Item.RequestLoadItemDataByID(itemID)
        return nil, itemID
    end
    info = {
        id = itemID, slot = Plain(equipLoc) or "", classID = Plain(classID), subclassID = Plain(subclassID),
        minLevel = isNumber(minLevel) and minLevel or 0, stats = ItemStats.Normalize(C_Item.GetItemStats(link)),
    }
    cache[link] = info
    return info
end

-- The weapon slots whose DPS a weight set prices apart from a main hand's.
local DPS_KEYS = { INVTYPE_WEAPONOFFHAND = "DPS_OFF", INVTYPE_RANGED = "DPS_RANGED", INVTYPE_RANGEDRIGHT = "DPS_RANGED",
    INVTYPE_THROWN = "DPS_RANGED" }

-- An item's stats with its DPS under the key its slot prices.
function ItemStats.Slotted(stats, slot)
    local key = DPS_KEYS[slot]
    if not (key and stats.DPS) then return stats end
    local copy = {}
    for k, v in pairs(stats) do copy[k] = v end
    copy[key], copy.DPS = copy.DPS, nil
    return copy
end

-- Each stat times its weight, added up.
function ItemStats.Score(stats, weights)
    local total = 0
    for key, value in pairs(stats) do
        local weight = weights[key]
        if weight then total = total + value * weight end
    end
    return total
end

-- Whether `score` beats `rival` by more than `threshold` percent, and by how much (nil against
-- an empty slot, where anything with a score is an upgrade).
function ItemStats.Compare(score, rival, threshold)
    if rival <= 0 then return score > 0, nil end
    local percent = (score - rival) / rival * 100
    return percent > (threshold or 0), percent
end

-- A global function's number, or nil.
local function callNumber(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    return ok and isNumber(value) and value or nil
end

local function total(stat)
    local _, value = UnitStat("player", stat)
    value = Plain(value)
    return type(value) == "number" and value > 0 and value or nil
end

local function percentPerOwnPoint(name, stat, noArgs)
    local points = total(stat)
    if not points then return nil end
    local value = noArgs and callNumber(name) or not noArgs and callNumber(name, stat, points)
    return value and value * 100 / points or nil
end

-- What one point of each attribute gives this character now (the character sheet's functions).
function ItemStats.PlayerRates()
    local rates = {}
    local ap = callNumber("GetAttackPowerForStat", 1, 100)
    rates.AP_STR = ap and ap / 100
    ap = callNumber("GetAttackPowerForStat", 2, 100)
    rates.AP_AGI = ap and ap / 100
    local rap = callNumber("GetRangedAttackPowerForStat", 2, 100)
    rates.RAP_AGI = rap and rap / 100
    rates.CRIT_AGI = percentPerOwnPoint("GetCritChanceFromStat", 2)
    rates.DODGE_AGI = percentPerOwnPoint("GetDodgeChanceFromAttribute", 2, true)
    rates.SPELLCRIT_INT = percentPerOwnPoint("GetSpellCritChanceFromStat", 4)
    rates.HEALTH_STA = callNumber("UnitHPPerStamina", "player")
    rates.MANA_INT = type(_G.MANA_PER_INTELLECT) == "number" and _G.MANA_PER_INTELLECT or nil
    rates.ARMOR_AGI = 2
    local perBlock = _G.BLOCK_VALUE_PER_STRENGTH
    rates.BLOCKVALUE_STR = type(perBlock) == "number" and perBlock > 0 and 1 / perBlock or nil
    return rates
end

local function round(value) return floor(value * 100 + 0.5) / 100 end

-- The attribute weights that follow from root weights (AP, CRIT, DODGE, HEALTH, SPELLCRIT, MANA,
-- ...) and the player's rates; only those whose rates are all there.
function ItemStats.DeriveAttributes(weights, rates)
    local function w(key) return weights[key] or 0 end
    local derived = {}
    if rates.AP_STR then derived.STR = round(rates.AP_STR * w("AP") + (rates.BLOCKVALUE_STR or 0) * w("BLOCKVALUE")) end
    if rates.AP_AGI and rates.CRIT_AGI and rates.DODGE_AGI then
        derived.AGI = round(rates.AP_AGI * w("AP") + (rates.RAP_AGI or 0) * w("RAP") + rates.CRIT_AGI * w("CRIT")
            + rates.DODGE_AGI * w("DODGE") + (rates.ARMOR_AGI or 0) * w("ARMOR"))
    end
    if rates.HEALTH_STA then derived.STA = round(rates.HEALTH_STA * w("HEALTH")) end
    if rates.SPELLCRIT_INT and rates.MANA_INT then
        derived.INT = round(rates.SPELLCRIT_INT * w("SPELLCRIT") + rates.MANA_INT * w("MANA"))
    end
    return derived
end
