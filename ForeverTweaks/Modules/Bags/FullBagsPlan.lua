--[[
    Forever Tweaks - Modules/Bags/FullBagsPlan.lua
    Full Bags: the plan
    What Full Bags (Modules/Bags/FullBags.lua) suggests: every loot item and every bag item
    valued at its price (Auctionator's auction price when chosen and known, Lib/OtherAddons.lua,
    else what a vendor pays) times how many there are, then the most valuable loot paired with the cheapest bag items
    it's worth more than. The keep rules decide which bag items can never be picked. Reads the
    game and the module's settings; draws nothing. Full Bags reads ns.FullBagsPlan.

    The rules and their defaults come from LootTriage by Krelock (its EvaluateSlot and
    IsProtected); this is written from scratch for Forever Tweaks.
]]

local _, ns = ...
local QuestLog = assert(ns.QuestLog, "FullBagsPlan.lua loads after QuestLog.lua")

local ipairs, sort, wipe, select = ipairs, table.sort, wipe, select
local C_Container, C_Item = C_Container, C_Item
local GetNumLootItems, GetLootSlotInfo, GetLootSlotLink, GetLootSlotType = GetNumLootItems, GetLootSlotInfo,
    GetLootSlotLink, GetLootSlotType

local FullBagsPlan = {}
ns.FullBagsPlan = FullBagsPlan

local Quality, Class = Enum.ItemQuality, Enum.ItemClass
local POOR = Quality.Poor
local QUALITY = { poor = Quality.Poor, common = Quality.Common, uncommon = Quality.Uncommon } -- maxQuality's choices

-- The item classes and subclasses the keep rules read.
local CONSUMABLE, WEAPON, ARMOR, REAGENT = Class.Consumable, Class.Weapon, Class.Armor, Class.Reagent
local TRADEGOODS, RECIPE, MISC, PROFESSION = Class.Tradegoods, Class.Recipe, Class.Miscellaneous, Class.Profession
local FISHING_POLE = Enum.ItemWeaponSubclass.Fishingpole
local SPELL_REAGENT = Enum.ItemMiscellaneousSubclass.Reagent

-- Tools the game doesn't flag as tools (LootTriage's list).
local TOOL_ITEMS = {
    [4471] = true, -- Flint and Tinder
    [2901] = true, -- Mining Pick
    [5956] = true, -- Blacksmith Hammer
    [7005] = true, -- Skinning Knife
    [6219] = true, -- Arclight Spanner
    [10498] = true, -- Gyromatic Micro-Adjustor
    [9149] = true, -- Philosopher's Stone
    [6218] = true, -- Runed Copper Rod
    [6339] = true, -- Runed Silver Rod
    [11130] = true, -- Runed Golden Rod
    [11145] = true, -- Runed Truesilver Rod
    [16207] = true, -- Runed Arcanite Rod
}

---------------------------------------------------------------------------
-- Values
---------------------------------------------------------------------------

-- What one is worth, or nil while the game hasn't loaded the item yet (GET_ITEM_INFO_RECEIVED
-- redoes the plan). sellPrice is GetItemInfo's 11th value.
local function unitPrice(db, link, itemID, bound)
    if db.price == "auction" and not bound then
        local price = ns.OtherAddons.AuctionPrice(link, itemID)
        if price then return price end
    end
    return (select(11, C_Item.GetItemInfo(link)))
end

-- A white or better item of a kind the options keep, by Blizzard's item class.
local function protectedKind(db, itemID, classID, subclassID, isReagent)
    if db.keepConsumables and classID == CONSUMABLE then return true end
    if db.keepReagents and (isReagent or classID == REAGENT or classID == TRADEGOODS
        or (classID == MISC and subclassID == SPELL_REAGENT)) then return true end
    if db.keepTools and (TOOL_ITEMS[itemID] or classID == PROFESSION
        or (classID == WEAPON and subclassID == FISHING_POLE)) then return true end
    if db.keepRecipes and classID == RECIPE then return true end
    return db.keepEquipment and (classID == WEAPON or classID == ARMOR) or false
end

-- An item a player shouldn't be told to delete. True too while the game hasn't loaded it
-- (GET_ITEM_INFO_RECEIVED redoes the plan). `questKind` is ns.QuestLog's: a quest in the log
-- needs it, or it begins one.
local function kept(db, bag, slot, info, questKind)
    local quality = info.quality or POOR
    if info.isLocked or info.hasNoValue or db.keep[info.itemID] then return true end
    if quality > QUALITY[db.maxQuality] then return true end
    if questKind then return true end -- needed, begins a quest, or a leftover with Leftovers First off
    local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
    if quest.isQuestItem or quest.questID then return true end
    if info.isBound and quality > POOR and C_Item.IsEquippableItem(info.hyperlink) then return true end
    local name, _, _, _, _, _, _, _, _, _, _, classID, subclassID, _, _, _, isReagent = C_Item.GetItemInfo(info.hyperlink)
    if not name then return true end
    if quality > POOR and protectedKind(db, info.itemID, classID, subclassID, isReagent) then return true end
    return (classID == WEAPON or classID == ARMOR) and C_Container.GetContainerItemEquipmentSetInfo(bag, slot) or false
end

-- How the plan names a bag slot.
function FullBagsPlan.SlotKey(bag, slot) return bag .. ":" .. slot end
local slotKey = FullBagsPlan.SlotKey

-- The bags' items: what each could be deleted for (cheapest first), whether any slot is free,
-- and which items have a stack with room left (itemID -> true).
local function readBags(db)
    local candidates, roomIn, free = {}, {}, 0
    for bag = Enum.BagIndex.Backpack, NUM_BAG_FRAMES do
        local freeSlots, family = C_Container.GetContainerNumFreeSlots(bag)
        if family == 0 then free = free + freeSlots end
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info then
                local maxStack = select(8, C_Item.GetItemInfo(info.hyperlink))
                if maxStack and info.stackCount < maxStack then roomIn[info.itemID] = true end
                local questKind = QuestLog.ForBagSlot(bag, slot)
                if questKind == "leftover" and db.leftoversFirst and not info.isLocked and not db.keep[info.itemID] then
                    -- Useless now and usually unsellable: before anything with a price.
                    candidates[#candidates + 1] = { key = slotKey(bag, slot), value = 0 }
                elseif not kept(db, bag, slot, info, questKind) then
                    local price = unitPrice(db, info.hyperlink, info.itemID, info.isBound)
                    if price and price > 0 then
                        candidates[#candidates + 1] = { key = slotKey(bag, slot), value = price * info.stackCount }
                    end
                end
            end
        end
    end
    sort(candidates, function(a, b) return a.value < b.value end)
    return candidates, roomIn, free
end

-- The loot window's items that would need a free slot, most valuable first.
local function readLoot(db, roomIn)
    local list = {}
    for slot = 1, GetNumLootItems() do
        if GetLootSlotType(slot) == Enum.LootSlotType.Item then
            local _, _, quantity, _, _, locked, isQuestItem = GetLootSlotInfo(slot)
            local link = GetLootSlotLink(slot)
            local itemID = link and C_Item.GetItemInfoInstant(link)
            if link and not locked and not isQuestItem and not roomIn[itemID] then
                local price = unitPrice(db, link, itemID, false)
                if price and price > 0 then list[#list + 1] = { slot = slot, value = price * (quantity or 1) } end
            end
        end
    end
    sort(list, function(a, b) return a.value > b.value end)
    return list
end

-- Fills `plan` ({ coins = {}, deletes = {} }) by `db`, the module's settings: pairs the best loot
-- with the cheapest bag items, as long as the loot is worth more. Empty unless the loot window
-- is open and the bags are full.
function FullBagsPlan.Fill(db, plan)
    wipe(plan.coins)
    wipe(plan.deletes)
    if GetNumLootItems() == 0 then return end
    local candidates, roomIn, free = readBags(db)
    if free > 0 then return end
    for i, loot in ipairs(readLoot(db, roomIn)) do
        local victim = candidates[i]
        if not (victim and loot.value > victim.value) then break end
        plan.coins[loot.slot] = true
        plan.deletes[victim.key] = i
    end
end
