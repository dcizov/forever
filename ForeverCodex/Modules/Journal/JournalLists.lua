--[[
    Forever Codex - Modules/Journal/JournalLists.lua
    The journal's lists, more of JournalKit (ns.JournalKit), drawn as the game's own lists (the
    way Spoken's Azeroth's Compendium draws its): on Blizzard's dark inset, a group is one line,
    the quest log's plus or minus at its left, its name in gold and its count at its right; what
    an open group holds is indented under it, a faint gold line down its left. Over the groups, a
    banner per continent on the quest log's campaign header bar (as the Compendium heads its
    continents), Blizzard's plus or minus on it, its name and how many are under it. Each entry has a
    picture (a round portrait, an icon, or a quest's status mark on a compact line), its name in
    gold, a smaller line under it and a note at its right; the recipe list's light under the
    mouse and on the chosen one, with a gold edge at its left. Rows draw only while in view
    (UI/List.lua).

      * EntryList: such a list. An item with .banner is a banner, one with .header a group's line
        (.inBanner: under a banner); one with .inGroup is drawn under its group's rail.
      * ListPage: the layout the list pages share: the count box in the strip at the top, the
        list's inset on the left with the search box and the filter along its top and its scroll
        bar in the gap right of it, and right of that the band (J.Band: Back and Forward, as the
        quest log heads a quest's details) over the parchment page (p.right).
]]

local _, ns = ...

local CreateFrame, unpack, math = CreateFrame, unpack, math
local J = assert(ns.JournalKit, "JournalLists.lua loads after JournalKit.lua")
local C = J.COLOR

local ROW_HEIGHT, COMPACT_HEIGHT, HEADER_HEIGHT, BANNER_HEIGHT = 44, 22, 24, 36
local INDENT = 16 -- what an open group holds, in from its line
local RAIL_X = 9  -- the rail down an open group, under its plus or minus

---------------------------------------------------------------------------
-- Entry lists
---------------------------------------------------------------------------

local function newHeader(row)
    local head = CreateFrame("Frame", nil, row)
    head:SetAllPoints()
    head.toggle = head:CreateTexture(nil, "ARTWORK")
    head.toggle:SetSize(14, 14)
    head.toggle:SetPoint("LEFT", 2, 0)
    head.name = head:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    head.name:SetPoint("LEFT", head.toggle, "RIGHT", 6, 0)
    head.name:SetPoint("RIGHT", -60, 0)
    head.name:SetJustifyH("LEFT")
    head.name:SetWordWrap(false)
    head.count = head:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    head.count:SetPoint("RIGHT", -8, 0)
    head.count:SetTextColor(unpack(C.share))
    return head
end

-- A banner: the quest log's campaign header bar (Objective-Header-Campaign*, your faction's), as
-- Spoken's Azeroth's Compendium heads its continents. Its left end is its right end turned round
-- (the bar's crest sits half outside its left end and would look cut off); the middle stretches.
-- The bar's pixels in its atlas: the gold bar from 3 to 40 down, its middle from 64 to 250 across.
local BAR_TOP, BAR_BOTTOM, BAR_MIDDLE, BAR_END = 3, 40, 64, 250

local function cut(texture, info, x1, x2, mirror)
    local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
    local u1, u2 = l + (r - l) * x1 / info.width, l + (r - l) * x2 / info.width
    if mirror then u1, u2 = u2, u1 end
    texture:SetTexture(info.file or info.filename)
    texture:SetTexCoord(u1, u2, t + (b - t) * BAR_TOP / info.height, t + (b - t) * BAR_BOTTOM / info.height)
end

local function newBanner(row)
    local banner = CreateFrame("Frame", nil, row)
    banner:SetAllPoints()
    banner.left = banner:CreateTexture(nil, "BACKGROUND")
    banner.middle = banner:CreateTexture(nil, "BACKGROUND")
    banner.right = banner:CreateTexture(nil, "BACKGROUND")
    local atlas = UnitFactionGroup("player") == "Horde" and "Objective-Header-CampaignHorde" or "Objective-Header-CampaignAlliance"
    local info = C_Texture.GetAtlasInfo(atlas)
    if info and info.width and info.width > BAR_END then
        local cap = math.floor((info.width - BAR_END) * BANNER_HEIGHT / (BAR_BOTTOM - BAR_TOP) + 0.5)
        cut(banner.left, info, BAR_END, info.width, true)
        cut(banner.middle, info, BAR_MIDDLE, BAR_END)
        cut(banner.right, info, BAR_END, info.width)
        banner.left:SetPoint("TOPLEFT")
        banner.left:SetSize(cap, BANNER_HEIGHT)
        banner.right:SetPoint("TOPRIGHT")
        banner.right:SetSize(cap, BANNER_HEIGHT)
        banner.middle:SetPoint("TOPLEFT", banner.left, "TOPRIGHT")
        banner.middle:SetPoint("BOTTOMRIGHT", banner.right, "BOTTOMLEFT")
    else
        banner.middle:SetAllPoints()
        banner.middle:SetColorTexture(1, 1, 1, 0.05)
    end
    banner.toggle = banner:CreateTexture(nil, "ARTWORK")
    banner.toggle:SetSize(14, 14)
    banner.toggle:SetPoint("LEFT", 10, -1)
    banner.name = banner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    banner.name:SetPoint("LEFT", 32, -1)
    banner.name:SetPoint("RIGHT", -60, -1)
    banner.name:SetJustifyH("LEFT")
    banner.name:SetWordWrap(false)
    banner.name:SetShadowColor(0, 0, 0, 1)
    banner.name:SetShadowOffset(0, -1)
    banner.count = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    banner.count:SetPoint("RIGHT", -12, -1)
    banner.count:SetTextColor(unpack(C.share))
    return banner
end

local function newEntry(row)
    local entry = CreateFrame("Frame", nil, row)
    entry:SetAllPoints()
    entry.selected = entry:CreateTexture(nil, "BACKGROUND")
    entry.selected:SetAtlas("Professions_Recipe_Hover")
    entry.selected:SetAllPoints()
    entry.edge = entry:CreateTexture(nil, "BORDER")
    entry.edge:SetColorTexture(unpack(C.edge))
    entry.edge:SetWidth(2)
    entry.edge:SetPoint("TOPLEFT")
    entry.edge:SetPoint("BOTTOMLEFT")
    entry.rail = entry:CreateTexture(nil, "BORDER")
    entry.rail:SetColorTexture(unpack(C.rail))
    entry.rail:SetWidth(1)
    entry.rail:SetPoint("TOPLEFT", RAIL_X, 0)
    entry.rail:SetPoint("BOTTOMLEFT", RAIL_X, 0)
    entry.portrait = J.Portrait(entry, 36)
    entry.icon = entry:CreateTexture(nil, "ARTWORK")
    entry.iconBorder = entry:CreateTexture(nil, "OVERLAY")
    entry.iconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
    entry.iconBorder:SetAllPoints(entry.icon)
    entry.favorite = entry:CreateTexture(nil, "OVERLAY", nil, 2)
    entry.favorite:SetAtlas("PetJournal-FavoritesIcon")
    entry.favorite:SetSize(18, 18)
    entry.favorite:SetPoint("TOPLEFT", entry.portrait, "TOPLEFT", -5, 5)
    entry.mark = entry:CreateTexture(nil, "OVERLAY", nil, 3)
    entry.mark:SetSize(16, 16)
    entry.mark:SetPoint("BOTTOMRIGHT", entry.portrait, "BOTTOMRIGHT", 4, -2)
    entry.note = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    entry.note:SetPoint("RIGHT", -8, 0)
    entry.note:SetTextColor(unpack(C.share))
    entry.name = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    entry.name:SetPoint("RIGHT", entry.note, "LEFT", -6, 0)
    entry.name:SetJustifyH("LEFT")
    entry.name:SetWordWrap(false)
    entry.sub = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    entry.sub:SetPoint("TOPLEFT", entry.name, "BOTTOMLEFT", 0, -3)
    entry.sub:SetPoint("RIGHT", entry.note, "LEFT", -6, 0)
    entry.sub:SetJustifyH("LEFT")
    entry.sub:SetWordWrap(false)
    entry.sub:SetTextColor(unpack(C.share))
    return entry
end

-- Lays an entry out: a compact line (a status mark and its name) or a full row (a portrait or
-- an icon, its name and the line under it), in from the left under a group.
local function layOut(entry, compact, left, plainIcon)
    entry.portrait:ClearAllPoints()
    entry.icon:ClearAllPoints()
    entry.name:ClearAllPoints()
    entry.name:SetPoint("RIGHT", entry.note, "LEFT", -6, 0)
    if compact then
        entry.icon:SetSize(14, 14)
        entry.icon:SetPoint("LEFT", left, 0)
        entry.name:SetPoint("LEFT", left + 20, 0)
        entry.name:SetFontObject("GameFontHighlight")
        return
    end
    local size = plainIcon and 22 or 32
    entry.portrait:SetPoint("LEFT", left, 0)
    entry.icon:SetSize(size, size)
    entry.icon:SetPoint("LEFT", left + (36 - size) / 2, 0)
    entry.name:SetPoint("TOPLEFT", left + 44, -7)
    entry.name:SetFontObject("GameFontNormal")
end

-- A list in `parent` (the caller places list.scroll). fill(entry, item) fills an entry: it calls
-- entry.portrait:SetCreature(rec) or sets entry.icon (the other hides; J.SetIcon with
-- entry.plainIcon = true for an atlas or a mark without the item frame), sets entry.name,
-- entry.sub, entry.note, entry.mark and entry.favorite. onClick(item, button) on a click;
-- isSelected(item) marks the chosen one; `compact`: its entries are one line each (quests).
-- Returns the list (UI/List.lua's).
function J.EntryList(parent, fill, onClick, isSelected, compact)
    local function makeRow(content)
        local row = CreateFrame("Button", nil, content)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetHighlightAtlas("Professions_Recipe_Hover", "ADD")
        row.entry = newEntry(row)
        row.head = newHeader(row)
        row.banner = newBanner(row)
        row:SetScript("OnClick", function(self, button) onClick(self.item, button) end)
        return row
    end

    local function fillRow(row, item)
        row.item = item
        local isHead = item.header ~= nil
        row.banner:SetShown(item.banner == true)
        row.head:SetShown(isHead and not item.banner)
        row.entry:SetShown(not isHead)
        if item.banner then
            local banner = row.banner
            banner.toggle:SetTexture(item.collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
            banner.name:SetText(item.name)
            banner.count:SetText(item.count)
            return
        end
        if isHead then
            -- A group under a banner: in from its left, its rail where its creatures' will be.
            row.head.toggle:SetPoint("LEFT", item.inBanner and INDENT - 6 or 2, 0)
            row.head.toggle:SetAtlas(item.collapsed and "ui-questtrackerbutton-secondary-expand"
                or "ui-questtrackerbutton-secondary-collapse")
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
        entry.plainIcon = nil
        entry.name:SetTextColor(unpack(C.gold))
        fill(entry, item)
        local hasIcon = entry.plainIcon or entry.icon:GetTexture() ~= nil
        local left = item.inGroup and INDENT + 4 or 6
        layOut(entry, compact, left, entry.plainIcon)
        entry.rail:SetShown(item.inGroup == true)
        entry.icon:SetShown(hasIcon)
        entry.iconBorder:SetShown(hasIcon and not entry.plainIcon and not compact)
        entry.portrait:SetShown(not hasIcon and not compact)
        entry.sub:SetShown(not compact)
        local chosen = isSelected(item) == true
        entry.selected:SetShown(chosen)
        entry.edge:SetShown(chosen)
    end

    local height = compact and COMPACT_HEIGHT or ROW_HEIGHT
    return ns.List.New(parent, height, makeRow, fillRow,
        function(item) return item.banner and BANNER_HEIGHT or item.header and HEADER_HEIGHT or height end)
end

---------------------------------------------------------------------------
-- The list pages' layout
---------------------------------------------------------------------------

-- The usual page in `frame`: the count box (labelled o.countLabel) in the strip, `sortMenu`'s
-- dropdown at the strip's right (with sortText()), the list's inset on the left (the search
-- box, o.search its hint, onSearch(text); the filter, filterMenu, isDefault(), onReset(); and
-- the Back/Forward band between them), and the parchment page right of it (p.page its inset;
-- p.right the frame on it to lay the page out in). Returns { list, count, search, filter, sort,
-- left, page, right }.
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
    p.filter = J.Dropdown(left, nil, o.filterMenu, true)
    p.filter:SetPoint("TOPRIGHT", left, "TOPRIGHT", -J.INSET, -J.INSET)
    p.filter:SetIsDefaultCallback(o.isDefault)
    p.filter:SetDefaultCallback(o.onReset)
    local searchWidth = math.max(80, left:GetWidth() - (J.INSET * 2 + p.filter:GetWidth() + J.GAP))
    p.search = J.Search(left, searchWidth, o.search, o.onSearch)
    p.search:SetPoint("TOPLEFT", left, "TOPLEFT", J.INSET, -J.INSET)
    p.search:SetPoint("RIGHT", p.filter, "LEFT", -J.GAP, 0)
    p.list = J.EntryList(left, o.fill, o.onClick, o.isSelected, o.compact)
    p.list.scroll:SetPoint("TOPLEFT", 3, -20)
    p.list.scroll:SetPoint("BOTTOMRIGHT", -2, 3)
    p.page, p.right = J.Page(frame)
    p.page:SetPoint("TOPLEFT", left, "TOPRIGHT", J.GAP, 0)
    p.page:SetPoint("BOTTOMRIGHT")
    return p
end

