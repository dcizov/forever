--[[
    Forever Codex - Modules/Journal/Npcs/NpcsPage.lua
    The journal's NPCs page: the friendly NPCs you dealt with (Book.IsNpc: the Recorder meets one
    when you talk to it, buy from it, train or fly with it, or use its bank), apart from the
    creatures. The list on the left under a header for each zone, searched by name or title and
    filtered by what you dealt with it for; the chosen one on the right (NpcDetail.lua).
]]

local _, ns = ...
local L = ns.L

local ipairs, pairs, next, format, table = ipairs, pairs, next, string.format, table
local Book = ns.Book
local Text = assert(ns.JournalText, "NpcsPage.lua loads after JournalText.lua")
local J = assert(ns.JournalKit, "NpcsPage.lua loads after JournalKit.lua")
local Filter = assert(ns.CreatureFilter, "NpcsPage.lua loads after CreatureFilter.lua")
local Journal = assert(ns.Journal, "NpcsPage.lua loads after Journal.lua")
local Detail = assert(ns.NpcDetail, "NpcsPage.lua loads after NpcDetail.lua")

local M = Journal.module
local page = { key = "npcs", label = L.JOURNAL_TAB_NPCS, icon = "Interface\\Icons\\INV_Misc_GroupNeedMore", order = 15 }

local SERVICES = Detail.SERVICES
local list, count, filterButton
local selected
local terms = ""
local onlyFor = {} -- service -> true: only NPCs that offer one of these

local function db() return M.db end

-- Whether NPC `rec` passes the search (name, title) and the service filter.
local function passes(rec)
    if terms ~= "" and not (Text.Has(rec.name, terms) or Text.Has(rec.title, terms)) then return false end
    if next(onlyFor) then
        for service in pairs(rec.services or {}) do
            if onlyFor[service] then return true end
        end
        return false
    end
    return true
end

local function items()
    local out = {}
    for npcID, rec in pairs(Book.Creatures()) do
        if Book.IsNpc(rec) and passes(rec) then out[#out + 1] = { npcID = npcID, rec = rec } end
    end
    table.sort(out, function(a, b) return (a.rec.name or "") < (b.rec.name or "") end)
    return out
end


local function fillEntry(entry, item)
    local rec = item.rec
    entry.portrait:SetCreature(rec)
    entry.name:SetText(rec.name or "?")
    entry.sub:SetText(rec.title or Text.Where(rec))
    entry.note:SetText(Detail.ServiceIcons(rec, 14))
    entry.favorite:SetShown(rec.pinned == true)
end

function page.Refresh()
    local found = items()
    local total = 0
    for _, rec in pairs(Book.Creatures()) do
        if Book.IsNpc(rec) then total = total + 1 end
    end
    list:SetItems(db().groupZones and Filter.Grouped(found, db().npcsCollapsed) or found)
    count.Count:SetText(#found < total and format(L.JOURNAL_COUNT, #found, total) or total)
    filterButton:ValidateResetState()
    if not (selected and Book.Creature(selected)) then selected = found[1] and found[1].npcID end
    Detail.Show(selected)
end

function page.Select(npcID)
    selected = npcID
    Journal.Visit(page.key, npcID)
    local rec = Book.Creature(npcID)
    if rec then Filter.Unfold(db().npcsCollapsed, rec) end
    page.Refresh()
    for i, item in ipairs(list.items) do
        if item.npcID == npcID then list:ShowIndex(i) end
    end
end

local function onRowClick(item, button)
    if item.header then
        local collapsed = db().npcsCollapsed
        collapsed[item.header] = not collapsed[item.header] or nil
        return page.Refresh()
    end
    if button == "RightButton" then return Journal.TogglePin(item.npcID) end
    Detail.Show(item.npcID)
    Journal.Visit(page.key, item.npcID)
    list:Refresh()
end

local function filterMenu(_, root)
    root:CreateTitle(L.NPCS_FILTER)
    for _, s in ipairs(SERVICES) do
        root:CreateCheckbox(s[3], function() return onlyFor[s[1]] == true end, function()
            onlyFor[s[1]] = not onlyFor[s[1]] or nil
            page.Refresh()
        end)
    end
end

function page.Build(frame)
    local p = J.ListPage(frame, {
        countLabel = L.JOURNAL_TAB_NPCS,
        search = L.NPCS_SEARCH,
        onSearch = function(text)
            terms = text
            page.Refresh()
        end,
        filterMenu = filterMenu,
        isDefault = function() return next(onlyFor) == nil end,
        onReset = function()
            onlyFor = {}
            page.Refresh()
        end,
        fill = fillEntry,
        onClick = onRowClick,
        isSelected = function(item) return item.npcID == selected end,
    })
    list, count, filterButton = p.list, p.count, p.filter
    Detail.Build(p.right)
end

Journal.AddPage(page)
