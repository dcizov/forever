--[[
    Forever Codex - Modules/Social/BadgesPage.lua
    The journal's Badges page (its tab shows while Badges is on), laid out as the spellbook lays
    out what you can learn (JournalSpells.lua): the page's title with the tiers earned at its
    right, then the badges you've earned (under a green heading, as the spellbook heads what's
    yours to learn now) and those still to earn, a cell each: its icon in a frame of its tier's
    colour (greyed until the first), its name and tier, and how far along you are to its next
    tier. Click an earned badge to show it on your tooltip (a star marks the shown ones, up to
    three).
]]

local _, ns = ...
local L = ns.L

local ipairs, format = ipairs, string.format
local Text = assert(ns.JournalText, "BadgesPage.lua loads after JournalText.lua")
local J = assert(ns.JournalKit, "BadgesPage.lua loads after JournalKit.lua")
local Journal = assert(ns.Journal, "BadgesPage.lua loads after Journal.lua")
local Badges = assert(ns.Badges, "BadgesPage.lua loads after Badges.lua")

local page = { key = "badges", label = L.JOURNAL_TAB_BADGES, icon = "Interface\\Icons\\Achievement_GuildPerk_HonorableMention", order = 40 }
local summary, book

function page.Shown() return Badges.module.active end

local function cellTip(cell)
    local key, stats = cell.entry.key, cell.entry.stats
    local earned = Badges.module.db.earned[key]
    local _, need = Badges.TierOf(key, stats[key] or 0)
    J.Tip(cell, Badges.TierName(key, earned and earned.tier), Badges.Describe(key, need or stats[key] or 0),
        earned and { format(L.BADGES_EARNED_ON, Text.Date(earned.at)), 0.7, 0.7, 0.7 } or nil,
        earned and { Badges.IsShown(key) and L.BADGES_HIDE_HINT or L.BADGES_SHOW_HINT, 0.1, 1, 0.1 } or nil)
end

local function fill(cell, entry)
    local badge, key = entry.badge, entry.key
    local count = entry.stats[key] or 0
    local tier, need = Badges.TierOf(key, count)
    if tier > 0 then cell:Icon(badge.icon, Badges.TierColor(tier)) else cell:Icon(badge.icon) end
    cell:Dim(tier == 0)
    cell.name:SetText(tier > 0 and Badges.TierName(key, tier) or Badges.Name(key))
    cell.sub:SetText(need and format(L.BADGES_PROGRESS, Badges.CountText(key, count), Badges.CountText(key, need))
        or L.BADGES_COMPLETE)
    cell.mark:SetShown(Badges.IsShown(key))
end

local CELLS = {
    fill = fill, onEnter = cellTip,
    onClick = function(cell)
        Badges.ToggleShown(cell.entry.key)
        page.Refresh()
        cellTip(cell)
    end,
}

function page.Refresh()
    local stats = Badges.Stats()
    local earnedTiers, total = 0, 0
    local earned, open = {}, {}
    for _, badge in ipairs(Badges.LIST) do
        local entry = Badges.module.db.earned[badge.key]
        earnedTiers, total = earnedTiers + (entry and entry.tier or 0), total + #badge.tiers
        local tier = Badges.TierOf(badge.key, stats[badge.key] or 0)
        local list = tier > 0 and earned or open
        list[#list + 1] = { badge = badge, key = badge.key, stats = stats }
    end
    summary.Count:SetText(format(L.JOURNAL_COUNT, earnedTiers, total))
    book.total:SetText(format(L.BADGES_TOTAL, earnedTiers, total))
    local lines = book.lines
    lines:Begin()
    if #earned > 0 then
        lines:Head(L.BADGES_EARNED, #earned, "good")
        lines:Entries(earned, CELLS)
    end
    if #open > 0 then
        lines:Head(L.BADGES_OPEN, #open)
        lines:Entries(open, CELLS)
    end
    lines:End()
end

function page.Build(frame)
    summary = J.CountBox(frame, L.BADGES_TIERS)
    summary:SetPoint("LEFT", frame, "TOPLEFT", J.PORTRAIT, -J.STRIP / 2 + 2)
    book = J.SpellPage(frame)
    book.title:SetText(L.BADGES_ROOM)
    book.hint:SetText(L.BADGES_PAGE_HINT)
end

Journal.AddPage(page)
