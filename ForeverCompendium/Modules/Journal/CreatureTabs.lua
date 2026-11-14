--[[
    Forever Compendium - Modules/Journal/CreatureTabs.lua
    The bottom of the Creatures page's right side (CreaturesPage.lua makes it and calls Show):
    one creature's tabs, each labelled with how many things it holds.

      * Loot: what its corpses held, each with how often (corpses it was on over corpses
        looted), filtered by quality and sorted by chance, quality or name; a quest item is
        marked. Under the grid: the money it carried and the reputation its kills gave.
      * Wares: what it sells (its price and stack on mouse over; limited stock marked).
      * Rewards: what the quests it gives reward.
      * Quests: the quests it has to do with, and a legend of their icons (CreatureQuestTab.lua).
      * Notes: your own note on it, kept as you type.
    Click an item for the Items page on it, a quest to see it (ns.ShowQuest); shift-click links.
]]

local _, ns = ...
local L = ns.L

local ipairs, pairs, format, table, math, select = ipairs, pairs, string.format, table, math, select
local CreateFrame = CreateFrame
local Book, Text, J = ns.Book, ns.JournalText, ns.JournalKit

local QuestTab = assert(ns.CreatureQuestTab, "CreatureTabs.lua loads after CreatureQuestTab.lua")

local Tabs = {}
ns.CreatureTabs = Tabs

local SLOT, GAP = 36, 6
local QUEST_MARK = "Interface\\GossipFrame\\AvailableQuestIcon"
local LIMITED_MARK = "Interface\\Common\\Indicator-Yellow"
local TABS = { "loot", "wares", "rewards", "quests", "notes" }
local QUALITIES = { 0, 1, 2, 3, 4, 5 }

local pane = { hidden = {}, sort = "chance" }

---------------------------------------------------------------------------
-- What each tab holds
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

local COUNTS = {
    loot = function(rec) return Book.Count(rec.loot) end,
    wares = function(rec) return Book.Count(rec.wares) end,
    rewards = function(rec) return #rewardsOf(rec) end,
    quests = function(rec) return #Text.CreatureQuests(rec) end,
}

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
    GameTooltip:AddLine(format(L.CTABS_PRICE, Text.Money(ware.price or 0), ware.stack or 1), 1, 1, 1)
    if ware.limited then GameTooltip:AddLine(L.CTABS_LIMITED, 1, 0.82, 0) end
end

local function rewardTip(slot)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(format(slot.choice and L.CTABS_CHOICE_FOR or L.CTABS_REWARD_FOR, Book.QuestName(slot.questID)), 1, 0.82, 0)
end

local function openItem(slot) ns.ShowItem(slot.itemID) end

local function makeGrid(content, tip)
    local scroll = ns.Kit.NewScroll(content)
    scroll:SetPoint("TOPLEFT", 0, -28)
    scroll:SetPoint("BOTTOMRIGHT", -22, 20)
    local inner = CreateFrame("Frame", nil, scroll)
    inner:SetSize(1, 1)
    scroll:SetScrollChild(inner)
    local grid = J.Grid(inner, SLOT, GAP, tip, openItem)
    grid.scroll, grid.inner = scroll, inner
    grid.empty = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    grid.empty:SetPoint("TOPLEFT", 4, -36)
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
-- The tabs' contents
---------------------------------------------------------------------------

local function lootMenu(_, root)
    root:CreateTitle(L.CTABS_SORT)
    for _, sort in ipairs({ { "chance", L.CTABS_SORT_CHANCE }, { "quality", L.CTABS_SORT_QUALITY }, { "name", L.CTABS_SORT_NAME } }) do
        root:CreateRadio(sort[2], function() return pane.sort == sort[1] end, function()
            pane.sort = sort[1]
            Tabs:Show(pane.npcID)
        end)
    end
    root:CreateTitle(L.CTABS_QUALITY)
    for _, q in ipairs(QUALITIES) do
        local r, g, b = C_Item.GetItemQualityColor(q)
        root:CreateCheckbox(Text.Color(r, g, b) .. _G["ITEM_QUALITY" .. q .. "_DESC"] .. "|r", function() return not pane.hidden[q] end, function()
            pane.hidden[q] = not pane.hidden[q] or nil
            Tabs:Show(pane.npcID)
        end)
    end
end

local function lootSummary(rec)
    local parts = {}
    if (rec.money or 0) > 0 then
        parts[#parts + 1] = format(L.CTABS_MONEY, Text.Money(rec.money / math.max(rec.looted or 1, 1)))
    end
    for faction, r in pairs(rec.rep or {}) do
        parts[#parts + 1] = format(L.CTABS_REP, faction, format("%+d", math.floor(r.total / math.max(r.count, 1) + 0.5)))
    end
    return table.concat(parts, "    ")
end

local SHOW = {}

function SHOW.loot(rec)
    local looted = rec.looted or 0
    fillGrid(pane.loot, lootOf(rec), function(slot, itemID)
        J.SetSlot(slot, itemID, Text.Percent(Book.DropRate(rec, itemID)), isQuestItem(itemID) and QUEST_MARK or nil)
    end, looted == 0 and L.JOURNAL_NO_LOOT or L.CTABS_NONE_SHOWN)
    pane.summary:SetText(lootSummary(rec))
end

function SHOW.wares(rec)
    fillGrid(pane.wares, waresOf(rec), function(slot, itemID)
        local ware = rec.wares[itemID]
        J.SetSlot(slot, itemID, (ware.stack or 1) > 1 and ware.stack or "", ware.limited and LIMITED_MARK or nil)
    end, L.CTABS_NO_WARES)
end

function SHOW.rewards(rec)
    fillGrid(pane.rewards, rewardsOf(rec), function(slot, entry)
        J.SetSlot(slot, entry.itemID, "", nil)
        slot.questID, slot.choice = entry.questID, entry.choice
    end, L.CTABS_NO_REWARDS)
end

function SHOW.quests(rec) pane.quests:Show(rec) end

function SHOW.notes(rec)
    pane.note:SetWidth(math.max((pane.noteScroll:GetWidth() or 0) - 4, 100))
    pane.filling = true
    pane.note:SetText(rec.note or "")
    pane.filling = false
    pane.notePrompt:SetShown((rec.note or "") == "")
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------

local function buildNotes(content)
    local scroll = ns.Kit.NewScroll(content)
    scroll:SetPoint("TOPLEFT", 4, -6)
    scroll:SetPoint("BOTTOMRIGHT", -26, 6)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(560)
    edit:SetMaxLetters(4000)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    edit:SetScript("OnTextChanged", function(self)
        if pane.filling then return end
        local rec = Book.Creature(pane.npcID)
        if not rec then return end
        local text = self:GetText()
        rec.note = text ~= "" and text or nil
        pane.notePrompt:SetShown(text == "")
    end)
    scroll:SetScrollChild(edit)
    scroll:EnableMouse(true)
    scroll:SetScript("OnMouseDown", function() edit:SetFocus() end)
    pane.note, pane.noteScroll = edit, scroll
    pane.notePrompt = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    pane.notePrompt:SetPoint("TOPLEFT", 8, -10)
    pane.notePrompt:SetText(L.CTABS_NOTE_PROMPT)
end

local function selectTab(index)
    pane.current = TABS[index]
    pane.tabs.Select(index)
    for key, content in pairs(pane.contents) do content:SetShown(key == pane.current) end
    local rec = Book.Creature(pane.npcID)
    if rec then SHOW[pane.current](rec) end
end

-- Below the display (`top` high): Blizzard's tabs on top of an inset holding the chosen one.
function Tabs.Build(parent, top)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetPoint("TOPLEFT", 0, -top - 6)
    holder:SetPoint("BOTTOMRIGHT")
    pane.holder = holder
    local labels = {}
    for i, key in ipairs(TABS) do labels[i] = L["CTABS_" .. key:upper()] end
    local inset = J.Inset(holder)
    inset:SetPoint("TOPLEFT", 0, -30)
    inset:SetPoint("BOTTOMRIGHT")
    pane.tabs = J.TopTabs(holder, labels, selectTab, true)
    pane.tabs.system:SetPoint("BOTTOMLEFT", inset, "TOPLEFT", 10, -2)

    pane.contents = {}
    for _, key in ipairs(TABS) do
        local content = CreateFrame("Frame", nil, inset)
        content:SetPoint("TOPLEFT", 14, -12)
        content:SetPoint("BOTTOMRIGHT", -10, 10)
        pane.contents[key] = content
    end
    pane.loot = makeGrid(pane.contents.loot, lootTip)
    local lootOptions = J.Dropdown(pane.contents.loot, 150, lootMenu, true)
    lootOptions:SetPoint("TOPRIGHT", -4, 0)
    lootOptions:SetIsDefaultCallback(function() return next(pane.hidden) == nil and pane.sort == "chance" end)
    lootOptions:SetDefaultCallback(function()
        pane.hidden, pane.sort = {}, "chance"
        Tabs:Show(pane.npcID)
    end)
    pane.summary = pane.contents.loot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pane.summary:SetPoint("BOTTOMLEFT", 2, 2)
    pane.wares = makeGrid(pane.contents.wares, wareTip)
    pane.rewards = makeGrid(pane.contents.rewards, rewardTip)
    pane.quests = QuestTab.Build(pane.contents.quests)
    buildNotes(pane.contents.notes)
    pane.current = "loot"
    selectTab(1)
    return setmetatable(pane, { __index = Tabs })
end

-- Shows creature `npcID`'s tabs (nil: none).
function Tabs:Show(npcID)
    local rec = npcID and Book.Creature(npcID)
    pane.holder:SetShown(rec ~= nil)
    if not rec then return end
    if pane.npcID ~= npcID and pane.note:HasFocus() then pane.note:ClearFocus() end
    pane.npcID = npcID
    for i, key in ipairs(TABS) do
        local count = COUNTS[key] and COUNTS[key](rec)
        pane.tabs.SetLabel(i, L["CTABS_" .. key:upper()] .. (count and count > 0 and format(" (%d)", count) or ""))
    end
    SHOW[pane.current](rec)
end

-- Opens tab `key` ("loot", "wares", "rewards", "quests", "notes") of the creature shown.
function Tabs:Open(key)
    for i, k in ipairs(TABS) do
        if k == key then selectTab(i) end
    end
end
