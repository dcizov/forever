--[[
    Forever Tweaks - tests/scenarios/tweaks/outfits.lua
    Fishing's outfit: saving keeps only the fishing slots (and the off hand with the main hand),
    wearing saves your usual gear first and swapping back puts it on, an outfit taken off by hand,
    no swaps in combat, Combat Weapons, no Equipment Manager, and moving 1.8.0's Profession Outfits
    settings and character data over to Fishing.
    Run by tests/run.lua (lua5.1 tests/run.lua outfits), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local POLE, SWORD, SHIELD, HAT, HELM, CHEST, BETTER_CHEST = 6365, 2131, 2129, 19972, 7413, 2580, 4000
W.items["[Strong Fishing Pole]"] = { id = POLE, class = 2, subclass = 20 }
W.items["[Short Sword]"] = { id = SWORD, class = 2, subclass = 7 }
W.items["[Lucky Fishing Hat]"] = { id = HAT, class = 4, subclass = 1 }
W.tooltips[HAT] = { "Lucky Fishing Hat", "Equip: Increased Fishing +5." }
W.tooltips[CHEST] = { "Fine Chest", "Requires Fishing (1)" } -- names Fishing, adds nothing
W.profs[1] = { name = "Mining", rank = 50, maxRank = 75, line = 186 }
W.profs[2] = { name = "Tailoring", rank = 50, maxRank = 75, line = 197 }
W.profs[4] = { name = "Fishing", rank = 100, maxRank = 150, line = 356 }
-- What's worn: the usual gear.
W.equipped = { [1] = HELM, [5] = CHEST, [16] = SWORD, [17] = SHIELD }

-- Saved by 1.8.0, with Profession Outfits on, Combat Weapons off and the outfit on.
ForeverTweaksDB = { version = 8, installed = "1.8.0",
    settings = { ProfessionOutfits = { combatWeapons = false } }, data = { ProfessionOutfits = {} },
    seenModules = { ProfessionOutfits = "1.8.0" } }
ForeverTweaksCharDB = { data = { ProfessionOutfits = { state = { wearing = 356 } } } }

local ns = W.LoadAddon(root, "ForeverTweaks")
login()
local mod = ns.modules.Fishing
eq(ns.modules.ProfessionOutfits, nil, "Profession Outfits is part of Fishing now")
eq(ForeverTweaksDB.settings.ProfessionOutfits, nil, "its settings gone")
eq(ForeverTweaksDB.seenModules.ProfessionOutfits, nil, "and its NEW mark")
eq(mod.db.combatWeapons, false, "Combat Weapons off, as it was")
eq(ForeverTweaksCharDB.data.ProfessionOutfits, nil, "its character data gone")
eq(ForeverTweaksCharDB.version, ns.member.charLayout, "the character file is at the current layout")
eq(mod.db.state.wearing, 356, "which outfit is on moved to Fishing")
ns:SetOption("Fishing", "combatWeapons", true)
check(mod.active, "on")
-- Saved as on, but no outfit exists: the toggle doesn't put an old Usual on.
eq(W.equipped[16], SWORD, "the sword in hand")
local function setNamed(name)
    for _, set in pairs(W.sets) do if set.name == name then return set end end
end

-- Saving: put the pole and hat on, then save.
W.Slash("/ft outfit save")
eq(setNamed("FT Fishing"), nil, "nothing that helps Fishing on: nothing saved")
W.equipped[16], W.equipped[17], W.equipped[1] = POLE, nil, HAT
W.Slash("/ft outfit save")
local outfit = setNamed("FT Fishing")
check(outfit ~= nil, "saved as the game's equipment set FT Fishing")
eq(outfit.items[16], POLE, "the pole is in it")
eq(outfit.items[1], HAT, "and the hat (its tooltip adds Fishing)")
eq(outfit.ignored[17], nil, "the off hand goes with the main hand")
eq(outfit.ignored[5], true, "the chest (which only names Fishing) is left out")

-- Back to the usual gear by hand, then a better chest piece.
W.equipped[16], W.equipped[17], W.equipped[1], W.equipped[5] = SWORD, SHIELD, HELM, BETTER_CHEST

-- Wearing: the usual gear is saved first, then the outfit goes on.
W.Slash("/ft outfit")
eq(W.equipped[16], POLE, "the pole goes on")
eq(W.equipped[1], HAT, "and the hat")
eq(W.equipped[17], nil, "the off hand comes off with it")
eq(W.equipped[5], BETTER_CHEST, "the chest isn't touched")
local usual = setNamed("FT Usual")
eq(usual and usual.items[16], SWORD, "your weapon is saved in FT Usual")
eq(usual and usual.items[17], SHIELD, "and your shield")
eq(usual and usual.ignored[5], true, "but only the outfit's slots")

-- Combat Weapons: the usual weapons for the fight, the pole back after.
W.combat = true
W.Fire("PLAYER_REGEN_DISABLED")
eq(W.equipped[16], SWORD, "combat with a pole: the sword goes on")
eq(W.equipped[17], SHIELD, "and the shield")
W.Slash("/ft outfit")
eq(W.equipped[16], SWORD, "no swapping in combat")
W.combat = false
W.Fire("PLAYER_REGEN_ENABLED")
eq(W.equipped[16], POLE, "after combat the pole comes back")

-- Swapping back.
W.Slash("/ft outfit")
eq(W.equipped[16], SWORD, "toggling again puts the sword back")
eq(W.equipped[17], SHIELD, "and the shield")
eq(W.equipped[1], HELM, "and the usual helm")
eq(W.equipped[5], BETTER_CHEST, "the better chest stays")

-- The outfit taken off by hand: the next swap puts it on again (saving the gear you have on now
-- as Usual) instead of putting the old Usual gear back.
W.Slash("/ft outfit")
eq(W.equipped[16], POLE, "the outfit on again")
local AXE = 2132
W.equipped[16], W.equipped[17], W.equipped[1] = AXE, nil, HELM
W.Slash("/ft outfit")
eq(W.equipped[16], POLE, "taken off by hand: the toggle puts the pole on, not the old sword")
eq(setNamed("FT Usual").items[16], AXE, "and the axe you had on is the usual weapon now")
W.Slash("/ft outfit")
eq(W.equipped[16], AXE, "swapping back gives the axe")

-- Only Fishing has an outfit now.
W.Slash("/ft outfit save mining")
eq(setNamed("FT Mining"), nil, "no other profession's outfit")
eq(W.equipped[16], AXE, "an unknown word doesn't swap")

-- The Fishing line's menu swaps it too.
local function menuEntry(label)
    ForeverTweaksFishing:Fire("OnMouseUp", "RightButton")
    return W.menu:Find(label)
end
local entry = menuEntry(ns.L.OUTFITS_WEAR_FISHING)
check(entry ~= nil, "the menu offers the outfit")
entry.fn()
eq(W.equipped[16], POLE, "and puts it on")
check(menuEntry(ns.L.OUTFITS_WEAR_USUAL) ~= nil, "then offers the usual gear")
W.Slash("/ft outfit usual")
eq(W.equipped[16], AXE, "/ft outfit usual puts it back")

-- Combat Weapons with a pole put on by hand (the outfit not on): it still comes back.
W.equipped[16] = POLE
W.combat = true
W.Fire("PLAYER_REGEN_DISABLED")
eq(W.equipped[16], AXE, "combat with a pole: the usual weapon goes on")
W.combat = false
W.Fire("PLAYER_REGEN_ENABLED")
eq(W.equipped[16], POLE, "and the pole comes back, outfit or not")
W.Slash("/ft outfit usual")

-- No Equipment Manager.
W.setsUsable = false
W.Slash("/ft outfit")
eq(W.equipped[16], AXE, "without the Equipment Manager nothing swaps")
ns:OpenSettings("Fishing")
W.setsUsable = true
ns:OpenSettings("Fishing")

finish()
