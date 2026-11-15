--[[
    Forever Tweaks - Dungeon Journal Skin
    Gives DungeonJournal (the ForeverDungeonJournal addon, by Exehn) the look of Forever's own
    windows: the metal frame of PortraitFrameTemplate-style windows on a rock background, marble
    insets, gold titles over white text, and item-quality borders on loot icons. DungeonJournal's
    files are never changed; everything is done from outside, through what it makes public
    (docs/forever-api.md, Other addons):

      * Colours: FDJ.THEMES (UI/ThemeData.lua) is the table Journal.lua reads every colour from when
        it paints (ApplyTheme, row hover, the mode tabs), so its entries are swapped for one neutral
        palette here, and put back when Colours is turned off.
      * Window frame and panels: the main window is ForeverDungeonJournalFrame, made once on
        PLAYER_LOGIN, with its panels as named fields. Their backdrops are cleared (after which
        Blizzard's Backdrop mixin ignores DungeonJournal's colour calls), and Blizzard's NineSlice
        layouts drawn instead. A cleared backdrop can't be put back exactly, so turning these off
        asks to reload.
        The boss and quest lists get the Professions window's list and recipe art, their rows
        the pet list's row art: a picked boss or quest has the pet list's Select frame over a gold
        tint, and any row under the mouse (loot too) the Settings list's softer hover,
        the quest page Blizzard's quest window's look, the Journey bar a little smaller with room
        (Modules/Addons/DungeonJournalPages.lua); the window's search box Blizzard's search box art, and the
        Map / Bosses / Quests buttons lose their oversized icons (DungeonJournal sets those again
        on every redraw but never their alpha).
      * Icon borders: loot rows are pooled children of frame.lootContent, each with .icon and
        .item ({ itemID, ... }). Borders, like the row art, are added after every list refresh
        (each list sets its content frame's height last).
]]

local _, ns = ...
local L = ns.L
local Pages = assert(ns.DungeonJournalPages, "DungeonJournalSkin.lua loads after DungeonJournalPages.lua")
local Restyle = ns.Restyle

local ipairs, pairs, type = ipairs, pairs, type
local C_Item = C_Item

local ADDON = "ForeverDungeonJournal"

local M = ns:NewModule("DungeonJournalSkin", {
    title = L.DJSKIN_TITLE,
    category = "addons",
    description = L.DJSKIN_DESC,
    added = "1.7.0",
    defaults = { frame = true, panels = true, colors = true, icons = true },
    options = {
        { key = "frame", type = "checkbox", label = L.DJSKIN_FRAME, tooltip = L.DJSKIN_FRAME_TIP },
        { key = "panels", type = "checkbox", label = L.DJSKIN_PANELS, tooltip = L.DJSKIN_PANELS_TIP },
        { key = "colors", type = "checkbox", label = L.DJSKIN_COLORS, tooltip = L.DJSKIN_COLORS_TIP },
        { key = "icons", type = "checkbox", label = L.DJSKIN_ICONS, tooltip = L.DJSKIN_ICONS_TIP },
    },
    features = { "frame", "panels", "colors", "icons" },
    addon = ADDON, -- the Tweaks for Addons page shows its section only while it's loaded
})

local function journal() return ns.OtherAddons.Loaded(ADDON) and _G.ForeverDungeonJournal_NS or nil end
local function window() return ns.OtherAddons.Loaded(ADDON) and _G.ForeverDungeonJournalFrame or nil end

local applied = {} -- part key -> true once put into effect this session

---------------------------------------------------------------------------
-- Colours: one palette for every dungeon
---------------------------------------------------------------------------

-- Blizzard's dark window greys, gold for titles (NORMAL_FONT_COLOR) and white text
-- (HIGHLIGHT_FONT_COLOR). Each field is a colour DungeonJournal unpacks into SetBackdropColor or
-- SetTextColor.
local PALETTE = {
    frame = { 0.06, 0.06, 0.06, 0.95 },
    content = { 0.08, 0.08, 0.08, 0.90 },
    header = { 0.10, 0.10, 0.10, 0.92 },
    left = { 0.08, 0.08, 0.08, 0.92 },
    right = { 0.08, 0.08, 0.08, 0.92 },
    row = { 0.12, 0.12, 0.12, 0.90 },
    lootRow = { 0.12, 0.12, 0.12, 0.90 },
    rowSelected = { 0.30, 0.24, 0.08, 0.95 },
    border = { 0.50, 0.50, 0.50, 1 },
    title = { 1, 0.82, 0 },
    text = { 1, 1, 1 },
    muted = { 0.75, 0.75, 0.75 },
}

-- With Panels on, rows have the pet list's art (skinLists below): their own fill and edge go
-- clear, and a picked or hovered row is a gold wash over the art.
local OVER_ART = {
    row = { 0, 0, 0, 0 },
    lootRow = { 0, 0, 0, 0 },
    border = { 0, 0, 0, 0 },
    rowSelected = { 1, 0.82, 0, 0.22 },
}

local original = {} -- theme table -> { field = its own colour }

-- Writes the palette into every theme (over the art while Panels is on or still in effect),
-- remembering each theme's own colours the first time. Again whenever Panels changes.
local function applyColors(fdj)
    if type(fdj.THEMES) ~= "table" then return end
    local overArt = M.db.panels or applied.panels
    for _, theme in pairs(fdj.THEMES) do
        if type(theme) == "table" then
            -- Some dungeons share one theme table (the Scarlet Monastery wings): kept once.
            if not original[theme] then
                local kept = {}
                for field in pairs(PALETTE) do kept[field] = theme[field] end
                original[theme] = kept
            end
            for field, color in pairs(PALETTE) do theme[field] = overArt and OVER_ART[field] or color end
        end
    end
    applied.colors = true
end

local function restoreColors()
    for theme, kept in pairs(original) do
        for field in pairs(PALETTE) do theme[field] = kept[field] end
    end
    original = {}
    applied.colors = nil
end

---------------------------------------------------------------------------
-- Window frame: the metal border, rock background, title bar and close button
---------------------------------------------------------------------------

local BORDER_LIFT = 10 -- the metal title bar sits this far above the window, clear of its search box
local SEARCH_HEIGHT = 22
local border

-- The search box in SearchBoxTemplate's art (common-search-border-*), centred on the height of
-- the Report and language buttons beside it.
local function skinSearch(frame)
    local box = frame.searchEditBox
    if not box then return end
    box:ClearBackdrop()
    box:SetHeight(SEARCH_HEIGHT)
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -16)
    local left = box:CreateTexture(nil, "BACKGROUND")
    left:SetAtlas("common-search-border-left")
    left:SetWidth(8)
    left:SetPoint("TOPLEFT", -5, 0)
    left:SetPoint("BOTTOMLEFT", -5, 0)
    local right = box:CreateTexture(nil, "BACKGROUND")
    right:SetAtlas("common-search-border-right")
    right:SetWidth(8)
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    local middle = box:CreateTexture(nil, "BACKGROUND")
    middle:SetAtlas("common-search-border-middle")
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
end

-- The Map, Bosses and Quests buttons: Blizzard's red buttons without DungeonJournal's oversized
-- icons (the skull is a raid marker), their labels centred again whenever it moves them.
local MODE_BUTTONS = { "bossesTab", "questsTab", "mapTab" }
local centering = false

local function centerLabel(_, text)
    if centering then return end
    centering = true
    text:ClearAllPoints()
    text:SetPoint("CENTER", text:GetParent(), "CENTER", 0, 0)
    centering = false
end

local function plainModeButtons(frame)
    for _, key in ipairs(MODE_BUTTONS) do
        local button = frame[key]
        if button then
            if button.fdjIcon then button.fdjIcon:SetAlpha(0) end
            if button.fdjIconBorder then button.fdjIconBorder:SetAlpha(0) end
            if button.text then
                M:Hook(button.text, "SetPoint", centerLabel)
                centerLabel(nil, button.text)
            end
        end
    end
end

local function skinFrame(frame)
    for _, key in ipairs({ "topStrip", "topStripLine", "topStripBottomLine" }) do
        if frame[key] then frame[key]:Hide() end
    end
    border = Restyle.Window(frame, "ButtonFrameTemplateNoPortrait", BORDER_LIFT)

    if frame.mainTitle then
        frame.mainTitle:SetParent(border)
        frame.mainTitle:SetDrawLayer("OVERLAY", 7)
        frame.mainTitle:ClearAllPoints()
        frame.mainTitle:SetPoint("TOP", border, "TOP", 0, -5)
    end
    if frame.closeButton then
        frame.closeButton:ClearAllPoints()
        frame.closeButton:SetPoint("TOPRIGHT", border, "TOPRIGHT", 1, 0)
        frame.closeButton:SetFrameLevel(border:GetFrameLevel() + 1)
    end
    skinSearch(frame)
    applied.frame = true
end

---------------------------------------------------------------------------
-- Panels: Blizzard's inset (marble with an inner edge) in place of each coloured box
---------------------------------------------------------------------------

-- Each panel, the parchment wash DungeonJournal lays over it, and its art: the boss and quest
-- lists the Professions window's recipe list, the pages beside them its recipe page, the rest
-- the inset's marble. The quest text's parchment (questTextInset) is left alone: it's the quest
-- frame's own look.
local LIST_ART, PAGE_ART = "Professions-background-summarylist", "Professions-Recipe-Background"
local PANELS = {
    { "contentPanel", "contentParchment" }, { "headerPanel", "headerParchment" },
    { "leftPanel", "leftParchment", LIST_ART }, { "rightPanel", "rightParchment", PAGE_ART },
    { "questLeftPanel", "questLeftParchment", LIST_ART }, { "questRightPanel", "questRightParchment", PAGE_ART },
    { "homePanel", "homeParchment" },
}

local function skinPanels(frame)
    for _, pair in ipairs(PANELS) do
        local panel, parchment = frame[pair[1]], frame[pair[2]]
        if panel then Restyle.Inset(panel, pair[3]) end
        if parchment then parchment:Hide() end
    end
    Pages.SkinQuestPage(M, frame, journal())
    applied.panels = true
end

---------------------------------------------------------------------------
-- The lists: row art and icon borders
---------------------------------------------------------------------------

local LISTS = { "bossContent", "questContent", "lootContent" } -- each list's pooled rows' parent
local iconBorder = setmetatable({}, { __mode = "k" }) -- loot row -> its border
local rowArt = setmetatable({}, { __mode = "k" })     -- row -> the pet list's row art behind it

-- A picked boss or quest row: the pet list's Select frame over a gold tint.
local rowPicked = setmetatable({}, { __mode = "k" })  -- boss or quest row -> { frame, tint }

-- DungeonJournal marks a picked boss or quest by filling its row with rowSelected (the
-- palette's, part clear), and a hovered loot row with the same colour at full alpha. Its fill
-- (Center, the Backdrop mixin's fill) is hidden again after every colour it gets. A boss or
-- quest row with a fill is the picked one; a loot row is never picked (its hover is the
-- highlight, as every row's is), so its fill shows nothing.
local function onRowColor(_, row, _, _, _, alpha)
    if row.Center then row.Center:Hide() end
    local picked = rowPicked[row]
    if not picked then return end
    local shown = (alpha or 1) > 0.05
    picked.frame:SetShown(shown)
    picked.tint:SetShown(shown)
end

-- The row art's right edge: a list's rows are wider than the scroll frame showing them (the boss
-- list's 315 px in a narrower frame), so the art stops where the frame cuts the row off.
local function placeArt(texture, row, content)
    local scroll = content:GetParent()
    local overflow = math.max(0, content:GetWidth() - scroll:GetWidth())
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", row, "TOPLEFT")
    texture:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -overflow, 0)
end

-- Every row lights softly under the mouse (the Settings list's hover); `canPick`: a boss or quest
-- row, which also gets the picked look.
local function addRowArt(row, content, canPick)
    if rowArt[row] or not row.SetBackdropColor then return end
    local art = row:CreateTexture(nil, "BACKGROUND", nil, -8)
    art:SetAtlas("PetList-ButtonBackground")
    placeArt(art, row, content)
    rowArt[row] = art
    if canPick then
        local tint = row:CreateTexture(nil, "BACKGROUND", nil, -7)
        tint:SetColorTexture(1, 0.82, 0, 0.18) -- gold (NORMAL_FONT_COLOR), faint
        placeArt(tint, row, content)
        tint:Hide()
        local frame = row:CreateTexture(nil, "BACKGROUND", nil, -6)
        frame:SetAtlas("PetList-ButtonSelect")
        placeArt(frame, row, content)
        frame:Hide()
        rowPicked[row] = { frame = frame, tint = tint }
    end
    if row.SetHighlightAtlas then
        row:SetHighlightAtlas("Options_List_Hover", "ADD")
        placeArt(row:GetHighlightTexture(), row, content)
    end
    if row.Center then row.Center:Hide() end
    M:Hook(row, "SetBackdropColor", onRowColor)
end

local function paintRow(row)
    local item = row.item
    local quality = type(item) == "table" and item[1] and C_Item.GetItemQualityByID(item[1]) or nil
    local shown = M.active and M.db.icons and row:IsShown() and quality ~= nil
    local b = iconBorder[row]
    if not b then
        if not shown then return end
        b = row:CreateTexture(nil, "OVERLAY")
        b:SetTexture("Interface\\Common\\WhiteIconFrame")
        b:SetAllPoints(row.icon)
        iconBorder[row] = b
    end
    if shown then
        local r, g, bl = C_Item.GetItemQualityColor(quality) -- (its fourth return is the hex code)
        b:SetVertexColor(r, g, bl)
    end
    b:SetShown(shown)
end

-- Every list's rows: their art (Panels) and the loot icons' borders (Icon Borders); and the
-- mode buttons' icons, which DungeonJournal may make after the window was skinned.
local function paintLists()
    local frame = window()
    if not frame then return end
    if applied.frame then
        plainModeButtons(frame)
        Pages.SkinJourneyBar(M, frame)
    end
    for _, key in ipairs(LISTS) do
        local content = frame[key]
        for _, child in ipairs(content and { content:GetChildren() } or {}) do
            if applied.panels then addRowArt(child, content, key ~= "lootContent") end
            local isLootRow = child.icon and child.slot and child.item ~= nil
            if isLootRow or iconBorder[child] then paintRow(child) end
        end
    end
end

local function requestPaintLists() M:Soon(paintLists) end

-- Once: after each list refresh, and when the window opens.
local function hookLists(frame)
    for _, key in ipairs(LISTS) do
        if frame[key] then M:Hook(frame[key], "SetHeight", requestPaintLists) end
    end
    -- The home page's cards: RPG Mode's Journey bar is made when they're drawn.
    if frame.homeCardsContent then M:Hook(frame.homeCardsContent, "SetHeight", requestPaintLists) end
    M:HookScript(frame, "OnShow", requestPaintLists)
end

---------------------------------------------------------------------------
-- Putting it into effect
---------------------------------------------------------------------------

-- Every part that's ticked and not in effect yet, once the window exists.
local function skinWindow()
    local frame = window()
    if not frame then return end
    if M.db.frame and not applied.frame then skinFrame(frame) end
    if M.db.panels and not applied.panels then skinPanels(frame) end
    applied.icons = M.db.icons or nil
    hookLists(frame)
    requestPaintLists()
end

local function askReload()
    ns:Confirm(M, "DJSKIN_RELOAD", L.DJSKIN_RELOAD, ReloadUI)
end

function M:OnEnable()
    local fdj = journal()
    if not fdj then return end
    if self.db.colors then applyColors(fdj) end
    if self.db.frame then Pages.MoveJourneyBar(fdj) end
    -- DungeonJournal makes its window in its own PLAYER_LOGIN handler, which may run after ours
    -- (OnEnable runs inside our PLAYER_LOGIN): look now, and again on the next frame.
    skinWindow()
    self:Soon(skinWindow)
end

function M:OnDisable()
    restoreColors()
    paintLists()
    if applied.frame or applied.panels then askReload() end
end

-- Colors and Icon Borders go on and off live; Frame and Panels go on live, and off at a reload.
function M:OnSettingChanged(key, value)
    local fdj = journal()
    if key == "colors" then
        if value and fdj then applyColors(fdj) elseif not value then restoreColors() end
    elseif key == "icons" then
        applied.icons = value or nil
        paintLists()
    else
        -- The palette is drawn over the row art while Panels is on.
        if key == "panels" and self.db.colors and fdj then applyColors(fdj) end
        if value then skinWindow() elseif applied[key] then askReload() end
    end
end

function M:DebugLine()
    if not journal() then return L.DJSKIN_MISSING end
    local parts = {}
    for _, key in ipairs(self.features) do
        if applied[key] then parts[#parts + 1] = key end
    end
    return #parts > 0 and table.concat(parts, ", ") or L.DJSKIN_WAITING
end
