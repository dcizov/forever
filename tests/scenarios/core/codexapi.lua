--[[
    Forever suite - tests/scenarios/core/codexapi.lua
    Forever Codex's public API: READY, module and option callbacks, and read-only getters.
    Run by tests/run.lua (lua5.1 tests/run.lua codexapi), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverCodex")
local api = ForeverCodexAPI and ForeverCodexAPI.v1
check(api ~= nil, "ForeverCodexAPI.v1 is there")

local ready = false
api.RegisterCallback("READY", function() ready = true end)
login()
check(ready, "READY once modules have started")

eq(api.GetVersion(), W.metadata.Version, "API version")
eq(api.IsModuleEnabled("Recorder"), true, "API module state")
eq(api.GetOption("Recorder", "learnCombat"), true, "API option")
eq(api.RegisterCallback("NO_SUCH_EVENT", function() end), nil, "an event the API doesn't have is refused")

local addonOf = {}
for _, row in ipairs(api.GetModules()) do addonOf[row.name] = row.addon end
eq(addonOf.Recorder, "ForeverCodex", "a Codex module says it's Forever Codex'")
eq(addonOf.Performance, nil, "Forever Gearbox's aren't listed")

local heard = {}
api.RegisterCallback("OPTION_CHANGED", function(_, name, key, value, addon) heard[#heard + 1] = { name, key, value, addon } end)
api.RegisterCallback("MODULE_TOGGLED", function(_, name, on) heard[#heard + 1] = { name, "toggled", on } end)
ns:SetOption("Recorder", "learnCombat", false)
eq(heard[1] and heard[1][1], "Recorder", "OPTION_CHANGED module")
eq(heard[1] and heard[1][2], "learnCombat", "OPTION_CHANGED key")
eq(heard[1] and heard[1][3], false, "with the new value")
eq(heard[1] and heard[1][4], "ForeverCodex", "and the addon the module belongs to")

ns:SetEnabled("MinimapButton", false)
eq(heard[2] and heard[2][1], "MinimapButton", "MODULE_TOGGLED")
eq(heard[2] and heard[2][3], false, "off")

finish()