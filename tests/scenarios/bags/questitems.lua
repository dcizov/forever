--[[
    Forever Tweaks - tests/scenarios/bags/questitems.lua
    Quest Items: which quest a bag item is for (needed, begins a quest, or left over), the marks
    in Blizzard's bags and Baganator's, the quest log changing, and QuestieDB's item IDs.
    Run by tests/run.lua (lua5.1 tests/run.lua questitems), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root
local ns

W.items = {
    ["[Rock]"] = { id = 200, stack = 1, sell = 1 },
    ["[Murloc Eye]"] = { id = 201, stack = 20, sell = 1 },
    ["[Red Mushroom]"] = { id = 202, stack = 20, sell = 1, class = 0 },
    ["[Old Letter]"] = { id = 203, stack = 1, sell = 0, class = 12 },
    ["[Signal Flare]"] = { id = 204, stack = 1, sell = 0, class = 12 },
    ["[Strange Note]"] = { id = 205, stack = 1, sell = 0, class = 12 },
    ["[Sealed Package]"] = { id = 206, stack = 1, sell = 0, class = 12 },
    ["[Gnoll Paw]"] = { id = 207, stack = 20, sell = 0, class = 12 },
}
W.itemSpells["[Signal Flare]"] = 1234 -- a quest gave it to use somewhere
W.FillBags("[Rock]")
W.bags[0][1] = { link = "[Murloc Eye]", count = 2 }
W.bags[0][2] = { link = "[Red Mushroom]", count = 10 }
W.bags[0][3] = { link = "[Old Letter]", quest = true }
W.bags[0][4] = { link = "[Signal Flare]", quest = true }
W.bags[1][1] = { link = "[Strange Note]", quest = true, starts = 600 }
W.quests = {
    { title = "Murloc Mayhem", questID = 1, objectives = {
        { type = "item", text = "Murloc Eye: 2/3", numFulfilled = 2, numRequired = 3 },
        { type = "monster", text = "Murloc slain: 4/8", numFulfilled = 4, numRequired = 8 } } },
    { title = "Mushroom Stew", questID = 2, objectives = {
        { type = "item", text = "10/10 Red Mushroom", numFulfilled = 10, numRequired = 10, finished = true } } },
}

W.Strict()
ns = W.LoadAddon(root, "ForeverTweaks")
local B = W.UseBaganator()
login()
-- Item Tooltips (its own scenario: tooltips) adds lines to the same tooltips: off here.
ns:SetEnabled("ItemTooltips", false)
local mod, QuestLog = ns.modules.QuestItems, ns.QuestLog
check(mod.active, "on by default")

-- The three kinds.
eq(QuestLog.ForBagSlot(0, 1), "needed", "an objective names it: needed")
eq(QuestLog.ForBagSlot(0, 2), "needed", "'10/10 Name' too, and a finished quest still needs it")
eq(QuestLog.ForBagSlot(0, 3), "leftover", "a quest item nothing needs: leftover")
eq(QuestLog.ForBagSlot(0, 4), nil, "a quest item with a Use spell: never a leftover")
eq(QuestLog.ForBagSlot(1, 1), "starts", "it begins a quest")
eq(QuestLog.ForBagSlot(1, 2), nil, "a plain item: nothing")
eq(QuestLog.Needed().names["Murloc slain"], nil, "only item objectives")
check(mod:DebugLine():find("2 items", 1, true) ~= nil, "Debug line counts them")

-- Marks in Blizzard's bags.
local function markOn(bag, slot)
    for _, c in ipairs(W.BagButton(bag, slot)._children or {}) do
        if c._atlas == "QuestNormal" and c:IsShown() then return true end
    end
    return false
end
W.ShowBags()
check(markOn(0, 1) and markOn(0, 2) and markOn(1, 1), "needed items and quest starters marked")
check(markOn(0, 3), "the leftover marked")
check(not markOn(0, 4) and not markOn(1, 2), "nothing on the others")
ns:SetOption("QuestItems", "markNeeded", false)
check(not markOn(0, 1) and markOn(0, 3), "Mark Needed Items off")
check(markOn(1, 1), "quest starters still marked (their own checkbox)")
ns:SetOption("QuestItems", "markStarts", false)
check(not markOn(1, 1), "Mark Quest Starters off")
ns:SetOption("QuestItems", "markStarts", true)
ns:SetOption("QuestItems", "markNeeded", true)
ns:SetOption("QuestItems", "markLeftover", false)
check(markOn(0, 1) and not markOn(0, 3), "Mark Leftovers off")
ns:SetOption("QuestItems", "markLeftover", true)

-- A leftover's tooltip says what it is; a needed item's and a plain one's get nothing (Questie's).
local function tooltipText(itemID, getter, lines)
    local out = {}
    for _, line in ipairs(W.ItemTooltip(itemID, getter, lines)) do out[#out + 1] = line.text end
    return table.concat(out, "\n")
end
local text = tooltipText(203, { "GetBagItem", 0, 3 })
check(text:find("no quest in your log", 1, true) ~= nil, "a leftover's tooltip says so")
check(text:find("safe to destroy", 1, true) ~= nil, "and that one with no vendor price can go")
eq(tooltipText(201, { "GetBagItem", 0, 1 }), "", "nothing on a needed item")
eq(tooltipText(204, { "GetBagItem", 0, 4 }), "", "nothing on a quest item with a Use spell")
eq(tooltipText(200), "", "nothing on a plain item")
eq(tooltipText(205, nil, { { leftText = ITEM_STARTS_QUEST } }), "", "Blizzard's line says it starts one")
check(tooltipText(203):find("no quest in your log", 1, true) ~= nil, "a leftover shown by ID (a link) too")
-- QuestieDB knows the quest it was for: turned in or not.
local questNames = { [70] = "Lost Letters", [71] = "Letters Again" }
local related = { [203] = { 70 } }
_G.LibQuestieDB = {
    Quest = { Get = function(id, key) return key == "name" and questNames[id] or nil end },
    Item = { Get = function(id, key) return key == "relatedQuests" and related[id] or nil end },
}
text = tooltipText(203, { "GetBagItem", 0, 3 })
check(text:find("Was for Lost Letters (not turned in)", 1, true) ~= nil, "names the quest, not turned in")
check(text:find("Keep it", 1, true) ~= nil and not text:find("destroy", 1, true), "so keep it")
W.questsDone[70] = true
text = tooltipText(203, { "GetBagItem", 0, 3 })
check(text:find("(turned in)", 1, true) ~= nil and text:find("safe to destroy", 1, true) ~= nil,
    "turned in: safe to destroy")
related[203] = { 70, 71 }
check(tooltipText(203, { "GetBagItem", 0, 3 }):find("Keep it", 1, true) ~= nil, "any quest not turned in: keep")
_G.LibQuestieDB = { Quest = { Get = function() error("questie broke") end }, Item = { Get = function() error("x") end } }
check(tooltipText(203, { "GetBagItem", 0, 3 }):find("safe to destroy", 1, true) ~= nil, "QuestieDB failing: still a line")
eq(#W.errors, 0, "and its error isn't ours")
_G.LibQuestieDB = nil
W.questsDone = {}
ns:SetOption("QuestItems", "tooltip", false)
eq(tooltipText(203, { "GetBagItem", 0, 3 }), "", "Explain Leftovers off")
ns:SetOption("QuestItems", "tooltip", true)

-- In Baganator.
check(B.widgets.ForeverTweaks_QuestNeeded ~= nil and B.widgets.ForeverTweaks_QuestLeftover ~= nil, "two widgets")
eq(B.widgets.ForeverTweaks_QuestNeeded.position.corner, "top_right", "top right")
eq(B.Widget("ForeverTweaks_QuestNeeded", "[Murloc Eye]"), true, "needed widget")
eq(B.Widget("ForeverTweaks_QuestNeeded", "[Rock]"), false, "not on a plain item")
eq(B.Widget("ForeverTweaks_QuestLeftover", "[Old Letter]"), true, "leftover widget")
eq(B.Widget("ForeverTweaks_QuestLeftover", "[Murloc Eye]"), false, "not on a needed item")

-- The quest log changes: a quest turned in.
table.remove(W.quests, 1)
W.Fire("QUEST_TURNED_IN", 1)
W.Fire("QUEST_LOG_UPDATE")
W.RunTimers()
eq(QuestLog.ForBagSlot(0, 1), nil, "its items aren't needed any more")
check(not markOn(0, 1), "and lose their mark")
check(markOn(0, 2), "the other quest's stay")
W.Fire("QUEST_LOG_UPDATE") -- nothing new
W.RunTimers()
check(markOn(0, 2), "an update with nothing new changes nothing")

-- Off: no marks or widgets.
ns:SetEnabled("QuestItems", false)
check(not markOn(0, 2) and not markOn(0, 3), "off: no marks")
eq(B.Widget("ForeverTweaks_QuestLeftover", "[Old Letter]"), false, "off: no widgets")
eq(QuestLog.ForBagSlot(0, 3), "leftover", "the library still answers other modules")
ns:SetEnabled("QuestItems", true)
check(markOn(0, 3), "back on")
-- The log changes while no module listens (Quest Items and Full Bags both off): turned on again,
-- it reads the log afresh rather than what it kept.
check(markOn(0, 2), "a needed item marked")
ns:SetEnabled("QuestItems", false)
ns:SetEnabled("FullBags", false)
W.quests = {}
W.Fire("QUEST_REMOVED", 2)
W.Fire("QUEST_LOG_UPDATE")
W.RunTimers()
ns:SetEnabled("QuestItems", true)
check(not markOn(0, 2), "back on after the quest went: no longer needed")
ns:SetEnabled("FullBags", true)

-- QuestieDB: what a quest needs by item ID. A delivery quest hands you a package and has no item
-- objective, and an objective may not read as the item's name; without QuestieDB both look like
-- leftovers, with it both are needed.
W.bags[1][3] = { link = "[Sealed Package]", quest = true }
W.bags[1][4] = { link = "[Gnoll Paw]", quest = true, count = 3 }
W.quests = {
    { title = "Special Delivery", questID = 10, objectives = {} },
    { title = "Paws Off", questID = 11, objectives = {
        { type = "item", text = "Gnoll Paws: 3/8", numFulfilled = 3, numRequired = 8 } } },
}
W.Fire("QUEST_ACCEPTED", 10)
W.RunTimers()
eq(QuestLog.ForBagSlot(1, 3), "leftover", "no QuestieDB: a package to deliver looks left over")
eq(QuestLog.ForBagSlot(1, 4), "leftover", "and so does an item its objective names differently")
local questie = {
    [10] = { objectives = {}, sourceItemId = 206 },
    [11] = { objectives = { nil, nil, { { 207 } } } },
}
_G.LibQuestieDB = { Quest = { Get = function(id, key) return questie[id] and questie[id][key] end } }
W.Fire("QUEST_LOG_UPDATE")
W.RunTimers()
eq(QuestLog.ForBagSlot(1, 3), "needed", "QuestieDB: the package its quest hands you is needed")
eq(QuestLog.ForBagSlot(1, 4), "needed", "and the objective's item, by ID")
check(markOn(1, 3) and markOn(1, 4), "both marked as needed")
questie[11] = { objectives = {}, requiredSourceItems = { 207 } }
QuestLog.Invalidate()
eq(QuestLog.ForBagSlot(1, 4), "needed", "an item a quest needs that isn't an objective")
_G.LibQuestieDB = { Quest = { Get = function() error("questie broke") end } }
QuestLog.Invalidate()
eq(QuestLog.ForBagSlot(1, 3), "leftover", "QuestieDB failing: back to the names")
eq(#W.errors, 0, "and its error isn't ours")
_G.LibQuestieDB = nil
_G.Baganator = nil
finish()
