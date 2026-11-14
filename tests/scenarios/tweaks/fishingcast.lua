--[[
    Forever Tweaks - tests/scenarios/tweaks/fishingcast.lua
    Fishing Cast: a double right-click on the world with a pole arms Fishing on the right mouse
    button (once released), the cast takes it off, a slow second click or a creature under the
    mouse doesn't, Apply Lure puts a lure on a bare pole first, nothing is armed or changed in
    combat, Louder Bobber's volumes come back, and Forever++'s own Fishing Cast is left to.
    Run by tests/run.lua (lua5.1 tests/run.lua fishingcast), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverTweaks")
login()
W.items["[Strong Fishing Pole]"] = { id = 6365, class = 2, subclass = 20 }
W.items["[Shiny Bauble]"] = { id = 6529, stack = 20, class = 0 }
W.equipped[16] = 6365

local function armed() return W.bindings.BUTTON2 end

-- Releasing the first right-click arms Fishing for the second (the binding has to be in place
-- before its press); without a second one it comes off again. The cast takes it off too.
W.RightClick()
eq(armed() and armed().spell, "Fishing", "the first quick click: Fishing ready for the second")
W.Advance(0.5)
eq(armed(), nil, "no second click: off again")
W.RightClick(1)
W.RightClick(0.2)
eq(armed() and armed().spell, "Fishing", "the second click finds it")
W.Fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast", 7620)
eq(armed(), nil, "the cast takes it off: the bobber's right-click loots")

-- Too slow, a creature under the mouse, moving, or no pole: nothing.
W.Advance(1)
W.Fire("GLOBAL_MOUSE_DOWN", "RightButton")
W.Advance(0.5)
W.Fire("GLOBAL_MOUSE_UP", "RightButton")
eq(armed(), nil, "a press held too long: nothing")
W.unitExists.mouseover = true
W.RightClick(1)
W.RightClick(0.2)
eq(armed(), nil, "a creature under the mouse: nothing")
W.unitExists.mouseover = nil
W.equipped[16] = nil
W.RightClick(1)
W.RightClick(0.2)
eq(armed(), nil, "no pole: nothing")
W.equipped[16] = 6365

-- Apply Lure: a bare pole and a lure in the bags, so the double-click puts it on.
W.owned[6529] = 3
W.RightClick(1)
W.RightClick(0.2)
eq(armed() and armed().click, "ForeverTweaksLureButton", "a bare pole: the lure first")
local button = ForeverTweaksLureButton
eq(button:GetAttribute("item"), "item:6529", "the lure from the bags")
eq(button:GetAttribute("target-slot"), 16, "on the main hand")
W.Fire("UNIT_SPELLCAST_START", "player")
W.lure = 600000
W.RightClick(1)
W.RightClick(0.2)
eq(armed() and armed().spell, "Fishing", "a lure on: casts")
W.Fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast", 7620)

-- Combat: nothing armed, a warning, and a binding from before comes off once it's over.
local warned = #W.uiErrors
W.RightClick(1)
W.RightClick(0.2)
W.Fire("PLAYER_REGEN_DISABLED")
W.combat = true
check(W.uiErrors[#W.uiErrors] == ns.L.FCAST_COMBAT_TEXT and #W.uiErrors == warned + 1, "warned of combat with the pole")
W.RightClick(1)
W.RightClick(0.2)
W.combat = false
W.Fire("PLAYER_REGEN_ENABLED")
eq(armed(), nil, "the binding from before combat came off after it")

-- Louder Bobber: up while fishing, your own values back after.
W.cvars.Sound_EnableSFX, W.cvars.Sound_SFXVolume, W.cvars.Sound_MusicVolume = "0", "0.4", "0.8"
ns:SetOption("FishingCast", "louderBobber", true)
W.Fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast", 7620)
eq(W.cvars.Sound_SFXVolume, "1", "sound effects up while fishing")
eq(W.cvars.Sound_MusicVolume, "0.1", "music down")
W.Fire("UNIT_SPELLCAST_CHANNEL_STOP", "player")
W.Advance(6)
eq(W.cvars.Sound_SFXVolume, "0.4", "your own volume back after")
eq(W.cvars.Sound_EnableSFX, "0", "and your own sound setting")

-- Forever++'s Fishing Cast on: ours arms nothing.
W.loaded.ForeverPlusPlus = true
ForeverPlusPlusAPI = { v1 = { IsModuleEnabled = function(name) return name == "FishingCast" end } }
W.RightClick(1)
W.RightClick(0.2)
eq(armed(), nil, "left to Forever++'s Fishing Cast")
eq(#W.errors, 0, "nothing touched in combat, no errors")
eq(#W.blocked, 0, "no protected frame changed in combat")
finish()
