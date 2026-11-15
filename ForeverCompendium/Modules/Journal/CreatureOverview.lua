--[[
    Forever Compendium - Modules/Journal/CreatureOverview.lua
    What's known of a creature, the column beside its model (CreatureDetail.lua makes and fills
    it): lines under gold headers, scrolling when long. The information Forever Bestiary showed,
    in our own order:

      * Wanted: the quests in your log that want it (kill, loot, speak to), first, in gold.
      * Identification: its level with its rank (Elite, Rare, Boss), its kind and family, how
        it stands toward you. Inside some instances the game keeps a creature's kind to itself:
        then it says Unknown, with a mark saying why.
      * Locations: zones (click one to open the map there with its area shown) with the areas
        in them, then dungeons and raids.
      * Abilities (each spell's tooltip on mouse over) and Defenses.
      * Best Drops: its likeliest drops worth having (common or better), with their chances.
      * Encounters (first and last seen, your deaths to it), Kills (how many, first and last,
        corpses looted, money) and Reputation.
    Each label says on mouse over how the journal learns it.
]]

local _, ns = ...
local L = ns.L

local ipairs, pairs, format, table, math = ipairs, pairs, string.format, table, math
local Book = ns.Book
local Text = assert(ns.JournalText, "CreatureOverview.lua loads after JournalText.lua")
local J = assert(ns.JournalKit, "CreatureOverview.lua loads after JournalKit.lua")

local BEST_DROPS = 4 -- drops the column names, at most

local Overview = {}
ns.CreatureOverview = Overview

local pane = {} -- the columns, and the creature shown (npcID)

local function field(label, value)
    return Text.GOLD .. label .. "|r " .. Text.WHITE .. value .. "|r"
end

local function learnedTip(line)
    J.Tip(line, line.data.title, line.data.text)
end

-- A "Label: value" line saying on mouse over how it was learned (`tip`).
local function fact(lines, label, value, tip, opts)
    opts = opts or {}
    if tip then
        opts.data = { title = label:gsub(":$", ""), text = tip }
        opts.onEnter = learnedTip
    end
    return lines:Line(field(label, value), opts)
end

local function addIdentity(lines, rec)
    lines:Head(L.CDETAIL_IDENTITY)
    local ranged = rec.minLevel and rec.minLevel ~= rec.maxLevel
    fact(lines, ranged and L.CDETAIL_LEVELS or L.CDETAIL_LEVEL, Text.LevelTagged(rec), L.CDETAIL_LEVEL_TIP)
    local kind = rec.creatureType and (rec.creatureType .. (rec.family and (" (" .. rec.family .. ")") or ""))
    if kind then
        fact(lines, L.CDETAIL_TYPE, kind, L.CDETAIL_TYPE_TIP)
    else
        fact(lines, L.CDETAIL_TYPE, L.JOURNAL_UNKNOWN, L.CDETAIL_TYPE_HIDDEN_TIP, { icon = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew" })
    end
    local r, g, b = Text.ReactionColor(rec.reaction)
    fact(lines, L.CDETAIL_REACTION, Text.Color(r, g, b) .. Text.Reaction(rec.reaction) .. "|r", L.CDETAIL_REACTION_TIP)
end

local function openMap(line)
    local data = line.data
    if ns.FocusCreature then ns.FocusCreature(pane.npcID) end
    OpenWorldMap(data.mapID)
end

local function placeTip(line)
    J.Tip(line, line.data.name, L.CDETAIL_MAP_TIP)
end

local function addZone(lines, place)
    lines:Line(place.name, { indent = 12, onClick = openMap, onEnter = placeTip, data = place })
    for _, sub in ipairs(place.subs) do lines:Line(Text.GRAY .. sub .. "|r", { indent = 28 }) end
end

-- A sub-label ("Zones:"; none when it carries on the one above) and its entries.
local function group(lines, label, entries, add)
    if #entries == 0 then return end
    if label then lines:Line(Text.GOLD .. label .. "|r", { font = "GameFontNormalSmall" }) end
    for _, entry in ipairs(entries) do add(lines, entry) end
end

local function instanceLine(lines, name) lines:Line(name, { indent = 12 }) end

-- Zones, then dungeons and raids: an instance's own map (with its areas) where it has one, else
-- its name as the Recorder kept it.
local function addPlaces(lines, rec)
    local zones, dungeons, raids, mapped = {}, {}, {}, {}
    local instances = rec.instances or {}
    for _, place in ipairs(Text.Places(rec)) do
        if instances[place.name] == "raid" then
            raids[#raids + 1] = place
        elseif place.dungeon or instances[place.name] then
            dungeons[#dungeons + 1] = place
        else
            zones[#zones + 1] = place
        end
        mapped[place.name] = true
    end
    local otherDungeons, otherRaids = {}, {}
    for name, kind in pairs(instances) do
        if not mapped[name] then
            local list = kind == "raid" and otherRaids or otherDungeons
            list[#list + 1] = name
        end
    end
    table.sort(otherDungeons)
    table.sort(otherRaids)
    if #zones + #dungeons + #raids + #otherDungeons + #otherRaids == 0 then return end
    lines:Head(L.CDETAIL_LOCATIONS)
    group(lines, #zones == 1 and L.CDETAIL_ZONE or L.CDETAIL_ZONES, zones, addZone)
    local dungeonCount, raidCount = #dungeons + #otherDungeons, #raids + #otherRaids
    group(lines, dungeonCount == 1 and L.CDETAIL_DUNGEON_ONE or L.CDETAIL_DUNGEONS, dungeons, addZone)
    group(lines, #dungeons == 0 and (dungeonCount == 1 and L.CDETAIL_DUNGEON_ONE or L.CDETAIL_DUNGEONS) or nil,
        otherDungeons, instanceLine)
    group(lines, raidCount == 1 and L.CDETAIL_RAID_ONE or L.CDETAIL_RAIDS, raids, addZone)
    group(lines, #raids == 0 and (raidCount == 1 and L.CDETAIL_RAID_ONE or L.CDETAIL_RAIDS) or nil, otherRaids, instanceLine)
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
    fact(lines, L.CDETAIL_FIRST_SEEN, Text.Date(rec.first), L.CDETAIL_SEEN_TIP)
    fact(lines, L.CDETAIL_LAST_SEEN, Text.Date(rec.last), L.CDETAIL_SEEN_TIP)
    if (rec.deaths or 0) > 0 then fact(lines, L.CDETAIL_DEATHS, rec.deaths, L.CDETAIL_DEATHS_TIP) end
end

local function addKills(lines, rec)
    if (rec.kills or 0) == 0 and (rec.looted or 0) == 0 then return end
    lines:Head(L.CDETAIL_KILLS)
    fact(lines, L.CDETAIL_TOTAL_KILLS, rec.kills or 0, L.CDETAIL_KILLS_TIP)
    if rec.firstKill then lines:Line(field(L.CDETAIL_FIRST_KILL, Text.Date(rec.firstKill))) end
    if rec.lastKill then lines:Line(field(L.CDETAIL_LAST_KILL, Text.Date(rec.lastKill))) end
    if (rec.looted or 0) > 0 then fact(lines, L.CDETAIL_LOOTED, rec.looted, L.CDETAIL_LOOTED_TIP) end
    if (rec.money or 0) > 0 then
        lines:Line(field(L.CDETAIL_MONEY, ns.MoneyText(rec.money)))
        lines:Line(field(L.CDETAIL_MONEY_AVERAGE, ns.MoneyText(rec.money / math.max(rec.looted or 1, 1))))
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

-- Every section, in order.
local function addSections(lines, rec)
    addWanted(lines, rec)
    addIdentity(lines, rec)
    addPlaces(lines, rec)
    addAbilities(lines, rec)
    addDefenses(lines, rec)
    addBestDrops(lines, rec)
    addEncounters(lines, rec)
    addKills(lines, rec)
    addReputation(lines, rec)
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
    addSections(lines, rec)
    lines:End()
    lines.scroll:SetVerticalScroll(0)
end
