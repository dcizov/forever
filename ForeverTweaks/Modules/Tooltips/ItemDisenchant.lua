--[[
    Forever Tweaks - Modules/Tooltips/ItemDisenchant.lua
    Item Tooltips: Disenchant
    On a green, blue or purple weapon or armor piece, what disenchanting it gives on average,
    priced from the auction prices (AuctionPrices.lua) when every material has one, or else the
    material it most likely gives; Shift adds every outcome with its chance, in gray. The rules
    are in Lib/Disenchant.lua. An item whose bracket isn't known yet says so, and the player's own
    disenchants teach it: a cast of Disenchant on the one disenchantable item locked in the bags,
    then loot that's only enchanting materials (Trade Goods, Enchanting), so a corpse's or chest's
    loot opened around it is never taken for one. Adapted from Forever++'s Item Tooltips by
    xIGBClutchIx (MIT License).
]]

local _, ns = ...
local L = ns.L

local pairs, ipairs, type, format, floor = pairs, ipairs, type, string.format, math.floor
local ItemTooltip, Plain, Disenchant = ns.ItemTooltip, ns.Plain, ns.Disenchant
local Shared = assert(ns.ItemTooltipsShared, "ItemDisenchant.lua loads after ItemTooltips.lua")
local M = assert(ns.modules.ItemTooltips, "ItemDisenchant.lua loads after ItemTooltips.lua")

-- A material's name, or a stand-in while the client hasn't cached it (asking loads it, so the
-- next redraw has it).
local function materialName(itemID)
    local name = C_Item.GetItemNameByID(itemID)
    if name then
        return name
    end
    C_Item.RequestLoadItemDataByID(itemID)
    return format(L.DISENCHANT_UNKNOWN_ITEM, itemID)
end

-- "1-2 Soul Dust", or "1 Nexus Crystal".
local function amountText(each)
    local amount = each.min == each.max and each.min or format(L.DISENCHANT_RANGE, each.min, each.max)
    return format(L.DISENCHANT_AMOUNT, amount, materialName(each.item))
end

-- "75%", "99.5%", "0.5%".
local function chanceText(chance)
    local percent = chance * 100
    if percent == floor(percent) then
        return format(L.DISENCHANT_CHANCE, format("%d", percent))
    end
    return format(L.DISENCHANT_CHANCE, format("%.1f", percent))
end

-- The disenchant outcomes for an item and its bracket: both nil when it can't be disenchanted (or
-- its item info isn't cached yet), outcomes nil when what its bracket gives isn't known yet.
local function outcomesFor(itemID)
    local _, _, quality, itemLevel, _, _, _, _, equipLoc, _, _, classID = C_Item.GetItemInfo(itemID)
    if not quality then
        return nil
    end
    return Disenchant.ForItem(classID, quality, equipLoc, itemLevel)
end

local function addDisenchant(tooltip, data)
    local itemID = Shared.IsShown("disenchant") and ItemTooltip.ItemID(data)
    if not itemID then
        return
    end
    local outcomes, bracket = outcomesFor(itemID)
    if not bracket then
        return
    end
    local db = M.db
    if not outcomes then
        -- The game says it disenchants, but not into what: learned from the first one done.
        ItemTooltip.AddInfo(tooltip, L.DISENCHANT_LINE, L.DISENCHANT_NOT_KNOWN, db.align, "gray")
        return
    end
    local value, missing = Disenchant.Value(outcomes, ns.AuctionPrices.Price)
    if missing == 0 and value > 0 then
        ItemTooltip.AddInfo(tooltip, L.DISENCHANT_LINE, ns.MoneyText(value), db.align, "white")
    else
        -- No prices for every outcome: what it most likely gives instead.
        ItemTooltip.AddInfo(tooltip, L.DISENCHANT_LINE, amountText(outcomes[1]), db.align, "white")
    end
    if IsShiftKeyDown() then
        local r, g, b = GRAY_FONT_COLOR:GetRGB()
        for _, each in ipairs(outcomes) do
            tooltip:AddLine(format(L.DISENCHANT_OUTCOME, chanceText(each.chance), amountText(each)),
                r, g, b)
        end
        if outcomes[1].seen then
            tooltip:AddLine(format(L.DISENCHANT_SEEN, outcomes[1].seen), r, g, b)
        end
    end
end

-- Learning from play ------------------------------------------------------------------------------
-- A disenchant is a cast of Disenchant on a bag item, which the game locks while it casts, then
-- loot from that item. The cast's start names the item: the one disenchantable item locked in the
-- bags then (none or two, and it's left out). Its loot counts once the cast succeeds, only when
-- every item in it is an enchanting material (Trade Goods, Enchanting: 7, 12, as the client's Item
-- table has every Classic dust, essence, shard, and Nexus Crystal, build 70888), so a corpse's or
-- a chest's loot opened around it is never taken for one. Probe: the lock during the cast and
-- GetLootSourceInfo's "Item-" GUID are Mainline's; unverified on Forever.

local DISENCHANT_SPELL = 13262 -- Enchanting's Disenchant (SkillLineAbility, build 70888)
local TRADE_GOODS, ENCHANTING = 7, 12
local LAST_BAG = 4
local WAIT = 5 -- seconds after the cast for its loot

local pending -- { castGUID, bracket, succeeded, items }

local function lockedItem()
    local found
    for bag = 0, LAST_BAG do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and Plain(info.isLocked) and type(Plain(info.itemID)) == "number" then
                local _, bracket = outcomesFor(info.itemID)
                if bracket then
                    if found then
                        return nil -- two: can't tell which
                    end
                    found = bracket
                end
            end
        end
    end
    return found
end

local function learn()
    local cast = pending
    pending = nil
    if cast and cast.items and cast.items[1] then
        Disenchant.Learn(cast.bracket, cast.items)
    end
end

local function isDisenchant(spellID)
    return Plain(spellID) == DISENCHANT_SPELL
end

local function onStart(_, _, unit, castGUID, spellID)
    if unit ~= "player" then return end
    if not isDisenchant(spellID) then
        return
    end
    local bracket = lockedItem()
    castGUID = Plain(castGUID)
    pending = bracket and { castGUID = type(castGUID) == "string" and castGUID or nil, bracket = bracket } or nil
end

-- Whether an event's cast is the pending disenchant: its cast ID, or the spell when the start's
-- cast ID couldn't be read.
local function isPending(castGUID, spellID)
    if not (pending and isDisenchant(spellID)) then
        return false
    end
    return not pending.castGUID or Plain(castGUID) == pending.castGUID
end

local function onSucceeded(_, _, unit, castGUID, spellID)
    if unit ~= "player" or not isPending(castGUID, spellID) then
        return
    end
    pending.succeeded = GetTime()
    if pending.items then
        learn()
        return
    end
    local cast = pending
    M:After(WAIT, function()
        if pending == cast then
            pending = nil
        end
    end)
end

local function onFailed(_, _, unit, castGUID, spellID)
    if unit == "player" and isPending(castGUID, spellID) then
        pending = nil
    end
end

-- The loot, which can come before the cast's success.
local function onLoot()
    if not pending or pending.items then
        return
    end
    local source = Plain(GetLootSourceInfo(1))
    if type(source) == "string" and not source:find("^Item") then
        return
    end
    local items = {}
    for slot = 1, GetNumLootItems() do
        local link = Plain(GetLootSlotLink(slot))
        local _, _, count = GetLootSlotInfo(slot)
        count = Plain(count)
        local id, _, _, _, _, classID, subclassID
        if type(link) == "string" then
            id, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(link)
        end
        if not (type(id) == "number" and classID == TRADE_GOODS and subclassID == ENCHANTING
            and type(count) == "number") then
            pending = nil -- not a disenchant's loot, or one it can't read whole
            return
        end
        items[#items + 1] = { id = id, count = count }
    end
    if not items[1] then
        return
    end
    pending.items = items
    if pending.succeeded then
        learn()
    end
end

local LOOT_EVENTS = {
    UNIT_SPELLCAST_START = onStart,
    UNIT_SPELLCAST_SUCCEEDED = onSucceeded,
    UNIT_SPELLCAST_FAILED = onFailed,
    UNIT_SPELLCAST_INTERRUPTED = onFailed,
    LOOT_READY = onLoot, -- before the window: Fast Loot takes the loot then
    LOOT_OPENED = onLoot,
}

-- Only while the line is on: nothing listens otherwise.
local function update()
    for event, fn in pairs(LOOT_EVENTS) do
        if Shared.IsShown("disenchant") then M:RegisterEvent(event, fn) else M:UnregisterEvent(event) end
    end
    if not Shared.IsShown("disenchant") then pending = nil end
end

M:AddPart({
    Enable = function()
        ItemTooltip.OnPrices(M, addDisenchant)
        update()
    end,
    Disable = function() pending = nil end,
    Changed = function(_, key) if key == "disenchant" then update() end end,
})
