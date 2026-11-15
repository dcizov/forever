--[[
    Forever Compendium - Journal
    The journal window (/fc, the minimap button, or a key you bind): what the Recorder learned,
    built the way Blizzard builds its Collections window (the Mount Journal and Toy Box: insets,
    the count box, journal rows with portraits, the model on the Mount Journal's backdrop), with
    Forever's big icon tabs down the right edge (the Character window's), one per page:

      * Creatures (Modules/Journal/CreaturesPage.lua): every creature by zone, searched, filtered
        and sorted, with its model, what's known of it, its loot, wares, quest rewards, quests
        and your note.
      * Items (ItemsPage.lua): every item, and who drops, sells or gives it.
      * Trophies (TrophiesPage.lua): the rares and bosses met, and which you've defeated.
      * Badges (Modules/Social/BadgesPage.lua, while Badges is on): milestones.
    Quests have no page of their own: the quest log has the ones you're on, and a creature's
    Quests tab every one it has to do with (ns.ShowQuest picks between them).
    A page is { key, label, icon, order, Build(parent), Refresh(), Shown() (optional: whether its
    tab shows), Select(...) (optional: picks what ns.ShowCreature / ShowItem point it at) },
    added with Journal.AddPage. While the window is open, what the Recorder learns
    shows at once (its news redraws the page on the next frame).
]]

local _, ns = ...
local L = ns.L

local ipairs, table = ipairs, table
local CreateFrame = CreateFrame

local WIDTH, HEIGHT = 920, 620

local M = ns:NewModule("Journal", {
    title = L.JOURNAL_TITLE,
    category = "journal",
    description = L.JOURNAL_DESC,
    added = "0.3.0",
    defaults = { enabled = true, sort = "seen", reverse = false, critters = false, groupZones = true, scale = 1, sounds = true,
        collapsed = {}, -- data: the creature list's folded groups (group key -> true)
    },
    options = {
        { key = "sort", type = "dropdown", label = L.JOURNAL_SORT, tooltip = L.JOURNAL_SORT_TIP,
          choices = ns.CreatureFilter.SORTS },
        { key = "critters", type = "checkbox", label = L.JOURNAL_CRITTERS, tooltip = L.JOURNAL_CRITTERS_TIP },
        { key = "groupZones", type = "checkbox", label = L.JOURNAL_GROUP_ZONES, tooltip = L.JOURNAL_GROUP_ZONES_TIP, added = "2.4.0" },
        { key = "scale", type = "slider", label = L.JOURNAL_SCALE, tooltip = L.JOURNAL_SCALE_TIP, added = "2.3.0",
          min = 0.7, max = 1.3, step = 0.05, format = "%.2f" },
        { key = "sounds", type = "checkbox", label = L.JOURNAL_SOUNDS, tooltip = L.JOURNAL_SOUNDS_TIP, added = "2.5.0" },
    },
})

local Journal = { module = M, pages = {} }
ns.Journal = Journal

local window, tabs
local shownPages = {} -- the pages with a tab now, in tab order
local current -- the page shown

function Journal.AddPage(page)
    Journal.pages[#Journal.pages + 1] = page
    table.sort(Journal.pages, function(a, b) return a.order < b.order end)
end

function Journal.IsOpen() return window ~= nil and window:IsShown() end

local function pageNamed(key)
    for _, page in ipairs(Journal.pages) do
        if page.key == key then return page end
    end
end

local function refresh()
    if Journal.IsOpen() and current then ns.ChargedCall(M, "journal page", current.Refresh) end
end

-- Builds a page the first time it's shown: from under the title bar to the window's inner edges
-- (Blizzard's insets: 4 from the left, 6 from the right, 5 from the bottom); its top strip sits
-- right of the portrait and its insets start where the Character window's does (60 down).
-- Widths come from the laid-out frames, so a page draws again once it has its size.
local function frameOf(page)
    if not page.frame then
        page.frame = CreateFrame("Frame", nil, window)
        page.frame:SetPoint("TOPLEFT", 4, -(60 - ns.JournalKit.STRIP))
        page.frame:SetPoint("BOTTOMRIGHT", -6, 5)
        ns.ChargedCall(M, "journal page", page.Build, page.frame)
        page.frame:HookScript("OnSizeChanged", function() M:Soon(refresh) end)
    end
    return page.frame
end
Journal.Refresh = refresh

-- Shows page `key` (its tab picked).
function Journal.Show(key)
    local page = pageNamed(key)
    if not page then return end
    for _, other in ipairs(Journal.pages) do
        if other.frame and other ~= page then other.frame:Hide() end
    end
    current = page
    frameOf(page):Show()
    for i, shown in ipairs(shownPages) do
        if shown == page then tabs.Select(i) end
    end
    refresh()
end

-- The tabs down the window's right edge: one per page whose Shown() allows it, again each time
-- the window opens (Badges' shows only while that module is on).
local function makeTabs()
    shownPages = {}
    for _, page in ipairs(Journal.pages) do
        if not page.Shown or page.Shown() then shownPages[#shownPages + 1] = page end
    end
    tabs.Set(shownPages)
end

local function buildWindow()
    window = CreateFrame("Frame", "ForeverCompendiumJournal", UIParent, "PortraitFrameTemplate")
    window:SetSize(WIDTH, HEIGHT)
    window:SetPoint("CENTER")
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetClampedToScreen(true)
    window:SetTitle(ns.member.title)
    window:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Book_11")
    window:SetScale(M.db.scale)
    tabs = ns.JournalKit.SideTabs(window, function(index) Journal.Show(shownPages[index].key) end)
    tinsert(UISpecialFrames, "ForeverCompendiumJournal")
    window:Hide()
    window:HookScript("OnShow", function()
        ns.Sound("open")
        makeTabs()
        Journal.Show(current and current.key or Journal.pages[1].key)
    end)
    window:HookScript("OnHide", function() ns.Sound("close") end)
end

local function open(key)
    if not M.active then return false end
    if not window then buildWindow() end
    if key then current = pageNamed(key) or current end
    if window:IsShown() then
        if key then Journal.Show(key) end
    else
        window:Show()
    end
    return true
end
Journal.Open = open

function ns.ToggleJournal()
    if not M.active then return ns:OpenSettings(M.name) end
    if window and window:IsShown() then window:Hide() else open() end
end

-- Opens the journal on page `key` and picks what's given there (its Select(...)).
local function openOn(key, ...)
    local page = open(key) and pageNamed(key)
    if page and page.Select then page.Select(...) end
end

-- Opens the journal on creature `npcID` (the tooltips, map pins and banner point here).
function ns.ShowCreature(npcID) openOn("creatures", npcID) end

-- Shows quest `questID`: one in your log in Blizzard's quest log, any other on the creature that
-- gives it (or takes it in), its Quests tab open.
function ns.ShowQuest(questID)
    if C_QuestLog.GetLogIndexForQuestID(questID) then return QuestMapFrame_OpenToQuestDetails(questID) end
    local q = ns.Book.Quest(questID)
    local npc = q and ((q.giver and q.giver.npc) or (q.ender and q.ender.npc))
    if npc and ns.Book.Creature(npc) then openOn("creatures", npc, "quests") end
end

-- Opens the journal on item `itemID`.
function ns.ShowItem(itemID) openOn("items", itemID) end

-- Global for the key binding (Bindings.xml) and the addon compartment.
function ForeverCompendium_ToggleJournal() ns.ToggleJournal() end

-- The Recorder's news: redraw once on the next frame while open.
local REDRAW = { CREATURE_NEW = true, LOOT_NEW = true, QUEST_PLACE = true, QUEST_TITLE = true,
    CREATURE_LEARNED = true, BOOK_MERGED = true, BADGE_EARNED = true, TROPHY = true }
M:OnNews(function(_, event)
    if Journal.IsOpen() and REDRAW[event] then M:Soon(refresh) end
end)

M:AddCommand("journal", nil, L.CMD_JOURNAL, function() ns.ToggleJournal() end)

function M:OnDisable()
    if window then window:Hide() end
end

function M:OnSettingChanged(key)
    if window and key == "scale" then window:SetScale(self.db.scale) end
    refresh()
end

function M:DebugLine()
    if not Journal.IsOpen() then return L.JOURNAL_CLOSED end
    return string.format(L.JOURNAL_DEBUG, current and current.label or "?")
end
