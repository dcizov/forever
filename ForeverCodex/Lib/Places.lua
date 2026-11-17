--[[
    Forever Codex - Lib/Places.lua
    Where things are: the player's place on the map, and the coarse grid the journal keeps places
    in. A map is cut into GRID x GRID cells; a place is stored as how often it was seen in a cell,
    so the saved data stays small however long one plays, and a creature's area can be drawn from
    it (the map pins). Only the player's own place is known (the game gives no unit positions),
    so a creature's place is where the player was when it was seen: close enough at nameplate range.
]]

local _, ns = ...

local math = math
local Plain = ns.Plain

local Places = {}
ns.Places = Places

Places.GRID = 40
local GRID = Places.GRID
local MAX_COUNT = 255 -- how often one cell counts at most

-- The map the player is on and their place on it (0..1), or nil (an instance, a taxi with no
-- map, a secret value).
function Places.Here()
    local mapID = Plain(C_Map.GetBestMapForUnit("player"))
    if not mapID then return nil end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return nil end
    local x, y = pos:GetXY()
    x, y = Plain(x), Plain(y)
    if not (x and y) or (x == 0 and y == 0) then return nil end
    return mapID, x, y
end

function Places.Cell(x, y)
    local cx = math.min(GRID - 1, math.max(0, math.floor(x * GRID)))
    local cy = math.min(GRID - 1, math.max(0, math.floor(y * GRID)))
    return cy * GRID + cx + 1
end

-- The centre of a cell, 0..1 on its map.
function Places.CellCenter(cell)
    local i = cell - 1
    return (i % GRID + 0.5) / GRID, (math.floor(i / GRID) + 0.5) / GRID
end

-- Counts one sighting at (x, y) on `mapID` in `zones` ({ [mapID] = { cells = { [cell] = n } } }).
-- Returns that map's entry.
function Places.Add(zones, mapID, x, y)
    local zone = zones[mapID]
    if not zone then
        zone = { cells = {} }
        zones[mapID] = zone
    end
    local cell = Places.Cell(x, y)
    zone.cells[cell] = math.min(MAX_COUNT, (zone.cells[cell] or 0) + 1)
    return zone
end

-- Puts Blizzard's map pin (the user waypoint, tracked) at (x, y) on `mapID` and opens the map
-- there. Returns whether the map takes a pin (an instance's doesn't: the map opens alone).
function Places.Waypoint(mapID, x, y)
    OpenWorldMap(mapID)
    if not C_Map.CanSetUserWaypointOnMap(mapID) then return false end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    return true
end
