--[[
    Forever Tweaks - Item Tooltips: Auction Prices
    The lowest auction house buyout in item tooltips, under the sell price, counted for the stack
    (Shift for one) like it, and how long ago it was seen ("Scanned: 2h ago", green when fresh to
    red at Red After). The prices come from scanning the auction house (AuctionScan.lua), kept for
    each auction house ("Realm-Faction"), or, with Use Auctionator's Prices, from Auctionator
    (Core/OtherAddons.lua). Disenchant prices its materials through Parts.AuctionPrice. A saved
    price is one short string, "copper,minutes since EPOCH", since thousands are kept. Adapted from
    Forever++'s Item Tooltips by xIGBClutchIx (MIT License).
]]

local _, ns = ...
local L = ns.L

local type, tonumber, format, floor, time = type, tonumber, string.format, math.floor, time
local ItemTooltip, OtherAddons = ns.ItemTooltip, ns.OtherAddons
local Parts = ns.ItemTooltipParts
local M = Parts.module

local EPOCH = 1700000000 -- before any price was saved

-- A price and when it was seen, as saved; and back.
function Parts.PackPrice(copper, seenAt)
    -- %.0f: the game's %d overflows past 2^31 copper, and listings go higher.
    return format("%.0f,%d", floor(copper + 0.5), floor((seenAt - EPOCH) / 60))
end

local function unpackPrice(saved)
    if type(saved) ~= "string" then return nil end
    local copper, minutes = saved:match("^(%d+),(%-?%d+)$")
    if not copper then return nil end
    return tonumber(copper), EPOCH + tonumber(minutes) * 60
end
Parts.UnpackPrice = unpackPrice

local houseData -- this character's auction house, once its faction is known

-- The auction house this character sees (realms share one per faction).
function Parts.House()
    if houseData then return houseData end
    local faction = UnitFactionGroup("player")
    local key = format("%s-%s", GetRealmName(), faction or "")
    local data = M.db.houses[key]
    if not (data and data.items) then
        data = { scannedAt = 0, items = {} }
        M.db.houses[key] = data
    end
    if faction then houseData = data end
    return data
end

-- Whether prices come from Auctionator: chosen, and it's there.
function Parts.UsingAuctionator() return M.db.auctionator and OtherAddons.HasAuctionPrices() end

-- One item's lowest buyout in copper and when it was seen (nil when Auctionator gives it), or nil
-- while the auction lines are off or nothing's known.
function Parts.AuctionPrice(itemID)
    if not Parts.On("auction") then return nil end
    if Parts.UsingAuctionator() then return OtherAddons.AuctionPrice(nil, itemID) end
    return unpackPrice(Parts.House().items[itemID])
end

-- A price's age color: by age green, yellow halfway, red at Red After; or the color named.
local function ageColor(seconds)
    if M.db.scanAgeColor ~= "age" then return M.db.scanAgeColor end
    local t = math.min(1, seconds / (M.db.scanAgeRedHours * 3600))
    if t < 0.5 then return { t * 2, 1, 0 } end
    return { 1, (1 - t) * 2, 0 }
end

-- "5m ago", "3h ago", "2d ago".
local function ago(seconds)
    if seconds < 3600 then return format(L.AUCTIONPRICES_MINUTES_AGO, floor(seconds / 60)) end
    if seconds < 86400 then return format(L.AUCTIONPRICES_HOURS_AGO, floor(seconds / 3600)) end
    return format(L.AUCTIONPRICES_DAYS_AGO, floor(seconds / 86400))
end

-- The tooltip's item, unless it's gray and Hide on Junk is on.
local function tooltipItem(data)
    local itemID = Parts.On("auction") and ItemTooltip.ItemID(data)
    if itemID and M.db.hideJunk and C_Item.GetItemQualityByID(itemID) == Enum.ItemQuality.Poor then return nil end
    return itemID
end

local function addPrice(tooltip, data)
    local itemID = tooltipItem(data)
    local price = itemID and Parts.AuctionPrice(itemID)
    if price then
        ItemTooltip.AddPrice(tooltip, data, L.AUCTIONPRICES_LINE, price, M.db.mode, M.db.align, M.db.auctionColor)
    end
end

-- After every price line, so prices from this one (Disenchant) sit above it.
local function addAge(tooltip, data)
    local itemID = tooltipItem(data)
    if not itemID or M.db.scanAge == "off" then return end
    local price, seenAt = Parts.AuctionPrice(itemID)
    if price and seenAt then
        local age = time() - seenAt
        ItemTooltip.AddInfo(tooltip, L.AUCTIONPRICES_SCAN_AGE_LINE, ago(age), M.db.scanAge, ageColor(age))
    end
end

-- /ft resetprices: forgets this auction house's prices, after asking.
M:AddCommand("resetprices", nil, L.AUCTIONPRICES_RESET_COMMAND, function()
    ns:Confirm(M, "AUCTIONPRICES_RESET", L.AUCTIONPRICES_RESET_CONFIRM, function()
        local data = Parts.House()
        data.items, data.scannedAt = {}, 0
        ns.Print(M, L.AUCTIONPRICES_RESET_DONE) -- a reply: shown even with chat muted
    end)
end)

Parts.Add({
    Enable = function()
        ItemTooltip.OnPrices(addPrice, M)
        ItemTooltip.OnPriceNotes(addAge, M)
    end,
})
