--[[
    Forever Gearbox - Lib/Equipment.lua
    What the player wears and what a piece of gear would replace, for Upgrade Arrows in Baganator's
    own judgement (Lib/Upgrades.lua): the inventory slots an item's type goes in, the worn item in
    each, whether the character can use an item, and the worn items it competes with (rings and
    trinkets against the weaker, a two-hander against both hands, a one-hander against either
    hand when dual wielding), asked of the client's own item comparison first
    (C_TooltipComparison.GetItemComparisonInfo, the "Equipped" tooltips' source) and worked out
    from the slot rules when it doesn't answer. Nothing is cached: worn gear changes under us.
    Adapted from Forever++'s Lib/Equipment.lua by xIGBClutchIx (MIT License).
]]

local _, ns = ...

local ipairs, type, select = ipairs, type, select
local Plain = ns.Plain

local Equipment = { WEAPON = 2, FISHING_POLE = 20 } -- Enum.ItemClass.Weapon, Enum.ItemWeaponSubclass.Fishingpole
ns.Equipment = Equipment

-- Each item type's inventory slots; shirts, tabards, bags and ammo aren't gear worth a score.
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}

function Equipment.Slots(invType) return invType and SLOTS[invType] or nil end

function Equipment.Worn(slot)
    local link = Plain(GetInventoryItemLink("player", slot))
    return type(link) == "string" and link ~= "" and link or nil
end

-- The part of a link naming the item with its suffix and enchant, so two links to the same item
-- read the same whoever made them.
local function linkKey(link)
    local key = type(link) == "string" and link:match("item:[^|]+")
    return key and (key:gsub(":+$", "")) or link
end

function Equipment.IsWorn(link)
    local key = linkKey(link)
    for slot = 1, 19 do
        local worn = Equipment.Worn(slot)
        if worn and linkKey(worn) == key then return true end
    end
    return false
end

local function wornType(slot)
    local link = Equipment.Worn(slot)
    local equipLoc = link and select(4, C_Item.GetItemInfoInstant(link))
    return Plain(equipLoc)
end

-- Whether the character can use an item: its level requirement, then the client's own check
-- (class and proficiencies).
function Equipment.CanUse(link, minLevel)
    local level = Plain(UnitLevel("player"))
    if minLevel and minLevel > 0 and type(level) == "number" and level < minLevel then return false end
    local itemID = C_Item.GetItemInfoInstant(link)
    if itemID and Plain(C_PlayerInfo.CanUseItem(itemID)) == false then return false end
    return true
end

local function linkOf(guid)
    if type(Plain(guid)) ~= "string" then return nil end
    local link = Plain(C_Item.GetItemLinkByGUID(guid))
    return type(link) == "string" and link or nil
end

local function comparedLink(entry) return type(entry) == "table" and linkOf(entry.guid) or nil end

-- The client's own answer: the alternatives it compares with, and for a hand item against a
-- worn two-hander the bag items it would wear with it (the second value). Nil when it doesn't answer.
local function clientRivals(link)
    local info = Plain(C_TooltipComparison.GetItemComparisonInfo({ hyperlink = link }))
    if type(info) ~= "table" then return nil end
    local methods = Enum.TooltipComparisonMethod or {}
    local method = Plain(info.method) or 0
    local first = comparedLink(info.item)
    local extra = type(Plain(info.additionalItems)) == "table" and info.additionalItems or {}
    if method == (methods.WithBothHands or 1) then
        local pair = { first }
        for _, entry in ipairs(extra) do pair[#pair + 1] = comparedLink(entry) end
        return { pair }
    end
    if method == (methods.WithBagMainHandItem or 2) or method == (methods.WithBagOffHandItem or 3) then
        local partners = {}
        for _, entry in ipairs(extra) do
            partners[#partners + 1] = type(entry) == "table" and (linkOf(entry.guid) or Plain(entry.hyperlink)) or nil
        end
        return { { first } }, partners
    end
    local alternatives = { { first } }
    for _, entry in ipairs(extra) do alternatives[#alternatives + 1] = { comparedLink(entry) } end
    return alternatives
end

-- Which slots an item type competes for, by the rules.
local function ruleSlots(invType)
    local slots = SLOTS[invType]
    if not slots then return {} end
    if invType == "INVTYPE_2HWEAPON" then return { { 16, 17 } } end
    if invType == "INVTYPE_WEAPON" then
        local off = wornType(17)
        local offIsWeapon = off == nil or off == "INVTYPE_WEAPON" or off == "INVTYPE_WEAPONOFFHAND"
        if Plain(CanDualWield()) == true and offIsWeapon and wornType(16) ~= "INVTYPE_2HWEAPON" then
            return { { 16 }, { 17 } }
        end
        return { { 16 } }
    end
    if slots[1] == 17 and wornType(16) == "INVTYPE_2HWEAPON" then return { { 16 } } end
    if #slots == 2 then return { { slots[1] }, { slots[2] } } end
    return { { slots[1] } }
end

-- The alternatives an item type competes with by the rules alone, through `worn(slot)`.
function Equipment.RuleRivals(invType, worn)
    local alternatives = {}
    for _, slots in ipairs(ruleSlots(invType)) do
        local links = {}
        for _, slot in ipairs(slots) do links[#links + 1] = worn(slot) end
        alternatives[#alternatives + 1] = links
    end
    return alternatives
end

-- The worn items an item would replace (lists of links whose scores add up; an empty list is an
-- empty slot), and for a hand item against a worn two-hander the bag partners, or nil.
function Equipment.Rivals(link, invType)
    local alternatives, partners = clientRivals(link)
    if not alternatives then return Equipment.RuleRivals(invType, Equipment.Worn) end
    if partners then return alternatives, partners end
    -- An empty slot the item could take beats any rival; the client compares with what's worn.
    for _, slots in ipairs(ruleSlots(invType)) do
        if #slots == 1 and not Equipment.Worn(slots[1]) then alternatives[#alternatives + 1] = {} end
    end
    return alternatives
end
