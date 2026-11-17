--[[
    Forever Codex - Modules/Journal/TrophiesPage.lua
    The journal's Trophies page: the bosses, rares and elites the Recorder met
    (CreatureFilter.RankOf), laid out as the spellbook lays out what you can learn
    (JournalSpells.lua): the page's title with how many you've defeated at its right, a heading
    for each zone (CreatureFilter.GroupOf) and under it a cell for each: the creature's round
    face, its name (a boss's in purple, a rare's in blue) and what it is and how often you beat
    it. One not yet defeated is greyed. Bosses first, then rares, then elites; the latest
    defeated first. The filter keeps kinds, defeated ones or the rest. Click one for its page.
]]

local _, ns = ...
local L = ns.L

local ipairs, pairs, next, format, table = ipairs, pairs, next, string.format, table
local Book = ns.Book
local J = assert(ns.JournalKit, "TrophiesPage.lua loads after JournalKit.lua")
local Journal = assert(ns.Journal, "TrophiesPage.lua loads after Journal.lua")
local Filter = assert(ns.CreatureFilter, "TrophiesPage.lua loads after CreatureFilter.lua")
local Text = assert(ns.JournalText, "TrophiesPage.lua loads after JournalText.lua")

-- The kinds, in their order on the page: each one's name and the colour its name is written in.
local KINDS = {
    { key = "boss", label = L.TROPHY_BOSSES, one = L.TROPHY_BOSS, color = "|cffa335ee" },
    { key = "rare", label = L.TROPHY_RARES, one = L.TROPHY_RARE, color = "|cff0070dd" },
    { key = "elite", label = L.TROPHY_ELITES, one = L.TROPHY_ELITE },
}
local KIND = {}
for i, kind in ipairs(KINDS) do
    KIND[kind.key] = kind
    kind.order = i
end

local page = { key = "trophies", label = L.JOURNAL_TAB_TROPHIES, icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01", order = 35 }
local summary, filterButton, book
local shown = {} -- filter: a kind ("boss", ...) or state ("won", "open") -> true while kept

local function defeated(rec) return (rec.kills or 0) > 0 end

-- Whether a creature of `kind` passes the filter (nothing ticked in a part keeps all of it).
local function kept(kind, won)
    local kindOk = not (shown.boss or shown.rare or shown.elite) or shown[kind]
    local stateOk = not (shown.won or shown.open) or shown[won and "won" or "open"]
    return kindOk and stateOk
end

-- The trophies to show, by zone (zones by name, the unknown place last); in each, bosses, rares
-- and elites, the latest defeated first, then by name. Also how many there are and how many
-- you've defeated, of all of them.
local function trophies()
    local zones, byKey, won, total = {}, {}, 0, 0
    for npcID, rec in pairs(Book.Creatures()) do
        local kind = not Book.IsNpc(rec) and Filter.RankOf(rec)
        if KIND[kind] then
            total = total + 1
            if defeated(rec) then won = won + 1 end
            if kept(kind, defeated(rec)) then
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
            if a.kind ~= b.kind then return KIND[a.kind].order < KIND[b.kind].order end
            local x, y = a.rec.lastKill or 0, b.rec.lastKill or 0
            if x ~= y then return x > y end
            return (a.rec.name or "") < (b.rec.name or "")
        end)
    end
    return zones, won, total
end

local function fill(cell, entry)
    local rec, kind = entry.rec, KIND[entry.kind]
    local won = defeated(rec)
    cell:Face(rec)
    cell:Dim(not won)
    cell.name:SetText(won and kind.color and (kind.color .. (rec.name or "?") .. "|r") or rec.name or "?")
    cell.sub:SetText(format(L.TROPHY_SUB, kind.one, won and format(L.TROPHY_KILLS, rec.kills) or L.TROPHY_OPEN))
end

local function cellTip(cell)
    local rec = cell.entry.rec
    J.Tip(cell, rec.name, Text.Kind(rec), Text.Where(rec),
        defeated(rec) and format(L.TROPHY_KILLS, rec.kills) or L.TROPHY_OPEN,
        rec.firstKill and format(L.TROPHY_FIRST, Text.Date(rec.firstKill)) or nil,
        { L.TROPHY_HINT, 0.1, 1, 0.1 })
end

local CELLS = { fill = fill, onEnter = cellTip, onClick = function(cell) J.Link("creature", cell.entry.npcID, "LeftButton") end }

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------

function page.Refresh()
    local zones, won, total = trophies()
    summary.Count:SetText(format(L.JOURNAL_COUNT, won, total))
    book.total:SetText(format(L.TROPHY_TOTAL, won, total))
    filterButton:ValidateResetState()
    local lines = book.lines
    lines:Begin()
    for _, zone in ipairs(zones) do
        lines:Head(zone.name, #zone.list)
        lines:Entries(zone.list, CELLS)
    end
    if #zones == 0 then lines:Line(Text.GRAY .. L.TROPHY_EMPTY .. "|r") end
    lines:End()
end

local STATES = { { "won", L.TROPHY_WON }, { "open", L.TROPHY_NOT_YET } }

local function check(root, key, label)
    root:CreateCheckbox(label, function() return shown[key] == true end, function()
        shown[key] = not shown[key] or nil
        page.Refresh()
    end)
end

local function filterMenu(_, root)
    root:CreateTitle(L.TROPHY_FILTER_KIND)
    for _, kind in ipairs(KINDS) do check(root, kind.key, kind.label) end
    root:CreateTitle(L.TROPHY_FILTER_STATE)
    for _, choice in ipairs(STATES) do check(root, choice[1], choice[2]) end
end

function page.Build(frame)
    summary = J.CountBox(frame, L.TROPHY_DEFEATED)
    summary:SetPoint("LEFT", frame, "TOPLEFT", J.PORTRAIT, -J.STRIP / 2 + 2)
    filterButton = J.Dropdown(frame, nil, filterMenu, true)
    filterButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -J.ROW_INSET, -J.ROW_INSET)
    filterButton:SetIsDefaultCallback(function() return next(shown) == nil end)
    filterButton:SetDefaultCallback(function()
        shown = {}
        page.Refresh()
    end)
    book = J.SpellPage(frame)
    book.title:SetText(L.TROPHY_ROOM)
    book.hint:SetText(L.TROPHY_PAGE_HINT)
end

Journal.AddPage(page)
