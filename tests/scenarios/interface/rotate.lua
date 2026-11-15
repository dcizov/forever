--[[
    Forever Tweaks - tests/scenarios/interface/rotate.lua
    Console variables a module keeps while on (Lib/CVars.lua). Rotate Minimap: off by default; on,
    it sets rotateMinimap and sets it again after the game resets it on a loading screen; off, the
    player's own value comes back. Loot Sparkle: set again a second after a graphics preset turns
    it off; off, the player's value back, unless they changed it since; nothing while Forever++'s
    own is on.
    Run by tests/run.lua (lua5.1 tests/run.lua rotate), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
W.cvars.rotateMinimap = "0"
W.cvars.outlineModeShowLootEffectWhenDisabled = "0"
local ns = W.LoadAddon(root, "ForeverTweaks")
login()
check(not ns.modules.RotateMinimap.active, "off until turned on")
eq(W.cvars.rotateMinimap, "0", "so the minimap stays as it was")
ns:SetEnabled("RotateMinimap", true)
eq(W.cvars.rotateMinimap, "1", "on: the minimap turns with you")
W.cvars.rotateMinimap = "0" -- the game resets it at login
W.Fire("PLAYER_ENTERING_WORLD")
eq(W.cvars.rotateMinimap, "1", "set again after a loading screen")
ns:SetEnabled("RotateMinimap", false)
eq(W.cvars.rotateMinimap, "0", "off: the player's own value back")

-- Loot Sparkle.
local SPARKLE = "outlineModeShowLootEffectWhenDisabled"
ns:SetEnabled("LootSparkle", true)
eq(W.cvars[SPARKLE], "1", "on: the sparkle shows")
W.cvars[SPARKLE] = "0" -- a graphics preset
W.Fire("CVAR_UPDATE", SPARKLE, "0")
eq(W.cvars[SPARKLE], "0", "not at once: the preset may still be setting things")
W.Advance(1)
eq(W.cvars[SPARKLE], "1", "a second later: on again")
ns:SetEnabled("LootSparkle", false)
eq(W.cvars[SPARKLE], "0", "off: the player's own value back")
ns:SetEnabled("LootSparkle", true)
W.cvars[SPARKLE] = "2" -- the player sets something else themselves... then turns the module off
ns:SetEnabled("LootSparkle", false)
eq(W.cvars[SPARKLE], "2", "a value the player set since is theirs to keep")
W.cvars[SPARKLE] = "0"
W.loaded.ForeverPlusPlus = true
ForeverPlusPlusAPI = { v1 = { IsModuleEnabled = function(n) return n == "QuestItemSparkles" end } }
ns:SetEnabled("LootSparkle", true)
eq(W.cvars[SPARKLE], "0", "left to Forever++'s Quest Item Sparkles")
eq(#W.errors, 0, "no errors")
finish()
