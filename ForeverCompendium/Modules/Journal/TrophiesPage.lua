--[[
    Forever Compendium - Modules/Journal/TrophiesPage.lua
    The journal's Trophies page, laid out like the Toy Box on the Collections page's background:
    every boss, rare and elite the Recorder met (CreatureFilter.RankOf).

      * At the top, a tile for each kind: its mark, how many of those met you've defeated, and
        Blizzard's collection progress bar.
      * Under them the trophies, under a header for each zone (CreatureFilter.GroupOf), bosses
        first, then rares, then elites: a defeated one shows its portrait in colour with how
        often you beat it and when first; one not yet defeated is greyed.
    The strip's count box says how many you've defeated in all; its filter keeps one kind, or
    defeated ones, or the rest. Click a trophy for the creature's page.
]]

local _, ns = ...
local L = ns.L

local ipairs, pairs, next, format, math, table = ipairs, pairs, next, string.format, math, table
local CreateFrame = CreateFrame
local Book, Text, J, Journal, Filter = ns.Book, ns.JournalText, ns.JournalKit, ns.Journal, ns.CreatureFilter

local CARD_W, CARD_H, GAP, HEAD_H = 196, 60, 6, 30
local TILES_H = 74
local KINDS = {
    { key = "boss", label = L.TROPHY_BOSSES, atlas = "VignetteKillElite" },
    { key = "rare", label = L.TROPHY_RARES, atlas = "VignetteKill" },
    { key = "elite", label = L.TROPHY_ELITES, atlas = "nameplates-icon-elite-gold" },
}
local KIND_ATLAS, KIND_ORDER = {}, {}
for i, kind in ipairs(KINDS) do KIND_ATLAS[kind.key], KIND_ORDER[kind.key] = kind.atlas, i end

local page = { key = "trophies", label = L.JOURNAL_TAB_TROPHIES, icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01", order = 35 }
local cards, heads, tiles = {}, {}, {}
local summary, scroll, content, filterButton
local shown = {} -- filter: kind ("boss", "rare", "elite") and state ("won", "open") -> true while kept

local function defeated(rec) return (rec.kills or 0) > 0 end

-- The trophies to show, by zone (zones by name, the unknown place last); in each, bosses, rares
-- and elites, the latest defeated first, then by name. Also how many of each kind there are and
-- how many you've defeated: counts[kind] = { won, total }.
local function trophies()
    local zones, byKey, counts = {}, {}, {}
    for _, kind in ipairs(KINDS) do counts[kind.key] = { won = 0, total = 0 } end
    for npcID, rec in pairs(Book.Creatures()) do
        local kind = Filter.RankOf(rec)
        local count = counts[kind]
        if count then
            count.total = count.total + 1
            if defeated(rec) then count.won = count.won + 1 end
            local kindOk = not (shown.boss or shown.rare or shown.elite) or shown[kind]
            local stateOk = not (shown.won or shown.open) or shown[defeated(rec) and "won" or "open"]
            if kindOk and stateOk then
                local key, name = Filter.GroupOf(rec)
                local zone = byKey[key]
                if not zone then
                    zone = { key = key, name = name, list = {} }
                    byKey[key] = zone
                    zones[#zones + 1] = zone
                end
                zone.list[#zone.list + 1] = { npcID = npcID, rec = rec, kind = kind }
            end
        end
    end
    table.sort(zones, function(a, b)
        if (a.key == "none") ~= (b.key == "none") then return b.key == "none" end
        return a.name < b.name
    end)
    for _, zone in ipairs(zones) do
        table.sort(zone.list, function(a, b)
            if a.kind ~= b.kind then return KIND_ORDER[a.kind] < KIND_ORDER[b.kind] end
            local x, y = a.rec.lastKill or 0, b.rec.lastKill or 0
            if x ~= y then return x > y end
            return (a.rec.name or "") < (b.rec.name or "")
        end)
    end
    return zones, counts
end

local function cardTip(card)
    local rec = Book.Creature(card.npcID)
    if not rec then return end
    J.Tip(card, rec.name, Text.Kind(rec), Text.Where(rec),
        defeated(rec) and format(L.TROPHY_KILLS, rec.kills) or L.TROPHY_OPEN,
        rec.firstKill and format(L.TROPHY_FIRST, Text.Date(rec.firstKill)) or nil,
        { L.TROPHY_HINT, 0.1, 1, 0.1 })
end

---------------------------------------------------------------------------
-- The pieces
---------------------------------------------------------------------------

-- Blizzard's collection progress bar (the Toy Box's): the skills bar in its border.
local function newProgress(parent, width)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(width, 13)
    bar:SetStatusBarTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar")
    bar:SetStatusBarColor(0.03125, 0.85, 0)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetColorTexture(0, 0, 0, 1)
    bg:SetPoint("TOPLEFT", 0, -1)
    bg:SetPoint("BOTTOMRIGHT", 0, 1)
    local border = bar:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder")
    border:SetPoint("TOPLEFT", -5, 8)
    border:SetPoint("BOTTOMRIGHT", 5, -8)
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("CENTER", 0, 1)
    return bar
end

-- A kind's tile: its mark, its name, and how many of them you've defeated as a bar.
local function newTile(parent, kind)
    local tile = CreateFrame("Frame", nil, parent)
    tile:SetSize(190, TILES_H - 14)
    tile.mark = tile:CreateTexture(nil, "ARTWORK")
    tile.mark:SetAtlas(kind.atlas)
    tile.mark:SetSize(36, 36)
    tile.mark:SetPoint("LEFT", 0, 0)
    tile.label = tile:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    tile.label:SetPoint("TOPLEFT", tile.mark, "TOPRIGHT", 10, 0)
    tile.label:SetText(kind.label)
    tile.bar = newProgress(tile, 130)
    tile.bar:SetPoint("TOPLEFT", tile.label, "BOTTOMLEFT", 2, -10)
    return tile
end

-- A zone's header: the Collections window's slot header bar with the zone's name.
local function newHead(parent)
    local head = CreateFrame("Frame", nil, parent)
    head:SetHeight(24)
    head.bar = head:CreateTexture(nil, "BACKGROUND")
    head.bar:SetAtlas("collections-slotheader")
    head.bar:SetAllPoints()
    head.text = head:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    head.text:SetPoint("LEFT", 14, 1)
    head.count = head:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    head.count:SetPoint("RIGHT", -14, 1)
    return head
end

-- A trophy, the Toy Box's way: the creature's portrait in its gold ring (greyed until defeated,
-- its kind's mark on it), its name, level and how often you beat it.
local function newCard(parent)
    local card = CreateFrame("Button", nil, parent)
    card:SetSize(CARD_W, CARD_H)
    card:SetHighlightAtlas("PetList-ButtonHighlight", "ADD")
    card.portrait = J.Portrait(card, 50)
    card.portrait:SetPoint("LEFT", 2, 0)
    card.mark = card:CreateTexture(nil, "OVERLAY", nil, 3)
    card.mark:SetSize(20, 20)
    card.mark:SetPoint("BOTTOMRIGHT", card.portrait, "BOTTOMRIGHT", 4, -2)
    card.name = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.name:SetPoint("TOPLEFT", card.portrait, "TOPRIGHT", 8, -2)
    card.name:SetPoint("RIGHT", -4, 0)
    card.name:SetJustifyH("LEFT")
    card.name:SetMaxLines(2)
    card.level = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.level:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -2)
    card.kills = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    card.kills:SetPoint("TOPLEFT", card.level, "BOTTOMLEFT", 0, -2)
    card:SetScript("OnClick", function(self) ns.ShowCreature(self.npcID) end)
    card:SetScript("OnEnter", cardTip)
    card:SetScript("OnLeave", GameTooltip_Hide)
    return card
end

local function fillCard(card, entry)
    local rec, won = entry.rec, defeated(entry.rec)
    card.npcID = entry.npcID
    card.portrait:SetCreature(rec)
    card.portrait:SetDesaturated(not won)
    card.mark:SetAtlas(KIND_ATLAS[entry.kind])
    card.mark:SetDesaturated(not won)
    card.name:SetText(rec.name or "?")
    card.name:SetTextColor(won and 1 or 0.55, won and 0.82 or 0.55, won and 0 or 0.55)
    card.level:SetText(Text.LevelText(rec))
    card.kills:SetText(won and format(L.TROPHY_KILLS_SINCE, rec.kills, Text.Date(rec.firstKill)) or L.TROPHY_OPEN)
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------

function page.Refresh()
    local zones, counts = trophies()
    local won, total = 0, 0
    for _, kind in ipairs(KINDS) do
        local count, tile = counts[kind.key], tiles[kind.key]
        won, total = won + count.won, total + count.total
        tile.bar:SetMinMaxValues(0, math.max(count.total, 1))
        tile.bar:SetValue(count.won)
        tile.bar.text:SetText(format(L.JOURNAL_COUNT, count.won, count.total))
    end
    summary.Count:SetText(format(L.JOURNAL_COUNT, won, total))
    filterButton:ValidateResetState()

    local width = math.max(scroll:GetWidth() or 0, CARD_W)
    local perRow = math.max(1, math.floor((width + GAP) / (CARD_W + GAP)))
    content:SetWidth(width)
    local y, usedCards, usedHeads = 0, 0, 0
    for _, zone in ipairs(zones) do
        usedHeads = usedHeads + 1
        local head = heads[usedHeads] or newHead(content)
        heads[usedHeads] = head
        head:ClearAllPoints()
        head:SetPoint("TOPLEFT", 0, -y)
        head:SetPoint("RIGHT", content, "RIGHT")
        head.text:SetText(zone.name)
        head.count:SetText(#zone.list)
        head:Show()
        y = y + HEAD_H
        for i, entry in ipairs(zone.list) do
            usedCards = usedCards + 1
            local card = cards[usedCards] or newCard(content)
            cards[usedCards] = card
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", ((i - 1) % perRow) * (CARD_W + GAP), -(y + math.floor((i - 1) / perRow) * (CARD_H + GAP)))
            fillCard(card, entry)
            card:Show()
        end
        y = y + math.ceil(#zone.list / perRow) * (CARD_H + GAP) + 8
    end
    for i = usedCards + 1, #cards do cards[i]:Hide() end
    for i = usedHeads + 1, #heads do heads[i]:Hide() end
    content:SetHeight(math.max(y, 1))
    page.empty:SetShown(#zones == 0)
end

local FILTERS = {
    { L.TROPHY_FILTER_KIND, { { "boss", L.TROPHY_BOSSES }, { "rare", L.TROPHY_RARES }, { "elite", L.TROPHY_ELITES } } },
    { L.TROPHY_FILTER_STATE, { { "won", L.TROPHY_WON }, { "open", L.TROPHY_NOT_YET } } },
}

local function filterMenu(_, root)
    for _, group in ipairs(FILTERS) do
        root:CreateTitle(group[1])
        for _, choice in ipairs(group[2]) do
            root:CreateCheckbox(choice[2], function() return shown[choice[1]] == true end, function()
                shown[choice[1]] = not shown[choice[1]] or nil
                page.Refresh()
            end)
        end
    end
end

function page.Build(frame)
    summary = J.CountBox(frame, L.TROPHY_DEFEATED)
    summary:SetPoint("LEFT", frame, "TOPLEFT", J.PORTRAIT, -J.STRIP / 2 + 2)
    filterButton = J.Dropdown(frame, 90, filterMenu, true)
    filterButton:SetPoint("RIGHT", frame, "TOPRIGHT", -2, -J.STRIP / 2 + 2)
    filterButton:SetIsDefaultCallback(function() return next(shown) == nil end)
    filterButton:SetDefaultCallback(function()
        shown = {}
        page.Refresh()
    end)
    local inset = J.Inset(frame)
    inset:SetPoint("TOPLEFT", 0, -J.STRIP)
    inset:SetPoint("BOTTOMRIGHT")
    J.CollectionsBackground(inset)
    -- The tiles across the top, evenly spaced.
    local band = CreateFrame("Frame", nil, inset)
    band:SetPoint("TOPLEFT", 40, -30)
    band:SetPoint("TOPRIGHT", -40, -30)
    band:SetHeight(TILES_H)
    for i, kind in ipairs(KINDS) do
        local tile = newTile(band, kind)
        tile:SetPoint("LEFT", band, "LEFT", (i - 1) * 210 + 20, 0)
        tiles[kind.key] = tile
    end
    scroll = ns.Kit.NewScroll(inset)
    scroll:SetPoint("TOPLEFT", band, "BOTTOMLEFT", 0, -8)
    scroll:SetPoint("BOTTOMRIGHT", -40, 20)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    page.empty = inset:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
    page.empty:SetPoint("CENTER", 0, -30)
    page.empty:SetText(L.TROPHY_EMPTY)
end

Journal.AddPage(page)
