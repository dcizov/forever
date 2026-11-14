--[[
    Forever Tweaks - tests/scenarios/bags/fullbags.lua
    Full Bags: which loot is worth taking with full bags, and what to delete for it.
    Run by tests/run.lua (lua5.1 tests/run.lua fullbags), which passes its helpers in.
]]

local T = ...
local under = T.under -- every frame under one that passes a test (tests/run.lua)
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root
local ns

-- Prices in copper; stack is how many fit in one slot.
W.items = {
    ["[Junk]"] = { id = 1, stack = 1, sell = 5 },
    ["[Cloth]"] = { id = 2, stack = 20, sell = 10 },
    ["[Ore]"] = { id = 3, stack = 20, sell = 50 },
    ["[Gem]"] = { id = 4, stack = 1, sell = 1000 },
    ["[Hearthstone]"] = { id = 5, stack = 1, sell = 0 },
    ["[Old Sword]"] = { id = 6, stack = 1, sell = 1, equippable = true },
    ["[Quest Note]"] = { id = 7, stack = 1, sell = 1 },
}
-- Full bags: junk in bags 0-1, a full stack of cloth everywhere else. The cheapest things are
-- ones never to delete: a hearthstone, bound gear and a quest item.
W.FillBags("[Cloth]")
for bag = 0, NUM_BAG_FRAMES do
    for slot = 1, 4 do W.bags[bag][slot].count = 20 end
end
for slot = 1, 4 do W.bags[1][slot] = { link = "[Junk]" } end
W.bags[0][1] = { link = "[Hearthstone]" }
W.bags[0][2] = { link = "[Old Sword]", bound = true, quality = Enum.ItemQuality.Rare }
W.bags[0][3] = { link = "[Quest Note]", quest = true }
W.bags[0][4] = { link = "[Junk]" }

W.Strict()
ns = W.LoadAddon(root, "ForeverTweaks")
login()
local mod = ns.modules.FullBags

local function coinOn(slot)
    for _, c in ipairs(W.LootRow(slot).Item._children or {}) do
        if c._kind == "Texture" and c:IsShown() then return true end
    end
    return false
end
local function numberOn(bag, slot)
    for _, c in ipairs(W.BagButton(bag, slot)._children or {}) do
        if c._kind == "FontString" and c:IsShown() then return c._text end
    end
end
local function marked()
    local list = {}
    for bag = 0, NUM_BAG_FRAMES do
        for slot = 1, 4 do
            local n = numberOn(bag, slot)
            if n then list[n] = bag .. ":" .. slot end
        end
    end
    return list
end

W.loot = {
    { link = "[Gem]" },              -- 1000: worth taking
    { link = "[Ore]", count = 2 },   -- 100: worth taking
    { link = "[Junk]" },             -- 5: no better than the cheapest junk
    { money = true },                -- coins take no room
    { link = "[Quest Note]", quest = true },
}
W.OpenLoot()
check(coinOn(1) and coinOn(2), "a coin on loot worth more than what it would replace")
check(not coinOn(3), "no coin on loot worth no more than the cheapest bag item")
check(not coinOn(5), "no coin on quest loot")
W.ShowBags()
local list = marked()
check(list[1] ~= nil and list[2] ~= nil and list[3] == nil, "two bag items numbered, one for each coin")
for n, where in pairs(list) do
    local bag, slot = where:match("(%d+):(%d+)")
    eq(W.bags[tonumber(bag)][tonumber(slot)].link, "[Junk]", "number " .. n .. " is on junk")
end
eq(numberOn(0, 1) or numberOn(0, 2) or numberOn(0, 3), nil, "never the hearthstone, bound gear or quest item")
check(mod:DebugLine():find("2", 1, true) ~= nil, "Debug line counts them")

-- Ore that stacks onto ore already in the bags needs no room.
W.bags[2][1] = { link = "[Ore]", count = 3 }
W.Fire("BAG_UPDATE_DELAYED")
W.RunTimers()
check(coinOn(1) and not coinOn(2), "loot that fits on a stack gets no coin")
eq(#marked(), 1, "and frees its bag item")

-- Taken loot: a slot freed up by the game is not counted twice.
W.TakeLoot(1)
W.RunTimers()
check(not coinOn(1), "taken loot loses its coin")
W.bags[2][1] = { link = "[Cloth]", count = 20 }

-- Auction prices make junk worth keeping: the cloth goes instead.
W.loot = { { link = "[Gem]" } }
W.CloseLoot()
eq(#marked(), 0, "closing the loot window clears the marks")
_G.Auctionator = { API = { v1 = { GetAuctionPriceByItemLink = function(caller, link)
    eq(caller, "Forever Tweaks", "Auctionator is told who asks")
    if link == "[Junk]" then return 50000 end
end } } }
local notice = mod.notice[1]
check(not notice.shown(mod.db), "Auctionator's prices there: no notice")
W.loot = { { link = "[Gem]" } }
W.OpenLoot()
local where = marked()[1]
check(where ~= nil, "one bag item to delete")
if where then
    local bag, slot = where:match("(%d+):(%d+)")
    eq(W.bags[tonumber(bag)][tonumber(slot)].link, "[Cloth]", "with junk worth more at auction, cloth goes")
end
ns:SetOption("FullBags", "price", "vendor")
where = marked()[1]
local bag, slot = (where or ""):match("(%d+):(%d+)")
eq(bag and W.bags[tonumber(bag)][tonumber(slot)].link, "[Junk]", "vendor prices: junk again")
ns:SetOption("FullBags", "price", "auction")
-- An Auctionator error is logged, not reported: vendor prices are used.
Auctionator.API.v1.GetAuctionPriceByItemLink = function() error("their bug") end
W.Fire("BAG_UPDATE_DELAYED")
W.RunTimers()
eq(#W.errors, 0, "Auctionator's error isn't ours")
check(marked()[1] ~= nil, "still a plan, from vendor prices")
_G.Auctionator = nil
check(not notice.shown(mod.db), "no Auctionator installed: nothing about it")
W.loaded.Auctionator = true
_G.Auctionator = { API = { v1 = {} } }
check(notice.shown(mod.db), "Auctionator installed without a price call: the notice shows")
_G.Auctionator = nil
W.loaded.Auctionator = nil

-- Options and the module going off.
ns:SetOption("FullBags", "coins", false)
check(not coinOn(1), "no coins with the option off")
ns:SetOption("FullBags", "borders", false)
eq(#marked(), 0, "no numbers with the option off")
ns:SetOption("FullBags", "borders", true)
check(#marked() == 1, "numbers back")
ns:SetEnabled("FullBags", false)
eq(#marked(), 0, "nothing marked while the module is off")
ns:SetEnabled("FullBags", true)
check(#marked() == 1, "marked again when it's back on mid-loot")
-- Off mid-loot, the loot closed while it's off, then on again: no numbers left from that loot.
local loot = W.loot
ns:SetEnabled("FullBags", false)
W.CloseLoot()
ns:SetEnabled("FullBags", true)
eq(#marked(), 0, "back on after the loot closed: nothing left from it")
W.loot = loot
W.OpenLoot()
check(#marked() == 1, "marked again for the loot open now")

-- Room in the bags: nothing to triage.
W.bags[4][4] = nil
W.Fire("BAG_UPDATE_DELAYED")
W.RunTimers()
eq(#marked(), 0, "a free slot: nothing to delete")
W.CloseLoot()
W.bags[4][4] = { link = "[Cloth]", count = 20 }

local function linkAt(where)
    local bag, slot = (where or ""):match("(%d+):(%d+)")
    return bag and W.bags[tonumber(bag)][tonumber(slot)].link
end

-- Open Bags: opened for the loot, once, and closed with it.
ContainerFrameCombinedBags:Hide()
W.bagsOpened = 0
W.loot = { { link = "[Gem]" } }
W.OpenLoot()
eq(W.bagsOpened, 1, "the bags open when there's something to delete")
eq(linkAt(marked()[1]), "[Junk]", "and show what to delete")
W.Fire("BAG_UPDATE_DELAYED")
W.RunTimers()
eq(W.bagsOpened, 1, "opened once per loot window")
W.CloseLoot()
check(not ContainerFrameCombinedBags:IsShown(), "closed again with the loot window")
-- Bags the player opened stay open.
W.ShowBags()
W.loot = { { link = "[Gem]" } }
W.OpenLoot()
eq(W.bagsOpened, 1, "already open: not opened again")
W.CloseLoot()
check(ContainerFrameCombinedBags:IsShown(), "the player's open bags stay open")
-- Never in combat, and not with the option off.
ContainerFrameCombinedBags:Hide()
W.combat = true
W.loot = { { link = "[Gem]" } }
W.OpenLoot()
eq(W.bagsOpened, 1, "not opened in combat")
W.CloseLoot()
W.combat = false
ns:SetOption("FullBags", "openBags", false)
W.loot = { { link = "[Gem]" } }
W.OpenLoot()
eq(W.bagsOpened, 1, "not opened with Open Bags off")
W.CloseLoot()
ns:SetOption("FullBags", "openBags", true)

-- Blizzard's pooled buttons changing slots: the marks follow the slots when the items redraw.
W.ShowBags()
W.loot = { { link = "[Gem]" } }
W.OpenLoot()
local before = marked()[1]
local items = ContainerFrameCombinedBags._items
local from
for i, b in ipairs(items) do
    if b:GetBagID() .. ":" .. b:GetID() == before then from = i end
end
W.SwapBagButtons(from, from == 1 and 2 or 1)
eq(marked()[1], before, "the number stays on its slot after the buttons are re-pooled")
eq(#marked(), 1, "and only there")
W.CloseLoot()

-- Auctionator without the by-link call: its price by item ID is used.
_G.Auctionator = { API = { v1 = { GetAuctionPriceByItemID = function(caller, itemID)
    eq(caller, "Forever Tweaks", "Auctionator is told who asks (by ID)")
    if itemID == 1 then return 50000 end
end } } }
W.loot = { { link = "[Gem]" } }
W.OpenLoot()
eq(linkAt(marked()[1]), "[Cloth]", "price by item ID: junk is worth keeping")
W.CloseLoot()
_G.Auctionator = nil
ContainerFrameCombinedBags:Hide()

-- Baganator: the mark is its corner widget, on its own bag window.
local B = W.UseBaganator()
ns:SetEnabled("FullBags", false)
ns:SetEnabled("FullBags", true)
W.RunTimers() -- the widget registers a frame later (after Upgrade Arrows')
local widget = B.widgets.ForeverTweaks_FullBagsDelete
check(widget ~= nil, "a corner widget registered with Baganator")
eq(widget and widget.position.corner, "top_left", "placed in a corner by default")
-- A registration Baganator refuses isn't remembered as done: the next call tries again.
do
    local api, real = Baganator.API, Baganator.API.RegisterCornerWidget
    api.RegisterCornerWidget = function() error("not now") end
    local owner = { name = "RetryTest", active = true, Debug = function() end }
    local opts = { label = "Retry", id = "RetryTest", position = {},
        onUpdate = function() return true end, onInit = function() end }
    eq(ns.BagButtons.RegisterWidget(owner, opts), false, "a refused registration answers false")
    api.RegisterCornerWidget = real
    eq(ns.BagButtons.RegisterWidget(owner, opts), true, "and is tried again next time")
    check(B.widgets.RetryTest ~= nil, "now registered")
end
-- A widget whose callback errors is reported and answers "not shown" (not nil, which Baganator
-- would ask about again); while its module is off it answers "not shown" without being called.
local owner = { name = "WidgetTest", active = true, Debug = function() end }
local calls = 0
ns.BagButtons.RegisterWidget(owner, { label = "Test", id = "WidgetTest", position = {},
    onUpdate = function() calls = calls + 1; error("widget broke") end, onInit = function() end })
local before = #W.errors
eq(B.widgets.WidgetTest.onUpdate({}, {}), false, "a broken widget answers false")
eq(#W.errors, before + 1, "and its error is reported")
W.errors[#W.errors] = nil
owner.active = false
eq(B.widgets.WidgetTest.onUpdate({}, {}), false, "off: false")
eq(calls, 1, "off: the callback isn't called")
ns:SetEnabled("FullBags", false)
ns:SetEnabled("FullBags", true)
W.loot = { { link = "[Gem]" } }
W.OpenLoot()
W.RunTimers()
eq(B.shows, 1, "Baganator's bags opened for the loot")
local found
for bag = 0, NUM_BAG_FRAMES do
    for slot = 1, 4 do
        local n = B.NumberOn(bag, slot)
        if n then
            found = (found or 0) + 1
            eq(n, 1, "numbered 1")
            eq(W.bags[bag][slot].link, "[Junk]", "on junk, in Baganator")
        end
    end
end
eq(found, 1, "one item marked in Baganator")
eq(B.cachedShown, false, "nothing on another character's bags")
eq(#marked(), 0, "Blizzard's bags, closed, untouched")
W.CloseLoot()
W.RunTimers()
eq(B.hides, 1, "Baganator's bags closed with the loot window")
B.view:Show()
local any
for bag = 0, NUM_BAG_FRAMES do
    for slot = 1, 4 do any = any or B.NumberOn(bag, slot) end
end
eq(any, nil, "marks cleared in Baganator")
_G.Baganator = nil

-- What's never suggested, by Blizzard's item class (LootTriage's rules). One test item in the
-- first slot, every other slot something with no value: is the test item numbered for the gem?
W.items["[Mushroom]"] = { id = 8, stack = 20, sell = 1, class = 0 }
W.items["[Broken Fang]"] = { id = 9, stack = 1, sell = 1 }
W.items["[Wool Cloth]"] = { id = 10, stack = 20, sell = 1, class = 7 }
W.items["[Light Feather]"] = { id = 11, stack = 20, sell = 1, class = 15, subclass = 1 }
W.items["[Copper Bar]"] = { id = 12, stack = 20, sell = 1, class = 15, reagent = true }
W.items["[Recipe: Stew]"] = { id = 13, stack = 1, sell = 1, class = 9 }
W.items["[Fishing Pole]"] = { id = 14, stack = 1, sell = 1, class = 2, subclass = 20 }
W.items["[Mining Pick]"] = { id = 2901, stack = 1, sell = 1, class = 15 }
W.items["[Rusty Sword]"] = { id = 15, stack = 1, sell = 1, class = 2, subclass = 7 }
W.items["[Green Ring]"] = { id = 16, stack = 1, sell = 1, class = 4 }
W.FillBags("[Hearthstone]")
ContainerFrameCombinedBags:Show()
local function suggested(entry)
    W.bags[0][1] = entry
    W.loot = { { link = "[Gem]" } }
    W.OpenLoot()
    local yes = marked()[1] == "0:1"
    W.CloseLoot()
    ContainerFrameCombinedBags:Show()
    return yes
end
check(not suggested({ link = "[Mushroom]" }), "food isn't suggested (the mushroom)")
check(suggested({ link = "[Mushroom]", quality = 0 }), "a gray one is")
check(suggested({ link = "[Broken Fang]" }), "a plain white item is")
check(not suggested({ link = "[Wool Cloth]" }), "trade goods are kept")
check(not suggested({ link = "[Light Feather]" }), "spell reagents are kept")
check(not suggested({ link = "[Copper Bar]" }), "crafting reagents are kept")
check(not suggested({ link = "[Recipe: Stew]" }), "recipes are kept")
check(not suggested({ link = "[Fishing Pole]" }), "fishing poles are kept")
check(not suggested({ link = "[Mining Pick]" }), "tools the game doesn't flag are kept")
check(suggested({ link = "[Rusty Sword]" }), "white gear is suggested by default")
check(not suggested({ link = "[Rusty Sword]", set = true }), "but not gear in an equipment set")
check(not suggested({ link = "[Green Ring]", quality = 2 }), "greens are above Common")
for key, link in pairs({ keepConsumables = "[Mushroom]", keepReagents = "[Wool Cloth]",
    keepRecipes = "[Recipe: Stew]", keepTools = "[Fishing Pole]" }) do
    ns:SetOption("FullBags", key, false)
    check(suggested({ link = link }), key .. " off: suggested")
    ns:SetOption("FullBags", key, true)
end
ns:SetOption("FullBags", "keepEquipment", true)
check(not suggested({ link = "[Rusty Sword]" }), "Weapons and Armor kept")
ns:SetOption("FullBags", "keepEquipment", false)
ns:SetOption("FullBags", "maxQuality", "uncommon")
check(suggested({ link = "[Green Ring]", quality = 2 }), "up to Uncommon: greens too")
ns:SetOption("FullBags", "maxQuality", "poor")
check(not suggested({ link = "[Broken Fang]" }), "Poor only: whites kept")
check(suggested({ link = "[Broken Fang]", quality = 0 }), "Poor only: grays still go")
ns:SetOption("FullBags", "maxQuality", "common")

-- The keep list: Alt-click a bag item.
local fang = W.BagButton(0, 1)
local function lockOn(button)
    for _, c in ipairs(button._children or {}) do
        if c._atlas == "bankslot-icon-lock" and c:IsShown() then return true end
    end
    return false
end
W.bags[0][1] = { link = "[Broken Fang]" }
W.chat = {}
fang:Fire("OnClick", "LeftButton")
eq(next(mod.db.keep), nil, "a plain click keeps nothing")
W.alt = true
fang:Fire("OnClick", "RightButton")
eq(next(mod.db.keep), nil, "Alt+Right-click keeps nothing")
fang:Fire("OnClick", "LeftButton")
eq(mod.db.keep[9], true, "Alt-click keeps it")
check(W.ChatHas("never be suggested"), "and says so")
check(lockOn(fang), "with a lock on it")
W.alt = false
check(not suggested({ link = "[Broken Fang]" }), "a kept item isn't suggested")
check(lockOn(fang), "the lock stays")
ns:SetOption("FullBags", "keepMark", false)
check(not lockOn(fang), "Mark Kept Items off")
ns:SetOption("FullBags", "keepMark", true)
W.alt = true
fang:Fire("OnClick", "LeftButton")
W.alt = false
eq(mod.db.keep[9], nil, "Alt-click again lets it go")
check(not lockOn(fang), "lock gone")
check(suggested({ link = "[Broken Fang]" }), "suggested again")

-- /ft keep and /ft unkeep.
W.Slash("/ft keep [Broken Fang]")
eq(mod.db.keep[9], true, "/ft keep")
W.chat = {}
W.Slash("/ft keep list")
check(W.ChatHas("[Broken Fang]"), "/ft keep list lists it by name")
W.Slash("/ft unkeep [Broken Fang]")
eq(mod.db.keep[9], nil, "/ft unkeep")
W.chat = {}
W.Slash("/ft keep")
check(W.ChatHas("No items are kept"), "an empty list says how to keep one")
W.Slash("/ft keep nonsense")
check(W.ChatHas("Shift-click"), "a word that isn't an item: usage")

-- The keep list on its Settings pane: an item added there while looting leaves the plan at once.
W.bags[0][1] = { link = "[Broken Fang]" }
W.loot = { { link = "[Gem]" } }
W.OpenLoot()
eq(marked()[1], "0:1", "looting: the fang is suggested")
ns:OpenSettings("FullBags")
local page = W.categories[ns.member.short].frame
local itemBox = under(page, function(f) return f._kind == "EditBox" and (f:GetText() or "") == "" and f:IsVisible() end)[1]
local addButton = under(page, function(f) return f._text == ns.L.ITEMLIST_ADD and f:IsVisible() end)[1]
itemBox:SetText("9")
addButton:Fire("OnClick")
eq(mod.db.keep[9], true, "kept from the pane")
eq(marked()[1], nil, "and no longer suggested while the loot is open")
mod.db.keep[9] = nil
W.CloseLoot()
ContainerFrameCombinedBags:Show()

-- Off: no click does anything.
ns:SetEnabled("FullBags", false)
W.alt = true
fang:Fire("OnClick", "LeftButton")
W.alt = false
eq(mod.db.keep[9], nil, "off: Alt-click does nothing")
ns:SetEnabled("FullBags", true)

-- In Baganator: Alt-click on its buttons, and the kept widget.
local B2 = B
_G.Baganator = B.global
check(B2.widgets.ForeverTweaks_Kept ~= nil, "a kept widget registered")
eq(B2.widgets.ForeverTweaks_Kept.position.corner, "bottom_left", "bottom left")
local bbutton = B2.buttons[1] -- bag 0, slot 1
B2.widgets.ForeverTweaks_FullBagsDelete.onInit(bbutton) -- Baganator sets each button up
W.alt = true
bbutton:Fire("OnClick", "LeftButton")
W.alt = false
eq(mod.db.keep[9], true, "Alt-click on a Baganator button keeps it")
local w = B2.widgets.ForeverTweaks_Kept
eq(w.onUpdate(w.onInit(bbutton), { itemLink = "[Broken Fang]" }), true, "the kept widget shows")
eq(w.onUpdate(w.onInit(bbutton), { itemLink = "[Mushroom]" }), false, "not on other items")
_G.Baganator = nil

-- Quests: Full Bags asks ns.QuestLog, whether or not the Quest Items module is on.
ns:SetEnabled("QuestItems", false)
W.Slash("/ft unkeep [Broken Fang]")
W.items["[Old Letter]"] = { id = 17, stack = 1, sell = 0, class = 12 }
W.quests = { { title = "Fangs", questID = 5, objectives = {
    { type = "item", text = "Broken Fang: 1/5", numFulfilled = 1, numRequired = 5 } } } }
W.Fire("QUEST_LOG_UPDATE")
W.RunTimers()
check(not suggested({ link = "[Broken Fang]" }), "an item a quest in the log needs is kept")
W.quests = {}
W.Fire("QUEST_REMOVED", 5)
W.RunTimers()
check(suggested({ link = "[Broken Fang]" }), "suggested again once the quest is gone")
check(not suggested({ link = "[Broken Fang]", starts = 600 }), "an item that begins a quest is kept")
check(suggested({ link = "[Old Letter]", quest = true }), "a leftover quest item goes first, with no price")
ns:SetOption("FullBags", "leftoversFirst", false)
check(not suggested({ link = "[Old Letter]", quest = true }), "Leftover Quest Items First off: kept")
ns:SetOption("FullBags", "leftoversFirst", true)
W.itemSpells["[Old Letter]"] = 99
check(not suggested({ link = "[Old Letter]", quest = true }), "a quest item with a Use spell is kept")
W.itemSpells["[Old Letter]"] = nil
-- Alt-click while looting refreshes the plan (it used to call it before it was defined).
W.bags[0][1] = { link = "[Broken Fang]" }
W.loot = { { link = "[Gem]" } }
W.OpenLoot()
eq(marked()[1], "0:1", "numbered while looting")
W.alt = true
W.BagButton(0, 1):Fire("OnClick", "LeftButton")
W.alt = false
eq(marked()[1], nil, "kept mid-loot: the number goes at once")
W.CloseLoot()
finish()
