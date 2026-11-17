--[[
    Forever Gearbox - tests/scenarios/interface/nameplatedistance.lua
    Nameplate Distance: preset behavior, resting transitions, queueing through combat, and
    restoring the original value when the module is turned off.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.cvars.nameplateMaxDistance = "60"
W.cvarDefaults.nameplateMaxDistance = "45"

local ns = W.LoadAddon(root, "ForeverGearbox")
login()
local M = ns.modules.NameplateDistance

-- Off: leave the CVar alone.
eq(W.cvars.nameplateMaxDistance, "60", "module off: no CVar change")
W.resting = false
ns:SetEnabled("NameplateDistance", true)
eq(W.cvars.nameplateMaxDistance, "45", "turn on while active: normal distance")
eq(M.db.original, "60", "records the original value once on first write")

W.resting = true
W.Fire("PLAYER_UPDATE_RESTING")
eq(W.cvars.nameplateMaxDistance, "25", "resting uses the shorter distance")
W.resting = false
W.Fire("PLAYER_UPDATE_RESTING")
eq(W.cvars.nameplateMaxDistance, "45", "active uses the normal distance")

W.combat = true
W.resting = true
W.Fire("PLAYER_UPDATE_RESTING")
eq(W.cvars.nameplateMaxDistance, "45", "combat never writes the CVar")
W.combat = false
W.Fire("PLAYER_REGEN_ENABLED")
eq(W.cvars.nameplateMaxDistance, "25", "combat-end apply writes the pending value exactly once")

W.resting = true
ns:SetOption("NameplateDistance", "restingDistance", 30)
eq(W.cvars.nameplateMaxDistance, "30", "resting slider applies immediately")
W.resting = false
ns:SetOption("NameplateDistance", "normalDistance", 60)
eq(W.cvars.nameplateMaxDistance, "60", "normal slider applies immediately")

ns:SetEnabled("NameplateDistance", false)
eq(W.cvars.nameplateMaxDistance, "60", "disable restores the original value")
W.resting = true
W.Fire("PLAYER_UPDATE_RESTING")
eq(W.cvars.nameplateMaxDistance, "60", "off: no further changes while disabled")

finish()
