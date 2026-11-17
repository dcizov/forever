--[[
    Forever Gearbox - Modules/Gathering/FishingZones.lua
    Fishing's zones
    The Fishing skill each zone's water needs before fish stop getting away, by zone map ID (the
    Classic zones' C_Map IDs): { inland, coast } where the coast (open sea, or the zone's deeper
    pools) needs more than the inland water, else { both }. Skill here is your rank plus the
    bonus from gear, lure and food, as the game counts it.

    Adapted from Forever++'s World Map zone info (Modules/Map/WorldMap/ZoneInfo/Data.lua, MIT,
    see LICENSE-ForeverPlusPlus.txt), which took them from Leatrix Maps' zone table. Zones with no
    fishing water (Searing Gorge, Badlands, Blasted Lands, ...) aren't here. Forever may change a
    zone: fix it here.
]]

local _, ns = ...

ns.FishingZones = {
    -- Eastern Kingdoms
    [1429] = { 1 },        -- Elwynn Forest
    [1426] = { 1 },        -- Dun Morogh
    [1420] = { 1 },        -- Tirisfal Glades
    [1432] = { 1 },        -- Loch Modan
    [1436] = { 1 },        -- Westfall
    [1421] = { 1 },        -- Silverpine Forest
    [1433] = { 55 },       -- Redridge Mountains
    [1431] = { 55 },       -- Duskwood
    [1424] = { 55 },       -- Hillsbrad Foothills
    [1437] = { 55 },       -- Wetlands
    [1416] = { 130 },      -- Alterac Mountains
    [1417] = { 130 },      -- Arathi Highlands
    [1434] = { 130, 205 }, -- Stranglethorn Vale
    [1435] = { 130 },      -- Swamp of Sorrows
    [1425] = { 205 },      -- The Hinterlands
    [1428] = { 330 },      -- Burning Steppes
    [1422] = { 205 },      -- Western Plaguelands
    [1423] = { 330 },      -- Eastern Plaguelands
    [1430] = { 330 },      -- Deadwind Pass
    [1453] = { 1 },        -- Stormwind City
    [1455] = { 1 },        -- Ironforge
    [1458] = { 1 },        -- Undercity
    -- Kalimdor
    [1411] = { 1 },        -- Durotar
    [1412] = { 1 },        -- Mulgore
    [1438] = { 1 },        -- Teldrassil
    [1439] = { 1 },        -- Darkshore
    [1413] = { 1 },        -- The Barrens
    [1442] = { 55 },       -- Stonetalon Mountains
    [1440] = { 55 },       -- Ashenvale
    [1441] = { 130 },      -- Thousand Needles
    [1443] = { 130 },      -- Desolace
    [1445] = { 130 },      -- Dustwallow Marsh
    [1444] = { 205, 330 }, -- Feralas
    [1446] = { 205 },      -- Tanaris
    [1447] = { 205, 330 }, -- Azshara
    [1448] = { 205 },      -- Felwood
    [1449] = { 205 },      -- Un'Goro Crater
    [1451] = { 330 },      -- Silithus
    [1452] = { 330 },      -- Winterspring
    [1450] = { 205 },      -- Moonglade
    [1457] = { 1 },        -- Darnassus
    [1454] = { 1 },        -- Orgrimmar
    [1456] = { 1 },        -- Thunder Bluff
}
