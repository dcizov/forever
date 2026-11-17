--[[
    Forever Codex - Modules/Journal/ItemsPage.lua
    The journal's Items page: every item the Recorder saw (in loot, on vendors, as quest rewards),
    searched by name, filtered by quality and sorted by name, quality or how many sources it has.
    The chosen item: a card with its icon in the achievement window's ornate ring (Shift-click
    links it), name, kind, item level and how many you have, and buttons (Try On for what can be
    worn, Find in Bags for what you carry: UI/Bags.lua; a right-click on its row in the list
    too); under it what its tooltip says, written on the page (Details: binding, slot, armor,
    stats, the level it needs, sell price), then who drops it (each with its face, name, level
    and home, its drop chance at the right), who sells it and for how much, the quests that give
    it, the quest it starts and the discovered quests it's used in (QuestieDB). Every creature,
    NPC and quest named opens on a click.
]]

local _, ns = ...
local L = ns.L

local ipairs, pairs, next, type, format, table = ipairs, pairs, next, type, string.format, table
local CreateFrame = CreateFrame
local Book, Plain = ns.Book, ns.Plain
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

-- A creature's line: its round face, its name in its reaction's colour, its level and home in
-- grey, `tag` at the right (a drop rate, a price); a click opens it.
local function creatureLine(lines, e, tag)
    local rec = e.rec
    local r, g, b = Text.ReactionColor(rec.reaction)
    local where = Text.Where(rec)
    local display = rec.display or next(rec.displays or {})
    lines:Line(Text.Color(r, g, b) .. (rec.name or "?") .. "|r" .. Text.GRAY .. "  [" .. Text.LevelShort(rec) .. "]"
        .. (where ~= "" and ("  " .. where) or "") .. "|r", {
        display = display, icon = not display and "Interface\\Icons\\INV_Misc_QuestionMark" or nil, tag = tag,
        data = e, onEnter = creatureTip, link = { "creature", e.npcID } })
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

-- The item's link: the one it was last seen with (its random enchantment, "of the Bear", is only
-- there), else the game's.
local function linkOf(itemID)
    local item = Book.Item(itemID)
    if item and item.link then return item.link end
    local _, link = C_Item.GetItemInfo(itemID)
    return link
end

-- What the item's tooltip says (the game's own lines, from the link it was last seen with: its
-- random enchantment, "of the Bear", is only there), written on the page as the label of an
-- exhibit: each line in its colour inked for the paper, the right-hand text (a slot, a weapon's
-- speed) at the right, a sell price as money. Its name, the first line, is the page's title.
-- The tooltip's lines as wide as a tooltip, so what it writes at the right stays beside its line.
local DETAILS_W = 340

local function addDetails(lines, itemID)
    local link = linkOf(itemID)
    local data = link and C_TooltipInfo.GetHyperlink(link) or C_TooltipInfo.GetItemByID(itemID)
    local shown = false
    for i, line in ipairs(data and data.lines or {}) do
        local left, right = Plain(line.leftText), Plain(line.rightText)
        local price = Plain(line.price)
        if price and price > 0 then right = ns.MoneyText(price) end
        if i > 1 and type(left) == "string" and left ~= "" then
            if not shown then lines:Head(L.JITEMS_DETAILS) end
            shown = true
            local c = line.leftColor
            local text = c and Text.Color(Plain(c.r) or 1, Plain(c.g) or 1, Plain(c.b) or 1) .. left .. "|r" or left
            lines:Line(text, { tag = type(right) == "string" and right or nil, font = "GameFontHighlightSmall", width = DETAILS_W })
        end
    end
end

local function questLines(lines, title, quests)
    if #quests == 0 then return end
    lines:Head(title, #quests)
    for _, questID in ipairs(quests) do lines:Quest(questID) end
end

-- The quests QuestieDB says the item is used in (not those the book has already).
-- Only the quests you've discovered (Lib/QuestIndex.lua): the rest stay hidden.
local function usedIn(itemID, known)
    local info = ns.QuestieDB.Status() == "ready" and ns.QuestieDB.Item(itemID)
    local out, seen = {}, {}
    for _, questID in ipairs(known) do seen[questID] = true end
    local Discovered = ns.QuestIndex.Discovered
    for _, questID in ipairs(info and info.relatedQuests or {}) do
        if not seen[questID] and Discovered(questID) then out[#out + 1] = questID end
    end
    local starts = info and info.startsQuest
    if starts and not seen[starts] and Discovered(starts) then table.insert(out, 1, starts) end
    return out
end

local function showItem(itemID)
    selected = itemID
    view.top:SetShown(itemID ~= nil)
    view.empty:SetShown(itemID == nil)
    if not itemID then return end
    J.SetSlot(view.slot, itemID)
    view.ring:SetVertexColor(Text.ItemColor(itemID))
    local r, g, b = Text.ItemColor(itemID)
    view.name:SetText(J.Ink(Text.Color(r, g, b) .. Text.ItemName(itemID) .. "|r"))
    view.kind:SetText(itemKind(itemID))
    view.facts:SetText(itemFacts(itemID))
    view.tryOn:SetShown(C_Item.IsDressableItemByID(itemID) == true)
    view.find:SetShown(Bags.Has(itemID))
    -- The buttons shown, right to left from the card's bottom right corner.
    local previous
    for _, b in ipairs({ view.tryOn, view.find }) do
        if b:IsShown() then
            b:ClearAllPoints()
            if previous then b:SetPoint("RIGHT", previous, "LEFT", -6, 0) else b:SetPoint("BOTTOMRIGHT", -12, 12) end
            previous = b
        end
    end
    local e = index[itemID] or { drops = {}, wares = {}, rewards = {}, starts = {} }
    local lines = view.lines
    lines:Begin()
    addDetails(lines, itemID)
    if #e.drops > 0 then
        table.sort(e.drops, function(a, b) return (Book.DropRate(a.rec, itemID) or 0) > (Book.DropRate(b.rec, itemID) or 0) end)
        lines:Head(L.JITEMS_DROPPED_BY, #e.drops)
        for _, d in ipairs(e.drops) do
            creatureLine(lines, d, format("%s  (%d/%d)", Text.Percent(Book.DropRate(d.rec, itemID)),
                d.rec.loot[itemID] or 0, d.rec.looted or 0))
        end
    end
    if #e.wares > 0 then
        lines:Head(L.JITEMS_SOLD_BY, #e.wares)
        for _, w in ipairs(e.wares) do
            local ware = w.rec.wares[itemID]
            creatureLine(lines, w, ns.MoneyText(ware.price or 0) .. ((ware.stack or 1) > 1 and (" x" .. ware.stack) or ""))
        end
    end
    questLines(lines, L.JITEMS_REWARD_FROM, e.rewards)
    questLines(lines, L.JITEMS_STARTS, e.starts)
    local used = usedIn(itemID, e.starts)
    questLines(lines, L.JITEMS_USED_IN, used)
    if #e.drops + #e.wares + #e.rewards + #e.starts + #used == 0 then lines:Line(Text.GRAY .. L.JITEMS_NO_SOURCE .. "|r") end
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
    Journal.Visit(page.key, itemID)
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

-- The chosen item: its card at the top, its tooltip's panel at the left under it, who has it right of that.
local function buildItemView(parent)
    view = {}
    local top = CreateFrame("Frame", nil, parent)
    top:SetAllPoints()
    view.top = top
    local head = J.Panel(top)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    head:SetHeight(92)
    -- The icon: a click finds the item in your bags; its tooltip says so when you have it.
    view.slot = J.ItemSlot(head, 52, function(slot)
        if Bags.Has(slot.itemID) then GameTooltip:AddLine(L.JITEMS_FIND_HINT, 0, 1, 0) end
    end, function(slot) Bags.Find(M, slot.itemID) end)
    view.slot:SetPoint("TOPLEFT", 22, -20)
    -- The achievement window's ornate ring round it, in its quality's colour (Blizzard draws it
    -- at about 1.44 times the icon).
    view.ring = view.slot:CreateTexture(nil, "OVERLAY", nil, 3)
    view.ring:SetTexture("Interface\\AchievementFrame\\UI-Achievement-IconFrame")
    view.ring:SetTexCoord(0, 0.5625, 0, 0.5625)
    view.ring:SetSize(75, 75)
    view.ring:SetPoint("CENTER", -1, 1)
    view.name = head:CreateFontString(nil, "OVERLAY", J.TITLE_FONT)
    J.InkFont(view.name)
    view.name:SetPoint("TOPLEFT", view.slot, "TOPRIGHT", 14, -2)
    view.name:SetPoint("RIGHT", -16, 0)
    view.name:SetJustifyH("LEFT")
    view.name:SetWordWrap(false)
    view.kind = head:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    view.kind:SetPoint("TOPLEFT", view.name, "BOTTOMLEFT", 0, -5)
    J.InkFont(view.kind, "inkSoft")
    view.facts = head:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    J.InkFont(view.facts, "inkSoft")
    local divider = J.Divider(head)
    divider:SetPoint("BOTTOMLEFT", 10, 0)
    divider:SetPoint("BOTTOMRIGHT", -10, 0)
    view.facts:SetPoint("TOPLEFT", view.kind, "BOTTOMLEFT", 0, -4)
    view.tryOn = ns.Kit.NewButton(head, L.JITEMS_TRY_ON, 80, function()
        local link = linkOf(selected)
        if link then DressUpLink(link) end
    end)
    view.find = ns.Kit.NewButton(head, L.JITEMS_FIND, 100, function() Bags.Find(M, selected) end)
    -- What it is (its tooltip's lines) and who has it, under the card.
    view.body = J.Panel(top)
    view.body:SetPoint("BOTTOMRIGHT")
    view.body:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -4)
    view.lines = J.NewLines(view.body, 300)
    view.lines.scroll:SetPoint("TOPLEFT", 12, -10)
    view.lines.scroll:SetPoint("BOTTOMRIGHT", -24, 10)
    view.empty = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    J.InkFont(view.empty, "inkSoft")
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
            Journal.Visit(page.key, item.itemID)
            list:Refresh()
        end,
        isSelected = function(item) return item.itemID == selected end,
    })
    list, count, filterButton, sortButton = p.list, p.count, p.filter, p.sort
    buildItemView(p.right)
end

Journal.AddPage(page)
