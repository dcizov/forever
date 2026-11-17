--[[
    Forever Gearbox - Lib/Upgrades.lua
    Upgrade Arrows in Baganator's own judgement of gear (Modules/Bags/BaganatorUpgrades.lua),
    for when it doesn't use Forever++'s: whether an item beats what it would replace, by stat
    weights for your class and the talent tree with the most points.

      * The tree: Forever's talents are Classic trees on the trait system; C_Traits says what's
        spent in each tab (Upgrades.Tree).
      * The weights: Forever++'s Upgrade Arrows defaults (its role templates and each tree's
        nudges, docs/stat-weights.md there), with Strength, Agility, Stamina and Intellect worked
        out from the game's own conversions for your character (Lib/ItemStats.lua).
      * An item's score is its stats times the weights; what it would replace is the client's own
        comparison (Lib/Equipment.lua), so a ring is judged against the weaker ring and a
        two-hander against both hands. Fishing poles and gear you can't use are never upgrades.
      * Upgrades.Judge(link): { isUpgrade, isDowngrade, percent }, false for no candidate, or nil
        while an item involved isn't loaded (Upgrades.Waiting(itemID) says it was asked for).
        Kept per link until Upgrades.Forget (gear, level or talents changed).
    Adapted from Forever++'s Lib/Talents.lua and Upgrade Arrows (UpgradeArrows.lua, Weights.lua) by
    xIGBClutchIx (MIT License).
]]

local _, ns = ...

local ipairs, pairs, type, sort = ipairs, pairs, type, table.sort
local Plain = ns.Plain
local ItemStats, Equipment = ns.ItemStats, ns.Equipment

local Upgrades = {}
ns.Upgrades = Upgrades

-- Role templates (Forever++'s defaults): DPS a main hand's, DPS_OFF an off hand's, DPS_RANGED a
-- ranged weapon's. STR, AGI, STA and INT are worked out for your own class (derive).
local TEMPLATES = {
    strength = { STR = 1, AGI = 0.6, AP = 0.5, HIT = 10, CRIT = 10, HASTE = 7, EXPERTISE = 8, STA = 0.3,
        HEALTH = 0.03, ARMOR = 0.01, DPS = 7, DPS_OFF = 3.5 },
    agility = { AGI = 1, STR = 0.5, AP = 0.5, HIT = 10, CRIT = 10, HASTE = 7, EXPERTISE = 8, STA = 0.3,
        HEALTH = 0.03, ARMOR = 0.01, DPS = 7, DPS_OFF = 3.5 },
    ranged = { AGI = 1, RAP = 0.5, AP = 0.1, HIT = 12, CRIT = 12, HASTE = 7, INT = 0.3, MANA = 0.02, MP5 = 0.3,
        STA = 0.3, HEALTH = 0.03, ARMOR = 0.01, DPS_RANGED = 7.5, DPS = 0.2 },
    caster = { SP = 1, SPELLHIT = 10, SPELLCRIT = 7, HASTE = 6, INT = 0.35, MANA = 0.02, STA = 0.3,
        HEALTH = 0.03, MP5 = 0.6, SPI = 0.15, DPS_RANGED = 1.2 },
    healer = { HEAL = 1, SP = 0.1, MP5 = 1.5, INT = 0.6, MANA = 0.04, SPI = 0.5, SPELLCRIT = 3, HASTE = 3,
        STA = 0.2, HEALTH = 0.02, DPS_RANGED = 0.5 },
    tank = { STA = 1, HEALTH = 0.1, DEF = 1.5, DODGE = 8, PARRY = 7, BLOCK = 3, BLOCKVALUE = 0.3, ARMOR = 0.04,
        STR = 0.5, AGI = 0.7, AP = 0.25, HIT = 6, CRIT = 3, EXPERTISE = 4, DPS = 2 },
    fallback = { STR = 1, AGI = 1, STA = 0.5, HEALTH = 0.05, INT = 1, MANA = 0.03, SPI = 0.5, AP = 0.3, SP = 0.8,
        HEAL = 0.6, HIT = 5, CRIT = 5, SPELLHIT = 5, SPELLCRIT = 5, DPS = 2 },
}

-- Each class's talent tabs in Classic's order, and the template each uses.
local CLASS_TABS = {
    WARRIOR = { "strength", "strength", "tank" }, PALADIN = { "healer", "tank", "strength" },
    HUNTER = { "ranged", "ranged", "ranged" }, ROGUE = { "agility", "agility", "agility" },
    PRIEST = { "healer", "healer", "caster" }, SHAMAN = { "caster", "strength", "healer" },
    MAGE = { "caster", "caster", "caster" }, WARLOCK = { "caster", "caster", "caster" },
    DRUID = { "caster", "agility", "healer" },
}

-- What each tree changes in its template (Forever++'s nudges).
local NUDGES = {
    WARRIOR = { { CRIT = 11, DPS = 8, DPS_OFF = 0 }, { HIT = 11, DPS_OFF = 4.5 }, {} },
    PALADIN = { { SPELLCRIT = 8, MP5 = 2, SPI = 0.15, INT = 0.8 },
        { SP = 0.5, SPELLHIT = 2, INT = 0.5, MANA = 0.03, MP5 = 1, BLOCK = 3.5, BLOCKVALUE = 0.35, DPS = 1 },
        { CRIT = 11, DPS = 8, DPS_OFF = 0, SP = 0.25, SPELLCRIT = 1, SPELLHIT = 1, INT = 0.25, MANA = 0.015, MP5 = 0.5 } },
    HUNTER = { { STA = 0.35, INT = 0.35, MANA = 0.025 }, { RAP = 0.55, CRIT = 13, DPS_RANGED = 8 }, { AGI = 1.1 } },
    ROGUE = { { CRIT = 11 }, { HIT = 11, DPS_OFF = 4.5 }, { DPS = 7.5, AGI = 1.1 } },
    PRIEST = { { SPI = 0.9, INT = 0.7, SP = 0.2 }, { SPI = 0.9, SPELLCRIT = 4, SP = 0.2 }, { SPELLHIT = 11, SPI = 0.4 } },
    SHAMAN = { { SPELLCRIT = 9 }, { DPS = 8, DPS_OFF = 0.5, CRIT = 11, SP = 0.15, INT = 0.25, MANA = 0.01 },
        { MP5 = 1.7, SPELLCRIT = 4 } },
    MAGE = { { INT = 0.5, MANA = 0.03, SPELLCRIT = 6 }, { SPELLCRIT = 9 }, { SPELLCRIT = 8, SPI = 0.3 } },
    WARLOCK = { { MP5 = 0.2, SPI = 0.25 }, { MP5 = 0.2, STA = 0.4, HEALTH = 0.04 }, { MP5 = 0.2, SPELLCRIT = 9 } },
    DRUID = { { SPELLCRIT = 8, SPI = 0.3 }, { STR = 1, CRIT = 11, DPS = 0, DPS_OFF = 0 }, { SPI = 0.9 } },
}

-- Hand items: their score can depend on a partner for the other hand.
local HAND_SLOTS = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true,
    INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true }

---------------------------------------------------------------------------
-- The tree and the weights
---------------------------------------------------------------------------

-- The points spent in a display group, 0 when the game lists none.
local function spentIn(configID, groupID)
    local result = C_Traits.GetGroupCurrencyInfo(configID, { groupID })
    local entry = type(result) == "table" and result[1]
    local currency = entry and type(entry.currencyInfos) == "table" and entry.currencyInfos[1]
    local spent = currency and Plain(currency.spent)
    return type(spent) == "number" and spent or 0
end

-- The talent tab with the most points (1 to 3), the first tab while there are none or no data.
function Upgrades.Tree()
    local configID = C_ClassTalents.GetActiveConfigID()
    local info = configID and C_Traits.GetConfigInfo(configID)
    local trees = info and Plain(info.treeIDs)
    local treeID = type(trees) == "table" and trees[1]
    if not treeID then return 1 end
    local tabs = {}
    for _, group in ipairs(C_Traits.GetGroupDisplayInfoByTreeID(treeID) or {}) do
        local groupID = type(group) == "table" and Plain(group.groupID)
        if groupID then
            tabs[#tabs + 1] = { order = Plain(group.orderIndex) or 0, spent = spentIn(configID, groupID) }
        end
    end
    sort(tabs, function(a, b) return a.order < b.order end)
    local best, most = 1, 0
    for i, tab in ipairs(tabs) do
        if tab.spent > most then best, most = i, tab.spent end
    end
    return best
end

local weights -- the weights in use, made again on Forget

-- The weights for your class and tree: its template, the tree's nudges, then the attributes
-- worked out from your character's own conversions.
local function currentWeights()
    local _, class = UnitClass("player")
    class = Plain(class) or "?"
    local tree = Upgrades.Tree()
    local list = {}
    local template = CLASS_TABS[class] and CLASS_TABS[class][tree] or "fallback"
    for stat, weight in pairs(TEMPLATES[template]) do list[stat] = weight end
    for stat, weight in pairs(NUDGES[class] and NUDGES[class][tree] or {}) do list[stat] = weight end
    local rates = ItemStats.PlayerRates()
    if class == "DRUID" and tree == 2 and (rates.AP_AGI or 0) < 1 then rates.AP_AGI = 1 end -- Cat Form
    for stat, weight in pairs(ItemStats.DeriveAttributes(list, rates)) do list[stat] = weight end
    return list
end

---------------------------------------------------------------------------
-- Judging
---------------------------------------------------------------------------

local results = {} -- link -> its judgement, or false
local waiting = {} -- itemID -> true while the game loads it

local function scoreOf(info) return ItemStats.Score(ItemStats.Slotted(info.stats, info.slot), weights) end

-- The info of every link, or nil (noting what's loading).
local function infoOf(link)
    local info, itemID = ItemStats.Get(link)
    if not info and itemID then waiting[itemID] = true end
    return info
end

local function compute(link)
    local info = infoOf(link)
    if not info then return nil end
    if not Equipment.Slots(info.slot) or not Equipment.CanUse(link, info.minLevel) or Equipment.IsWorn(link)
        or info.classID == Equipment.WEAPON and info.subclassID == Equipment.FISHING_POLE then
        return false
    end
    local score = scoreOf(info)
    local alternatives, partners = Equipment.Rivals(link, info.slot)
    -- Against a worn two-hander, a hand item is judged with the best partner in your bags.
    local partnerScore
    for _, partnerLink in ipairs(partners or {}) do
        local partner = infoOf(partnerLink)
        if not partner then return nil end
        local value = scoreOf(partner)
        if not partnerScore or value > partnerScore then partnerScore = value end
    end
    score = score + (partnerScore or 0)
    local rival
    for _, alternative in ipairs(alternatives) do
        local sum = 0
        for _, wornLink in ipairs(alternative) do
            local worn = infoOf(wornLink)
            if not worn then return nil end
            sum = sum + scoreOf(worn)
        end
        if not rival or sum < rival then rival = sum end
    end
    local upgrade, percent = ItemStats.Compare(score, rival or 0, 0)
    return { isUpgrade = upgrade, isDowngrade = not upgrade and percent ~= nil and percent < 0, percent = percent,
        hand = HAND_SLOTS[info.slot] }
end

function Upgrades.Judge(link)
    if type(link) ~= "string" then return false end
    local result = results[link]
    if result == nil then
        weights = weights or currentWeights()
        result = compute(link)
        if result ~= nil then results[link] = result end
    end
    return result
end

-- Whether an item was asked for while it loaded (its judgement can be made now).
function Upgrades.Waiting(itemID)
    if not waiting[itemID] then return false end
    waiting[itemID] = nil
    return true
end

-- Gear, level or talents changed: every judgement and the weights are made again.
function Upgrades.Forget()
    results, weights = {}, nil
end
