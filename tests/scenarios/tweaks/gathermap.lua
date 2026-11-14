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

-- Forever++'s Gathering Map on: ours records and draws nothing.
W.loaded.ForeverPlusPlus = true
ForeverPlusPlusAPI = { v1 = { IsModuleEnabled = function(name) return name == "GatheringMap" end } }
local before = #nodes()
gather(2366, "Mageroyal", "c7")
eq(#nodes(), before, "left to Forever++: nothing recorded")
check(mod:DebugLine():find("nodes", 1, true) ~= nil, "Debug line")
eq(#W.errors, 0, "no errors")
finish()
