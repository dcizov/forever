--[[
    Forever Tweaks - Vendor (Autobuy)
    Keeps a number of items in your bags (reagents, ammo, food, ...): add an item and its amount
    on the Autobuy list in its Settings pane, or Alt-click it in a merchant's window (0 stops
    buying it); the list is kept per character, and an item can be paused there without taking
    it off. What's missing is bought from a merchant who sells it:
      * when the merchant opens (Buy When a Merchant Opens; Shift held skips that visit), after a
        question listing what and what it costs (Ask First),
      * or with the Restock button in the merchant window (Modules/Merchant/VendorButton.lua).
    Keep 20 Runes of Teleportation with 15 in the bags and 5 are bought. Items sold in bundles are
    never overbought, only whole bundles that fit: keeping 20 water sold in 5s with 11 in the bags
    buys 5. Split into stacks the merchant sells at once, never more than you can pay for, and
    never items that cost something other than money. Their tooltips say how many are kept.
    Ideas from Stockpile and ForeverPlus (Restock button, the question, pausing, Have/Want); no
    code from either.

    Alt-click on a merchant item does nothing in the game's own window (MerchantItemButton_
    OnModifiedClick only handles chat links and dress-up), so it's free for this.
]]

local _, ns = ...
local L = ns.L

local format, floor, min, max = string.format, math.floor, math.min, math.max
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

-- How many of an item to buy, in units, as purchases of at most `perPurchase` each: the whole
-- bundles of `bundle` that fit in what's missing (never more than the amount kept), cut to what
-- the merchant has (`available` bundles, -1 for no limit) and to what `cash` pays for at `price` a
-- bundle. Plain numbers in and out, so the tests can check it directly.
function M.PlanPurchase(missing, bundle, price, available, cash, perPurchase)
    bundle = max(bundle or 1, 1)
    local bundles = floor(missing / bundle)
    if available and available >= 0 then bundles = min(bundles, available) end
    if price and price > 0 then bundles = min(bundles, floor(cash / price)) end
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

-- What this merchant would sell now: a list of { index, link, units (purchases), count, cost,
-- have, keep }, in the merchant's order, paid for from the money there is, item by item.
function M:Plan()
    local list, paused, entries = M.db.buy, M.db.paused, {}
    if next(list) == nil then return entries end
    local cash = GetMoney()
    for index = 1, GetMerchantNumItems() do
        local itemID = GetMerchantItemID(index)
        local keep = itemID and not paused[itemID] and list[itemID]
        local info = keep and C_MerchantFrame.GetItemInfo(index)
        local have = info and C_Item.GetItemCount(itemID)
        local missing = info and keep - have
        if info then M:Debug(itemID, "keep", keep, "have", have, "missing", missing) end
        if info and missing > 0 and info.isPurchasable and not info.hasExtendedCost then
            local units = M.PlanPurchase(missing, info.stackCount, info.price, info.numAvailable, cash,
                GetMerchantItemMaxStack(index))
            local count = 0
            for _, n in ipairs(units) do count = count + n end
            if count > 0 then
                local cost = info.price * count / max(info.stackCount, 1)
                cash = cash - cost
                entries[#entries + 1] = { index = index, link = GetMerchantItemLink(index) or info.name or "?",
                    units = units, count = count, cost = cost, have = have, keep = keep }
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
-- Adding items: Alt-click at a merchant, the tooltips, /ft autobuy
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

-- /ft autobuy: the list.
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
        local name = C_Item.GetItemNameByID(id) or ("item:" .. id)
        ns:PrintLine(format(M.db.paused[id] and L.VENDOR_LIST_PAUSED or "  %d x %s", M.db.buy[id], name))
    end
end)

function M:OnEnable()
    merchantOpen = MerchantFrame:IsShown()
    self:RegisterEvent("MERCHANT_SHOW", onMerchantShow)
    self:RegisterEvent("MERCHANT_CLOSED", onMerchantClosed)
    self:RegisterEvent("BAG_UPDATE_DELAYED", onBagsChanged)
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
