--[[
    Forever Codex - tests/scenarios/compendium/openmap.lua
    Forever Codex with OpenMap, as OpenMap works with Questie (Modules/Map/OpenMap.lua): QuestieDB
    handed to OpenMap's townsfolk in Questie's shape while Questie isn't loaded (copied, its areas
    on their maps), Codex's map layers as switches in OpenMap's menu, the creatures met in a
    dungeon on its map card; Questie loaded takes the townsfolk back; locked off without OpenMap.
    Run by tests/run.lua (lua5.1 tests/run.lua openmap), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

local NPCS = { [3143] = { name = "Gornek", npcFlags = 4, spawns = { [14] = { { 40, 60 } } }, zoneID = 14 } }
local function entity(rows)
    local e = {}
    function e.Get(id, key) return rows[id] and rows[id][key] end
    function e.GetAllIds()
        local ids = {}
        for id in pairs(rows) do ids[#ids + 1] = id end
        return ids
    end
    return e
end
LibQuestieDB = { Quest = entity({}), Npc = entity(NPCS), Item = entity({}), Object = entity({}),
    Enum = { npcFlags = { VENDOR = 4, REPAIR = 16384 } },
    Support = { Get = function(name)
        if name == "ZoneDB" then return { private = { areaIdToUiMapId = "return { [14] = 1411 }" } } end
    end } }

-- OpenMap's API, as other addons see it.
local given = { toggles = {} }
OpenMapAPI = {
    ArtTopLevel = function() return 3000 end,
    RegisterCallback = function() end,
    RegisterTownsfolkProvider = function(owner, provider) given.owner, given.provider = owner, provider end,
    RegisterMenuToggle = function(owner, spec) given.toggles[spec.id] = spec end,
    RegisterDungeonSection = function(owner, fn) given.section = fn end,
}
W.loaded.OpenMap = true

W.Strict()
local ns = W.LoadAddon(root, "ForeverCodex")
login()
W.RunTimers()
local M = ns.modules.OpenMap
check(M.active and not M.locked, "on with OpenMap loaded")

-- Townsfolk: QuestieDB in Questie's shape.
local provider = given.provider
check(provider ~= nil and given.owner == "ForeverCodex", "OpenMap's townsfolk get QuestieDB without Questie")
eq(provider and provider.db.NPCPointers[3143], true, "every NPC it knows")
eq(provider and provider.db.npcFlags.VENDOR, 4, "with QuestieDB's flags")
local spawns = provider and provider.db.QueryNPCSingle(3143, "spawns")
eq(spawns and spawns[14][1][1], 40, "a field as Questie keeps it")
check(spawns ~= NPCS[3143].spawns, "copied, not QuestieDB's own table")
eq(provider and provider.zones:GetUiMapIdByAreaId(14), 1411, "an area's map")
eq(provider and provider.db.QueryNPCSingle(3143, "npcFlags"), 4, "its flags")

-- Codex's layers in OpenMap's menu.
local quests = given.toggles.QuestPins
check(quests ~= nil and given.toggles.RarePins ~= nil and given.toggles.CreatureAreas ~= nil, "three switches in its menu")
eq(quests.get(), ns.modules.QuestPins.db.enabled and true or false, "showing the layer's on/off")
quests.set(false)
eq(ns.modules.QuestPins.active, false, "the switch turns Quest Pins off")
quests.set(true)
check(ns.modules.QuestPins.active, "and on")

-- A dungeon's map card: the creatures met in it.
local creatures = ns.Book.Creatures()
creatures[100] = { name = "Ragefire Trogg", kills = 9, zones = { [213] = { cells = {} } } }
creatures[101] = { name = "Taragaman", kills = 1, zones = { [213] = { cells = {} } } }
creatures[102] = { name = "Elsewhere", kills = 50, zones = { [1411] = { cells = {} } } }
local title, lines = given.section({ mapID = 213 })
check(title ~= nil, "a section on the dungeon's card")
eq(lines and #lines, 2, "the creatures met there only")
check(lines and lines[1]:find("Ragefire Trogg", 1, true) == 1, "most killed first")
eq(given.section({ mapID = 999 }), nil, "none met: no section")

-- Questie loaded: OpenMap reads Questie's own.
W.loaded.Questie = true
ns:SetOption("OpenMap", "townsfolk", true)
ns:SetOption("OpenMap", "dungeons", false)
eq(given.provider, nil, "with Questie, ours is taken back")
eq(given.section, nil, "Creatures on Dungeon Maps off: the section goes")
ns:SetEnabled("OpenMap", false)
quests.set(false)
check(ns.modules.QuestPins.active, "off: the menu switch does nothing")
W.loaded.Questie, W.loaded.OpenMap, OpenMapAPI = nil, nil, nil
eq(#W.errors, 0, "no errors")
finish()
