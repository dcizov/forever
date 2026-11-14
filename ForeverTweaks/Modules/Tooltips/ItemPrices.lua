--[[
    Forever Tweaks - Item Tooltips: Sell Price, Repair Cost and Item Count
      * Sell Price: the vendor price counts the whole stack, and Shift shows one (Mode turns that
        round). Forever's own line prices one item, so it's drawn again in its place.
      * Repair Cost: what repairing a damaged piece of gear costs, on gear you wear or carry (the
        client puts it in the item's tooltip data); Blizzard's own shows only with the repair
        cursor, so not then.
      * Item Count: how many you own, above the prices: the total, then in your bags and bank.
        Bags are counted live; the bank while it's open, and kept for each character after,
        since its contents only change there.
    Adapted from Forever++'s Item Tooltips by xIGBClutchIx (MIT License).
]]

local _, ns = ...
local L = ns.L

local pairs, type, select, format, strfind, tconcat = pairs, type, select, string.format, string.find, table.concat
local ItemTooltip, Kit, Plain = ns.ItemTooltip, ns.TooltipKit, ns.Plain
local Parts = ns.ItemTooltipParts
local M = Parts.module

---------------------------------------------------------------------------
-- Sell Price
---------------------------------------------------------------------------

-- One item's vendor price: from item info, else the line's own (while item info isn't cached).
local function drawSellPrice(_, tooltip, data, lineData)
    local itemID = Parts.On("sellPrice") and ItemTooltip.ItemID(data)
    if not itemID then return false end
    local price = select(11, C_Item.GetItemInfo(itemID)) or lineData.price
    if not price or price <= 0 then return false end
    ItemTooltip.AddPrice(tooltip, data, SELL_PRICE, price, M.db.mode, M.db.align, M.db.sellPriceColor)
    return true
end

---------------------------------------------------------------------------
-- Repair Cost
---------------------------------------------------------------------------

local function addRepairCost(_, tooltip, data)
    if not Parts.On("repairCost") or InRepairMode() then return end
    local cost = Plain(data.repairCost)
    if type(cost) == "number" and cost > 0 then
        ItemTooltip.AddInfo(tooltip, L.REPAIRCOST_LINE, Kit.Money(cost), M.db.align, "white")
    end
end

---------------------------------------------------------------------------
-- Item Count
---------------------------------------------------------------------------

local ICONS = { bags = "|A:bag-main:0:0|a", bank = "|A:Banker:0:0|a" }

-- The bank's bag ids: every Enum.BagIndex with "Bank" in its name but the account bank.
local bankBags
local function bankBagIDs()
    if not bankBags then
        bankBags = {}
        for name, id in pairs(Enum.BagIndex) do
            if strfind(name, "[Bb]ank") and not strfind(name, "Account") then bankBags[#bankBags + 1] = id end
        end
    end
    return bankBags
end

-- UnitName's second value is a surname on Forever, not a realm.
local function characterKey() return format("%s-%s", GetRealmName(), (UnitName("player"))) end

local bankOpen = false

local function scanBank()
    if not (bankOpen and Parts.On("itemCount")) then return end
    local counts = {}
    for _, bag in pairs(bankBagIDs()) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and Plain(info.itemID)
            if id then counts[id] = (counts[id] or 0) + (info.stackCount or 1) end
        end
    end
    M.db.banks[characterKey()] = counts
end

-- How many are in the bank: counted live while open, else what was kept, else the client's count.
local function bankCount(id, bags)
    local kept = M.db.banks[characterKey()]
    if kept and not bankOpen then return kept[id] or 0 end
    local all = C_Item.GetItemCount(id, true, false, true)
    return all and all > bags and all - bags or 0
end

local function where(place, count)
    if M.db.labels == "icons" then return format(L.ITEMCOUNT_ICON_COUNT, ICONS[place], count) end
    return format(place == "bags" and L.ITEMCOUNT_IN_BAGS or L.ITEMCOUNT_IN_BANK, count)
end

-- "Owned: 45 (bag 30  bank 15)", or just one place and its count.
local function addCount(_, tooltip, data)
    local id = Parts.On("itemCount") and ItemTooltip.ItemID(data)
    if not id then return end
    local bags = C_Item.GetItemCount(id) or 0
    local bank = M.db.bank and bankCount(id, bags) or 0
    local total = bags + bank
    if total <= 0 then return end
    local text
    if bags > 0 and bank > 0 then
        local both = tconcat({ where("bags", bags), where("bank", bank) }, L.ITEMCOUNT_SEPARATOR)
        text = format(L.ITEMCOUNT_TOTAL, total, GRAY_FONT_COLOR:WrapTextInColorCode(format(L.ITEMCOUNT_WHERE, both)))
    else
        text = where(bags > 0 and "bags" or "bank", total)
    end
    ItemTooltip.AddInfo(tooltip, L.ITEMCOUNT_LINE, text, M.db.align, "white")
end

local function queueScan() if bankOpen then M:Soon(scanBank) end end

local BANK_EVENTS = {
    BANKFRAME_OPENED = function() bankOpen = true queueScan() end,
    BANKFRAME_CLOSED = function() bankOpen = false end,
    BAG_UPDATE_DELAYED = queueScan,
    PLAYERBANKSLOTS_CHANGED = queueScan,
}

---------------------------------------------------------------------------

-- Each fn checks its line is on (the tooltip hooks can't be taken off), and runs as the module's.
local function asModule(fn) return function(...) return fn(M, ...) end end
local sellPrice, repairCost, count = asModule(drawSellPrice), asModule(addRepairCost), asModule(addCount)

Parts.Add({
    Enable = function()
        ItemTooltip.ReplaceSellPrice(sellPrice, M)
        ItemTooltip.OnPrices(repairCost, M)
        ItemTooltip.OnInfo(count, M)
        ItemTooltip.RedrawOnShift(M, true)
        for event, fn in pairs(BANK_EVENTS) do M:RegisterEvent(event, fn) end
        bankOpen = BankFrame:IsShown()
        queueScan()
    end,
    Disable = function()
        ItemTooltip.RedrawOnShift(M, false)
        bankOpen = false
    end,
})
