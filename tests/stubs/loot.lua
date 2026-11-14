--[[
    Forever Tweaks - tests/stubs/loot.lua
    The stand-in game's items, bags and loot window, loaded by tests/wow.lua.
]]

---------------------------------------------------------------------------
-- Items, bags and the loot window. A scenario fills W.items (link -> { id, stack, sell,
-- equippable, class, subclass, reagent }: an item is Miscellaneous unless its class says), W.bags (bag -> slot -> { link, count, bound, quality, quest, locked }) and
-- W.loot (slot -> { link, count, quest, money }), then calls W.ShowBags() / W.OpenLoot().
---------------------------------------------------------------------------

W.items, W.bags, W.loot = {}, {}, {}
NUM_BAG_FRAMES, NUM_CONTAINER_FRAMES = 4, 13
local BAG_SIZE = 4

C_Item = {
    GetItemInfo = function(link)
        local item = W.items[link]
        if not item and type(link) == "number" then
            for l, it in pairs(W.items) do if it.id == link then item, link = it, l end end
        end
        if not item then return nil end
        local name = link:match("^%[(.*)%]$") or link -- the scenarios' links are "[Name]"
        return name, link, item.quality or 1, item.level or 1, 1, "", "", item.stack, item.equipLoc or "", 0, item.sell,
            item.class or 15, item.subclass or 0,
            0, 0, nil, item.reagent or false
    end,
    GetItemInfoInstant = function(link)
        local item = W.items[link]
        if not item and type(link) == "number" then
            for _, it in pairs(W.items) do if it.id == link then item = it end end
        end
        if not item then return nil end
        return item.id, nil, nil, nil, nil, item.class, item.subclass
    end,
    IsEquippableItem = function(link) local item = W.items[link]; return item and item.equippable or false end,
    GetItemIconByID = function(id) return 200000 + id end,
    GetItemQualityByID = function(id)
        for _, item in pairs(W.items) do if item.id == id then return item.quality or 1 end end
    end,
    GetItemQualityColor = function(quality) return quality / 10, 0.5, 0.5, "ffffffff" end,
}
C_Container = {
    GetContainerNumSlots = function(bag) return bag <= NUM_BAG_FRAMES and BAG_SIZE or 0 end,
    GetContainerNumFreeSlots = function(bag)
        local used = 0
        for _ in pairs(W.bags[bag] or {}) do used = used + 1 end
        return BAG_SIZE - used, 0
    end,
    GetContainerItemInfo = function(bag, slot)
        local entry = W.bags[bag] and W.bags[bag][slot]
        if not entry then return nil end
        local item = W.items[entry.link]
        return { stackCount = entry.count or 1, isLocked = entry.locked or false, quality = entry.quality or 1,
            hyperlink = entry.link, hasNoValue = (item.sell or 0) == 0, itemID = item.id, isBound = entry.bound or false }
    end,
    GetContainerItemEquipmentSetInfo = function(bag, slot)
        local entry = W.bags[bag] and W.bags[bag][slot]
        return entry and entry.set or false, entry and entry.set and "Set" or ""
    end,
    GetContainerItemQuestInfo = function(bag, slot)
        local entry = W.bags[bag] and W.bags[bag][slot]
        return { isQuestItem = entry and entry.quest or false, questID = entry and entry.starts or nil, isActive = false }
    end,
}
-- Fills every bag slot with a cheap common item, so the bags are full.
function W.FillBags(link)
    for bag = 0, NUM_BAG_FRAMES do
        W.bags[bag] = {}
        for slot = 1, BAG_SIZE do W.bags[bag][slot] = { link = link, count = 1 } end
    end
end

W.lootCount = 0 -- slots stay numbered while the window is open, taken ones empty
function GetNumLootItems() return W.lootCount end
function GetLootSlotType(slot)
    local entry = W.loot[slot]
    if not entry then return Enum.LootSlotType.None end
    return entry.money and Enum.LootSlotType.Money or Enum.LootSlotType.Item
end
function GetLootSlotInfo(slot)
    local entry = W.loot[slot]
    return 0, entry.link, entry.count or 1, nil, entry.quality or 1, entry.locked or false, entry.quest or false, entry.questID, false, entry.money or false
end
-- Where loot came from: W.lootSource is the GUID of what's being looted (a mob, or a
-- "GameObject-..." node); W.fishing says it's a catch.
W.lootSource, W.fishing = "Creature-0-1-0-1-3296-0000000001", false
function GetLootSourceInfo(slot) if W.loot[slot] then return W.lootSource, W.loot[slot].count or 1 end end
function IsFishingLoot() return W.fishing end
function GetLootSlotLink(slot) local entry = W.loot[slot]; return entry and not entry.money and entry.link or nil end

-- The bag window: one combined bag whose buttons know their bag and slot.
local function itemButton(parent, bag, slot)
    local b = W.NewFrame("ItemButton", nil, parent)
    function b:GetBagID() return bag end
    function b:GetID() return slot end
    return b
end
ContainerFrameCombinedBags = W.NewFrame("Frame", "ContainerFrameCombinedBags", UIParent)
ContainerFrameCombinedBags._shown = false
ContainerFrameCombinedBags._items = {}
for bag = 0, NUM_BAG_FRAMES do
    for slot = 1, BAG_SIZE do
        local list = ContainerFrameCombinedBags._items
        list[#list + 1] = itemButton(ContainerFrameCombinedBags, bag, slot)
    end
end
function ContainerFrameCombinedBags:EnumerateValidItems() return ipairs(self._items) end
-- Draws the items, as Blizzard's does after it re-pools its buttons.
function ContainerFrameCombinedBags:UpdateItems() end
for i = 1, NUM_CONTAINER_FRAMES do
    local frame = W.NewFrame("Frame", "ContainerFrame" .. i, UIParent)
    frame._shown = false
    function frame:UpdateItems() end
end
function ContainerFrameUtil_EnumerateContainerFrames() return ipairs({ ContainerFrameCombinedBags }) end
function W.ShowBags() ContainerFrameCombinedBags:Show() end
W.bagsOpened = 0
function OpenAllBags() W.bagsOpened = W.bagsOpened + 1; ContainerFrameCombinedBags:Show() end
function CloseAllBags() ContainerFrameCombinedBags:Hide() end
-- Blizzard's buttons are pooled: the same buttons can show other slots after a redraw. Swaps the
-- slots of two buttons and draws the items again.
function W.SwapBagButtons(a, b)
    local items = ContainerFrameCombinedBags._items
    local ga, gb = items[a].GetBagID, items[b].GetBagID
    local ia, ib = items[a].GetID, items[b].GetID
    items[a].GetBagID, items[a].GetID, items[b].GetBagID, items[b].GetID = gb, ib, ga, ia
    ContainerFrameCombinedBags:UpdateItems()
end

-- Baganator (optional): W.UseBaganator() puts a stand-in of its API in place. Its bag window has
-- one live button per bag slot. As in Baganator (ItemViewCommon/ItemButton.lua, API/Main.lua):
-- each corner is an ordered list of widget ids, starting from Baganator's defaults (its own
-- widgets "junk" and "item_level" top left, "equipment_set" bottom left, "quantity" bottom right);
-- a widget registered with a position is inserted once, at its priority (appended when that's
-- past the end); and per corner only the first widget answering true shows, the ones after it
-- aren't asked. Widgets redraw on RequestItemButtonsRefresh (next frame: W.RunTimers).
function W.UseBaganator()
    local view = W.NewFrame("Frame", "Baganator_SingleViewBackpackViewFramedefault", UIParent)
    view._shown = false
    local B = { view = view, widgets = {}, buttons = {}, shows = 0, hides = 0,
        corners = { top_left = { "junk", "item_level" }, top_right = {}, bottom_left = { "equipment_set" },
                    bottom_right = { "quantity" } } }
    -- Its saved settings, which hold the same corners (what BagButtons.WidgetPlaced reads).
    BAGANATOR_CONFIG = { Profiles = { Default = { icon_top_left_corner_array = B.corners.top_left,
        icon_top_right_corner_array = B.corners.top_right, icon_bottom_left_corner_array = B.corners.bottom_left,
        icon_bottom_right_corner_array = B.corners.bottom_right } } }
    BAGANATOR_CURRENT_PROFILE = "Default"
    -- Baganator's own widgets: whether each shows for an item's details.
    B.builtin = {
        junk = function() return false end,
        item_level = function(d) local it = d.itemLink and W.items[d.itemLink]; return it and it.equippable or false end,
        equipment_set = function() return false end,
        quantity = function(d) return (d.itemCount or 1) > 1 end,
    }
    for bag = 0, NUM_BAG_FRAMES do
        for slot = 1, BAG_SIZE do
            local b = W.NewFrame("ItemButton", nil, view)
            function b:GetBagID() return bag end
            function b:GetID() return slot end
            function b:IsVisible() return view:IsShown() end
            B.buttons[#B.buttons + 1] = b
        end
    end
    -- Another character's bag: a cached button with no slot.
    B.cached = W.NewFrame("ItemButton", nil, view)
    local function detailsOf(b)
        local entry = W.bags[b:GetBagID()] and W.bags[b:GetBagID()][b:GetID()]
        return entry and { itemLink = entry.link, itemCount = entry.count or 1 } or {}
    end
    local function redraw()
        for _, b in ipairs(B.buttons) do
            b._corner, b._shownIn = b._corner or {}, {}
            local details = detailsOf(b)
            for corner, list in pairs(B.corners) do
                local shown = false
                for _, id in ipairs(list) do
                    local w = B.widgets[id]
                    if w then
                        if not b._corner[id] then b._corner[id] = w.onInit(b) end
                        local frame = b._corner[id]
                        if frame then
                            local show = not shown and w.onUpdate(frame, details) == true
                            frame:SetShown(show)
                            if show then shown, b._shownIn[corner] = true, id end
                        end
                    elseif B.builtin[id] and not shown and B.builtin[id](details) then
                        shown, b._shownIn[corner] = true, id
                    end
                end
            end
        end
        for _, w in pairs(B.widgets) do
            local frame = w.onInit(B.cached)
            B.cachedShown = w.onUpdate(frame, {})
        end
    end
    -- Which widget shows in a corner of the button for a bag slot, or nil.
    function B.ShownIn(bag, slot, corner)
        for _, b in ipairs(B.buttons) do
            if b:GetBagID() == bag and b:GetID() == slot then return b._shownIn and b._shownIn[corner] end
        end
    end
    _G.Baganator = {
        API = {
            RegisterCornerWidget = function(label, id, onUpdate, onInit, position, isFast)
                assert(not B.widgets[id], "widget registered twice")
                B.widgets[id] = { label = label, onUpdate = onUpdate, onInit = onInit, position = position }
                local list = position and B.corners[position.corner]
                if list and type(position.priority) == "number" then
                    if position.priority > #list then list[#list + 1] = id else table.insert(list, position.priority, id) end
                end
            end,
            RequestItemButtonsRefresh = function() C_Timer.After(0, redraw) end,
            RegisterUpgradePlugin = function(label, id, callback)
                B.plugins = B.plugins or {}
                B.plugins[id] = { label = label, callback = callback }
            end,
        },
        CallbackRegistry = {
            TriggerEvent = function(_, event)
                if event == "BagShow" then B.shows = B.shows + 1; view:Show(); redraw()
                elseif event == "BagHide" then B.hides = B.hides + 1; view:Hide() end
            end,
        },
    }
    B.global = _G.Baganator -- to put it back after a test takes it away
    -- What a widget shows for an item link: true/false/nil from its onUpdate, and its frame.
    function B.Widget(id, link)
        local w = B.widgets[id]
        local frame = w.onInit(B.cached)
        return w.onUpdate(frame, { itemLink = link }), frame
    end
    -- The number shown on the button for a bag slot, or nil.
    function B.NumberOn(bag, slot)
        for _, b in ipairs(B.buttons) do
            if b:GetBagID() == bag and b:GetID() == slot then
                for _, frame in pairs(b._corner or {}) do
                    if frame:IsShown() and view:IsShown() then return frame.text._text end
                end
            end
        end
    end
    return B
end
-- The bag item button for a slot.
function W.BagButton(bag, slot)
    for _, b in ipairs(ContainerFrameCombinedBags._items) do
        if b:GetBagID() == bag and b:GetID() == slot then return b end
    end
end

-- The loot window: rows made for the loot slots, set up again through the scroll box callback.
ScrollBoxListMixin = { Event = { OnInitializedFrame = "OnInitializedFrame" } }
LootFrame = W.NewFrame("Frame", "LootFrame", UIParent)
LootFrame._shown = false
local scrollBox = W.NewFrame("Frame", nil, LootFrame)
LootFrame.ScrollBox = scrollBox
scrollBox._rows, scrollBox._callbacks = {}, {}
function scrollBox:ForEachFrame(fn) for _, row in ipairs(self._rows) do fn(row) end end
function scrollBox:RegisterCallback(event, fn, owner) self._callbacks[#self._callbacks + 1] = { event, fn, owner } end
local function lootRow(slot)
    local row = W.NewFrame("Frame", nil, scrollBox)
    row.Item = W.NewFrame("ItemButton", nil, row)
    function row:GetSlotIndex() return slot end
    return row
end
-- Opens the loot window on W.loot.
function W.OpenLoot()
    W.lootCount = #W.loot
    scrollBox._rows = {}
    for slot in ipairs(W.loot) do
        local row = lootRow(slot)
        scrollBox._rows[slot] = row
        for _, cb in ipairs(scrollBox._callbacks) do cb[2](cb[3], row) end
    end
    LootFrame:Show()
    W.Fire("LOOT_OPENED", false)
end
-- Takes loot slot `slot` (it goes into the bags elsewhere) and redraws.
function W.TakeLoot(slot)
    W.loot[slot] = nil
    W.Fire("LOOT_SLOT_CLEARED", slot)
end
function W.CloseLoot()
    W.loot, W.lootCount = {}, 0
    LootFrame:Hide()
    W.Fire("LOOT_CLOSED")
end
-- The loot row for a slot.
function W.LootRow(slot) return scrollBox._rows[slot] end
