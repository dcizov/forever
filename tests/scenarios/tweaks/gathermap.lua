--[[
    Forever Tweaks - tests/scenarios/tweaks/gathermap.lua
    Gathering Map: a gather counted only once its cast succeeds, the same node merged and its spot
    averaged, a secret target named by the soft-target object, nothing in instances; the world
    map's pins (kinds, Shift+right-click to forget, sized against the canvas's scale); the minimap's
    pins within its reach only; and nothing recorded while Forever++'s own is on.
    Run by tests/run.lua (lua5.1 tests/run.lua gathermap), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverTweaks")
W.spells[2366], W.spells[2575] = "Herb Gathering", "Mining"
W.spells[2368] = "Herb Gathering" -- a higher rank, the same name
login()
local mod = ns.modules.GatherMap
local MAP = 1411
W.mapSizes[MAP] = { 1000, 1000 } -- yards
W.place, W.mapID = { map = MAP, x = 0.5, y = 0.5 }, MAP

local function gather(spellID, target, cast, succeed)
    W.Fire("UNIT_SPELLCAST_SENT", "player", target, cast, spellID)
    if succeed ~= false then W.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", cast, spellID) end
end
local function nodes() return mod.db.nodes[MAP] or {} end

gather(2366, "Peacebloom", "c1")
eq(#nodes(), 1, "a herb gathered: remembered")
eq(nodes()[1].kind, "herb", "as a herb")
gather(2366, "Silverleaf", "c2", false)
eq(#nodes(), 1, "a cast that didn't go off counts for nothing")
W.place.x = 0.51 -- 10 yards on
gather(2368, "Peacebloom", "c3")
eq(#nodes(), 1, "the same node again, any rank: merged")
eq(nodes()[1].count, 2, "counted twice")
eq(nodes()[1].x, 0.505, "its spot moved to the average")
W.place.x = 0.6
gather(2575, "Copper Vein", "c4")
eq(#nodes(), 2, "a vein elsewhere: a new node")
local secret = "Tin Vein"
W.secrets[secret] = true
W.softObject = { name = "Tin Vein (soft)" }
gather(2575, secret, "c5")
eq(nodes()[3] and nodes()[3].name, "Tin Vein (soft)", "a secret target: named by the soft-target object")
W.secrets[secret], W.softObject = nil, nil
W.instance = true
gather(2366, "Peacebloom", "c6")
eq(#nodes(), 3, "nothing in an instance")
W.instance = false

-- The world map: one pin per node of a shown kind, at the canvas's scale.
W.worldMapID, W.canvasScale = MAP, 2
WorldMapFrame:Show()
WorldMapFrame:OnMapChanged()
W.RunTimers()
local function worldPins()
    local list = {}
    for _, f in ipairs(W.frames) do
        local spec = rawget(f, "spec")
        if spec and spec.node and f._kind == "Button" and f:IsShown() then list[#list + 1] = f end
    end
    return list
end
eq(#worldPins(), 3, "every node on the map")
eq(worldPins()[1]._width, 8, "16 px at canvas scale 2")
ns:SetOption("GatherMap", "ore", false)
W.RunTimers()
eq(#worldPins(), 1, "ore hidden: only the herb")
ns:SetOption("GatherMap", "ore", true)
W.RunTimers()
local herb
for _, pin in ipairs(worldPins()) do if pin.spec.node.name == "Peacebloom" then herb = pin end end
W.shift = true
herb:Fire("OnClick", "RightButton")
W.shift = false
W.RunTimers()
eq(#nodes(), 2, "Shift+right-click forgets it")
check(W.LastChat():find("Peacebloom", 1, true) ~= nil, "and says so")

-- The minimap: only nodes within its reach (233 yards at zoom 0, outdoors).
W.place = { map = MAP, x = 0.6, y = 0.5 }
mod.db.nodes[MAP][#mod.db.nodes[MAP] + 1] = { name = "Far Vein", kind = "ore", x = 0.95, y = 0.5, count = 1, last = 0 }
W.Fire("ZONE_CHANGED_NEW_AREA")
W.Advance(0.3)
local near = 0
for _, f in ipairs(W.frames) do
    if rawget(f, "spec") and f._kind == "Frame" and f:IsShown() then near = near + 1 end
end
eq(near, 2, "the two near veins on the minimap, not the one 350 yards off")

-- Kept inside the minimap's edge, round or square, turned with it, and placed by the game's
-- view radius (233.33 yards outdoors at zoom 0 here: on the stand-in's 100 px minimap, 50 px
-- from centre to edge, 0.214 px a yard; a 12 px icon may come 45.2 px out).
local function mini(name)
    for _, f in ipairs(W.frames) do
        local spec = rawget(f, "spec")
        if spec and spec.node.name == name and f._kind == "Frame" and f:IsShown() then return f end
    end
end
local PER_YARD = 50 / 233.33
local list = mod.db.nodes[MAP]
for i = #list, 1, -1 do list[i] = nil end
W.place = { map = MAP, x = 0.5, y = 0.5 }
list[1] = { name = "East Vein", kind = "ore", x = 0.7, y = 0.5, count = 1, last = 0 } -- 200 yd east: 42.9 px
list[2] = { name = "Rim Vein", kind = "ore", x = 0.72, y = 0.5, count = 1, last = 0 } -- 47.1 px: on the rim
list[3] = { name = "Corner Vein", kind = "ore", x = 0.66, y = 0.66, count = 1, last = 0 } -- 34.3 px each way
W.Fire("ZONE_CHANGED")
W.Advance(0.1)
local east = mini("East Vein")
local _
local x, y = 0, 0
if east then _, _, _, x, y = east:GetPoint(1) end
check(east and math.abs(x - 200 * PER_YARD) < 0.01 and math.abs(y) < 0.01, "200 yards east: right of the centre")
eq(mini("Rim Vein"), nil, "an icon that would cross the rim isn't drawn")
eq(mini("Corner Vein"), nil, "a round minimap: the corner is outside")
GetMinimapShape = function() return "SQUARE" end
W.Advance(0.1)
check(mini("Corner Vein") ~= nil, "a square minimap: its corner is inside")
GetMinimapShape = nil
W.cvars.rotateMinimap, W.facing = "1", math.pi / 2 -- facing west: east is behind you
W.Advance(0.1)
_, _, _, x, y = mini("East Vein"):GetPoint(1)
check(math.abs(x) < 0.01 and math.abs(y + 200 * PER_YARD) < 0.01, "Rotate Minimap: what's behind you is below the centre")
W.cvars.rotateMinimap, W.facing = "0", nil
W.viewRadius = 400 -- zoomed out: 0.125 px a yard
W.Advance(0.1)
_, _, _, x = mini("East Vein"):GetPoint(1)
check(math.abs(x - 25) < 0.01, "zoomed out: closer to the centre")
check(mini("Rim Vein") ~= nil, "and the rim vein comes in")
W.viewRadius = nil
W.place = { map = MAP, x = 0, y = 0 }
W.Advance(0.1)
eq(mini("East Vein"), nil, "the game doesn't know where you are (0, 0): nothing")
W.place = { map = MAP, x = 0.5, y = 0.5 }

-- Forever++'s Gathering Map on: ours records and draws nothing.
W.loaded.ForeverPlusPlus = true
ForeverPlusPlusAPI = { v1 = { IsModuleEnabled = function(name) return name == "GatheringMap" end } }
local before = #nodes()
gather(2366, "Mageroyal", "c7")
eq(#nodes(), before, "left to Forever++: nothing recorded")
check(mod:DebugLine():find("nodes", 1, true) ~= nil, "Debug line")
eq(#W.errors, 0, "no errors")
finish()
