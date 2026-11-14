--[[
    Forever Tweaks - tests/scenarios/bags/baganator.lua
    Full Bags' Baganator widget, in the order the game sets it up (Baganator loaded first, our
    modules turning on at login), with Baganator's own corner rules: per corner only the first
    widget answering true shows. Full Bags' delete number must win the top left corner over
    Baganator's item level, or gear it suggests deleting shows its item level and no number.
    Run by tests/run.lua (lua5.1 tests/run.lua baganator), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.items = {
    ["[Helm C]"] = { id = 103, slot = "INVTYPE_HEAD", class = 4, subclass = 0, sell = 1, equippable = true },
    ["[Cloth]"] = { id = 2, stack = 20, sell = 10, class = 7 },
    ["[Gem]"] = { id = 4, stack = 1, sell = 1000 },
}
W.FillBags("[Cloth]")
for bag = 0, NUM_BAG_FRAMES do
    for slot = 1, 4 do W.bags[bag][slot].count = 20 end
end
W.bags[0][1] = { link = "[Helm C]" } -- the cheapest thing in the bags

W.Strict()
local ns = W.LoadAddon(root, "ForeverTweaks")
local B = W.UseBaganator() -- loaded before us (an optional dependency)
login()
W.RunTimers()
check(ns.modules.FullBags.active, "Full Bags on")

-- No loot: the helm shows Baganator's item level top left.
B.view:Show()
ns.BagButtons.RefreshBaganator()
W.RunTimers()
eq(B.ShownIn(0, 1, "top_left"), "item_level", "no loot: the item level")

-- Full bags and better loot: the helm is the one to delete, and its number shows top left.
W.loot = { { link = "[Gem]" } }
W.OpenLoot()
W.RunTimers()
eq(B.ShownIn(0, 1, "top_left"), "ForeverTweaks_FullBagsDelete", "the delete number wins the corner over the item level")
local frame = B.buttons[1]._corner.ForeverTweaks_FullBagsDelete
eq(frame and frame.text._text, 1, "numbered 1")
W.CloseLoot()
W.RunTimers()
eq(B.ShownIn(0, 1, "top_left"), "item_level", "loot gone: the item level again")
finish()
