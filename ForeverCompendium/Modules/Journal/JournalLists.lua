--[[
    Forever Compendium - Modules/Journal/JournalLists.lua
    The journal's lists, more of JournalKit (ns.JournalKit):

      * EntryList: the Mount Journal's list. Each entry is one of Blizzard's journal rows
        (PetList-ButtonBackground, its select and highlight art): a picture at the left (a
        round portrait, or an icon), its name and a smaller line under it, a note at the right,
        and the Collections favourite star on the picture for a pinned one. An item with .header
        is a folding group header in the Professions window's look instead (its arrow, name and
        count). Rows draw only while in view (Forever Core's UI/List.lua).
      * ListPage: the layout the list pages share, the Collections window's: the count box in
        the strip at the top, the list's inset on the left with the search box and the filter
        along its top and its scroll bar in the gap right of it, and the room right of that for
        the page's own insets.
]]

local _, ns = ...

local CreateFrame = CreateFrame
local J = assert(ns.JournalKit, "JournalLists.lua loads after JournalKit.lua")

local ROW_HEIGHT, HEADER_HEIGHT = 46, 28

---------------------------------------------------------------------------
-- Entry lists
---------------------------------------------------------------------------

local function newHeader(row)
    local head = CreateFrame("Frame", nil, row)
    head:SetPoint("TOPLEFT", 0, -2)
    head:SetPoint("BOTTOMRIGHT", 0, 0)
    local left = head:CreateTexture(nil, "BACKGROUND")
    left:SetAtlas("Professions-recipe-header-left", true)
    left:SetPoint("LEFT")
    local right = head:CreateTexture(nil, "BACKGROUND")
    right:SetAtlas("Professions-recipe-header-right", true)
    right:SetPoint("RIGHT")
    local middle = head:CreateTexture(nil, "BACKGROUND")
    middle:SetAtlas("Professions-recipe-header-middle")
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    head.arrow = head:CreateTexture(nil, "ARTWORK")
    head.arrow:SetSize(14, 10)
    head.arrow:SetPoint("LEFT", 10, 0)
    head.name = head:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    head.name:SetPoint("LEFT", head.arrow, "RIGHT", 7, 0)
    head.name:SetPoint("RIGHT", -40, 0)
    head.name:SetJustifyH("LEFT")
    head.name:SetWordWrap(false)
    head.count = head:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    head.count:SetPoint("RIGHT", -12, 0)
    return head
end

local function newEntry(row)
    local entry = CreateFrame("Frame", nil, row)
    entry:SetAllPoints()
    entry.bg = entry:CreateTexture(nil, "BACKGROUND")
    entry.bg:SetAtlas("PetList-ButtonBackground")
    entry.bg:SetAllPoints()
    entry.selected = entry:CreateTexture(nil, "BORDER")
    entry.selected:SetAtlas("PetList-ButtonSelect")
    entry.selected:SetAllPoints()
    entry.portrait = J.Portrait(entry, 40)
    entry.portrait:SetPoint("LEFT", 3, 0)
    entry.icon = entry:CreateTexture(nil, "ARTWORK")
    entry.icon:SetSize(34, 34)
    entry.icon:SetPoint("LEFT", 6, 0)
    entry.iconBorder = entry:CreateTexture(nil, "OVERLAY")
    entry.iconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
    entry.iconBorder:SetAllPoints(entry.icon)
    entry.favorite = entry:CreateTexture(nil, "OVERLAY", nil, 2)
    entry.favorite:SetAtlas("PetJournal-FavoritesIcon", true)
    entry.favorite:SetPoint("TOPLEFT", -4, 4)
    entry.mark = entry:CreateTexture(nil, "OVERLAY", nil, 3)
    entry.mark:SetSize(18, 18)
    entry.mark:SetPoint("BOTTOMLEFT", entry.portrait, "BOTTOMRIGHT", -14, -2)
    entry.note = entry:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    entry.note:SetPoint("RIGHT", -10, 0)
    entry.name = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    entry.name:SetPoint("TOPLEFT", 52, -8)
    entry.name:SetPoint("RIGHT", entry.note, "LEFT", -6, 0)
    entry.name:SetJustifyH("LEFT")
    entry.name:SetWordWrap(false)
    entry.sub = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    entry.sub:SetPoint("TOPLEFT", entry.name, "BOTTOMLEFT", 0, -4)
    entry.sub:SetPoint("RIGHT", entry.note, "LEFT", -6, 0)
    entry.sub:SetJustifyH("LEFT")
    entry.sub:SetWordWrap(false)
    return entry
end

-- A list in `parent` (the caller places list.scroll). fill(entry, item) fills an entry: it calls
-- entry.portrait:SetCreature(rec) or sets entry.icon (the other hides), sets entry.name,
-- entry.sub, entry.note, entry.mark and entry.favorite. onClick(item, button) on a click;
-- isSelected(item) marks the chosen one. Returns the list (UI/List.lua's).
function J.EntryList(parent, fill, onClick, isSelected)
    local function makeRow(content)
        local row = CreateFrame("Button", nil, content)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetHighlightAtlas("PetList-ButtonHighlight", "ADD")
        row.entry = newEntry(row)
        row.head = newHeader(row)
        row:SetScript("OnClick", function(self, button) onClick(self.item, button) end)
        return row
    end

    local function fillRow(row, item)
        row.item = item
        local isHead = item.header ~= nil
        row.head:SetShown(isHead)
        row.entry:SetShown(not isHead)
        local hl = row:GetHighlightTexture()
        if hl then hl:SetAlpha(isHead and 0 or 1) end
        if isHead then
            row.head.arrow:SetAtlas(item.collapsed and "Professions-recipe-header-expand" or "Professions-recipe-header-collapse")
            row.head.name:SetText(item.name)
            row.head.count:SetText(item.count)
            return
        end
        local entry = row.entry
        entry.icon:SetTexture(nil)
        entry.mark:SetTexture(nil)
        entry.note:SetText("")
        entry.sub:SetText("")
        entry.favorite:Hide()
        fill(entry, item)
        local hasIcon = entry.icon:GetTexture() ~= nil
        entry.icon:SetShown(hasIcon)
        entry.iconBorder:SetShown(hasIcon)
        entry.portrait:SetShown(not hasIcon)
        entry.selected:SetShown(isSelected(item) == true)
    end

    return ns.List.New(parent, ROW_HEIGHT, makeRow, fillRow,
        function(item) return item.header and HEADER_HEIGHT or ROW_HEIGHT end)
end

---------------------------------------------------------------------------
-- The list pages' layout
---------------------------------------------------------------------------

-- The usual page in `frame`: the count box (labelled o.countLabel) in the strip, `sortMenu`'s
-- dropdown at the strip's right (with sortText()), the list's inset on the left (the search
-- box, o.search its hint, onSearch(text); the filter, filterMenu, isDefault(), onReset();
-- EntryList's fill, onClick, isSelected), and the room right of it (p.right, a plain frame
-- for the page's insets). Returns { list, count, search, filter, sort, left, right }.
function J.ListPage(frame, o)
    local p = {}
    p.count = J.CountBox(frame, o.countLabel)
    p.count:SetPoint("LEFT", frame, "TOPLEFT", J.PORTRAIT, -J.STRIP / 2 + 2)
    if o.sortMenu then
        p.sort = J.Dropdown(frame, 150, o.sortMenu)
        p.sort:SetPoint("RIGHT", frame, "TOPRIGHT", -2, -J.STRIP / 2 + 2)
        p.sort:SetSelectionText(o.sortText)
    end
    local left = J.Inset(frame)
    left:SetPoint("TOPLEFT", 0, -J.STRIP)
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(J.LIST_WIDTH)
    p.left = left
    p.filter = J.Dropdown(left, 90, o.filterMenu, true)
    p.filter:SetPoint("TOPRIGHT", -5, -10)
    p.filter:SetIsDefaultCallback(o.isDefault)
    p.filter:SetDefaultCallback(o.onReset)
    p.search = J.Search(left, 145, o.search, o.onSearch)
    p.search:SetPoint("TOPLEFT", 15, -9)
    p.search:SetPoint("RIGHT", p.filter, "LEFT", -8, 0)
    p.list = J.EntryList(left, o.fill, o.onClick, o.isSelected)
    p.list.scroll:SetPoint("TOPLEFT", 3, -36)
    p.list.scroll:SetPoint("BOTTOMRIGHT", -2, 3)
    p.right = CreateFrame("Frame", nil, frame)
    p.right:SetPoint("TOPLEFT", left, "TOPRIGHT", J.GAP, 0)
    p.right:SetPoint("BOTTOMRIGHT")
    return p
end
