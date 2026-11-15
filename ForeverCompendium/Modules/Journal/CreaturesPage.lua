--[[
    Forever Compendium - Modules/Journal/CreaturesPage.lua
    The journal's Creatures page: the list of creatures on the left, under a folding header for
    each zone (Filter.Grouped; pinned ones first under their own; off with "Group by zone"),
    and the chosen one on the right, its model and what's known of it above (CreatureDetail.lua) and its loot and
    quests below (CreatureBoxes.lua). What the list holds is CreatureFilter.lua's. The layout is JournalKit's
    ListPage: the count and the order in the strip at the top, the search box and the filter
    menu (which also picks what the search looks through: Name / Loot / Quest) over the list.

    In the list, a creature's name is in the colour of how it stands toward you and its level in
    the colour of its level against yours; a star marks a pinned one, a skull a rare, a quest
    mark one a quest in your log wants. Right-click a row to pin or unpin it (pinned creatures
    come first, and Creature Areas shows where they live). The column headers sort.
]]

local _, ns = ...
local L = ns.L

local ipairs, format = ipairs, string.format
local Book = ns.Book
local Text = assert(ns.JournalText, "CreaturesPage.lua loads after JournalText.lua")
local J = assert(ns.JournalKit, "CreaturesPage.lua loads after JournalKit.lua")
local Filter = assert(ns.CreatureFilter, "CreaturesPage.lua loads after CreatureFilter.lua")
local Journal = assert(ns.Journal, "CreaturesPage.lua loads after Journal.lua")
local Detail = assert(ns.CreatureDetail, "CreaturesPage.lua loads after CreatureDetail.lua")
local Boxes = assert(ns.CreatureBoxes, "CreaturesPage.lua loads after CreatureBoxes.lua")

local DISPLAY_HEIGHT = 330 -- the model and what's known of it; the loot and quest boxes fill the rest
local SEARCH_TEXT = { name = L.JOURNAL_SEARCH, loot = L.CFILTER_SEARCH_LOOT, quest = L.CFILTER_SEARCH_QUEST }

local M = Journal.module
local page = { key = "creatures", label = L.JOURNAL_TAB_CREATURES, icon = "Interface\\Icons\\Ability_Hunter_BeastTaming", order = 10 }
local list, count, detail, boxes, filterButton, search
local selected
local log = {} -- the quests in your log, read once per redraw

local function db() return M.db end

local KILLS_ICON = "|TInterface\\WorldStateFrame\\SkullBones:14:14:0:0:64:64:0:32:0:32|t"

-- A creature's entry: its portrait (the favourite star when pinned), its name in the colour of
-- how it stands toward you, "Level 15-16 Beast" under it, its kills at the right, and a mark on
-- the portrait for a quest in your log that wants it, or for a rare or boss.
local function fillCreatureEntry(entry, item)
    local rec = item.rec
    entry.portrait:SetCreature(rec)
    entry.name:SetText(rec.name or "?")
    entry.name:SetTextColor(Text.ReactionColor(rec.reaction))
    entry.sub:SetText(Text.LevelShort(rec) .. (rec.creatureType and ("  " .. Text.GRAY .. rec.creatureType .. "|r") or ""))
    if (rec.kills or 0) > 0 then entry.note:SetText(rec.kills .. " " .. KILLS_ICON) end
    entry.favorite:SetShown(rec.pinned == true)
    local trophy = Book.TrophyKind(rec)
    if Book.WantedBy(rec, log) then
        entry.mark:SetAtlas("QuestNormal")
    elseif trophy then
        entry.mark:SetAtlas(trophy == "boss" and "VignetteKillElite" or "VignetteKill")
    end
end

-- Pins or unpins a creature (Creature Areas and the list's order follow).
function Journal.TogglePin(npcID)
    local rec = Book.Creature(npcID)
    if not rec then return end
    ns.Sound(Book.SetPinned(npcID, not rec.pinned) and "pinOn" or "pinOff")
    Journal.Refresh()
end

local function showCreature(npcID)
    selected = npcID
    detail:Show(npcID)
    boxes:Show(npcID)
end

local function onCreatureClick(item, button)
    if item.header then
        local collapsed = db().collapsed
        collapsed[item.header] = not collapsed[item.header] or nil
        return page.Refresh()
    end
    if button == "RightButton" then return Journal.TogglePin(item.npcID) end
    showCreature(item.npcID)
    list:Refresh()
end

function page.Refresh()
    log = Book.LogQuests()
    local items = Filter.Items(db())
    list:SetItems(db().groupZones and Filter.Grouped(items, db().collapsed) or items)
    local total = Book.Count(Book.Creatures())
    count.Count:SetText(#items < total and format(L.JOURNAL_COUNT, #items, total) or total)
    filterButton:ValidateResetState()
    page.dataButton:SetShown(ns.Archive.module.active)
    page.dataButton.selected = selected
    search.Instructions:SetText(SEARCH_TEXT[Filter.mode] or L.JOURNAL_SEARCH)
    if not (selected and Book.Creature(selected)) then selected = items[1] and items[1].npcID end
    showCreature(selected)
end

-- Picks creature `npcID` (its group unfolded, scrolled into view), and shows `part` if given
-- (CreatureBoxes:Open's keys: "quests" for ns.ShowQuest).
function page.Select(npcID, part)
    selected = npcID
    local rec = Book.Creature(npcID)
    if rec then
        db().collapsed[rec.pinned and "pinned" or Filter.GroupOf(rec)] = nil
    end
    page.Refresh()
    for i, item in ipairs(list.items) do
        if item.npcID == npcID then list:ShowIndex(i) end
    end
    if part then boxes:Open(part) end
end

-- Picks order `key`, or the same one the other way.
local function sortBy(key)
    local d = db()
    if d.sort == key then
        ns:SetOption(M.name, "reverse", not d.reverse)
    else
        ns:SetOption(M.name, "sort", key)
        ns:SetOption(M.name, "reverse", false)
    end
end

---------------------------------------------------------------------------
-- Menus
---------------------------------------------------------------------------

-- The filter menu: what the search looks through, then the filters.
local function filterMenu(_, root)
    root:CreateTitle(L.CFILTER_SEARCH_IN)
    for _, mode in ipairs(Filter.MODES) do
        root:CreateRadio(mode[2], function() return Filter.mode == mode[1] end, function()
            Filter.mode = mode[1]
            page.Refresh()
        end)
    end
    for _, group in ipairs(Filter.Groups()) do
        local title, setKey, choices, nested = group[1], group[2], group[3], group[4]
        local parent = root
        if nested then
            parent = root:CreateButton(title)
        else
            root:CreateTitle(title)
        end
        for _, choice in ipairs(choices) do
            parent:CreateCheckbox(choice[2], function() return Filter.sets[setKey][choice[1]] == true end, function()
                Filter.Toggle(setKey, choice[1])
                page.Refresh()
            end)
        end
    end
    root:CreateDivider()
    root:CreateCheckbox(L.JOURNAL_CRITTERS, function() return db().critters end, function()
        ns:SetOption(M.name, "critters", not db().critters)
    end)
end

local function sortMenu(_, root)
    for _, sort in ipairs(Filter.SORTS) do
        root:CreateRadio(sort[2], function() return db().sort == sort[1] end, function() sortBy(sort[1]) end)
    end
    root:CreateDivider()
    root:CreateCheckbox(L.CFILTER_REVERSE, function() return db().reverse end, function()
        ns:SetOption(M.name, "reverse", not db().reverse)
    end)
    root:CreateCheckbox(L.JOURNAL_GROUP_ZONES, function() return db().groupZones end, function()
        ns:SetOption(M.name, "groupZones", not db().groupZones)
    end)
end

function page.Build(frame)
    local p = J.ListPage(frame, {
        countLabel = L.JOURNAL_TAB_CREATURES,
        search = L.JOURNAL_SEARCH,
        onSearch = function(text)
            Filter.SetSearch(text)
            page.Refresh()
        end,
        filterMenu = filterMenu,
        isDefault = function() return not Filter.Any() end,
        onReset = function()
            Filter.Clear()
            page.Refresh()
        end,
        sortMenu = sortMenu,
        sortText = function()
            for _, s in ipairs(Filter.SORTS) do
                if s[1] == db().sort then return format(L.CFILTER_SORT_BY, s[2]) end
            end
        end,
        fill = fillCreatureEntry,
        onClick = onCreatureClick,
        isSelected = function(item) return item.npcID == selected end,
    })
    list, count, filterButton, search = p.list, p.count, p.filter, p.search
    -- The Archive's menu (export, import, backups) on Blizzard's settings gear, beside the order.
    page.dataButton = J.MenuButton(frame, L.ARCHIVE_MENU, function(_, root) ns.Archive.FillMenu(root, selected) end)
    page.dataButton:SetPoint("RIGHT", p.sort, "LEFT", -8, 0)
    detail = Detail.Build(p.right, DISPLAY_HEIGHT)
    boxes = Boxes.Build(p.right, DISPLAY_HEIGHT)
end

Journal.AddPage(page)
