--[[
    Forever Compendium - Modules/Journal/CreatureLootBox.lua
    A creature's Loot box (CreatureBoxes.lua makes the box and places it): its header names what
    it can show, each with how many: Loot (what its corpses held, each with how often: corpses
    it was on over corpses looted; filtered by quality and sorted by chance, quality or name; a
    quest item marked; the money it carried and the reputation its kills gave along the bottom),
    Wares (what it sells: price and stack on mouse over, limited stock marked) and Rewards (what
    the quests it gives reward). Click one in the header to show it; only those it has show.
    Click an item for the Items page on it; shift-click links.
]]

local _, ns = ...
local L = ns.L

local ipairs, pairs, format, table, math, select, next = ipairs, pairs, string.format, table, math, select, next
local CreateFrame = CreateFrame
local Book = ns.Book
local Text = assert(ns.JournalText, "CreatureLootBox.lua loads after JournalText.lua")
local J = assert(ns.JournalKit, "CreatureLootBox.lua loads after JournalKit.lua")

local LootBox = {}
ns.CreatureLootBox = LootBox

local SLOT, GAP = 36, 6
local QUEST_MARK = "Interface\\GossipFrame\\AvailableQuestIcon"
local LIMITED_MARK = "Interface\\Common\\Indicator-Yellow"
local VIEWS = { "loot", "wares", "rewards" }
local QUALITIES = { 0, 1, 2, 3, 4, 5 }

local pane = { hidden = {}, sort = "chance", view = "loot" } -- also: redraw, npcID, the box's parts

---------------------------------------------------------------------------
-- What each view holds
---------------------------------------------------------------------------

local function isQuestItem(itemID)
    local classID = select(6, C_Item.GetItemInfoInstant(itemID))
    return classID == Enum.ItemClass.Questitem
end

local function qualityOf(itemID)
    local item = Book.Item(itemID)
    return item and item.quality or C_Item.GetItemQualityByID(itemID) or 1
end

local LOOT_ORDER = {
    chance = function(rec) return function(a, b)
        local x, y = rec.loot[a] or 0, rec.loot[b] or 0
        if x ~= y then return x > y end
        return a < b
    end end,
    quality = function() return function(a, b)
        local x, y = qualityOf(a), qualityOf(b)
        if x ~= y then return x > y end
        return Text.ItemName(a) < Text.ItemName(b)
    end end,
    name = function() return function(a, b) return Text.ItemName(a) < Text.ItemName(b) end end,
}

local function lootOf(rec)
    local ids = {}
    for itemID in pairs(rec.loot or {}) do
        if not pane.hidden[qualityOf(itemID)] then ids[#ids + 1] = itemID end
    end
    table.sort(ids, (LOOT_ORDER[pane.sort] or LOOT_ORDER.chance)(rec))
    return ids
end

local function waresOf(rec)
    local ids = {}
    for itemID in pairs(rec.wares or {}) do ids[#ids + 1] = itemID end
    table.sort(ids, function(a, b) return Text.ItemName(a) < Text.ItemName(b) end)
    return ids
end

local function rewardsOf(rec)
    local list = {}
    for questID in pairs(rec.starts or {}) do
        local q = Book.Quest(questID) or {}
        for _, itemID in ipairs(q.rewards or {}) do list[#list + 1] = { itemID = itemID, questID = questID } end
        for _, itemID in ipairs(q.choices or {}) do list[#list + 1] = { itemID = itemID, questID = questID, choice = true } end
    end
    return list
end

-- How many things view `key` ("loot", "wares", "rewards") holds for creature `rec`, or nil for another key.
local function countOf(rec, key)
    if key == "loot" then return Book.Count(rec.loot) end
    if key == "wares" then return Book.Count(rec.wares) end
    if key == "rewards" then return #rewardsOf(rec) end
end

---------------------------------------------------------------------------
-- Item grids
---------------------------------------------------------------------------

local function lootTip(slot)
    local rec = Book.Creature(pane.npcID)
    if not rec then return end
    GameTooltip:AddLine(" ")
    local corpses = rec.loot[slot.itemID] or 0
    GameTooltip:AddLine(format(L.CTABS_DROPPED, corpses, rec.looted or 0, Text.Percent(Book.DropRate(rec, slot.itemID))), 1, 0.82, 0)
end

local function wareTip(slot)
    local rec = Book.Creature(pane.npcID)
    local ware = rec and rec.wares and rec.wares[slot.itemID]
    if not ware then return end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(format(L.CTABS_PRICE, ns.MoneyText(ware.price or 0), ware.stack or 1), 1, 1, 1)
    if ware.limited then GameTooltip:AddLine(L.CTABS_LIMITED, 1, 0.82, 0) end
end

local function rewardTip(slot)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(format(slot.choice and L.CTABS_CHOICE_FOR or L.CTABS_REWARD_FOR, Book.QuestName(slot.questID)), 1, 0.82, 0)
end

local function openItem(slot) ns.ShowItem(slot.itemID) end

local function makeGrid(content, tip)
    local scroll = ns.Kit.NewScroll(content)
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -22, 18)
    local inner = CreateFrame("Frame", nil, scroll)
    inner:SetSize(1, 1)
    scroll:SetScrollChild(inner)
    local grid = J.Grid(inner, SLOT, GAP, tip, openItem)
    grid.scroll, grid.inner = scroll, inner
    grid.empty = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    grid.empty:SetPoint("TOPLEFT", 4, -6)
    grid.empty:SetPoint("RIGHT", -8, 0)
    grid.empty:SetJustifyH("LEFT")
    return grid
end

local function fillGrid(grid, entries, set, emptyText)
    local width = math.max(grid.scroll:GetWidth() or 0, SLOT)
    grid.inner:SetWidth(width)
    local height = grid:Fill(entries, set, width)
    grid.inner:SetHeight(math.max(height, 1))
    grid.scroll:SetVerticalScroll(0)
    grid.empty:SetText(#entries == 0 and emptyText or "")
end

---------------------------------------------------------------------------
-- The views
---------------------------------------------------------------------------

local function lootSummary(rec)
    local parts = {}
    if (rec.money or 0) > 0 then
        parts[#parts + 1] = format(L.CTABS_MONEY, ns.MoneyText(rec.money / math.max(rec.looted or 1, 1)))
    end
    for faction, r in pairs(rec.rep or {}) do
        parts[#parts + 1] = format(L.CTABS_REP, faction, format("%+d", math.floor(r.total / math.max(r.count, 1) + 0.5)))
    end
    return table.concat(parts, "    ")
end

local function fillLoot(rec)
    local looted = rec.looted or 0
    fillGrid(pane.grids.loot, lootOf(rec), function(slot, itemID)
        J.SetSlot(slot, itemID, Text.Percent(Book.DropRate(rec, itemID)), isQuestItem(itemID) and QUEST_MARK or nil)
    end, looted == 0 and L.JOURNAL_NO_LOOT or L.CTABS_NONE_SHOWN)
    pane.summary:SetText(lootSummary(rec))
end

local function fillWares(rec)
    fillGrid(pane.grids.wares, waresOf(rec), function(slot, itemID)
        local ware = rec.wares[itemID]
        J.SetSlot(slot, itemID, (ware.stack or 1) > 1 and ware.stack or "", ware.limited and LIMITED_MARK or nil)
    end, L.CTABS_NO_WARES)
end

local function fillRewards(rec)
    fillGrid(pane.grids.rewards, rewardsOf(rec), function(slot, entry)
        J.SetSlot(slot, entry.itemID, "", nil)
        slot.questID, slot.choice = entry.questID, entry.choice
    end, L.CTABS_NO_REWARDS)
end

-- Fills the view picked.
local function fillView(rec)
    if pane.view == "wares" then return fillWares(rec) end
    if pane.view == "rewards" then return fillRewards(rec) end
    return fillLoot(rec)
end

-- The loot box's header: a word for each view the creature has (Loot always), the shown one in gold.
local function drawViewButtons(rec)
    local previous
    for _, key in ipairs(VIEWS) do
        local b = pane.viewButtons[key]
        local count = countOf(rec, key)
        local shown = key == "loot" or count > 0
        b:SetShown(shown)
        if shown then
            local label = L["CTABS_" .. key:upper()] .. (count > 0 and format(" (%d)", count) or "")
            b.text:SetText(label)
            b.text:SetFontObject(key == pane.view and "GameFontNormalLarge" or "GameFontDisableLarge")
            b:SetWidth(b.text:GetStringWidth() + 4)
            b:ClearAllPoints()
            if previous then b:SetPoint("LEFT", previous, "RIGHT", 14, 0) else b:SetPoint("TOPLEFT", 10, -8) end
            previous = b
        end
    end
end

local function showView(rec)
    if pane.view ~= "loot" and countOf(rec, pane.view) == 0 then pane.view = "loot" end
    for key, grid in pairs(pane.grids) do
        grid.scroll:SetShown(key == pane.view)
        grid.empty:SetShown(key == pane.view)
    end
    pane.lootOptions:SetShown(pane.view == "loot")
    pane.summary:SetShown(pane.view == "loot")
    drawViewButtons(rec)
    fillView(rec)
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------

local function lootMenu(_, root)
    root:CreateTitle(L.CTABS_SORT)
    for _, sort in ipairs({ { "chance", L.CTABS_SORT_CHANCE }, { "quality", L.CTABS_SORT_QUALITY }, { "name", L.CTABS_SORT_NAME } }) do
        root:CreateRadio(sort[2], function() return pane.sort == sort[1] end, function()
            pane.sort = sort[1]
            ns.Sound("button")
            pane.redraw()
        end)
    end
    root:CreateTitle(L.CTABS_QUALITY)
    for _, q in ipairs(QUALITIES) do
        local r, g, b = C_Item.GetItemQualityColor(q)
        root:CreateCheckbox(Text.Color(r, g, b) .. _G["ITEM_QUALITY" .. q .. "_DESC"] .. "|r", function() return not pane.hidden[q] end, function()
            pane.hidden[q] = not pane.hidden[q] or nil
            pane.redraw()
        end)
    end
end

local function viewButton(box, key)
    local b = CreateFrame("Button", nil, box)
    b:SetHeight(24)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    b.text:SetPoint("LEFT", 2, 0)
    b:SetScript("OnClick", function()
        if pane.view == key then return end
        pane.view = key
        ns.Sound("tab")
        pane.redraw()
    end)
    return b
end

local function buildParts(box)
    pane.viewButtons = {}
    for _, key in ipairs(VIEWS) do pane.viewButtons[key] = viewButton(box, key) end
    pane.grids = { loot = makeGrid(box.content, lootTip), wares = makeGrid(box.content, wareTip),
        rewards = makeGrid(box.content, rewardTip) }
    local options = J.Dropdown(box, 110, lootMenu, true)
    options:SetPoint("TOPRIGHT", -10, -6)
    options:SetIsDefaultCallback(function() return next(pane.hidden) == nil and pane.sort == "chance" end)
    options:SetDefaultCallback(function()
        pane.hidden, pane.sort = {}, "chance"
        pane.redraw()
    end)
    pane.lootOptions = options
    pane.summary = box.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pane.summary:SetPoint("BOTTOMLEFT", 2, 0)
    pane.summary:SetPoint("RIGHT", -4, 0)
    pane.summary:SetJustifyH("LEFT")
    pane.summary:SetWordWrap(false)
end

-- The box's header buttons, grids, menu and summary in `box` (J.HeaderInset); redraw() shows
-- the creature again after a change here.
function LootBox.Build(box, redraw)
    pane.redraw = redraw
    buildParts(box)
end

-- Shows creature `rec` (`npcID`) in the view picked (Loot when it has none of that).
function LootBox.Show(rec, npcID)
    pane.npcID = npcID
    showView(rec)
end

-- Picks view `key` ("loot", "wares", "rewards"); false for any other key.
function LootBox.SetView(key)
    if key ~= "loot" and key ~= "wares" and key ~= "rewards" then return false end
    pane.view = key
    return true
end
