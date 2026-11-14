--[[
    Forever Compendium - Modules/Data/ImportCreatures.lua
    Bestiary Import's creatures (Import.lua runs it): one Forever Bestiary creature entry made
    into the journal's. Counts take the larger of the two (kills, corpses, deaths, money, each
    item's drops), so nothing counted by both is counted twice; dates the earlier first and the
    later last; places on Bestiary's 100 x 100 grid fold into the journal's (Places.lua); notes
    are joined into the creature's note; a pin (not one Bestiary made for a quest) comes along.
]]

local _, ns = ...

local pairs, ipairs, type, math, table = pairs, ipairs, type, math, table
local Book, Places = ns.Book, ns.Places

local ImportCreatures = {}
ns.ImportCreatures = ImportCreatures

local REACTION = { hostile = 2, neutral = 4, friendly = 5 }
local KIND = { dungeon = "party", raid = "raid" }

local function larger(rec, key, value)
    if type(value) == "number" and value > (rec[key] or 0) then rec[key] = value end
end

local function earliest(rec, key, value)
    if type(value) == "number" and (not rec[key] or value < rec[key]) then rec[key] = value end
end

local function latest(rec, key, value)
    if type(value) == "number" and value > (rec[key] or 0) then rec[key] = value end
end

-- Bestiary's spots (a 100 x 100 grid, cell = row * 100 + column) folded into the journal's grid.
local function importSpots(rec, e)
    for mapID, cells in pairs(e.spots or {}) do
        rec.zones[mapID] = rec.zones[mapID] or { cells = {} }
        local zone = rec.zones[mapID]
        for cell, weight in pairs(cells) do
            local x, y = (cell % 100 + 0.5) / 100, (math.floor(cell / 100) + 0.5) / 100
            local ours = Places.Cell(x, y)
            zone.cells[ours] = math.min(255, (zone.cells[ours] or 0) + math.max(1, math.floor(weight / 2)))
            local sub = e.spotSubs and e.spotSubs[mapID] and e.spotSubs[mapID][cell]
            if sub then
                zone.sub = zone.sub or {}
                zone.sub[sub] = true
            end
        end
    end
    for zoneName, subs in pairs(e.zones or {}) do
        local mapID = e.zoneMaps and e.zoneMaps[zoneName]
        local kind = e.zoneKinds and KIND[e.zoneKinds[zoneName]]
        if mapID then
            rec.zones[mapID] = rec.zones[mapID] or { cells = {} }
            for sub in pairs(subs) do
                rec.zones[mapID].sub = rec.zones[mapID].sub or {}
                rec.zones[mapID].sub[sub] = true
            end
        elseif kind then
            Book.Mark(rec, "instances", zoneName, kind)
        end
    end
end

local function importLoot(rec, e)
    rec.loot = rec.loot or {}
    for itemID, item in pairs(e.loot or {}) do
        if type(itemID) == "number" and type(item) == "table" then
            Book.SetItem(itemID, item.name, item.quality, item.icon)
            local drops = item.drops or 0
            if drops > (rec.loot[itemID] or 0) then rec.loot[itemID] = drops end
        end
    end
    larger(rec, "looted", e.looted)
    if type(e.money) == "table" then
        larger(rec, "money", e.money.total)
        larger(rec, "moneyCorpses", e.money.drops)
    end
    for itemID, ware in pairs(e.wares or {}) do
        if type(itemID) == "number" and type(ware) == "table" then
            Book.SetItem(itemID, ware.name, ware.quality, ware.icon)
            rec.wares = rec.wares or {}
            rec.wares[itemID] = rec.wares[itemID] or { price = ware.price or 0, stack = ware.stack or 1, limited = ware.limited }
        end
    end
end

local function importFight(rec, e)
    for _, a in ipairs(e.abilities or {}) do
        if type(a.spellID) == "number" then Book.Mark(rec, "abilities", a.spellID) end
    end
    for school, kind in pairs(e.defenses or {}) do
        if kind == "resist" or kind == "immune" then Book.Mark(rec, "defenses", school, kind) end
    end
    for faction, r in pairs(e.rep or {}) do
        rec.rep = rec.rep or {}
        if not rec.rep[faction] and type(r) == "table" then
            rec.rep[faction] = { total = r.total or 0, count = r.count or 0, min = r.min or 0, max = r.max or 0 }
        end
    end
    larger(rec, "deaths", e.deaths)
    larger(rec, "kills", e.kills)
    earliest(rec, "firstKill", e.firstKill)
    latest(rec, "lastKill", e.lastKill)
end

local function importNotes(rec, e)
    if rec.note or type(e.notes) ~= "table" then return end
    local parts = {}
    for _, n in ipairs(e.notes) do
        local title, text = n.title or "", n.text or ""
        parts[#parts + 1] = title ~= "" and (title .. "\n" .. text) or text
    end
    if #parts > 0 then rec.note = table.concat(parts, "\n\n") end
end

-- Brings Bestiary entry `e` (named `name`) in as creature `npcID`. Returns whether it was new.
function ImportCreatures.Import(npcID, name, e, faction)
    local rec, isNew = Book.Meet(npcID, name)
    if type(e.minLevel) == "number" then rec.minLevel = math.min(rec.minLevel or e.minLevel, e.minLevel) end
    if type(e.maxLevel) == "number" then rec.maxLevel = math.max(rec.maxLevel or e.maxLevel, e.maxLevel) end
    rec.skull = rec.skull or e.skull
    rec.classification = rec.classification or e.class
    rec.creatureType = rec.creatureType or (e.ctype ~= "Not specified" and e.ctype or nil)
    rec.family = rec.family or (type(e.pet) == "table" and e.pet.family or nil)
    rec.reaction = rec.reaction or REACTION[e.disp and e.disp[faction] or ""]
    rec.title = rec.title or e.title
    earliest(rec, "first", e.firstSeen)
    latest(rec, "last", e.lastSeen)
    for _, v in ipairs(e.variants or {}) do
        if type(v.displayID) == "number" then
            Book.Mark(rec, "displays", v.displayID)
            rec.display = rec.display or v.displayID
        end
    end
    importSpots(rec, e)
    importLoot(rec, e)
    importFight(rec, e)
    importNotes(rec, e)
    if e.pinned and not e.autoPinned then rec.pinned = true end
    return isNew
end

