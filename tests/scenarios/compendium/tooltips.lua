--[[
    Forever Compendium - tests/scenarios/compendium/tooltips.lua
    Tooltip Lines: kills and looted on a creature's tooltip, its quests (counts for, takes in,
    offers) by what the log says, an item's likeliest sources with their rates, the index made
    again after new loot, each checkbox, and nothing while off.
    Run by tests/run.lua (lua5.1 tests/run.lua tooltips), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverCompendium")
login()
local Book, L = ns.Book, ns.L

local function texts(lines)
    local list = {}
    for _, line in ipairs(lines) do list[#list + 1] = line.text end
    return table.concat(list, "\n")
end
local function has(lines, text) return texts(lines):find(text, 1, true) ~= nil end

local GUID = "Creature-0-4618-0-3041-3100-0000AAAAAA"
local boar = Book.Meet(3100, "Mottled Boar")
boar.kills, boar.looted, boar.loot = 6, 4, { [769] = 3 }
boar.quests, boar.ends, boar.starts = { [10] = true }, { [11] = true }, { [12] = true, [13] = true }
Book.QuestRecord(10).title = "Boar Hunt"
Book.QuestRecord(11).title = "Report Back"
Book.QuestRecord(12).title = "Next Steps"
Book.QuestRecord(13).title = "Long Done"
W.questsDone[13] = true
W.quests = { { title = "Boar Hunt", questID = 10 }, { title = "Report Back", questID = 11 } }

local lines = W.UnitTooltip(GUID)
check(has(lines, string.format(L.TIPS_KILLS, 6, 4)), "kills and looted")
check(has(lines, string.format(L.TIPS_FOR_QUEST, "Boar Hunt")), "a quest in the log it counts for")
check(has(lines, string.format(L.TIPS_TAKES_IN, "Report Back")), "a quest in the log it takes in")
check(has(lines, string.format(L.TIPS_OFFERS, "Next Steps")), "a quest it offers you haven't taken")
check(not has(lines, "Long Done"), "but not one done")
check(not texts(lines):find("Abilities", 1, true), "no abilities line for a creature seen casting nothing")
boar.abilities = { [3150] = true, [3151] = true, [3152] = true, [3153] = true, [3154] = true }
W.spells[3150], W.spells[3151], W.spells[3152], W.spells[3153], W.spells[3154] = "Rabies", "Charge", "Thrash", "Gore", "Bite"
lines = W.UnitTooltip(GUID)
local abilities = texts(lines):match("Abilities: [^\n]*") or ""
check(abilities:find("Bite", 1, true) and abilities:find("Gore", 1, true) and not abilities:find("Thrash", 1, true),
    "its abilities, the first four by name")
check(abilities:find(string.format(L.TIPS_MORE_ABILITIES, 1), 1, true) ~= nil, "and how many more")
ns:SetOption("TooltipLines", "abilities", false)
check(not texts(W.UnitTooltip(GUID)):find("Abilities", 1, true), "off: no abilities line")
ns:SetOption("TooltipLines", "abilities", true)
boar.abilities = nil
eq(#W.UnitTooltip("Player-1-0000"), 0, "nothing on a player")
eq(#W.UnitTooltip("Creature-0-4618-0-3041-9999-0000AAAAAA"), 0, "nothing on a creature not met")

-- An item: its sources, likeliest first, at most three.
local others = { { 3101, "Boar A", 1, 4 }, { 3102, "Boar B", 1, 2 }, { 3103, "Boar C", 1, 10 } }
for _, o in ipairs(others) do
    local rec = Book.Meet(o[1], o[2])
    rec.looted, rec.loot = o[4], { [769] = o[3] }
end
local item = W.ItemTooltip(769)
eq(item[1] and item[1].text, string.format(L.TIPS_DROPS_FROM, "Mottled Boar", 75), "the likeliest source first")
eq(item[2] and item[2].text, string.format(L.TIPS_DROPS_FROM, "Boar B", 50), "then the next")
eq(#item, 4, "three sources and how many more")
eq(item[4] and item[4].text, string.format(L.TIPS_MORE, 1), "how many more")

-- New loot: the index is made again.
local fresh = Book.Meet(3104, "Boar D")
fresh.looted, fresh.loot = 1, { [118] = 1 }
eq(#W.ItemTooltip(118), 0, "not in the index yet")
ns:Announce("LOOT_NEW", 3104, 118)
eq(#W.ItemTooltip(118), 1, "after the Recorder's news")

-- Each checkbox, and off.
ns:SetOption("TooltipLines", "quests", false)
check(not has(W.UnitTooltip(GUID), "Boar Hunt"), "Quests off")
ns:SetOption("TooltipLines", "drops", false)
eq(#W.ItemTooltip(769), 0, "Drops off")
ns:SetEnabled("TooltipLines", false)
eq(#W.UnitTooltip(GUID), 0, "off: nothing")
finish()
