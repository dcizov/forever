--[[
    Forever Tweaks - Item Tooltips
    Lines in item tooltips, each its own checkbox: the vendor price of the whole stack (Shift for
    one), what damaged gear costs to repair, how many you own (bags and bank), what disenchanting
    gives, each stat line in its stat's color, and the lowest auction house buyout (from scanning
    the auction house, or Auctionator's prices); and Blizzard's comparison on a bag recipe for
    gear. This file has the module and the settings every line shares; each line is a part in a
    file of its own (ItemPrices.lua, ItemDisenchant.lua, ItemStatColors.lua, AuctionPrices.lua,
    AuctionScan.lua), placed by Lib/ItemTooltip.lua. Left to Forever++'s Item Tooltips while
    that's on. Adapted from Forever++ by xIGBClutchIx (MIT License).
]]

local _, ns = ...
local L = ns.L

local OtherAddons = ns.OtherAddons

local COVERS = { { "ForeverPlusPlus", "ItemTooltips" } }
local COLORS = { { "gray", L.PRICE_COLOR_GRAY }, { "white", L.PRICE_COLOR_WHITE }, { "gold", L.PRICE_COLOR_GOLD } }
local ALIGN = { { "right", L.PRICE_ALIGN_RIGHT }, { "inline", L.PRICE_ALIGN_INLINE } }

local M = ns:NewModule("ItemTooltips", {
    title = L.ITEMTOOLTIPS_TITLE,
    category = "tooltips",
    description = L.ITEMTOOLTIPS_DESC,
    added = "2.2.0",
    defaults = {
        sellPrice = true, repairCost = false, itemCount = false, disenchant = false, statColors = true,
        auction = true, craftedCompare = "usable",
        mode = "stack", align = "right",
        sellPriceColor = "white",
        bank = true, labels = "icons",
        auctionColor = "gold", hideJunk = false, scanAge = "right", scanAgeColor = "age", scanAgeRedHours = 12,
        scanOnOpen = true, auctionator = false, chat = true,
        -- Data: each character's bank ("Realm-Name" -> { [itemID] = count }), each auction house's
        -- prices ("Realm-Faction" -> { scannedAt, items = { [itemID] = "copper,minutes" } }), and
        -- what disenchanting showed (Lib/Disenchant.lua).
        banks = {}, houses = {}, disenchanted = {},
    },
    options = {
        { key = "mode", type = "dropdown", label = L.PRICE_MODE, tooltip = L.PRICE_MODE_TIP,
          choices = { { "stack", L.PRICE_MODE_STACK }, { "one", L.PRICE_MODE_ONE } }, section = L.ITEMTOOLTIPS_SECTION_GENERAL },
        { key = "align", type = "dropdown", label = L.PRICE_ALIGN, tooltip = L.PRICE_ALIGN_TIP, choices = ALIGN },
        { key = "sellPrice", type = "checkbox", label = L.ITEMTOOLTIPS_SELLPRICE, tooltip = L.ITEMTOOLTIPS_SELLPRICE_TIP,
          section = L.ITEMTOOLTIPS_SECTION_LINES },
        { key = "sellPriceColor", type = "dropdown", label = L.PRICE_COLOR, tooltip = L.PRICE_COLOR_TIP, choices = COLORS,
          requires = "sellPrice" },
        { key = "repairCost", type = "checkbox", label = L.ITEMTOOLTIPS_REPAIRCOST, tooltip = L.ITEMTOOLTIPS_REPAIRCOST_TIP },
        { key = "itemCount", type = "checkbox", label = L.ITEMTOOLTIPS_ITEMCOUNT, tooltip = L.ITEMTOOLTIPS_ITEMCOUNT_TIP },
        { key = "bank", type = "checkbox", label = L.ITEMCOUNT_BANK, tooltip = L.ITEMCOUNT_BANK_TIP, requires = "itemCount" },
        { key = "labels", type = "dropdown", label = L.ITEMCOUNT_LABELS, tooltip = L.ITEMCOUNT_LABELS_TIP, requires = "itemCount",
          choices = { { "icons", L.ITEMCOUNT_LABELS_ICONS }, { "words", L.ITEMCOUNT_LABELS_WORDS } } },
        { key = "disenchant", type = "checkbox", label = L.ITEMTOOLTIPS_DISENCHANT, tooltip = L.ITEMTOOLTIPS_DISENCHANT_TIP },
        { key = "statColors", type = "checkbox", label = L.ITEMTOOLTIPS_STATCOLORS, tooltip = L.ITEMTOOLTIPS_STATCOLORS_TIP },
        { key = "craftedCompare", type = "dropdown", label = L.CRAFTEDCOMPARE_TITLE, tooltip = L.CRAFTEDCOMPARE_TIP,
          choices = { { "usable", L.CRAFTEDCOMPARE_USABLE }, { "professions", L.CRAFTEDCOMPARE_PROFESSIONS },
              { "off", L.CRAFTEDCOMPARE_OFF } } },
        { key = "auction", type = "checkbox", label = L.ITEMTOOLTIPS_AUCTION, tooltip = L.ITEMTOOLTIPS_AUCTION_TIP,
          section = L.AUCTIONPRICES_TITLE },
        { key = "auctionColor", type = "dropdown", label = L.PRICE_COLOR, tooltip = L.PRICE_COLOR_TIP, choices = COLORS,
          requires = "auction" },
        { key = "hideJunk", type = "checkbox", label = L.AUCTIONPRICES_JUNK, tooltip = L.AUCTIONPRICES_JUNK_TIP, requires = "auction" },
        { key = "scanAge", type = "dropdown", label = L.AUCTIONPRICES_SCAN_AGE, tooltip = L.AUCTIONPRICES_SCAN_AGE_TIP,
          requires = "auction", choices = { ALIGN[1], ALIGN[2], { "off", L.AUCTIONPRICES_SCAN_AGE_OFF } } },
        { key = "scanAgeColor", type = "dropdown", label = L.AUCTIONPRICES_SCAN_AGE_COLOR, tooltip = L.AUCTIONPRICES_SCAN_AGE_COLOR_TIP,
          requires = "auction", shown = function(db) return db.scanAge ~= "off" end,
          choices = { { "age", L.AUCTIONPRICES_SCAN_AGE_COLOR_AGE }, COLORS[1], COLORS[2], COLORS[3] } },
        { key = "scanAgeRedHours", type = "slider", label = L.AUCTIONPRICES_SCAN_AGE_RED, tooltip = L.AUCTIONPRICES_SCAN_AGE_RED_TIP,
          requires = "auction", min = 1, max = 48, step = 1, format = L.AUCTIONPRICES_HOURS,
          shown = function(db) return db.scanAge ~= "off" and db.scanAgeColor == "age" end },
        { key = "scanOnOpen", type = "checkbox", label = L.AUCTIONPRICES_SCAN_ON_OPEN, tooltip = L.AUCTIONPRICES_SCAN_ON_OPEN_TIP,
          requires = "auction" },
        { key = "auctionator", type = "checkbox", label = L.AUCTIONPRICES_AUCTIONATOR, tooltip = L.AUCTIONPRICES_AUCTIONATOR_TIP,
          requires = "auction", shown = function() return OtherAddons.HasAuctionPrices() end },
        ns.ChatOption(L.AUCTIONPRICES_CHAT_TIP),
    },
    features = { "sellPrice", "repairCost", "itemCount", "disenchant", "statColors", "auction" },
})

M.notice = OtherAddons.CoveredNotices(M, COVERS, L.ITEMTOOLTIPS_WHAT)

-- What the part files (ItemPrices, ItemDisenchant, ItemStatColors, AuctionPrices, AuctionScan)
-- need from this file. Each reaches the module with assert(ns.modules.ItemTooltips) and joins
-- it with M:AddPart (Core/Module.lua), so it turns on, off and changes with the module.
local Shared = {}
ns.ItemTooltipsShared = Shared

-- Whether line `key` is drawn now: the module on, its checkbox ticked (a dropdown not "off"), and
-- Forever++'s own not on.
function Shared.IsShown(key)
    local value = M.db[key]
    return M.active and value and value ~= "off" and not OtherAddons.CoveredBy(M, COVERS) or false
end

function M:OnInitialize() ns.Disenchant.Attach(self.db.disenchanted) end
