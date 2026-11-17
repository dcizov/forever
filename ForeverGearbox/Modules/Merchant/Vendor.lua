--[[
    Forever Gearbox - Vendor (Autobuy)
    Keeps a number of items in your bags (reagents, ammo, food, ...): add an item and its amount
    on the Autobuy list in its Settings pane, or Alt-click it in a merchant's window (0 stops
    buying it); the list is kept per character, and an item can be paused there without taking
    it off. What's missing is bought from a merchant who sells it:
      * when the merchant opens (Buy When a Merchant Opens; Shift held skips that visit), after a
        question listing what and what it costs (Ask First),
      * or with the Restock button in the merchant window (Modules/Merchant/VendorButton.lua).
    Keep 20 Runes of Teleportation with 15 in the bags and 5 are bought. An item sold in bundles
    (water in 5s, arrows in 200s) can only be bought a whole bundle at a time, so as many bundles
    as reach the amount kept are bought: keeping 50 water sold in 5s with 19 in the bags buys 35
    (54), keeping 50 arrows with 19 buys 200. Split into the stacks the merchant sells at once,
    never more than you can pay for or than the bags have room for (bags of the item's kind:
    a quiver for arrows), and never items that cost something other than money. Their tooltips
    say how many are kept.
    Ammo (Best Ammo, on by default): arrows and bullets are counted as a kind, not an item. Every
    arrow in the bags counts toward the arrows kept, and the best arrows the merchant sells that
    you can use are bought (the highest required level, then item level), whichever arrows are on
    the list: keep 1000 Rough Arrows and a merchant selling Sharp Arrows sells you those.
    Ideas from Stockpile and ForeverPlus (Restock button, the question, pausing, Have/Want); no
    code from either.

    Alt-click on a merchant item does nothing in the game's own window (MerchantItemButton_
    OnModifiedClick only handles chat links and dress-up), so it's free for this.
]]

local _, ns = ...
local L = ns.L

local format, floor, ceil, min, max, select = string.format, math.floor, math.ceil, math.min, math.max, select
local pairs, ipairs, next, sort, concat = pairs, ipairs, next, table.sort, table.concat

local M = ns:NewModule("Vendor", {
    title = L.VENDOR_TITLE,
    category = "merchant",
    description = L.VENDOR_DESC,
    added = "1.5.0",
    defaults = {
        auto = true,
        ask = true,
        button = true,
        ammo = true,
        chat = true,
        buy = {},    -- data: itemID -> how many to keep in the bags
        paused = {}, -- data: itemID -> true while it's listed but not bought
    },
    perCharacter = { buy = true, paused = true },
    options = {
        { key = "auto", type = "checkbox", label = L.VENDOR_AUTO, tooltip = L.VENDOR_AUTO_TIP, added = "1.6.0" },
        { key = "ask", type = "checkbox", label = L.VENDOR_ASK, tooltip = L.VENDOR_ASK_TIP, requires = "auto",
          added = "1.6.0" },
        { key = "button", type = "checkbox", label = L.VENDOR_BUTTON, tooltip = L.VENDOR_BUTTON_TIP, added = "1.6.0" },
        { key = "ammo", type = "checkbox", label = L.VENDOR_AMMO, tooltip = L.VENDOR_AMMO_TIP, added = "3.0.0" },
        ns.ChatOption(),
    },
})

local money = ns.MoneyText

local merchantOpen = false
local lists = {} -- every Autobuy list drawn (its Settings pane, its window): { stack, refresh }

-- Redraws each Autobuy list that shows now.
local function refreshLists()
    for _, list in ipairs(lists) do
        if list.stack:IsVisible() then list.refresh() end
    end
end

---------------------------------------------------------------------------
-- What to buy
---------------------------------------------------------------------------

-- How many of an item to buy, in units, as purchases of at most `perPurchase` each: as many whole
-- bundles of `bundle` as reach what's missing (a bundle can't be split, so the last may go past it),
-- cut to what the merchant has (`available` bundles, -1 for no limit), to what `cash` pays for at
-- `price` a bundle, and to the `room` the bags have for it (units, nil for no limit). Plain
-- numbers in and out, so the tests can check it directly.
function M.PlanPurchase(missing, bundle, price, available, cash, perPurchase, room)
    bundle = max(bundle or 1, 1)
    if missing <= 0 then return {} end
    local bundles = ceil(missing / bundle)
    if available and available >= 0 then bundles = min(bundles, available) end
    if price and price > 0 then bundles = min(bundles, floor(cash / price)) end
    if room then bundles = min(bundles, floor(room / bundle)) end
    if bundles <= 0 then return {} end
    local chunk = max(floor(max(perPurchase or bundle, bundle) / bundle), 1) * bundle
    local units, purchases = bundles * bundle, {}
    while units > 0 do
        local n = min(units, chunk)
        purchases[#purchases + 1] = n
        units = units - n
    end
    return purchases
end

local PROJECTILE = Enum.ItemClass.Projectile -- arrows and bullets

-- An item's ammo kind (its subclass: arrow, bullet), or nil for anything else.
local function ammoKind(itemID)
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    if classID == PROJECTILE then return subclassID end
end

-- The bags: the backpack and the bags beside it.
local function eachBag(fn)
    for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do fn(bag) end
end

-- How much room the bags have for an item, in units: empty slots in bags that take it (any bag,
-- or a quiver or pouch of its kind) a full stack each, plus what its own stacks still hold. Nil
-- while the item isn't loaded (no limit then: the game says if the bags are full).
local function roomFor(itemID)
    local stackSize = select(8, C_Item.GetItemInfo(itemID))
    if not stackSize or stackSize < 1 then return nil end
    local family = C_Item.GetItemFamily(itemID) or 0
    local room = 0
    eachBag(function(bag)
        local free, bagFamily = C_Container.GetContainerNumFreeSlots(bag)
        if not bagFamily or bagFamily == 0 or bit.band(bagFamily, family) ~= 0 then
            room = room + (free or 0) * stackSize
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                if C_Container.GetContainerItemID(bag, slot) == itemID then
                    local info = C_Container.GetContainerItemInfo(bag, slot)
                    room = room + max(stackSize - (info and info.stackCount or stackSize), 0)
                end
            end
        end
    end)
    return room
end

-- How many of an ammo kind are in the bags: every item of that kind (those in `ids` too, so an
-- item counted by the game but not found in a bag slot still counts).
local function ammoCount(kind, ids)
    local seen, total = {}, 0
    local function count(id)
        if id and not seen[id] and ammoKind(id) == kind then
            seen[id] = true
            total = total + C_Item.GetItemCount(id)
        end
    end
    for id in pairs(ids) do count(id) end
    eachBag(function(bag)
        for slot = 1, C_Container.GetContainerNumSlots(bag) do count(C_Container.GetContainerItemID(bag, slot)) end
    end)
    return total
end

-- Whether the player can use an item (its required level), and how good ammo is to buy: its
-- required level, then its item level.
local function usable(itemID)
    local minLevel = select(5, C_Item.GetItemInfo(itemID))
    return not minLevel or minLevel <= (UnitLevel("player") or 0)
end
local function ammoRank(itemID)
    local _, _, _, itemLevel, minLevel = C_Item.GetItemInfo(itemID)
    return (minLevel or 0) * 1000 + (itemLevel or 0)
end

-- What's listed, as what to look for at a merchant: items by ID, and (Best Ammo) each ammo kind
-- with the most any of its listed items keeps.
local function wanted()
    local items, ammo = {}, {}
    for itemID, keep in pairs(M.db.buy) do
        if not M.db.paused[itemID] then
            local kind = M.db.ammo and ammoKind(itemID)
            if kind then
                local want = ammo[kind] or { keep = 0, ids = {} }
                want.keep, want.ids[itemID] = max(want.keep, keep), true
                ammo[kind] = want
            else
                items[itemID] = keep
            end
        end
    end
    return items, ammo
end

-- What this merchant would sell now: a list of { index, link, units (purchases), count, cost,
-- have, keep }, in the merchant's order, paid for from the money there is, item by item.
function M:Plan()
    local entries = {}
    if next(M.db.buy) == nil then return entries end
    local items, ammo = wanted()
    -- The merchant's goods to buy: listed items, and for each ammo kind the best it sells.
    local goods, best = {}, {}
    for index = 1, GetMerchantNumItems() do
        local itemID = GetMerchantItemID(index)
        local kind = itemID and next(ammo) and ammoKind(itemID)
        if kind and ammo[kind] and usable(itemID) then
            local rank = ammoRank(itemID)
            if not best[kind] or rank > best[kind].rank then best[kind] = { index = index, itemID = itemID, rank = rank } end
        elseif itemID and items[itemID] then
            goods[#goods + 1] = { index = index, itemID = itemID, keep = items[itemID], have = C_Item.GetItemCount(itemID) }
        end
    end
    for kind, pick in pairs(best) do
        local want = ammo[kind]
        want.ids[pick.itemID] = true
        goods[#goods + 1] = { index = pick.index, itemID = pick.itemID, keep = want.keep, have = ammoCount(kind, want.ids) }
    end
    sort(goods, function(a, b) return a.index < b.index end)
    local cash = GetMoney()
    for _, good in ipairs(goods) do
        local index = good.index
        local info = C_MerchantFrame.GetItemInfo(index)
        local missing = info and good.keep - good.have
        if info then M:Debug(good.itemID, "keep", good.keep, "have", good.have, "missing", missing) end
        if info and missing > 0 and info.isPurchasable and not info.hasExtendedCost then
            local units = M.PlanPurchase(missing, info.stackCount, info.price, info.numAvailable, cash,
                GetMerchantItemMaxStack(index), roomFor(good.itemID))
            local count = 0
            for _, n in ipairs(units) do count = count + n end
            if count > 0 then
                local cost = info.price * count / max(info.stackCount, 1)
                cash = cash - cost
                entries[#entries + 1] = { index = index, link = GetMerchantItemLink(index) or info.name or "?",
                    units = units, count = count, cost = cost, have = good.have, keep = good.keep }
            end
        end
    end
    return entries
end

-- The list changed: the Restock button (Modules/Merchant/VendorButton.lua, M.button) looks again.
function M:ListChanged()
    if M.button then M.button:Update() end
    refreshLists()
end

local function buy(entries)
    if not merchantOpen then return end
    for _, entry in ipairs(entries) do
        for _, units in ipairs(entry.units) do BuyMerchantItem(entry.index, units) end
        M:Print(format(L.VENDOR_BOUGHT, entry.count, entry.link, money(entry.cost)))
    end
end

-- The question's text: every item with how many, then the total.
local function questionText(entries)
    local lines, total = { L.VENDOR_ASK_QUESTION }, 0
    for _, entry in ipairs(entries) do
        lines[#lines + 1] = format(L.VENDOR_ASK_LINE, entry.count, entry.link, entry.have, entry.keep)
        total = total + entry.cost
    end
    lines[#lines + 1] = format(L.VENDOR_ASK_TOTAL, money(total))
    return concat(lines, "\n")
end

-- Buys what's missing now. `automatic` (a visit, not the Restock button): through the question
-- when Ask First is on; the button buys straight away, the click being the asking. Planned again
-- on Yes, since the bags and the money may have changed while the question stood.
function M:Restock(automatic)
    local entries = M:Plan()
    if #entries == 0 then return false end
    if automatic and M.db.ask then
        ns:Confirm(M, "VENDOR_BUY", "%s", function() buy(M:Plan()) end, questionText(entries))
    else
        buy(entries)
    end
    return true
end

local function onMerchantShow()
    merchantOpen = true
    if not M.db.auto then return end
    if IsShiftKeyDown() then
        M:Debug("Shift held: skipped")
        return
    end
    M:Restock(true)
end

local function onMerchantClosed() merchantOpen = false end

-- The bags changed: the page's counts (while it's shown) and the Restock button follow.
local function onBagsChanged()
    M:ListChanged()
end

---------------------------------------------------------------------------
-- Adding items: Alt-click at a merchant, the tooltips, /fg autobuy
---------------------------------------------------------------------------

-- Alt-click on a merchant item: how many to keep.
local function onModifiedClick(_, button)
    if not IsAltKeyDown() or IsShiftKeyDown() or IsControlKeyDown() then return end
    if MerchantFrame.selectedTab ~= 1 then return end
    local index = button:GetID()
    local itemID = GetMerchantItemID(index)
    if not itemID then return end
    local name = GetMerchantItemLink(index) or tostring(itemID)
    local current = M.db.buy[itemID]
    -- Items sold in bundles (arrows by 200) are counted one by one, and bought a whole bundle at a time.
    local info = C_MerchantFrame.GetItemInfo(index)
    local bundle = max(info and info.stackCount or 1, 1)
    local ask = bundle > 1 and format(L.VENDOR_PROMPT_BUNDLE, name, bundle) or format(L.VENDOR_PROMPT, name)
    ns:Prompt(M, "VENDOR_AUTOBUY", ask, function(text)
        local n = ns.ItemList.ParseAmount(text)
        if not n then
            M:Reply(L.VENDOR_PROMPT_BAD)
            return
        end
        M.db.buy[itemID] = n > 0 and n or nil
        M.db.paused[itemID] = nil
        M:Reply(n > 0 and format(L.VENDOR_KEEPING, n, name) or format(L.VENDOR_STOPPED, name))
        if n > 0 and n < bundle then M:Reply(format(L.VENDOR_BELOW_BUNDLE, bundle)) end
        M:ListChanged()
    end, current and tostring(current) or "")
end

-- "Autobuy keeps 20" on the item's tooltips (not while it's paused).
local function addTooltipLine(mod, tooltip, data)
    if not ns.Plain(data.id) then return end
    local keep = not mod.db.paused[data.id] and mod.db.buy[data.id]
    if keep then tooltip:AddLine(format(L.VENDOR_TOOLTIP, keep), 0.4, 0.8, 1) end
end

-- /fg autobuy: the list.
M:AddCommand("autobuy", L.VENDOR_CMD_USAGE, L.VENDOR_CMD_DESC, function(rest)
    if strtrim(rest or ""):lower() == L.VENDOR_CMD_WINDOW then return M.ToggleWindow() end
    local ids = {}
    for id in pairs(M.db.buy) do ids[#ids + 1] = id end
    if #ids == 0 then
        M:Reply(L.VENDOR_LIST_EMPTY)
        return
    end
    sort(ids)
    M:Reply(L.VENDOR_LIST)
    for _, id in ipairs(ids) do
        local name = C_Item.GetItemNameByID(id)
        if not name then
            C_Item.RequestLoadItemDataByID(id) -- named the next time
            name = "item:" .. id
        end
        ns:PrintLine(format(M.db.paused[id] and L.VENDOR_LIST_PAUSED or "  %d x %s", M.db.buy[id], name))
    end
end)

function M:OnEnable()
    merchantOpen = MerchantFrame:IsShown()
    self:RegisterEvent("MERCHANT_SHOW", onMerchantShow)
    self:RegisterEvent("MERCHANT_CLOSED", onMerchantClosed)
    self:RegisterEvent("BAG_UPDATE_DELAYED", onBagsChanged)
    -- An item the lists asked the game about: its name came, so the rows can show it.
    self:RegisterEvent("GET_ITEM_INFO_RECEIVED", function() M:Soon(refreshLists) end)
    self:Hook("MerchantItemButton_OnModifiedClick", onModifiedClick)
    self:HookCallback(TooltipDataProcessor, "tooltip", function(hook)
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, hook)
    end, addTooltipLine)
end

-- Its Settings pane, under the options: the Autobuy list, to add items with their amounts to,
-- change, pause and clear without a merchant, with how many are in the bags (Settings/Modules.lua
-- calls this when the pane is built, and redraws it with what it returns). The Autobuy window
-- (VendorWindow.lua) draws the same list with it.
function M:BuildPage(stack)
    ns.Kit.AddHeaderRow(stack, L.VENDOR_LIST_HEADER)
    local function changed(fn)
        return function(...)
            fn(...)
            M:ListChanged()
        end
    end
    local refresh = ns.ItemList.Add(stack, {
        owner = M,
        get = function() return M.db.buy end,
        add = changed(function(id, n) M.db.buy[id], M.db.paused[id] = n, nil end),
        defaultCount = 20,
        remove = changed(function(id) M.db.buy[id], M.db.paused[id] = nil, nil end),
        setCount = changed(function(id, n) M.db.buy[id] = n end),
        isOn = function(id) return not M.db.paused[id] end,
        setOn = changed(function(id, on) M.db.paused[id] = not on or nil end),
        have = function(id) return C_Item.GetItemCount(id) end,
        addLabel = L.VENDOR_LIST_ADD, addTip = L.VENDOR_LIST_ADD_TIP, empty = L.VENDOR_LIST_EMPTY,
    })
    lists[#lists + 1] = { stack = stack, refresh = refresh }
    return refresh
end

function M:DebugLine()
    local n = 0
    for _ in pairs(self.db.buy) do n = n + 1 end
    return format(L.VENDOR_DEBUG, n)
end
