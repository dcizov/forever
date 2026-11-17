--[[
    Forever Codex - Modules/Journal/CreatureFilter.lua
    What the journal's creature list shows (Modules/Journal/CreaturesPage.lua draws it): the
    search, the filters and the order.

      * Search, in one of three ways: by Name (names, titles, kinds and places), by Loot (the
        names of what it dropped, sells, or gives for a quest) or by Quest (the titles of its
        quests). Several terms at once are separated by ";" and any one matching is enough.
      * Filters, each a set of ticked values (none ticked: no filter): how it stands toward you,
        its rank, its kind, the zone it was seen in; and Pinned, Wanted (by a quest in your log),
        With Notes, Shared (known only from other players). Critters stay out unless asked, and
        NPCs always (Book.IsNpc: the NPCs page lists them, Modules/Journal/NpcsPage.lua).
      * Order: by name, level, when last or first seen, kills or deaths, either way. Pinned
        creatures always come first.
    The filters last while the game runs; the order and Critters are the Journal module's settings.
]]

local _, ns = ...
local L = ns.L

local pairs, ipairs, table, type, tonumber = pairs, ipairs, table, type, tonumber
local Book = ns.Book
local Text = assert(ns.JournalText, "CreatureFilter.lua loads after JournalText.lua")

local Filter = {}
ns.CreatureFilter = Filter

Filter.mode = "name"            -- the search's way: "name", "loot" or "quest"
Filter.terms = {}               -- the search's terms, lower case
Filter.sets = { reaction = {}, rank = {}, kind = {}, zone = {}, other = {} }

Filter.MODES = { { "name", L.CFILTER_MODE_NAME }, { "loot", L.CFILTER_MODE_LOOT }, { "quest", L.CFILTER_MODE_QUEST } }
Filter.SORTS = {
    { "seen", L.JOURNAL_SORT_SEEN }, { "name", L.JOURNAL_SORT_NAME }, { "level", L.JOURNAL_SORT_LEVEL },
    { "kills", L.JOURNAL_SORT_KILLS }, { "deaths", L.CFILTER_SORT_DEATHS }, { "first", L.CFILTER_SORT_FIRST },
}
local REACTIONS = { { "hostile", L.JOURNAL_HOSTILE }, { "neutral", L.JOURNAL_NEUTRAL }, { "friendly", L.JOURNAL_FRIENDLY } }
local RANKS = { { "normal", L.CFILTER_RANK_NORMAL }, { "elite", L.JOURNAL_ELITE }, { "rare", L.JOURNAL_RARE },
    { "boss", L.JOURNAL_BOSS } }
local OTHER = { { "pinned", L.CFILTER_PINNED }, { "wanted", L.CFILTER_WANTED }, { "notes", L.CFILTER_NOTES },
    { "shared", L.CFILTER_SHARED } }

local function reactionOf(rec)
    local r = rec.reaction
    if not r then return nil end
    return r <= 3 and "hostile" or r == 4 and "neutral" or "friendly"
end

-- A creature's rank: "boss" (a world boss or a skull), "rare", "elite" or "normal".
local function rankOf(rec)
    local c = rec.classification
    if c == "worldboss" or rec.skull then return "boss" end
    if c == "rare" or c == "rareelite" then return "rare" end
    if c == "elite" then return "elite" end
    return "normal"
end

Filter.RankOf = rankOf

function Filter.SetSearch(text)
    local terms = {}
    for term in (text or ""):gmatch("[^;]+") do
        term = strtrim(term)
        if term ~= "" then terms[#terms + 1] = term end
    end
    Filter.terms = terms
end

---------------------------------------------------------------------------
-- Matching
---------------------------------------------------------------------------

local function nameMatches(rec, term)
    if Text.Has(rec.name, term) or Text.Has(rec.title, term) or Text.Has(rec.creatureType, term)
        or Text.Has(rec.family, term) then
        return true
    end
    for mapID, zone in pairs(rec.zones or {}) do
        if Text.Has(Text.MapName(mapID), term) then return true end
        for sub in pairs(zone.sub or {}) do
            if Text.Has(sub, term) then return true end
        end
    end
    for instance in pairs(rec.instances or {}) do
        if Text.Has(instance, term) then return true end
    end
    return false
end

local function anyItem(set, term)
    for itemID in pairs(set or {}) do
        if Text.Has(Text.ItemName(itemID), term) then return true end
    end
end

local function lootMatches(rec, term)
    if anyItem(rec.loot, term) or anyItem(rec.wares, term) then return true end
    for questID in pairs(rec.starts or {}) do
        local q = Book.Quest(questID)
        for _, itemID in ipairs(q and q.rewards or {}) do
            if Text.Has(Text.ItemName(itemID), term) then return true end
        end
        for _, itemID in ipairs(q and q.choices or {}) do
            if Text.Has(Text.ItemName(itemID), term) then return true end
        end
    end
    return false
end

local function questMatches(rec, term)
    for _, field in ipairs({ "starts", "ends", "quests" }) do
        for questID in pairs(rec[field] or {}) do
            if Text.Has(Book.QuestName(questID), term) then return true end
        end
    end
    return false
end

local MATCH = { name = nameMatches, loot = lootMatches, quest = questMatches }

local function searchMatches(rec)
    if #Filter.terms == 0 then return true end
    local match = MATCH[Filter.mode] or nameMatches
    for _, term in ipairs(Filter.terms) do
        if match(rec, term) then return true end
    end
    return false
end

local function inZones(rec, zones)
    for mapID in pairs(rec.zones or {}) do
        if zones[mapID] then return true end
    end
    return false
end

local function otherMatches(rec, other, log)
    if other.pinned and not rec.pinned then return false end
    if other.wanted and not Book.WantedBy(rec, log) then return false end
    if other.notes and not (rec.note and rec.note ~= "") then return false end
    if other.shared and not rec.shared then return false end
    return true
end

-- Whether the creature passes the filters (the search aside).
function Filter.Passes(rec, critters, log)
    local sets = Filter.sets
    if rec.creatureType == L.CFILTER_CRITTER_TYPE and not critters and not rec.pinned then return false end
    if next(sets.reaction) and not sets.reaction[reactionOf(rec) or ""] then return false end
    if next(sets.rank) and not sets.rank[rankOf(rec)] then return false end
    if next(sets.kind) and not sets.kind[rec.creatureType or ""] then return false end
    if next(sets.zone) and not inZones(rec, sets.zone) then return false end
    return otherMatches(rec, sets.other, log)
end

function Filter.Any()
    for _, set in pairs(Filter.sets) do
        if next(set) then return true end
    end
    return false
end

function Filter.Clear()
    for key in pairs(Filter.sets) do Filter.sets[key] = {} end
end

---------------------------------------------------------------------------
-- Order
---------------------------------------------------------------------------

local KEYS = {
    name = function(rec) return rec.name or "" end,
    level = function(rec) return rec.maxLevel or 999 end,
    seen = function(rec) return rec.last or 0 end,
    first = function(rec) return rec.first or 0 end,
    kills = function(rec) return rec.kills or 0 end,
    deaths = function(rec) return rec.deaths or 0 end,
}
-- The way each order runs unless reversed: names A-Z, the rest most first.
local DOWN = { level = true, seen = true, first = true, kills = true, deaths = true }

local function sorter(sort, reverse)
    local key = KEYS[sort] or KEYS.name
    local down = DOWN[sort]
    if reverse then down = not down end
    return function(a, b)
        if (a.rec.pinned or false) ~= (b.rec.pinned or false) then return a.rec.pinned == true end
        local x, y = key(a.rec), key(b.rec)
        if x ~= y then
            if down then return x > y end
            return x < y
        end
        return (a.rec.name or "") < (b.rec.name or "")
    end
end

-- { npcID, rec } for every creature to list, in order. db: the Journal's (sort, reverse, critters).
function Filter.Items(db)
    local items, log = {}, Book.LogQuests()
    for npcID, rec in pairs(Book.Creatures()) do
        if not Book.IsNpc(rec) and Filter.Passes(rec, db.critters, log) and searchMatches(rec) then
            items[#items + 1] = { npcID = npcID, rec = rec }
        end
    end
    table.sort(items, sorter(db.sort, db.reverse))
    return items
end

-- The group a creature is listed under: the zone it was seen most in (JournalText.Places: a
-- city district or cave counts for its zone, a continent or the world map for none), else the
-- instance it was met in, else none. Returns key, name.
function Filter.GroupOf(rec)
    local best
    for _, place in ipairs(Text.Places(rec)) do
        if not best or place.seen > best.seen or (place.seen == best.seen and place.name < best.name) then best = place end
    end
    if best then return "map:" .. best.mapID, best.name end
    local instance = next(rec.instances or {})
    if instance then return "instance:" .. instance, instance end
    return "none", L.JOURNAL_GROUP_NONE
end

-- The banner a group is listed under, as Spoken's Azeroth's Compendium lists places: a zone's
-- continent (its key and name), dungeons and raids together, or nil for one with none of its own
-- (pinned creatures, an unknown place: their banner is the group itself).
function Filter.BannerOf(key)
    local mapID = tonumber(key:match("^map:(%d+)$"))
    if not mapID then
        if key:find("^instance:") then return "banner:instances", L.JOURNAL_GROUP_INSTANCES end
        return nil
    end
    local info = C_Map.GetMapInfo(mapID)
    if info and info.mapType == Enum.UIMapType.Dungeon then return "banner:instances", L.JOURNAL_GROUP_INSTANCES end
    while info and info.mapType > Enum.UIMapType.Continent and info.parentMapID and info.parentMapID > 0 do
        info = C_Map.GetMapInfo(info.parentMapID)
    end
    if info and info.mapType == Enum.UIMapType.Continent then return "banner:" .. info.mapID, info.name end
    return nil
end

-- Unfolds the group creature `rec` is listed under, and its banner, in `collapsed`.
function Filter.Unfold(collapsed, rec)
    local key = rec.pinned and "pinned" or Filter.GroupOf(rec)
    collapsed[key] = nil
    local banner = Filter.BannerOf(key)
    if banner then collapsed[banner] = nil end
end

-- `items` (Filter.Items') under banners and group headers, as Spoken's Azeroth's Compendium lists
-- them: pinned creatures first under a banner of their own, then a banner per continent (by name;
-- dungeons and raids, then an unknown place, last) with a group per zone under it (by name), each
-- with its creatures in the order they had. A banner is { header = key, banner = true, name, count,
-- collapsed }; a group { header = key, name, count, collapsed, inBanner }; a folded one
-- (collapsed[key]) lists nothing under it.
function Filter.Grouped(items, collapsed)
    local groups, byKey, pinned = {}, {}, {}
    for _, item in ipairs(items) do
        if item.rec.pinned then
            pinned[#pinned + 1] = item
        else
            local key, name = Filter.GroupOf(item.rec)
            local group = byKey[key]
            if not group then
                group = { header = key, name = name, items = {} }
                group.bannerKey, group.bannerName = Filter.BannerOf(key)
                byKey[key] = group
                groups[#groups + 1] = group
            end
            group.items[#group.items + 1] = item
        end
    end
    -- Banners: each continent's, then dungeons and raids; a group with no banner is one itself.
    local banners, byBanner = {}, {}
    for _, group in ipairs(groups) do
        local key = group.bannerKey or group.header
        local banner = byBanner[key]
        if not banner then
            banner = { header = key, banner = true, name = group.bannerKey and group.bannerName or group.name, groups = {}, count = 0 }
            byBanner[key] = banner
            banners[#banners + 1] = banner
        end
        banner.count = banner.count + #group.items
        if group.bannerKey then banner.groups[#banner.groups + 1] = group else banner.items = group.items end
    end
    local function rank(banner)
        if banner.header == "none" then return 3 end
        if banner.header == "banner:instances" then return 2 end
        return 1
    end
    table.sort(banners, function(a, b)
        if rank(a) ~= rank(b) then return rank(a) < rank(b) end
        return a.name < b.name
    end)
    if #pinned > 0 then
        table.insert(banners, 1, { header = "pinned", banner = true, name = L.CFILTER_PINNED, items = pinned, groups = {},
            count = #pinned })
    end
    local out = {}
    local function addItems(list)
        for _, item in ipairs(list) do
            item.inGroup = true
            out[#out + 1] = item
        end
    end
    for _, banner in ipairs(banners) do
        banner.collapsed = collapsed[banner.header] == true
        out[#out + 1] = banner
        if not banner.collapsed then
            if banner.items then addItems(banner.items) end
            table.sort(banner.groups, function(a, b) return a.name < b.name end)
            for _, group in ipairs(banner.groups) do
                group.count, group.collapsed, group.inBanner = #group.items, collapsed[group.header] == true, true
                out[#out + 1] = group
                if not group.collapsed then addItems(group.items) end
                group.items = nil
            end
        end
        banner.groups, banner.items = nil, nil
    end
    return out
end

---------------------------------------------------------------------------
-- The filter menu's choices: only those some creature has
---------------------------------------------------------------------------

local function sortedKeys(set, label)
    local list = {}
    for key in pairs(set) do list[#list + 1] = { key, label and label(key) or key } end
    table.sort(list, function(a, b) return a[2] < b[2] end)
    return list
end

-- { { title, setKey, choices = { { value, label } } } } for the filter menu.
function Filter.Groups()
    local kinds, zones = {}, {}
    for _, rec in pairs(Book.Creatures()) do
        if rec.creatureType then kinds[rec.creatureType] = true end
        for mapID in pairs(rec.zones or {}) do zones[mapID] = true end
    end
    return {
        { L.CFILTER_REACTION, "reaction", REACTIONS },
        { L.CFILTER_RANK, "rank", RANKS },
        { L.CFILTER_KIND, "kind", sortedKeys(kinds) },
        { L.CFILTER_ZONE, "zone", sortedKeys(zones, Text.MapName), true },
        { L.CFILTER_OTHER, "other", OTHER },
    }
end

function Filter.Toggle(setKey, value)
    local set = Filter.sets[setKey]
    if type(set) ~= "table" then return end
    set[value] = not set[value] or nil
end
