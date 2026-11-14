--[[
    Forever Compendium - Modules/Journal/CreatureOverview.lua
    What's known of a creature, the column beside its model (CreatureDetail.lua makes and fills
    it), as Forever Bestiary lays it out: lines under gold headers, scrolling when long.

      * Wanted: the quests in your log that want it (kill, loot, speak to), first, in gold.
      * Locations (click one to open the map there with its area shown).
      * Abilities (each spell's tooltip on mouse over) and Defenses.
      * Best Drops: its likeliest drops worth having (common or better), with their chances.
      * Encounters (first and last seen, your deaths to it), Kills (first and last, how many,
        corpses looted, money) and Reputation.
]]

local _, ns = ...
local L = ns.L

local ipairs, pairs, format, table, math = ipairs, pairs, string.format, table, math
local Book, Text, J = ns.Book, ns.JournalText, ns.JournalKit

local BEST_DROPS = 4 -- drops the column names, at most

local Overview = {}
ns.CreatureOverview = Overview

local pane = {} -- the columns, and the creature shown (npcID)

local function field(label, value)
    return Text.GOLD .. label .. "|r " .. Text.WHITE .. value .. "|r"
end

local function openMap(line)
    local data = line.data
    if ns.FocusCreature then ns.FocusCreature(pane.npcID) end
    OpenWorldMap(data.mapID)
end

local function placeTip(line)
    J.Tip(line, line.data.name, L.CDETAIL_MAP_TIP)
end

local function addPlaces(lines, rec)
    local places = Text.Places(rec)
    if #places == 0 and not next(rec.instances or {}) then return end
    lines:Head(L.CDETAIL_LOCATIONS)
    for _, place in ipairs(places) do
        lines:Line(place.name, { icon = "Interface\\Minimap\\Tracking\\None", onClick = openMap, onEnter = placeTip, data = place })
        for _, sub in ipairs(place.subs) do lines:Line(Text.GRAY .. sub .. "|r", { indent = 20 }) end
    end
    for instance, kind in pairs(rec.instances or {}) do
        local label = kind == "raid" and L.CDETAIL_RAID or L.CDETAIL_DUNGEON
        lines:Line(instance .. " " .. Text.GRAY .. "(" .. label .. ")|r", { icon = "Interface\\Minimap\\Dungeon" })
    end
end

local function spellTip(line)
    GameTooltip:SetOwner(line, "ANCHOR_RIGHT")
    GameTooltip:SetSpellByID(line.data)
    GameTooltip:Show()
end

local function addAbilities(lines, rec)
    local spells = {}
    for spellID in pairs(rec.abilities or {}) do
        local name = C_Spell.GetSpellName(spellID)
        if name then spells[#spells + 1] = { id = spellID, name = name } end
    end
    if #spells == 0 then return end
    table.sort(spells, function(a, b) return a.name < b.name end)
    lines:Head(L.CDETAIL_ABILITIES)
    for _, spell in ipairs(spells) do
        lines:Line(spell.name, { icon = C_Spell.GetSpellTexture(spell.id), onEnter = spellTip, data = spell.id })
    end
end

local function addDefenses(lines, rec)
    if not next(rec.defenses or {}) then return end
    lines:Head(L.CDETAIL_DEFENSES)
    for _, school in ipairs(Text.SCHOOLS) do
        local kind = rec.defenses[school[1]]
        if kind then
            local label = L["CDETAIL_SCHOOL_" .. school[1]:upper()]
            lines:Line(Text.RED .. format(kind == "immune" and L.CDETAIL_IMMUNE or L.CDETAIL_RESISTS, label) .. "|r",
                { icon = school[2] })
        end
    end
end

local function addEncounters(lines, rec)
    lines:Head(L.CDETAIL_ENCOUNTERS)
    lines:Line(field(L.CDETAIL_FIRST_SEEN, Text.Date(rec.first)))
    lines:Line(field(L.CDETAIL_LAST_SEEN, Text.Date(rec.last)))
    if (rec.deaths or 0) > 0 then lines:Line(field(L.CDETAIL_DEATHS, rec.deaths)) end
end

local function addKills(lines, rec)
    if (rec.kills or 0) == 0 and (rec.looted or 0) == 0 then return end
    lines:Head(L.CDETAIL_KILLS)
    lines:Line(field(L.CDETAIL_TOTAL_KILLS, rec.kills or 0))
    if rec.firstKill then lines:Line(field(L.CDETAIL_FIRST_KILL, Text.Date(rec.firstKill))) end
    if rec.lastKill then lines:Line(field(L.CDETAIL_LAST_KILL, Text.Date(rec.lastKill))) end
    if (rec.looted or 0) > 0 then lines:Line(field(L.CDETAIL_LOOTED, rec.looted)) end
    if (rec.money or 0) > 0 then
        lines:Line(field(L.CDETAIL_MONEY, Text.Money(rec.money)))
        lines:Line(field(L.CDETAIL_MONEY_AVERAGE, Text.Money(rec.money / math.max(rec.looted or 1, 1))))
    end
end

local function addReputation(lines, rec)
    if not next(rec.rep or {}) then return end
    lines:Head(L.CDETAIL_REPUTATION)
    for faction, r in pairs(rec.rep) do
        local per = r.min == r.max and format("%+d", r.min) or format(L.CDETAIL_REP_RANGE, r.min, r.max)
        lines:Line(field(faction .. ":", format(L.CDETAIL_REP_LINE, per, r.total)))
    end
end

local function addWanted(lines, rec)
    local log = Book.LogQuests()
    local first = true
    for _, entry in ipairs(Text.CreatureQuests(rec)) do
        if log[entry.questID] then
            if first then lines:Head(L.CDETAIL_WANTED) end
            first = false
            lines:Line(Text.RoleIcons(entry.roles, 14) .. "  " .. Text.QuestLine(entry.questID), {
                data = entry, onClick = function(line) ns.ShowQuest(line.data.questID) end })
        end
    end
end

local function itemTip(line)
    GameTooltip:SetOwner(line, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(line.data)
    GameTooltip:Show()
end

local function addBestDrops(lines, rec)
    if (rec.looted or 0) == 0 then return end
    local drops = {}
    for itemID in pairs(rec.loot or {}) do
        local item = Book.Item(itemID)
        if not item or (item.quality or 1) >= 1 then drops[#drops + 1] = itemID end
    end
    if #drops == 0 then return end
    table.sort(drops, function(a, b) return (rec.loot[a] or 0) > (rec.loot[b] or 0) end)
    lines:Head(L.CDETAIL_BEST_DROPS)
    for i = 1, math.min(#drops, BEST_DROPS) do
        local itemID = drops[i]
        local r, g, b = Text.ItemColor(itemID)
        lines:Line(Text.Color(r, g, b) .. Text.ItemName(itemID) .. "|r  " .. Text.GRAY .. Text.Percent(Book.DropRate(rec, itemID)) .. "|r",
            { icon = Text.ItemIcon(itemID), data = itemID, onEnter = itemTip, onClick = function(line) ns.ShowItem(line.data) end })
    end
end

-- The column in `parent` (the caller places Overview.lines.scroll).
function Overview.Build(parent)
    pane.lines = J.NewLines(parent, 300)
    Overview.lines = pane.lines
end

-- Fills it with creature `rec` (`npcID`).
function Overview.Fill(rec, npcID)
    pane.npcID = npcID
    local lines = pane.lines
    lines:Begin()
    addWanted(lines, rec)
    addPlaces(lines, rec)
    addAbilities(lines, rec)
    addDefenses(lines, rec)
    addBestDrops(lines, rec)
    addEncounters(lines, rec)
    addKills(lines, rec)
    addReputation(lines, rec)
    lines:End()
    lines.scroll:SetVerticalScroll(0)
end
