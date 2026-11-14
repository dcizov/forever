--[[
    Forever Tweaks - Repair & Sell Junk
    What a merchant visit always needs, done as it opens (hold Shift while opening one to skip it):
      * Repair: all gear, from the guild bank first when the guild pays (or only from it, or only
        your own money), and says what it cost. The server says whether a guild repair worked only
        afterwards: durability updates when it did; when it didn't (over the guild's daily limit),
        gear still needs it a moment later, and then your own money pays (Guild First).
      * Sell Junk: the merchant's own Sell All Junk (gray items, which go to its buyback list), and
        says what they sold for.
    Each is left to Forever++ (Auto Repair, Auto Sell Junk) or WilduTools (Auto Repair) while
    theirs is on, so nothing is done twice (Core/OtherAddons.lua, CoveredBy).
    Adapted from Forever++'s Auto Repair and Auto Sell Junk by xIGBClutchIx (MIT License).
]]

local _, ns = ...
local L = ns.L

local format, select = string.format, select
local C_Container, C_Item, C_MerchantFrame = C_Container, C_Item, C_MerchantFrame
local OtherAddons = ns.OtherAddons

local COVERS = {
    repair = { { "ForeverPlusPlus", "AutoRepair" }, { "!WilduTools", "automation_autoRepairEnabled" } },
    sellJunk = { { "ForeverPlusPlus", "AutoSellJunk" } },
}

local M = ns:NewModule("Repair", {
    title = L.REPAIR_TITLE,
    category = "merchant",
    description = L.REPAIR_DESC,
    added = "1.9.0",
    defaults = { repair = true, funds = "guildFirst", sellJunk = false, chat = true },
    options = {
        { key = "repair", type = "checkbox", label = L.REPAIR_REPAIR, tooltip = L.REPAIR_REPAIR_TIP },
        { key = "funds", type = "dropdown", label = L.REPAIR_FUNDS, tooltip = L.REPAIR_FUNDS_TIP, requires = "repair",
          choices = {
              { "guildFirst", L.REPAIR_FUNDS_GUILD_FIRST },
              { "guild", L.REPAIR_FUNDS_GUILD },
              { "own", L.REPAIR_FUNDS_OWN },
          } },
        { key = "sellJunk", type = "checkbox", label = L.REPAIR_SELL, tooltip = L.REPAIR_SELL_TIP },
        ns.ChatOption(),
    },
    features = { "repair", "sellJunk" },
})

M.notice = OtherAddons.CoveredNotices(M, COVERS.repair, L.REPAIR_WHAT_REPAIR)
OtherAddons.CoveredNotices(M, COVERS.sellJunk, L.REPAIR_WHAT_SELL, M.notice)

local function money(copper) return C_CurrencyInfo.GetCoinTextureString(copper) end

-- Whether feature `key` is ours to do now: ticked, and no other addon doing it.
local function ours(key)
    return M.db[key] and not OtherAddons.CoveredBy(M, COVERS[key])
end

---------------------------------------------------------------------------
-- Repair
---------------------------------------------------------------------------

local WAIT = 2 -- seconds to wait for the guild bank repair before calling it failed
local pending -- the cost of the guild bank repair waiting for an answer
local timer

local function stopWaiting()
    pending = nil
    M:CancelTimer(timer)
    M:UnregisterEvent("UPDATE_INVENTORY_DURABILITY")
    M:UnregisterEvent("MERCHANT_CLOSED")
end

local function repairOwn(cost)
    if GetMoney() < cost then
        M:Print(format(L.REPAIR_NO_MONEY, money(cost)))
        return
    end
    RepairAllItems()
    M:Print(format(L.REPAIR_DONE, money(cost)))
end

local function onDurability()
    M:Print(format(L.REPAIR_DONE_GUILD, money(pending)))
    stopWaiting()
end

-- No durability update came: repaired after all if nothing needs it now, else the guild didn't pay.
local function checkGuildRepair()
    local cost = pending
    stopWaiting()
    local left, canRepair = GetRepairAllCost()
    if not canRepair or left <= 0 then
        M:Print(format(L.REPAIR_DONE_GUILD, money(cost)))
    elseif M.db.funds == "guildFirst" then
        repairOwn(left)
    else
        M:Print(format(L.REPAIR_NO_GUILD_MONEY, money(left)))
    end
end

-- The guild bank can pay: in a guild, allowed to repair from it, and under today's limit (-1: none).
local function guildCanPay(cost)
    if not (IsInGuild() and CanGuildBankRepair()) then return false end
    local limit = GetGuildBankWithdrawMoney()
    return limit == -1 or limit >= cost
end

local function repairGuild(cost)
    stopWaiting()
    pending = cost
    M:RegisterEvent("UPDATE_INVENTORY_DURABILITY", onDurability)
    M:RegisterEvent("MERCHANT_CLOSED", stopWaiting)
    RepairAllItems(true)
    timer = M:After(WAIT, checkGuildRepair)
end

local function repair()
    if not CanMerchantRepair() then return end
    local cost, canRepair = GetRepairAllCost()
    if not canRepair or cost <= 0 then return end
    local funds = M.db.funds
    if funds ~= "own" and guildCanPay(cost) then
        repairGuild(cost)
    elseif funds == "guild" then
        M:Print(format(L.REPAIR_NO_GUILD_MONEY, money(cost)))
    else
        repairOwn(cost)
    end
end

---------------------------------------------------------------------------
-- Sell junk
---------------------------------------------------------------------------

-- How many gray items the bags hold and what they sell for.
local function junkInBags()
    local count, total = 0, 0
    for bag = 0, NUM_BAG_FRAMES + 1 do -- the backpack, four bags and the reagent bag
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.quality == Enum.ItemQuality.Poor and not info.hasNoValue then
                local price = select(11, C_Item.GetItemInfo(info.hyperlink)) or 0
                count, total = count + 1, total + price * (info.stackCount or 1)
            end
        end
    end
    return count, total
end

local function sellJunk()
    if not C_MerchantFrame.IsSellAllJunkEnabled() or C_MerchantFrame.GetNumJunkItems() == 0 then return end
    local count, total = junkInBags()
    C_MerchantFrame.SellAllJunkItems()
    if count > 0 then M:Print(format(L.REPAIR_SOLD, count, money(total))) end
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

local function onMerchantShow()
    if IsShiftKeyDown() then return end
    if ours("sellJunk") then sellJunk() end -- first: what it sells for can pay for the repair
    if ours("repair") then repair() end
end

function M:OnEnable() self:RegisterEvent("MERCHANT_SHOW", onMerchantShow) end
