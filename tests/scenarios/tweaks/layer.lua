--[[
    Forever Tweaks - tests/scenarios/tweaks/layer.lua
    Layer Info reading layers from GUIDs.
    Run by tests/run.lua (lua5.1 tests/run.lua layer), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root
local ns

W.Strict()
ns = W.LoadAddon(root, "ForeverTweaks")
login()
local mod, api = ns.modules.LayerInfo, ForeverTweaksAPI.v1
local heard
api.RegisterCallback("LAYER_CHANGED", function(_, zone, number) heard = { zone, number } end)
local function layer() return (mod:GetLayer()) end
local function stale() return select(3, mod:GetLayer()) end
check(stale(), "stale until an NPC is read")
-- The stand-in's target is "Creature-0-4618-0-3041-3296-0000ABCDEF": zone UID 3041.
W.Fire("PLAYER_TARGET_CHANGED")
eq(layer(), 3041, "zone UID read from the target's GUID")
eq(stale(), false, "fresh once read")
eq(heard, nil, "the first reading isn't a change")
check(ForeverTweaksLayer.current:find("3041", 1, true) ~= nil, "shown on screen")
W.units.target = "Player-4618-0ABCDEF0"
W.Fire("PLAYER_TARGET_CHANGED")
eq(layer(), 3041, "a player's GUID is ignored")
W.units.target = "Creature-0-4618-0-0-3296-0000ABCDEF"
W.Fire("PLAYER_TARGET_CHANGED")
eq(layer(), 3041, "a zone UID of 0 is ignored")
W.units.target = "Creature-0-4618-0-9999-3296-0000ABCDEF"
W.secrets[W.units.target] = true
W.Fire("PLAYER_TARGET_CHANGED")
eq(layer(), 3041, "a secret GUID is skipped")
W.Fire("ZONE_CHANGED_NEW_AREA")
eq(stale(), true, "stale after a zone change")
check(ForeverTweaksLayer.current:find("?", 1, true) ~= nil, "shown as unsure")
-- While stale, nameplates are read too.
W.units.nameplate1 = "Vehicle-0-4618-0-3050-3296-0000ABCDEF"
_G.NWB_CurrentLayer = 2
W.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
eq(layer(), 3050, "read from a nameplate")
eq(heard and heard[1], 3050, "LAYER_CHANGED with the zone UID")
eq(heard and heard[2], 2, "and Nova World Buffs' number")
check(ForeverTweaksLayer.current:find("Layer 2", 1, true) ~= nil, "Nova World Buffs' number shown")
W.units.nameplate1 = "Creature-0-4618-0-3060-3296-0000ABCDEF"
W.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
eq(layer(), 3050, "nameplates rest once the layer is known")
W.units.mouseover = "Creature-0-4618-0-3060-3296-0000ABCDEF"
W.Fire("UPDATE_MOUSEOVER_UNIT")
eq(layer(), 3060, "read from the mouseover")
eq(api.GetLayer(), 3060, "API layer")
heard = nil
ns:SetOption("LayerInfo", "size", 14)
eq(heard, nil, "an option change isn't a layer change")
_G.NWB_CurrentLayer = nil
finish()
