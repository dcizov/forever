--[[
    Forever Gearbox - Full Bags
    Looting with full bags: which loot is worth taking, and what to delete to make room.

    While the loot window is open and the bags have no free slot, every loot item and every bag
    item is given a value: its price (Auctionator's auction price when that's chosen and it has
    one, else what a vendor pays) times how many there are. The most valuable loot is paired with
    the cheapest bag items; wherever the loot is worth more, it gets a gold coin in the loot
    window and the bag item a gold border numbered in the order to delete them. Working that out
    is Modules/Bags/FullBagsPlan.lua; this file draws it, keeps the keep list, and opens and
    closes the bags.

    Never picked for deletion: quest items, items a vendor won't buy (hearthstone, keys), locked
    items, bound gear above Poor quality, gear in an equipment set, and items on the keep list
    (Alt-click one in the bags, or /fg keep). Price isn't usefulness, so the same rules as
    LootTriage's keep whole kinds of white-or-better items by Blizzard's item class: consumables,
    crafting and spell reagents, profession tools and recipes (and weapons and armor, when asked),
    and nothing above the Highest Quality to Delete (Common by default). Loot that stacks onto a
    stack already in the bags needs no room, so it's left alone. Bound items have no auction price.

    The borders go on Blizzard's bag windows, repainted each time they draw their items, and on
    Baganator's, as a corner widget (Baganator.API.RegisterCornerWidget). With Open Bags on, the
    bags open by themselves when there's something to delete, and close again with the loot
    window if they were opened for it.

    The idea, the rules above and their defaults come from LootTriage by Krelock (its EvaluateSlot
    and IsProtected); this is written from scratch for Forever Gearbox.
]]

local _, ns = ...
local L = ns.L
local BagButtons = assert(ns.BagButtons, "FullBags.lua loads after UI/BagButtons.lua")
local Plan = assert(ns.FullBagsPlan, "FullBags.lua loads after FullBagsPlan.lua")

local pairs, type, format, wipe, next = pairs, type, string.format, wipe, next
local setmetatable, CreateFrame, InCombatLockdown, IsAltKeyDown = setmetatable, CreateFrame, InCombatLockdown,
    IsAltKeyDown
local C_Container, C_Item, GetNumLootItems = C_Container, C_Item, GetNumLootItems

-- The kinds of item never suggested, picked in one dropdown.
local KEEP_GROUP = { label = L.FULL_KEEP_KINDS, format = L.FULL_KEEP_KINDS_COUNT, tooltip = L.FULL_KEEP_KINDS_TIP }

-- Our corner widget's id in Baganator. Baganator puts a widget in its corner once, the first time
-- its id is registered, and per corner shows only the first widget that answers true; under the
-- old id "ForeverTweaks_FullBags" the number was placed after other widgets in the corner, so gear
-- marked for deletion showed one of those and no number. This id is placed afresh, first.
local WIDGET = "ForeverTweaks_FullBagsDelete"
local KEPT_WIDGET = "ForeverTweaks_Kept" -- and the kept mark's

local M = ns:NewModule("FullBags", {
    title = L.FULL_TITLE,
    category = "bags",
    description = L.FULL_DESC,
    added = "1.3.0",
    defaults = {
        enabled = true,
        coins = true,
        borders = true,
        openBags = true,
        price = "auction",
        maxQuality = "common",
        keepConsumables = true,
        keepReagents = true,
        keepTools = true,
        keepRecipes = true,
        keepEquipment = false,
        keepMark = true,
        leftoversFirst = true,
        keep = {}, -- data: itemID -> true, never suggested (Alt-click, /fg keep)
    },
    options = {
        { key = "coins", type = "checkbox", label = L.FULL_COINS, tooltip = L.FULL_COINS_TIP },
        { key = "borders", type = "checkbox", label = L.FULL_BORDERS, tooltip = L.FULL_BORDERS_TIP },
        { key = "openBags", type = "checkbox", label = L.FULL_OPEN_BAGS, tooltip = L.FULL_OPEN_BAGS_TIP,
          requires = "borders", added = "1.4.0" },
        { key = "price", type = "dropdown", label = L.FULL_PRICE, tooltip = L.FULL_PRICE_TIP,
          choices = {
              { "auction", L.FULL_PRICE_AUCTION },
              { "vendor", L.FULL_PRICE_VENDOR },
          } },
        { key = "maxQuality", type = "dropdown", label = L.FULL_QUALITY, tooltip = L.FULL_QUALITY_TIP,
          section = L.FULL_SECTION_KEEP, added = "1.4.0",
          choices = {
              { "poor", L.FULL_QUALITY_POOR },
              { "common", L.FULL_QUALITY_COMMON },
              { "uncommon", L.FULL_QUALITY_UNCOMMON },
          } },
        { key = "keepConsumables", type = "checkbox", group = KEEP_GROUP, label = L.FULL_KEEP_CONSUMABLES,
          tooltip = L.FULL_KEEP_CONSUMABLES_TIP, added = "1.4.0" },
        { key = "keepReagents", type = "checkbox", group = KEEP_GROUP, label = L.FULL_KEEP_REAGENTS, tooltip = L.FULL_KEEP_REAGENTS_TIP,
          added = "1.4.0" },
        { key = "keepTools", type = "checkbox", group = KEEP_GROUP, label = L.FULL_KEEP_TOOLS, tooltip = L.FULL_KEEP_TOOLS_TIP,
          added = "1.4.0" },
        { key = "keepRecipes", type = "checkbox", group = KEEP_GROUP, label = L.FULL_KEEP_RECIPES, tooltip = L.FULL_KEEP_RECIPES_TIP,
          added = "1.4.0" },
        { key = "keepEquipment", type = "checkbox", group = KEEP_GROUP, label = L.FULL_KEEP_EQUIPMENT,
          tooltip = L.FULL_KEEP_EQUIPMENT_TIP, added = "1.4.0" },
        { key = "leftoversFirst", type = "checkbox", label = L.FULL_LEFTOVERS, tooltip = L.FULL_LEFTOVERS_TIP,
          added = "1.4.0" },
        { key = "keepMark", type = "checkbox", label = L.FULL_KEEP_MARK, tooltip = L.FULL_KEEP_MARK_TIP,
          added = "1.4.0" },
    },
    notice = {
        {
            text = L.FULL_NOTICE,
            addon = "Auctionator", advice = L.FULL_ADVICE_AUCTION,
            shown = function(db)
                return db.price == "auction" and ns.OtherAddons.Loaded("Auctionator") and not ns.OtherAddons.HasAuctionPrices()
            end,
        },
        {
            text = L.FULL_BAGANATOR,
            addon = "Baganator", advice = L.FULL_ADVICE_BAGANATOR,
            shown = function(db)
                return db.borders and BagButtons.WidgetPlaced({ WIDGET }) == false
            end,
        },
    },
})

-- Quest items it keeps or deletes first come from ns.QuestLog, which reads QuestieDB: like Quest
-- Items, it needs QuestieDB (red and locked off without it).
ns.QuestieDB.Require(M)

local plan = { coins = {}, deletes = {} } -- loot slot -> true; "bag:slot" -> number in delete order

---------------------------------------------------------------------------
-- Markers: made the first time each button needs one, hidden when it doesn't
---------------------------------------------------------------------------

local coinOf, borderOf = {}, {} -- loot item button -> texture; bag item button -> { border, number }

local function setCoin(button, shown)
    local coin = coinOf[button]
    if not coin then
        if not shown then return end
        coin = button:CreateTexture(nil, "OVERLAY", nil, 7)
        coin:SetAtlas("auctionhouse-icon-coin-gold")
        coin:SetSize(16, 16)
        coin:SetPoint("TOPRIGHT", 3, 3)
        coinOf[button] = coin
    end
    coin:SetShown(shown)
end

-- The gold border around `button`, made on `owner` (the button, or Baganator's widget frame).
local function newBorder(owner, button)
    local border = owner:CreateTexture(nil, "OVERLAY", nil, 6)
    border:SetAtlas("loottoast-itemborder-gold")
    border:SetPoint("TOPLEFT", button, "TOPLEFT", -6, 6)
    border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 6, -6)
    return border
end

local function setBorder(button, number)
    local mark = borderOf[button]
    if not mark then
        if not number then return end
        local border = newBorder(button, button)
        local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        text:SetPoint("TOPLEFT", 3, -2)
        mark = { border = border, text = text }
        borderOf[button] = mark
    end
    mark.border:SetShown(number ~= nil)
    mark.text:SetShown(number ~= nil)
    if number then mark.text:SetText(number) end
end

-- One loot window row (rows are reused as the list scrolls).
local function paintLootRow(row)
    if not row.Item then return end
    setCoin(row.Item, M.active and M.db.coins and plan.coins[row:GetSlotIndex()] or false)
end

local function paintLoot()
    LootFrame.ScrollBox:ForEachFrame(paintLootRow)
end

-- The delete number for a bag item button, or nil.
local function numberFor(button)
    if not (M.active and M.db.borders) then return nil end
    return plan.deletes[Plan.SlotKey(button:GetBagID(), button:GetID())]
end

-- Whether a bag slot's item is on the keep list and its mark should show.
local function keptMarkFor(bag, slot)
    if not (M.active and M.db.keepMark) or next(M.db.keep) == nil then return false end
    local info = C_Container.GetContainerItemInfo(bag, slot)
    return info and M.db.keep[info.itemID] and true or false
end

local lockOf = {} -- bag item button -> its kept mark

-- The kept mark: a small lock in the bottom left.
local function newLock(owner, button)
    local lock = owner:CreateTexture(nil, "OVERLAY", nil, 7)
    lock:SetAtlas("bankslot-icon-lock")
    lock:SetSize(14, 14)
    lock:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
    return lock
end

local function setLock(button, shown)
    local lock = lockOf[button]
    if not lock then
        if not shown then return end
        lock = newLock(button, button)
        lockOf[button] = lock
    end
    lock:SetShown(shown)
end

local onBagClick, refresh -- (the keep list and the plan, below)

-- One Blizzard bag button (ns.BagButtons). Buttons come from a pool and can change slots, so
-- every button is set, marked or not, and each is hooked for Alt-click the first time it's seen.
local function paintButton(button, bag, slot)
    M:HookScript(button, "OnClick", onBagClick)
    setBorder(button, numberFor(button))
    setLock(button, keptMarkFor(bag, slot))
end

local function paintBags() BagButtons.PaintBlizzard(paintButton) end

---------------------------------------------------------------------------
-- Baganator: its bag windows aren't Blizzard's, so the mark is a corner widget there. Baganator
-- makes one per item button (onInit) and asks whether to show it (onUpdate) each time a button
-- draws or RequestItemButtonsRefresh is called. A widget can't be unregistered: while the
-- module is off it just never shows.
---------------------------------------------------------------------------

local widgetButton = setmetatable({}, { __mode = "k" }) -- widget frame -> its item button

-- The widget for one Baganator item button: a frame Baganator puts in a corner (the number),
-- with the border round the whole button, so both show and hide together.
local function widgetInit(button)
    local frame = CreateFrame("Frame", nil, button)
    frame:SetSize(16, 16)
    newBorder(frame, button)
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("TOPLEFT")
    frame.text = text
    widgetButton[frame] = button
    M:HookScript(button, "OnClick", onBagClick)
    return frame
end

-- The kept mark's widget: shown on any of the player's items on the keep list.
local function keptShown(details)
    if not (M.db.keepMark and type(details) == "table" and details.itemLink) then return false end
    local itemID = C_Item.GetItemInfoInstant(details.itemLink)
    return itemID and M.db.keep[itemID] and true or false
end

-- Whether a widget shows. Only live bag buttons know their slot (not other characters' bags).
local function widgetShown(frame)
    local button = widgetButton[frame]
    if not (button and button.GetBagID) then return false end
    local number = numberFor(button)
    if number then frame.text:SetText(number) end
    return number ~= nil
end

-- The number goes first in the top left corner, ahead of Baganator's item level: it shows only
-- while you loot with full bags, and it's what matters then.
local function registerWidget()
    BagButtons.RegisterWidget(M, { label = L.FULL_BAGANATOR_WIDGET, id = WIDGET, onUpdate = widgetShown,
        onInit = widgetInit, position = { corner = "top_left", priority = 1 } })
    BagButtons.RegisterWidget(M, { label = L.FULL_BAGANATOR_KEPT, id = KEPT_WIDGET,
        onUpdate = function(_, details) return keptShown(details) end,
        onInit = function(button) return newLock(button, button) end,
        position = { corner = "bottom_left", priority = 1 } })
end

-- Both bag windows: Blizzard's now, Baganator's on the next frame.
local function repaintBags()
    paintBags()
    BagButtons.RefreshBaganator(M)
end

---------------------------------------------------------------------------
-- Open Bags: opened once per loot window when there's something to delete, never in combat,
-- and closed with the loot window only if they were opened for it.
---------------------------------------------------------------------------

local openedBags, triedOpen = false, false

-- Whether a bag window is open: Baganator's when one of its item buttons shows, else Blizzard's.
local function bagsShown()
    if BagButtons.Baganator() then
        for _, button in pairs(widgetButton) do
            if button:IsVisible() then return true end
        end
        return false
    end
    return BagButtons.BlizzardShown()
end

local function maybeOpenBags()
    if triedOpen or not (M.active and M.db.borders and M.db.openBags) or next(plan.deletes) == nil then return end
    if InCombatLockdown() then return end
    triedOpen = true
    if bagsShown() then return end
    openedBags = BagButtons.ShowBags(M, true)
    M:Debug("opened the bags:", openedBags)
end

local function closeOpenedBags()
    if openedBags and not InCombatLockdown() and bagsShown() then BagButtons.ShowBags(M, false) end
    openedBags, triedOpen = false, false
end

-- Forgets the plan and takes its coins and numbers away (the loot closing, the module going
-- off: a plan kept while off would paint stale numbers when it's back on outside a loot window).
-- Kept marks stay while the module is on: they're drawn again with the bags.
local function clearAll()
    wipe(plan.coins)
    wipe(plan.deletes)
    for button in pairs(coinOf) do setCoin(button, false) end
    for button in pairs(borderOf) do setBorder(button, nil) end
    if not M.active then
        for button in pairs(lockOf) do setLock(button, false) end
    end
    repaintBags()
end

---------------------------------------------------------------------------
-- The keep list: items never suggested, by item ID (all characters). Alt-click a bag item, or
-- /fg keep and /fg unkeep with its link.
---------------------------------------------------------------------------

-- The keep list changed (however): the bags' marks, and the plan while looting.
local function keepChanged()
    repaintBags()
    if GetNumLootItems() > 0 then refresh() end
end

local function setKeep(itemID, keep, link)
    M.db.keep[itemID] = keep or nil
    M:Reply(format(keep and L.FULL_KEPT or L.FULL_UNKEPT, link or ("item:" .. itemID)))
    keepChanged()
end

-- Alt+Left-click on a bag item (never with Shift or Ctrl): keep it, or let it go again. A
-- modified click doesn't use or pick up the item.
function onBagClick(_, button, mouseButton)
    if mouseButton ~= "LeftButton" or not IsAltKeyDown() or IsShiftKeyDown() or IsControlKeyDown() then return end
    if not button.GetBagID then return end
    local info = C_Container.GetContainerItemInfo(button:GetBagID(), button:GetID())
    if not (info and info.itemID) then return end
    local keep = not M.db.keep[info.itemID]
    PlaySound(keep and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    setKeep(info.itemID, keep, info.hyperlink)
end

-- /fg keep [item], /fg keep list, /fg unkeep [item].
local function keepCommand(keep, args)
    local text = args or ""
    if keep and (text == "" or text:lower() == "list") then
        if next(M.db.keep) == nil then
            M:Reply(L.FULL_KEEP_NONE)
            return
        end
        M:Reply(L.FULL_KEEP_LIST)
        for itemID in pairs(M.db.keep) do
            M:Reply("  " .. (select(2, C_Item.GetItemInfo(itemID)) or ("item:" .. itemID)))
        end
        return
    end
    local itemID = C_Item.GetItemInfoInstant(text)
    if not itemID then
        M:Reply(L.FULL_KEEP_USAGE)
        return
    end
    setKeep(itemID, keep, text:match("|H.-|h.-|h") and text or nil)
end

function refresh()
    Plan.Fill(M.db, plan)
    paintLoot()
    repaintBags()
    maybeOpenBags()
end

-- The keep list's Settings pane (BuildPage), redrawn when an item's name comes in.
local keepList -- { stack, refresh }
local function refreshKeepList()
    if keepList and keepList.stack:IsVisible() then keepList.refresh() end
end

-- Redone once, on the next frame, however many bag and loot events arrive together.
local function requestRefresh()
    if GetNumLootItems() > 0 then M:Soon(refresh) end
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

-- Hooked once, and idle while the module is off: loot rows set up again as the list scrolls,
-- and bag windows as they show and as they draw their items (after Blizzard's own drawing).
local function hookFrames()
    BagButtons.HookBlizzard(M, paintButton)
    local scrollBox = LootFrame.ScrollBox
    M:HookCallback(scrollBox, "loot row", function(hook)
        scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, hook, M)
    end, function(_, _, row) paintLootRow(row) end)
end

M:AddCommand("keep", L.FULL_KEEP_CMD_USAGE, L.FULL_KEEP_CMD_DESC, function(args) keepCommand(true, args) end)
M:AddCommand("unkeep", L.FULL_UNKEEP_CMD_USAGE, L.FULL_UNKEEP_CMD_DESC, function(args) keepCommand(false, args) end)

function M:OnEnable()
    hookFrames()
    registerWidget()
    paintBags()
    self:RegisterEvent("LOOT_OPENED", refresh)
    self:RegisterEvent("LOOT_SLOT_CLEARED", requestRefresh)
    self:RegisterEvent("BAG_UPDATE_DELAYED", requestRefresh)
    self:RegisterEvent("GET_ITEM_INFO_RECEIVED", function()
        requestRefresh()
        M:Soon(refreshKeepList) -- a kept item's name came
    end)
    ns.QuestLog.Listen(self, requestRefresh)
    self:RegisterEvent("LOOT_CLOSED", function()
        clearAll()
        closeOpenedBags()
    end)
    if GetNumLootItems() > 0 then refresh() end
end

function M:OnDisable()
    clearAll()
    openedBags, triedOpen = false, false
end

function M:OnSettingChanged()
    if GetNumLootItems() > 0 then return refresh() end
    repaintBags() -- the kept marks
end

-- Its Settings pane, under the options: the keep list (what Alt-click and /fg keep add).
function M:BuildPage(stack)
    ns.Kit.AddHeaderRow(stack, L.FULL_KEEP_HEADER)
    local refresh = ns.ItemList.Add(stack, {
        owner = M,
        get = function() return M.db.keep end,
        add = function(id) M.db.keep[id] = true; keepChanged() end,
        remove = function(id) M.db.keep[id] = nil; keepChanged() end,
        addLabel = L.FULL_KEEP_ADD, addTip = L.FULL_KEEP_ADD_TIP, empty = L.FULL_KEEP_EMPTY,
    })
    keepList = { stack = stack, refresh = refresh }
    return refresh
end

function M:DebugLine()
    local deletes, coins = 0, 0
    for _ in pairs(plan.deletes) do deletes = deletes + 1 end
    for _ in pairs(plan.coins) do coins = coins + 1 end
    if deletes == 0 and coins == 0 then return L.FULL_IDLE end
    return format(L.FULL_DEBUG, deletes, coins)
end
