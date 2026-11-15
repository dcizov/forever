--[[
    Forever Compendium - Modules/Journal/ItemsPage.lua
    The journal's Items page: every item the Recorder saw (in loot, on vendors, as quest rewards),
    searched by name, filtered by quality and sorted by name, quality or how many sources it has.
    The chosen item, on the Collections page's background: its icon (shift-click links it), name,
    kind, item level and how many you have; under them its own tooltip docked at the left (the
    Adventure Guide's way: required level, sell price and the rest), and right of it, filling the
    page, who drops it (each with its portrait, level, home and drop chance), who sells it and for
    how much, the quests that give it and the quest it starts. Click a creature or quest to open it.
    An item you carry is found in your bags (Forever Core's UI/Bags.lua) with a click on its icon,
    or a right-click on its row in the list.
]]

local _, ns = ...
local L = ns.L

local ipairs, pairs, next, format, table, math = ipairs, pairs, next, string.format, table, math
local CreateFrame = CreateFrame
local Book = ns.Book
local Text = assert(ns.JournalText, "ItemsPage.lua loads after JournalText.lua")
local J = assert(ns.JournalKit, "ItemsPage.lua loads after JournalKit.lua")
local Journal = assert(ns.Journal, "ItemsPage.lua loads after Journal.lua")
local M = assert(ns.modules.Journal, "ItemsPage.lua loads after Journal.lua")
local Bags = ns.Bags

local QUALITIES = { 0, 1, 2, 3, 4, 5 }

local page = { key = "items", label = L.JOURNAL_TAB_ITEMS, icon = "Interface\\Icons\\INV_Misc_Bag_10", order = 30 }
local list, count, filterButton, sortButton, view
local selected
local terms = {}
local hidden = {} -- quality -> true while filtered out
local sort = "name"
local index -- itemID -> { drops = { { npcID, rec } }, wares = {...}, rewards = { questID }, starts = { questID } }

---------------------------------------------------------------------------
-- Who has each item
---------------------------------------------------------------------------

local function entry(itemID)
    local e = index[itemID]
    if not e then
        e = { drops = {}, wares = {}, rewards = {}, starts = {} }
        index[itemID] = e
    end
    return e
end

local function buildIndex()
    index = {}
    for npcID, rec in pairs(Book.Creatures()) do
        for itemID in pairs(rec.loot or {}) do table.insert(entry(itemID).drops, { npcID = npcID, rec = rec }) end
        for itemID in pairs(rec.wares or {}) do table.insert(entry(itemID).wares, { npcID = npcID, rec = rec }) end
    end
    for questID, q in pairs(Book.Quests()) do
        for _, itemID in ipairs(q.rewards or {}) do table.insert(entry(itemID).rewards, questID) end
        for _, itemID in ipairs(q.choices or {}) do table.insert(entry(itemID).rewards, questID) end
        if q.startItem then table.insert(entry(q.startItem).starts, questID) end
    end
end

local function sourceCount(itemID)
    local e = index[itemID]
    if not e then return 0 end
    return #e.drops + #e.wares + #e.rewards
end

local function quality(itemID)
    local item = Book.Item(itemID)
    return item and item.quality or 1
end

local ORDER = {
    name = function(a, b) return a.name < b.name end,
    quality = function(a, b)
        if a.quality ~= b.quality then return a.quality > b.quality end
        return a.name < b.name
    end,
    sources = function(a, b)
        if a.sources ~= b.sources then return a.sources > b.sources end
        return a.name < b.name
    end,
}

local function itemSearched(name)
    if #terms == 0 then return true end
    for _, term in ipairs(terms) do
        if Text.Has(name, term) then return true end
    end
    return false
end

local function items()
    buildIndex()
    local all = {}
    for itemID in pairs(Book.Items()) do
        local name = Text.ItemName(itemID)
        local q = quality(itemID)
        if not hidden[q] and itemSearched(name) then
            all[#all + 1] = { itemID = itemID, name = name, quality = q, sources = sourceCount(itemID) }
        end
    end
    table.sort(all, ORDER[sort] or ORDER.name)
    return all
end

-- "Trade Goods - Meat", from what the game knows of the item.
local function itemKind(itemID)
    local _, itemType, subType = C_Item.GetItemInfoInstant(itemID)
    if subType and subType ~= itemType then return (itemType or "") .. " - " .. subType end
    return itemType or ""
end

-- An item's entry: its icon in its quality's border, its name in that colour, its kind under
-- it, and how many creatures and quests have it at the right.
local function fillItemEntry(e, item)
    e.icon:SetTexture(Text.ItemIcon(item.itemID))
    e.iconBorder:SetVertexColor(Text.ItemColor(item.itemID))
    e.name:SetText(item.name)
    e.name:SetTextColor(Text.ItemColor(item.itemID))
    e.sub:SetText(itemKind(item.itemID))
    if item.sources > 0 then e.note:SetText(format(L.JITEMS_SOURCES_NOTE, item.sources)) end
end

---------------------------------------------------------------------------
-- The chosen item
---------------------------------------------------------------------------

local function creatureTip(line)
    local rec = Book.Creature(line.data.npcID)
    J.Tip(line, rec.name, Text.Kind(rec), Text.Where(rec), { L.JOURNAL_OPEN_CREATURE, 0.1, 1, 0.1 })
end

-- A creature's line: its portrait, its name in its reaction's colour, its level and home in grey,
-- then `suffix` (a drop rate, a price).
local function creatureLine(lines, e, suffix)
    local rec = e.rec
    local r, g, b = Text.ReactionColor(rec.reaction)
    local where = Text.Where(rec)
    lines:Line(Text.Color(r, g, b) .. (rec.name or "?") .. "|r" .. Text.GRAY .. "  [" .. Text.LevelShort(rec) .. "]"
        .. (where ~= "" and ("  " .. where) or "") .. "|r" .. suffix, {
        display = rec.display or next(rec.displays or {}), icon = "Interface\\Icons\\INV_Misc_QuestionMark",
        data = e, onEnter = creatureTip, onClick = function(line) ns.ShowCreature(line.data.npcID) end })
end

-- "Item Level 12   You have 3": what the card doesn't already say (it gives the required level
-- and sell price).
local function itemFacts(itemID)
    local _, _, _, itemLevel = C_Item.GetItemInfo(itemID)
    local facts = {}
    if itemLevel and itemLevel > 1 then facts[#facts + 1] = format(L.JITEMS_ITEM_LEVEL, itemLevel) end
    local owned = C_Item.GetItemCount(itemID, true)
    if owned and owned > 0 then facts[#facts + 1] = format(L.JITEMS_OWNED, owned) end
    return table.concat(facts, "    ")
end

-- The item's own tooltip, docked at the page's left under its name (the Adventure Guide shows
-- loot so): the lines of what it is and does, the way the game writes them, from the link it
-- was last seen with (its random enchantment, "of the Bear", is only there). Returns how wide
-- it came out.
local function showCard(itemID)
    local card = view.card
    card:SetOwner(view.top, "ANCHOR_NONE")
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", view.slot, "BOTTOMLEFT", -4, -14)
    local item = Book.Item(itemID)
    if item and item.link then card:SetHyperlink(item.link) else card:SetItemByID(itemID) end
    card:Show()
    card:SetFrameStrata(view.top:GetFrameStrata())
    card:SetFrameLevel(view.top:GetFrameLevel() + 10)
    return card:GetWidth() or 0
end

local function questLines(lines, title, quests)
    if #quests == 0 then return end
    lines:Head(title)
    for _, questID in ipairs(quests) do
        lines:Line(Text.QuestLine(questID), { onClick = function() ns.ShowQuest(questID) end })
    end
end

local function showItem(itemID)
    selected = itemID
    view.top:SetShown(itemID ~= nil)
    view.empty:SetShown(itemID == nil)
    if not itemID then return end
    J.SetSlot(view.slot, itemID)
    view.name:SetText(Text.ItemName(itemID))
    view.name:SetTextColor(Text.ItemColor(itemID))
    view.kind:SetText(itemKind(itemID))
    view.facts:SetText(itemFacts(itemID))
    local cardWidth = showCard(itemID)
    view.lines.scroll:SetPoint("TOPLEFT", view.slot, "BOTTOMLEFT", math.max(cardWidth, 200) + 20, -14)
    local e = index[itemID] or { drops = {}, wares = {}, rewards = {}, starts = {} }
    local lines = view.lines
    lines:Begin()
    if #e.drops > 0 then
        table.sort(e.drops, function(a, b) return (Book.DropRate(a.rec, itemID) or 0) > (Book.DropRate(b.rec, itemID) or 0) end)
        lines:Head(L.JITEMS_DROPPED_BY)
        for _, d in ipairs(e.drops) do
            creatureLine(lines, d, Text.GRAY .. format("  %s  (%d/%d)", Text.Percent(Book.DropRate(d.rec, itemID)),
                d.rec.loot[itemID] or 0, d.rec.looted or 0) .. "|r")
        end
    end
    if #e.wares > 0 then
        lines:Head(L.JITEMS_SOLD_BY)
        for _, w in ipairs(e.wares) do
            local ware = w.rec.wares[itemID]
            creatureLine(lines, w, "  " .. ns.MoneyText(ware.price or 0) .. ((ware.stack or 1) > 1 and (" x" .. ware.stack) or ""))
        end
    end
    questLines(lines, L.JITEMS_REWARD_FROM, e.rewards)
    questLines(lines, L.JITEMS_STARTS, e.starts)
    if #e.drops + #e.wares + #e.rewards + #e.starts == 0 then lines:Line(Text.GRAY .. L.JITEMS_NO_SOURCE .. "|r") end
    lines:End()
    lines.scroll:SetVerticalScroll(0)
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------

function page.Refresh()
    local all = items()
    list:SetItems(all)
    local total = Book.Count(Book.Items())
    count.Count:SetText(#all < total and format(L.JOURNAL_COUNT, #all, total) or total)
    filterButton:ValidateResetState()
    if not (selected and Book.Item(selected)) then selected = all[1] and all[1].itemID end
    showItem(selected)
end

function page.Select(itemID)
    selected = itemID
    page.Refresh()
    for i, item in ipairs(list.items) do
        if item.itemID == itemID then list:ShowIndex(i) end
    end
end

local SORTS = { { "name", L.JOURNAL_SORT_NAME }, { "quality", L.CTABS_SORT_QUALITY }, { "sources", L.JITEMS_SORT_SOURCES } }

local function filterMenu(_, root)
    for _, q in ipairs(QUALITIES) do
        local r, g, b = C_Item.GetItemQualityColor(q)
        root:CreateCheckbox(Text.Color(r, g, b) .. _G["ITEM_QUALITY" .. q .. "_DESC"] .. "|r", function() return not hidden[q] end, function()
            hidden[q] = not hidden[q] or nil
            page.Refresh()
        end)
    end
end

local function sortMenu(_, root)
    for _, s in ipairs(SORTS) do
        root:CreateRadio(s[2], function() return sort == s[1] end, function()
            sort = s[1]
            page.Refresh()
        end)
    end
end

-- The chosen item on the Collections page's background: its slot, name and kind, then who has it.
local function buildItemView(parent)
    view = {}
    local top = J.Inset(parent)
    top:SetAllPoints()
    J.CollectionsBackground(top)
    view.top = top
    -- The icon: a click finds the item in your bags; its tooltip says so when you have it.
    view.slot = J.ItemSlot(top, 52, function(slot)
        if Bags.Has(slot.itemID) then GameTooltip:AddLine(L.JITEMS_FIND_HINT, 0, 1, 0) end
    end, function(slot) Bags.Find(M, slot.itemID) end)
    view.slot:SetPoint("TOPLEFT", 24, -28)
    view.name = top:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    view.name:SetPoint("TOPLEFT", view.slot, "TOPRIGHT", 14, -4)
    view.name:SetPoint("RIGHT", -24, 0)
    view.name:SetJustifyH("LEFT")
    view.kind = top:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    view.kind:SetPoint("TOPLEFT", view.name, "BOTTOMLEFT", 0, -4)
    view.facts = top:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    view.facts:SetPoint("TOPLEFT", view.kind, "BOTTOMLEFT", 0, -4)
    view.facts:SetPoint("RIGHT", -24, 0)
    view.facts:SetJustifyH("LEFT")
    view.card = CreateFrame("GameTooltip", "ForeverCompendiumItemCard", top, "GameTooltipTemplate")
    -- Who has it: right of the card (showItem places its left edge once the card is drawn), to
    -- the page's right and bottom.
    view.lines = J.NewLines(top, 300)
    view.lines.scroll:SetPoint("TOPLEFT", view.slot, "BOTTOMLEFT", 220, -14)
    view.lines.scroll:SetPoint("BOTTOMRIGHT", -30, 16)
    view.empty = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
    view.empty:SetPoint("CENTER")
    view.empty:SetText(L.JITEMS_EMPTY)
end

function page.Build(frame)
    local p = J.ListPage(frame, {
        countLabel = L.JOURNAL_TAB_ITEMS,
        search = L.JITEMS_SEARCH,
        onSearch = function(text)
            terms = {}
            for term in text:gmatch("[^;]+") do
                term = strtrim(term)
                if term ~= "" then terms[#terms + 1] = term end
            end
            page.Refresh()
        end,
        filterMenu = filterMenu,
        isDefault = function() return not next(hidden) end,
        onReset = function()
            hidden = {}
            page.Refresh()
        end,
        sortMenu = sortMenu,
        sortText = function()
            for _, s in ipairs(SORTS) do
                if s[1] == sort then return format(L.CFILTER_SORT_BY, s[2]) end
            end
        end,
        fill = fillItemEntry,
        onClick = function(item, button)
            if button == "RightButton" then
                Bags.Find(M, item.itemID)
                return
            end
            showItem(item.itemID)
            list:Refresh()
        end,
        isSelected = function(item) return item.itemID == selected end,
    })
    list, count, filterButton, sortButton = p.list, p.count, p.filter, p.sort
    buildItemView(p.right)
end

Journal.AddPage(page)
