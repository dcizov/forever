--[[
    Forever Gearbox - tests/stubs/merchant.lua
    The stand-in game's merchant window, loaded by tests/wow.lua. A scenario fills W.merchant
    (index -> { id, link, price, stackCount, numAvailable, maxStack, extended, purchasable }),
    sets W.money and W.owned (itemID -> count in the bags), then calls W.OpenMerchant().
    Purchases land in W.bought ({ index, units }).
]]

W.merchant, W.bought, W.owned = {}, {}, {}
W.money = 0

function GetMoney() return W.money end
C_CurrencyInfo = { GetCoinTextureString = function(copper) return tostring(copper) .. "c" end }
C_Item.GetItemCount = function(item) return W.owned[item] or 0 end
C_Item.RequestLoadItemDataByID = function() end
C_Item.GetItemNameByID = function(id)
    for _, it in pairs(W.merchant) do if it.id == id then return it.link end end
    for link, it in pairs(W.items) do if it.id == id then return (link:gsub("^%[(.*)%]$", "%1")) end end
end

function GetMerchantNumItems() return #W.merchant end
function GetMerchantItemID(i) return W.merchant[i] and W.merchant[i].id end
function GetMerchantItemLink(i) return W.merchant[i] and W.merchant[i].link end
function GetMerchantItemMaxStack(i) return W.merchant[i] and W.merchant[i].maxStack or 20 end
function BuyMerchantItem(i, units)
    local it = W.merchant[i]
    W.bought[#W.bought + 1] = { index = i, units = units }
    W.money = W.money - it.price * units / (it.stackCount or 1)
end

C_MerchantFrame = {
    GetItemInfo = function(i)
        local it = W.merchant[i]
        if not it then return nil end
        return { name = it.link, texture = 0, price = it.price, stackCount = it.stackCount or 1,
            numAvailable = it.numAvailable or -1, isPurchasable = it.purchasable ~= false, isUsable = true,
            hasExtendedCost = it.extended or false, isQuestStartItem = false }
    end,
}

-- The merchant window: its item buttons call MerchantItemButton_OnModifiedClick on a modified click.
-- Opening it shows the merchant tab (MerchantFrame_UpdateMerchantInfo), with Blizzard's Sell All
-- Junk button in its bottom row; W.MerchantTab(2) is the buyback tab.
MerchantFrame = W.NewFrame("Frame", "MerchantFrame", UIParent)
MerchantFrame:Hide()
MerchantFrame.selectedTab = 1
MerchantSellAllJunkButton = W.NewFrame("Button", "MerchantSellAllJunkButton", MerchantFrame)
MerchantRepairAllButton = W.NewFrame("Button", "MerchantRepairAllButton", MerchantFrame)
W.canRepair, W.canGuildRepair = false, false
function CanMerchantRepair() return W.canRepair end
function CanGuildBankRepair() return W.canGuildRepair end
function MerchantItemButton_OnModifiedClick() end
function MerchantFrame_UpdateMerchantInfo() end
function MerchantFrame_UpdateBuybackInfo() end
function W.MerchantTab(tab)
    MerchantFrame.selectedTab = tab
    if tab == 1 then MerchantFrame_UpdateMerchantInfo() else MerchantFrame_UpdateBuybackInfo() end
end
-- Alt-clicks the merchant's item `index`.
function W.AltClickMerchantItem(index)
    local button = W.NewFrame("ItemButton", nil, MerchantFrame)
    function button:GetID() return index end
    W.alt = true
    MerchantItemButton_OnModifiedClick(button, "LeftButton")
    W.alt = false
end
function W.OpenMerchant()
    W.bought = {}
    W.Fire("MERCHANT_SHOW")
    MerchantFrame:Show()
    W.MerchantTab(1)
end
function W.CloseMerchant()
    MerchantFrame:Hide()
    W.Fire("MERCHANT_CLOSED")
end
-- What was bought lands in the bags.
function W.LandPurchases()
    for _, b in ipairs(W.bought) do
        local id = W.merchant[b.index].id
        W.owned[id] = (W.owned[id] or 0) + b.units
    end
    W.bought = {}
    W.Fire("BAG_UPDATE_DELAYED")
end

-- Repairs and junk (Repair & Sell Junk). W.repairCost is what RepairAllItems costs; W.guildLimit is
-- the guild bank's daily limit (-1: none); W.repaired lists each repair as "own" or "guild";
-- W.junkSold counts Sell All Junk presses.
W.repairCost, W.guildLimit, W.repaired, W.junkSold = 0, -1, {}, 0
function GetRepairAllCost() return W.repairCost, W.repairCost > 0 end
function GetGuildBankWithdrawMoney() return W.guildLimit end
function RepairAllItems(guild)
    W.repaired[#W.repaired + 1] = guild and "guild" or "own"
    if not guild then W.money = W.money - W.repairCost end
    if not guild or W.guildLimit == -1 or W.guildLimit >= W.repairCost then W.repairCost = 0 end
end
local function junkCount()
    local n = 0
    for _, slots in pairs(W.bags) do
        for _, entry in pairs(slots) do if entry.quality == 0 then n = n + 1 end end
    end
    return n
end
C_MerchantFrame.IsSellAllJunkEnabled = function() return true end
C_MerchantFrame.GetNumJunkItems = junkCount
C_MerchantFrame.SellAllJunkItems = function() W.junkSold = W.junkSold + 1 end

-- Worn gear's durability (Durability Warning): W.durability[slot] = { current, maximum }.
W.durability = {}
function GetInventoryItemDurability(slot)
    local d = W.durability[slot]
    if d then return d[1], d[2] end
end
-- W.worn[slot]: the link worn there (gear for upgrade judgements); else a durability item's.
W.worn = {}
function GetInventoryItemLink(_, slot) return W.worn[slot] or W.durability[slot] and ("[Item " .. slot .. "]") or nil end

-- Minimap tracking (Gathering Tracking): W.tracking = { { spellID, active } }; W.trackingRefused
-- makes SetTracking error, as the game refusing an addon would.
W.tracking = {}
C_Minimap = {
    -- Yards from the minimap's centre to its edge: zoom 0, outdoors or in (W.viewRadius overrides).
    GetViewRadius = function() return W.viewRadius or (W.indoors and 150 or 233.33) end,
    GetNumTrackingTypes = function() return #W.tracking end,
    GetTrackingInfo = function(i)
        local t = W.tracking[i]
        return t and { name = tostring(t.spellID), spellID = t.spellID, active = t.active or false, type = "spell" }
    end,
    SetTracking = function(i, on)
        if W.trackingRefused then error("ADDON_ACTION_FORBIDDEN") end
        for j, t in ipairs(W.tracking) do t.active = (j == i) and on or false end
    end,
}
