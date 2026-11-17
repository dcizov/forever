--[[
    Forever Gearbox - tests/scenarios/bags/bagupgrades.lua
    Upgrade Arrows in Baganator, with Baganator: with Forever++ Integration, Forever++'s judgement
    as Baganator's upgrade plugin (true, false, nil while the item isn't loaded, nil while the
    module is off); its arrow in Baganator's top left corner, before the item level, red and
    turned over on a downgrade only with Show Downgrades, the percentage only with Percentage
    (its own options); Baganator redrawn on UPGRADES_UPDATED; Forever++'s Upgrade Arrows off: no
    answer from it. Without the integration, its own judgement (Lib/Upgrades.lua): a better helm
    by stat weights, a worse one, against what's worn.
    Run by tests/run.lua (lua5.1 tests/run.lua bagupgrades), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.items = {
    ["[Helm A]"] = { id = 101, slot = "INVTYPE_HEAD", class = 4, subclass = 0, sell = 1, equippable = true },
    ["[Helm B]"] = { id = 102, slot = "INVTYPE_HEAD", class = 4, subclass = 0, sell = 1, equippable = true },
    ["[Cloth]"] = { id = 2, stack = 20, sell = 10, class = 7 },
}
W.FillBags("[Cloth]")
W.bags[0][1] = { link = "[Helm A]" }
W.bags[0][2] = { link = "[Helm B]" }
W.bags[0][3] = { link = "[Cloth]", count = 5 }

W.Strict()
local ns = W.LoadAddon(root, "ForeverGearbox")
local B = W.UseBaganator()
W.loaded.Baganator = true
W.FPP.upgrades = {
    ["[Helm A]"] = { canUpgrade = true, isUpgrade = true, isDowngrade = false, percent = 12 },
    ["[Helm B]"] = { canUpgrade = true, isUpgrade = false, isDowngrade = true, percent = -9 },
    ["[Cloth]"] = { canUpgrade = false, isUpgrade = false, isDowngrade = false },
}
login()
-- Forever++ Integration on: what this checks works with Forever++ (Core/Plugin.lua).
ns:SetEnabled("ForeverPlusPlus", true)
W.RunTimers()
W.RunTimers()
local M = ns.modules.BaganatorUpgrades
check(W.FPP.Module("BaganatorUpgrades") == nil, "not on Forever++'s Modules page")
eq(ns.Attach.Target(M), "UpgradeArrows", "with the integration, a section on Upgrade Arrows' page")
check(ns.Attach.Available(M), "there with Baganator loaded")
check(M.active, "on by default")
ns:SetOption("BaganatorUpgrades", "downgrades", false)

-- Baganator's upgrade plugin.
local plugin = B.plugins and B.plugins.foreverplusplus
check(plugin ~= nil, "registered as an upgrade plugin")
eq(plugin.label, ns.L.BAGUP_PLUGIN, "named Forever Gearbox")
eq(plugin.callback("[Helm A]"), true, "an upgrade")
eq(plugin.callback("[Helm B]"), false, "a downgrade isn't one")
eq(plugin.callback("[Cloth]"), false, "nor something that can't be worn")
eq(plugin.callback("[Not Loaded]"), nil, "an item not loaded yet: ask again")

-- The arrow.
B.view:Show()
ns.BagButtons.RefreshBaganator()
W.RunTimers()
eq(B.ShownIn(0, 1, "top_left"), "ForeverTweaks_Upgrade", "the arrow wins the corner over the item level")
eq(B.ShownIn(0, 2, "top_left"), "item_level", "a downgrade: no arrow without Show Downgrades")
local shown, mark = B.Widget("ForeverTweaks_Upgrade", "[Helm A]")
eq(shown, true, "an upgrade shows")
eq(mark.arrow._atlas, "bags-greenarrow", "Blizzard's green arrow, as Forever++ draws it")
check(not mark.text:IsShown(), "no percentage without Percentage")
ns:SetOption("BaganatorUpgrades", "downgrades", true)
ns:SetOption("BaganatorUpgrades", "percent", true)
shown, mark = B.Widget("ForeverTweaks_Upgrade", "[Helm B]")
eq(shown, true, "Show Downgrades: a downgrade shows")
eq(mark.arrow._desaturated, true, "turned red")
check(mark.text:IsShown() and mark.text._text == "-9%", "with its percentage")
eq(B.Widget("ForeverTweaks_Upgrade", "[Not Loaded]"), nil, "not loaded yet: Baganator asks again")

-- Forever++ says the scores changed: Baganator redraws.
W.FPP.upgrades["[Helm A]"].isUpgrade = false
W.FPP.upgrades["[Helm A]"].isDowngrade = false
W.FPP.Fire("UPGRADES_UPDATED")
W.RunTimers()
eq(B.ShownIn(0, 1, "top_left"), "item_level", "no longer an upgrade: the arrow comes off")

-- Forever++'s Upgrade Arrows off: no judgement from it, nothing shown.
W.FPP.SetOwn("UpgradeArrows", false)
eq(B.Widget("ForeverTweaks_Upgrade", "[Helm B]"), false, "Forever++'s Upgrade Arrows off: no arrow")
eq(plugin.callback("[Helm B]"), false, "and no upgrade")
W.FPP.SetOwn("UpgradeArrows", true)

-- Without the integration: its own judgement, by stat weights against what's worn.
ns:SetEnabled("ForeverPlusPlus", false)
W.items["[Int Helm]"] = { id = 201, equipLoc = "INVTYPE_HEAD", class = 4, subclass = 1, sell = 1 }
W.items["[Worn Helm]"] = { id = 202, equipLoc = "INVTYPE_HEAD", class = 4, subclass = 1, sell = 1 }
W.items["[Weak Helm]"] = { id = 203, equipLoc = "INVTYPE_HEAD", class = 4, subclass = 1, sell = 1 }
W.itemStats["[Int Helm]"] = { ITEM_MOD_INTELLECT_SHORT = 12, ITEM_MOD_STAMINA_SHORT = 6 }
W.itemStats["[Worn Helm]"] = { ITEM_MOD_INTELLECT_SHORT = 5, ITEM_MOD_STAMINA_SHORT = 5 }
W.itemStats["[Weak Helm]"] = { ITEM_MOD_INTELLECT_SHORT = 1 }
W.worn[1] = "[Worn Helm]"
W.unitInfo.player = W.unitInfo.player or {}
W.unitInfo.player.class, W.unitInfo.player.level = "MAGE", 30
W.Fire("PLAYER_EQUIPMENT_CHANGED")
W.RunTimers()
eq(plugin.callback("[Int Helm]"), true, "its own judgement: a better helm is an upgrade")
eq(plugin.callback("[Weak Helm]"), false, "a worse one isn't")
eq(plugin.callback("[Worn Helm]"), false, "nor the one worn")
shown, mark = B.Widget("ForeverTweaks_Upgrade", "[Weak Helm]")
eq(shown, true, "a downgrade shows with Show Downgrades")
check(mark.text._text and mark.text._text:find("^%-"), "with how much worse")

-- Its own checkbox off: nothing.
ns:SetEnabled("BaganatorUpgrades", false)
eq(plugin.callback("[Helm B]"), nil, "off: no answer")
eq(B.Widget("ForeverTweaks_Upgrade", "[Helm B]"), false, "off: no arrow")
eq(#W.errors, 0, "no errors")
finish()
