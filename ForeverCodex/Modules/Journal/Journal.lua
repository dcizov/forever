--[[
    Forever Codex - Journal
    The journal window (/codex, the minimap button, or a key you bind): what the Recorder learned, in
    the look of the game's own books, as Spoken's Azeroth's Compendium has it (JournalKit.lua:
    Blizzard's portrait window, lists on its dark insets, pages on the spellbook's parchment),
    with Blizzard's panel tabs along its foot, one per page:

      * Creatures (Modules/Journal/CreaturesPage.lua): every creature you could fight, by zone,
        searched, filtered and sorted, with its model, what's known of it, its loot, quest
        rewards, quests and your note.
      * NPCs (NpcsPage.lua): the friendly NPCs you dealt with: what for, where, what they sell,
        their quests.
      * Items (ItemsPage.lua): every item, and who drops, sells or gives it.
      * Trophies (TrophiesPage.lua): the rares and bosses met, and which you've defeated.
      * Badges (Modules/Social/BadgesPage.lua, while Badges is on): milestones.
    Everything a page names opens where it's described (ns.ShowCreature, ShowItem; JournalLines'
    J.Link), a quest where it's best read (ns.ShowQuest: the quest log, Spoken's Azeroth's
    Codex, or the journal's quest page, QuestPage.lua), and Shift-click puts a quest or item
    in chat.
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
        fade = true, fadeAlpha = 50, openOn = "last",
        collapsed = {}, -- data: the creature list's folded groups (group key -> true)
        npcsCollapsed = {}, -- data: the NPC list's folded groups
    },
    options = {
        { key = "openOn", type = "dropdown", label = L.JOURNAL_OPEN_ON, tooltip = L.JOURNAL_OPEN_ON_TIP, added = "3.3.0",
          choices = { { "last", L.JOURNAL_OPEN_LAST }, { "zone", L.JOURNAL_OPEN_ZONE }, { "pinned", L.JOURNAL_OPEN_PINNED } } },
        { key = "sort", type = "dropdown", label = L.JOURNAL_SORT, tooltip = L.JOURNAL_SORT_TIP,
          choices = ns.CreatureFilter.SORTS },
        { key = "critters", type = "checkbox", label = L.JOURNAL_CRITTERS, tooltip = L.JOURNAL_CRITTERS_TIP },
        { key = "groupZones", type = "checkbox", label = L.JOURNAL_GROUP_ZONES, tooltip = L.JOURNAL_GROUP_ZONES_TIP, added = "2.4.0" },
        { key = "scale", type = "slider", label = L.JOURNAL_SCALE, tooltip = L.JOURNAL_SCALE_TIP, added = "2.3.0",
          min = 0.7, max = 1.3, step = 0.05, format = "%.2f" },
        { key = "sounds", type = "checkbox", label = L.JOURNAL_SOUNDS, tooltip = L.JOURNAL_SOUNDS_TIP, added = "2.5.0" },
        { key = "fade", type = "checkbox", label = L.JOURNAL_FADE, tooltip = L.JOURNAL_FADE_TIP, slider = "fadeAlpha",
          added = "3.2.0" },
        { key = "fadeAlpha", type = "slider", label = L.JOURNAL_FADE_ALPHA, tooltip = L.JOURNAL_FADE_ALPHA_TIP,
          min = 10, max = 90, step = 5, format = "%d%%", requires = "fade", added = "3.2.0" },
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
        page.frame:SetPoint("TOPLEFT", 4, -32)
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
    window = CreateFrame("Frame", "ForeverCodexJournal", UIParent, "PortraitFrameTemplate")
    Journal.FadeWhileMoving(window)
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
    window:SetPortraitToAsset(ns.icon) -- the addon's own book, as the settings window and minimap button
    window:SetScale(M.db.scale)
    tabs = ns.JournalKit.Tabs(window, function(index) Journal.Show(shownPages[index].key) end)
    tinsert(UISpecialFrames, "ForeverCodexJournal")
    window:Hide()
    window:HookScript("OnShow", function()
        ns.Sound("open")
        makeTabs()
        Journal.Show(current and current.key or Journal.pages[1].key)
    end)
    window:HookScript("OnHide", function()
        ns.Sound("close")
        ns.JournalKit.ClearSearches() -- each opening starts with the whole list
    end)
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

-- Opens it where Open On says: where you left it, or on the Creatures page at your zone's
-- creatures or the first pinned one (CreaturesPage.lua's SelectStart), when there's one.
local function openAtStart()
    local mode = M.db.openOn
    if not open() or mode == "last" then return end
    local creatures = pageNamed("creatures")
    if not (creatures and creatures.SelectStart) then return end
    local previous = current
    Journal.Show("creatures")
    if not creatures.SelectStart(mode) and previous and previous ~= creatures then Journal.Show(previous.key) end
end

function ns.ToggleJournal()
    if not M.active then return ns:OpenSettings(M.name) end
    if window and window:IsShown() then window:Hide() else openAtStart() end
end

-- Opens the journal on page `key` and picks what's given there (its Select(...)).
local function openOn(key, ...)
    local page = open(key) and pageNamed(key)
    if page and page.Select then page.Select(...) end
end

---------------------------------------------------------------------------
-- What you opened, in order: Back and Forward in the band over the page (JournalLists.lua)
---------------------------------------------------------------------------

local MOST_VISITS = 50
local visits, at, stepping = {}, 0, false

-- Page `key` shows `id` now because you opened it (a click, a link): remembered for Back. What
-- Back and Forward open isn't remembered again; going somewhere new after Back drops what was ahead.
function Journal.Visit(key, id)
    if stepping or id == nil then return end
    local last = visits[at]
    if last and last.key == key and last.id == id then return end
    for i = #visits, at + 1, -1 do visits[i] = nil end
    visits[#visits + 1] = { key = key, id = id }
    if #visits > MOST_VISITS then table.remove(visits, 1) end
    at = #visits
end

function Journal.CanBack() return at > 1 end
function Journal.CanForward() return at < #visits end

local function step(by)
    local visit = visits[at + by]
    if not visit then return end
    at = at + by
    stepping = true
    ns.ChargedCall(M, "journal back", openOn, visit.key, visit.id)
    stepping = false
end

function Journal.Back() step(-1) end
function Journal.Forward() step(1) end

-- Opens the journal on creature `npcID` (the tooltips, map pins and banner point here): an NPC
-- on the NPCs page, any other on the Creatures page.
function ns.ShowCreature(npcID, part)
    local rec = ns.Book.Creature(npcID)
    if rec and ns.Book.IsNpc(rec) then return openOn("npcs", npcID) end
    openOn("creatures", npcID, part)
end

-- Shows quest `questID` where it's best read: Blizzard's quest log while it's in your log (Spoken
-- puts its button there), else Spoken's Azeroth's Compendium when it has the quest's words
-- (Lib/Spoken.lua), else the journal's own quest page (QuestPage.lua).
function ns.ShowQuest(questID)
    if C_QuestLog.GetLogIndexForQuestID(questID) then return QuestMapFrame_OpenToQuestDetails(questID) end
    if ns.Spoken.HasLore(questID) then return ns.Spoken.Open(questID) end
    ns.QuestPage.Open(questID)
end

-- Opens the journal on item `itemID`.
function ns.ShowItem(itemID) openOn("items", itemID) end

-- Global for the key binding (Bindings.xml) and the addon compartment.
function ForeverCodex_ToggleJournal() ns.ToggleJournal() end

-- The Recorder's news: redraw once on the next frame while open.
local REDRAW = { CREATURE_NEW = true, LOOT_NEW = true, QUEST_PLACE = true, QUEST_TITLE = true,
    CREATURE_LEARNED = true, BOOK_MERGED = true, BADGE_EARNED = true, TROPHY = true }
-- What changes which quests are discovered (Lib/QuestIndex.lua) makes its list again.
local QUESTS_CHANGED = { QUEST_PLACE = true, QUEST_TITLE = true, BOOK_MERGED = true, QUEST_FOUND = true }
M:OnNews(function(_, event)
    if QUESTS_CHANGED[event] then ns.QuestIndex.Forget(event == "BOOK_MERGED") end
    if Journal.IsOpen() and (REDRAW[event] or QUESTS_CHANGED[event]) then M:Soon(refresh) end
end)

M:AddCommand("journal", nil, L.CMD_JOURNAL, function() ns.ToggleJournal() end)

-- Quests taken, given up and turned in change where they stand: redraw while open.
---------------------------------------------------------------------------
-- Fading while you move: the journal, its quest window and the settings window go to Fade
-- While Moving's opacity as you start moving (as the game's own map does), and back when you
-- stop or point at one.
---------------------------------------------------------------------------

local faded = {} -- the windows that fade (Journal.FadeWhileMoving)
local HOVER_EVERY = 0.1 -- seconds between looks at where the mouse is while moving
local moving, hoverTicker = false, nil

local function applyFade()
    local fading = moving and M.db.fade
    for _, frame in ipairs(faded) do
        if frame:IsShown() then frame:SetAlpha(fading and not frame:IsMouseOver() and M.db.fadeAlpha / 100 or 1) end
    end
end

-- A window that fades while you move with the journal (made once: the journal's, its quest
-- window's, the settings window's).
function Journal.FadeWhileMoving(frame)
    faded[#faded + 1] = frame
    if moving then applyFade() end
end

local function setMoving(now)
    moving = now
    M:CancelTimer(hoverTicker)
    hoverTicker = now and M.db.fade and M:NewTicker(HOVER_EVERY, applyFade) or nil
    applyFade()
end

function M:OnEnable()
    for _, event in ipairs({ "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN" }) do
        self:RegisterEvent(event, function()
            ns.QuestIndex.Forget()
            if Journal.IsOpen() then M:Soon(refresh) end
        end)
    end
    self:RegisterEvent("PLAYER_STARTED_MOVING", function() setMoving(true) end)
    self:RegisterEvent("PLAYER_STOPPED_MOVING", function() setMoving(false) end)
    moving = IsPlayerMoving() == true
end

function M:OnDisable()
    moving = false
    applyFade()
    if window then window:Hide() end
end

function M:OnSettingChanged(key)
    if window and key == "scale" then window:SetScale(self.db.scale) end
    if key == "fade" or key == "fadeAlpha" then setMoving(moving) end
    refresh()
end

function M:DebugLine()
    if not Journal.IsOpen() then return L.JOURNAL_CLOSED end
    return string.format(L.JOURNAL_DEBUG, current and current.label or "?")
end
