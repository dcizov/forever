--[[
    Forever Tweaks - tests/scenarios/tweaks/fpptooltips.lua
    The tooltips from Forever++: Item Tooltips' lines (sell price for the stack, repair cost, how
    many you own, disenchanting, the auction price and its age, with Shift and Auctionator), the
    auction scan keeping prices, Profession Tooltips on items, and each leaving its feature to
    Forever++'s own while that's on.
    Run by tests/run.lua (lua5.1 tests/run.lua fpptooltips), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverTweaks")
login()
local L = ns.L
local Parts = ns.ItemTooltipParts

local function lineOf(lines, label)
    for _, line in ipairs(lines) do
        if line.text and line.text:find(label, 1, true) then return line end
    end
end

-- Sell Price: on by default, the whole stack's price.
W.items["[Linen Cloth]"] = { id = 2589, sell = 13, stack = 20 }
local lines = W.ItemTooltip(2589)
local sell = lineOf(lines, SELL_PRICE)
check(sell ~= nil, "sell price: a line")
eq(sell and sell.right, "13c", "for one item outside the bags")

-- Repair Cost: off by default; on, from the tooltip data.
ns:SetOption("ItemTooltips", "repairCost", true)
local tooltip = { added = {}, NineSlice = { SetBorderColor = function() end } }
local data = { id = 2589, lines = {}, repairCost = 250 }
for _, call in ipairs(W.tooltipPostCalls) do
    if call.kind == Enum.TooltipDataType.Item then
        call.fn(setmetatable(tooltip, { __index = function(_, key)
            if key == "AddLine" then return function(self, text) table.insert(self.added, { text = text }) end end
            if key == "AddDoubleLine" then return function(self, l, r) table.insert(self.added, { text = l, right = r }) end end
            return function() end
        end }), data)
    end
end
local repair = lineOf(tooltip.added, L.REPAIRCOST_LINE)
check(repair and repair.right:find("250c", 1, true) ~= nil, "repair cost: the cost")

-- Item Count: how many you own.
ns:SetOption("ItemTooltips", "itemCount", true)
ns:SetOption("ItemTooltips", "labels", "words")
W.owned[2589] = 7
local owned = lineOf(W.ItemTooltip(2589), L.ITEMCOUNT_LINE)
check(owned and owned.right:find("7", 1, true) ~= nil, "item count: how many you own")

-- Disenchant: an uncommon armor piece of item level 20 gives Strange Dust most likely.
ns:SetOption("ItemTooltips", "disenchant", true)
W.items["[Green Boots]"] = { id = 9000, class = 4, quality = 2, level = 20, equipLoc = "INVTYPE_FEET" }
local de = lineOf(W.ItemTooltip(9000), L.DISENCHANT_LINE)
check(de and de.right:find("10940", 1, true) ~= nil, "disenchant: the likeliest material (its name loading)")
check(lineOf(W.ItemTooltip(2589), L.DISENCHANT_LINE) == nil, "nothing on cloth")

-- Auction Prices: a scanned price and its age.
Parts.House().items[2589] = Parts.PackPrice(40, time() - 7200)
local price = lineOf(W.ItemTooltip(2589), L.AUCTIONPRICES_LINE)
check(price and price.right == "40c", "auction price: the lowest buyout")
local age = lineOf(W.ItemTooltip(2589), L.AUCTIONPRICES_SCAN_AGE_LINE)
check(age and age.right:find("2h ago", 1, true) ~= nil, "and how old it is")
ns:SetOption("ItemTooltips", "auction", false)
check(lineOf(W.ItemTooltip(2589), L.AUCTIONPRICES_LINE) == nil, "Auction Prices off: no line")

-- The scan keeps the lowest price from browse results.
ns:SetOption("ItemTooltips", "auction", true)
W.Fire("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", { { itemKey = { itemID = 4306 }, minPrice = 99, totalQuantity = 3 } })
eq(Parts.AuctionPrice(4306), 99, "a browse result's price is kept")

-- Profession Tooltips: a herb in the bags says the skill that gathers it.
ns:SetOption("ProfessionTooltips", "show", "always")
W.items["[Peacebloom]"] = { id = 2447 }
check(lineOf(W.ItemTooltip(2447), "Herbalism") ~= nil, "profession tooltips: the herb's skill")

-- A lockbox learned from its "Requires Lockpicking" line still gets a line where its tooltip
-- has none of its own (another build of it: a chat link, another addon's lines).
W.items["[Battered Junkbox]"] = { id = 16882 }
W.knownSpells[1804] = true -- Pick Lock
W.ItemTooltip(16882, nil, { { leftText = "Battered Junkbox" }, { leftText = "Requires Lockpicking (1)" } })
local box = W.ItemTooltip(16882, nil, { { leftText = "Battered Junkbox" }, { leftText = "Locked" } })
check(lineOf(box, "Lockpicking") ~= nil, "profession tooltips: a known lockbox's line wherever its tooltip shows")

-- Tooltips: on by default; a player's name in their class color, the border too, and who they target.
W.Creature("mouseover", 1, "Somebody", { player = true, class = "MAGE" })
W.unitInfo.mouseover.guid = "Player-1-0000ABCD"
W.Creature("mouseovertarget", 2, "Big Boar")
local tip = W.UnitTooltip("Player-1-0000ABCD", "mouseover")
check(_G["W.UnitTipTextLeft1"]._color ~= nil, "tooltips: the name colored by class")
local target = lineOf(tip, L.TOOLTIPS_TARGET_LINE)
eq(target and target.right, "Big Boar", "and a line for who it targets")

-- On the game's own tooltip: a coloured border goes back to the default once the tooltip is
-- cleared (the same hook also brings back a tooltip faded in combat), and a faded one comes back
-- when combat ends.
local function onGameTooltip()
    function GameTooltip:GetUnit() return nil, "mouseover" end
    for _, call in ipairs(W.tooltipPostCalls) do
        if call.kind == Enum.TooltipDataType.Unit then call.fn(GameTooltip, { guid = "Player-1-0000ABCD", lines = {} }) end
    end
end
onGameTooltip()
check(GameTooltip.NineSlice._border[1] ~= TOOLTIP_DEFAULT_COLOR.r, "tooltips: the border in the class colour")
GameTooltip:Fire("OnTooltipCleared")
eq(GameTooltip.NineSlice._border[1], TOOLTIP_DEFAULT_COLOR.r, "and back to the default once cleared")
ns:SetOption("Tooltips", "hideInCombat", true)
W.combat = true
onGameTooltip()
eq(GameTooltip._alpha, 0, "hide in combat: faded")
W.combat = false
W.Fire("PLAYER_REGEN_ENABLED")
eq(GameTooltip._alpha, 1, "back when combat ends")

-- Each leaves its feature to Forever++'s own while that's on.
W.loaded.ForeverPlusPlus = true
ForeverPlusPlusAPI = { v1 = { IsModuleEnabled = function() return true end } }
check(lineOf(W.ItemTooltip(2589), SELL_PRICE) == nil, "Forever++'s Item Tooltips on: left to it")
check(lineOf(W.ItemTooltip(2447), "Herbalism") == nil, "and its Profession Tooltips")
finish()
