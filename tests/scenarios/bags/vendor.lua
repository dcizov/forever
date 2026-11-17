--[[
    Forever Gearbox - tests/scenarios/bags/vendor.lua
    Vendor: Auto Buy (Alt-click to pick a count, buying what's missing in whole bundles that reach it
    and in stacks, never beyond the money, the merchant's stock or the bags' room, never
    extended-cost items; ammo as a kind: every arrow counts, the best arrows the merchant sells
    that you can use are bought), Shift skipping it,
    pausing and the bag counts on its page, Ask First, and the Restock button.
    Run by tests/run.lua (lua5.1 tests/run.lua vendor), which passes its helpers in.
]]

local T = ...
local under = T.under -- every frame under one that passes a test (tests/run.lua)
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverGearbox")
login()
local mod = ns.modules.Vendor
check(mod.active, "on by default (Autobuy)")

-- The plan alone: (missing, bundle, price a bundle, available bundles, cash, units per purchase).
local function plan(...) return table.concat(mod.PlanPurchase(...), ",") end
eq(plan(45, 1, 10, -1, 10000, 20), "20,20,5", "45 missing, sold one at a time, 20 a purchase")
eq(plan(45, 5, 50, -1, 10000, 20), "20,20,5", "whole bundles of 5")
eq(plan(43, 5, 50, -1, 10000, 20), "20,20,5", "43 missing buys 45: whole bundles that reach it")
eq(plan(31, 5, 50, -1, 10000, 20), "20,15", "keep 50 water sold in 5s with 19 in the bags: 35, so 54")
eq(plan(31, 200, 100, -1, 10000, 1000), "200", "keep 50 arrows with 19: a bundle of 200")
eq(plan(5, 1, 10, -1, 10000, 20), "5", "keep 20 runes with 15 in the bags: buys 5")
eq(plan(3, 5, 50, -1, 10000, 20), "5", "fewer missing than a bundle: one bundle")
eq(plan(100, 1, 10, -1, 10000, 20, 42), "20,20,2", "no more than the bags have room for")
eq(plan(31, 5, 50, -1, 10000, 20, 12), "10", "room for 12: two bundles of 5")
eq(plan(100, 1, 10, 3, 10000, 20), "3", "the merchant has only 3")
eq(plan(100, 1, 10, -1, 55, 20), "5", "money for only 5")
eq(plan(400, 200, 100, -1, 10000, 1000), "400", "arrows come in 200s")
eq(plan(0, 1, 10, -1, 10000, 20), "", "nothing missing, nothing bought")

-- The merchant: arrows (200 for 1s), water (5 for 25c), and a token item.
W.merchant = {
    { id = 2512, link = "[Rough Arrow]", price = 100, stackCount = 200, maxStack = 1000 },
    { id = 159, link = "[Refreshing Spring Water]", price = 25, stackCount = 5, maxStack = 20 },
    { id = 999, link = "[Token Gear]", price = 0, extended = true },
}
W.money = 100000
-- Straight buying first; Ask First (on by default) and the Restock button come further down.
eq(mod.db.ask, true, "Ask First on by default")
ns:SetOption("Vendor", "ask", false)

-- Alt-click sets how many to keep; the prompt starts empty, then shows the current count.
W.AltClickMerchantItem(2)
local popup = W.popups[#W.popups]
check(popup and popup.text:find("Refreshing Spring Water", 1, true), "Alt-click asks how many to keep")
popup.EditBox:SetText("40")
W.Accept()
eq(mod.db.buy[159], 40, "keeps 40 water")
W.AltClickMerchantItem(1)
check(W.popups[#W.popups].text:find("sold 200 at a time", 1, true), "for arrows it says they're sold by 200")
W.popups[#W.popups].EditBox:SetText("6")
W.Accept()
check(W.ChatHas(ns.L.VENDOR_BELOW_BUNDLE:format(200)), "keeping fewer than a bundle: told nothing will be bought")
W.AltClickMerchantItem(1)
W.popups[#W.popups].EditBox:SetText("1000")
W.Accept()
W.AltClickMerchantItem(3)
W.popups[#W.popups].EditBox:SetText("1")
W.Accept()
eq(mod.db.buy[999], 1, "the token item is listed too")
W.AltClickMerchantItem(2)
eq(W.popups[#W.popups].EditBox:GetText(), "40", "asking again starts from the current count")
W.popups[#W.popups].EditBox:SetText("lots")
W.Accept()
eq(mod.db.buy[159], 40, "a word isn't a count: nothing changed")

local lines = W.ItemTooltip(159)
check(lines[1] and lines[1].text:find("40", 1, true), "the tooltip says how many are kept")

W.owned[159] = 12
W.owned[2512] = 600
W.OpenMerchant()
local byIndex = {}
for _, b in ipairs(W.bought) do byIndex[b.index] = (byIndex[b.index] and byIndex[b.index] .. "," or "") .. b.units end
eq(byIndex[2], "20,10", "28 water missing: 30 bought (whole 5s), as 20 and 10")
eq(byIndex[1], "400", "400 arrows missing: two bundles in one purchase")
eq(byIndex[3], nil, "an extended-cost item is never bought")

-- Not enough money: buys what it can, across items.
W.owned[159], W.owned[2512] = 0, 0
W.money = 125
W.OpenMerchant()
byIndex = {}
for _, b in ipairs(W.bought) do byIndex[b.index] = (byIndex[b.index] or 0) + b.units end
eq(byIndex[1], 200, "one bundle of arrows for 100")
eq(byIndex[2], 5, "and one bundle of water (25c) with the 25 left")
check(W.money >= 0, "never more than the money")

-- Alt-click 0 stops buying it.
W.AltClickMerchantItem(2)
W.popups[#W.popups].EditBox:SetText("0")
W.Accept()
eq(mod.db.buy[159], nil, "0 stops buying water")

-- Shift skips it.
W.owned[2512] = 0
W.shift = true
W.OpenMerchant()
W.shift = false
eq(#W.bought, 0, "Shift: nothing bought")

-- /fg autobuy lists the items.
W.Slash("/fg autobuy")
check(W.ChatHas("1000 x [Rough Arrow]"), "/fg autobuy lists what's kept")

-- Its list on its page in Gearbox' settings: the Autobuy list, edited without a merchant.
ns:OpenSettings("Vendor")
local page = W.categories[ns.title].frame
check(page:IsShown(), "the list on its page, under its options")
local function listed(text)
    return #under(page, function(f) return f._kind == "FontString" and f._text == text and f:IsShown() end) > 0
end
check(listed("[Rough Arrow]"), "the page lists what Autobuy keeps")
-- The add row: an Item box (empty) and an Amount box (starting at 20), then Add.
local function visibleBox(text)
    return under(page, function(f) return f._kind == "EditBox" and (f:GetText() or "") == text and f:IsVisible() end)[1]
end
local itemBox, amountBox = visibleBox(""), visibleBox("20")
local addButton = under(page, function(f) return f._text == ns.L.ITEMLIST_ADD and f:IsVisible() end)[1]
check(itemBox and amountBox and addButton, "an Item box, an Amount box and Add")
itemBox:SetText("159")
amountBox:SetText("40")
addButton:Fire("OnClick")
eq(mod.db.buy[159], 40, "added by ID with its amount")
check(listed("[Refreshing Spring Water]"), "and listed")
eq(itemBox:GetText(), "", "the Item box is cleared for the next")
-- Dragging an item from the bags onto the Item box, then Enter in the Amount box.
W.held = { "item", 4540, "|cffffffff|Hitem:4540::::::::|h[Tough Hunk of Bread]|h|r" }
itemBox:Fire("OnReceiveDrag")
check(itemBox:GetText():find("item:4540", 1, true), "a dragged item fills the box")
eq(W.held, nil, "and leaves the cursor")
amountBox:SetText("10")
amountBox:Fire("OnEnterPressed")
eq(mod.db.buy[4540], 10, "added from the drag, keeping 10")
-- No amount: nothing added.
itemBox:SetText("2287")
amountBox:SetText("0")
addButton:Fire("OnClick")
eq(mod.db.buy[2287], nil, "an amount of 0 adds nothing")
check(W.ChatHas(ns.L.ITEMLIST_BAD_AMOUNT), "and says so")
amountBox:SetText("2.5")
addButton:Fire("OnClick")
eq(mod.db.buy[2287], nil, "nor does a fraction")
-- One reading of an amount everywhere: whole numbers from 0; item IDs from 1.
local ItemList = ns.ItemList
eq(ItemList.ParseAmount(" 20 "), 20, "an amount, trimmed")
eq(ItemList.ParseAmount("0"), 0, "0 is an amount (the Alt-click prompt stops an item with it)")
eq(ItemList.ParseAmount("2.5"), nil, "a fraction isn't")
eq(ItemList.ParseAmount("-3"), nil, "nor a negative number")
eq(ItemList.Parse("159.5"), nil, "an item ID is whole")
eq(ItemList.Parse("0"), nil, "and more than 0")
itemBox:SetText("")
-- A row's amount box.
local countBox = visibleBox("40")
countBox:SetText("60")
countBox:Fire("OnEnterPressed")
eq(mod.db.buy[159], 60, "its amount changed on the page")
local removes = under(page, function(f) return f._text == ns.L.ITEMLIST_REMOVE and f:IsShown() end)
eq(#removes, 4, "a Remove button per item")
for _, b in ipairs(removes) do
    if b:GetParent().itemID == 159 then b:Fire("OnClick") end
end
eq(mod.db.buy[159], nil, "removed on the page")
check(not listed("[Refreshing Spring Water]"), "and gone from the list")
-- An item the game hasn't loaded: its ID until its name comes, then its name.
mod.db.buy[2515] = 200
mod:ListChanged()
check(listed("item:2515"), "an item not loaded yet shows its ID")
W.items["[Sharp Arrow]"] = { id = 2515 }
W.Fire("GET_ITEM_INFO_RECEIVED", 2515, true)
W.Advance(0.1)
check(listed("Sharp Arrow"), "its name once the game has it")
mod.db.buy[2515] = nil
mod:ListChanged()

-- Pausing an item on the page: listed, grayed, not bought, its tooltip quiet.
local function rowOf(id)
    for _, f in ipairs(under(page, function(f) return f.itemID == id and f:IsShown() end)) do return f end
end
local arrows = rowOf(2512)
check(arrows and arrows.on and arrows.on:GetChecked(), "each row has a checkbox, ticked")
eq(arrows.have._text, "0", "and how many are in the bags")
arrows.on:SetChecked(false)
arrows.on:Fire("OnClick")
eq(mod.db.paused[2512], true, "unticked: paused")
eq(mod.db.buy[2512], 1000, "and still listed")
eq(#W.ItemTooltip(2512), 0, "a paused item's tooltip says nothing")
W.OpenMerchant()
local boughtArrows = false
for _, b in ipairs(W.bought) do boughtArrows = boughtArrows or b.index == 1 end
eq(boughtArrows, false, "a paused item isn't bought")
W.Slash("/fg autobuy")
check(W.ChatHas("(paused)"), "/fg autobuy says it's paused")
arrows.on:SetChecked(true)
arrows.on:Fire("OnClick")
eq(mod.db.paused[2512], nil, "ticked again: bought again")
W.CloseMerchant()

-- Ask First: the question lists what and the total, and buys only on Yes.
W.money, W.owned[2512] = 100000, 600
ns:SetOption("Vendor", "ask", true)
W.OpenMerchant()
eq(#W.bought, 0, "Ask First: nothing bought before the answer")
local asked = W.popups[#W.popups]
check(asked and asked.text:find("400 x [Rough Arrow] (you have 600, keeping 1000)", 1, true),
    "the question lists each item, how many, and what it counted in the bags")
check(asked.text:find(ns.L.VENDOR_ASK_TOTAL:format("200c"), 1, true), "and the total")
W.Accept()
eq(W.bought[1] and W.bought[1].units, 400, "Yes buys it")
W.LandPurchases()
eq(arrows.have._text, "1000", "the page's count follows the bags")
W.CloseMerchant()

-- Buy When a Merchant Opens off: only the Restock button buys.
ns:SetOption("Vendor", "auto", false)
W.owned[2512] = 600
W.OpenMerchant()
eq(#W.popups, 0, "no question")
eq(#W.bought, 0, "nothing bought on opening")
local restock = _G.ForeverGearboxRestockButton
check(restock and restock:IsShown(), "the Restock button shows in the merchant window")
eq(select(2, restock:GetPoint()), MerchantSellAllJunkButton, "beside Sell All Junk")
eq(select(4, MerchantSellAllJunkButton:GetPoint()), -182, "no repairs: Sell All Junk moves left, the pair clear of the buyback item")
W.canRepair = true
W.MerchantTab(1)
eq(select(4, MerchantRepairAllButton:GetPoint()), 104, "repairs: Blizzard's group moves left for Restock")
eq(select(2, MerchantSellAllJunkButton:GetPoint()), MerchantRepairAllButton, "Sell All Junk stays beside Repair All")
W.canGuildRepair = true
W.MerchantTab(1)
eq(restock:IsShown(), false, "repairs from the guild bank: no room, no Restock")
W.canRepair, W.canGuildRepair = false, false
W.MerchantTab(1)
check(restock:IsEnabled(), "lit while something's missing")
restock:Fire("OnClick", "LeftButton")
eq(W.bought[1] and W.bought[1].units, 400, "a click buys without asking")
W.LandPurchases()
eq(restock:IsEnabled(), false, "grayed once nothing's missing")
W.MerchantTab(2)
eq(restock:IsShown(), false, "hidden on the buyback tab")
W.MerchantTab(1)
check(restock:IsShown(), "back on the merchant tab")
restock:Fire("OnClick", "RightButton")
check(ns.modules.Vendor.WindowShown(), "right-click opens the Autobuy window")
local autobuy = ForeverGearboxAutobuyWindow
check(#under(autobuy, function(f) return f._text == ns.L.VENDOR_LIST_HEADER end) > 0, "the Autobuy list in it")
restock:Fire("OnClick", "RightButton")
check(not ns.modules.Vendor.WindowShown(), "right-click again closes it")
ns:SetOption("Vendor", "button", false)
eq(restock:IsShown(), false, "Restock Button off: gone")
eq(select(4, MerchantSellAllJunkButton:GetPoint()), -148, "and Sell All Junk back in Blizzard's place")
ns:SetOption("Vendor", "button", true)
check(restock:IsShown(), "and back")
W.CloseMerchant()
ns:SetOption("Vendor", "auto", true)

-- The question still standing when the merchant closes: Yes buys nothing.
W.owned[2512] = 600
W.OpenMerchant()
W.CloseMerchant()
W.Accept()
eq(#W.bought, 0, "merchant gone: nothing bought")

-- Off: nothing at the merchant.
ns:SetEnabled("Vendor", false)
eq(mod.active, false, "the module is off")
W.OpenMerchant()
eq(#W.bought, 0, "off: nothing bought")
eq(#W.popups, 0, "and nothing asked")
eq(_G.ForeverGearboxRestockButton:IsShown(), false, "no Restock button")
-- Best Ammo: arrows are a kind. Rough Arrows listed, the merchant sells Rough and Sharp Arrows
-- (and Jagged ones you can't use yet): every arrow in the bags counts, the Sharp ones are bought.
W.CloseMerchant()
W.items["[Rough Arrow]"] = { id = 2512, class = 6, subclass = 2, stack = 200, minLevel = 1, level = 5, family = 1 }
W.items["[Sharp Arrow]"] = { id = 2515, class = 6, subclass = 2, stack = 200, minLevel = 10, level = 15, family = 1 }
W.items["[Jagged Arrow]"] = { id = 3030, class = 6, subclass = 2, stack = 200, minLevel = 40, level = 40, family = 1 }
W.items["[Heavy Shot]"] = { id = 2519, class = 6, subclass = 3, stack = 200, minLevel = 1, level = 5, family = 2 }
W.unitInfo.player = W.unitInfo.player or {}
W.unitInfo.player.level = 26
W.merchant = {
    { id = 2512, link = "[Rough Arrow]", price = 100, stackCount = 200, maxStack = 1000 },
    { id = 2515, link = "[Sharp Arrow]", price = 500, stackCount = 200, maxStack = 1000 },
    { id = 3030, link = "[Jagged Arrow]", price = 2000, stackCount = 200, maxStack = 1000 },
    { id = 2519, link = "[Heavy Shot]", price = 100, stackCount = 200, maxStack = 1000 },
}
ns:SetEnabled("Vendor", true)
mod.db.buy = { [2512] = 1000 }
ns:SetOption("Vendor", "ask", false)
ns:SetOption("Vendor", "auto", true)
mod.db.paused = {}
W.owned = { [2512] = 300, [2515] = 400, [2519] = 600 }
W.money = 100000
W.OpenMerchant()
eq(#W.bought, 1, "one kind of arrow bought")
eq(W.bought[1] and W.bought[1].index, 2, "the best arrows you can use: Sharp, not Rough or Jagged (level 40)")
eq(W.bought[1] and W.bought[1].units, 400, "300 Rough and 400 Sharp count toward 1000: 300 more, in whole 200s")
W.CloseMerchant()
ns:SetOption("Vendor", "ammo", false)
W.OpenMerchant()
eq(W.bought[1] and W.bought[1].index, 1, "Best Ammo off: the listed Rough Arrows")
eq(W.bought[1] and W.bought[1].units, 800, "counting only themselves: 700 short, so 800")
W.CloseMerchant()
ns:SetOption("Vendor", "ammo", true)
-- A full quiver and bags: no room, nothing bought.
for bag = 0, NUM_BAG_FRAMES do
    W.bags[bag] = {}
    for slot = 1, 4 do W.bags[bag][slot] = { link = "[Heavy Shot]", count = 200 } end
end
W.OpenMerchant()
eq(#W.bought, 0, "no room in the bags: nothing bought")
W.CloseMerchant()
W.bags = {}
finish()
