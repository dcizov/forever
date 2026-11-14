--[[
    Forever Compendium - tests/scenarios/compendium/journal.lua
    The journal window: /fc opens it on its Creatures tab; the list sorts, searches (by name, by
    loot, by quest) and filters, leaves critters out unless asked, keeps pinned creatures first
    (right-click pins); a row shows its creature (model, kind, places, abilities, kills, loot
    rates, quests by their titles, never "Quest 1234" once the game knows the title) and its note
    is kept; ns.ShowQuest opens the quest log or the giver's Quests tab; the Items page shows
    what it holds; zones fold; a creature met while it's open shows
    up; ns.ShowCreature picks one; turning the module off closes it.
    Run by tests/run.lua (lua5.1 tests/run.lua journal), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root, under = T.check, T.eq, T.login, T.finish, T.root, T.under

W.Strict()
local ns = W.LoadAddon(root, "ForeverCompendium")
login()
local Book, Filter, Journal = ns.Book, ns.CreatureFilter, ns.Journal
local journal = ns.modules.Journal

-- What the Recorder learned (written straight into its book).
local boar = Book.Meet(3100, "Mottled Boar")
boar.minLevel, boar.maxLevel, boar.creatureType, boar.reaction = 3, 5, "Beast", 2
boar.kills, boar.looted, boar.loot = 4, 4, { [769] = 3, [4865] = 1 }
for itemID = 2001, 2010 do boar.loot[itemID] = 1 end -- twelve kinds of loot: more than a row
boar.zones = { [1411] = { cells = { [10] = 2 }, sub = { ["Valley of Trials"] = true } },
    [947] = { cells = { [3] = 9 } } } -- seen more on the world map (Azeroth): no zone of its own
W.mapTypes[947] = 1
boar.quests = { [300] = "slay", [305] = true }
boar.abilities = { [3150] = true }
boar.money, boar.last = 120, 100
W.spells[3150] = "Rabies"
Book.SetItem(769, "Chunk of Boar Meat", 1, 133970)
Book.QuestRecord(300).title = "Cutting Teeth"
Book.QuestRecord(300).level = 4
W.questTitles[305] = "Sarkoth" -- a quest known only by number: its title comes from the game
local grunt = Book.Meet(3296, "Orgrimmar Grunt")
grunt.minLevel, grunt.maxLevel, grunt.reaction, grunt.display, grunt.last = 30, 30, 5, 4259, 200
grunt.starts = { [301] = true }
grunt.wares = { [159] = { price = 25, stack = 5 } }
Book.SetItem(159, "Refreshing Spring Water", 1, 132794)
Book.QuestRecord(301).title = "A Peon's Burden"
Book.QuestRecord(301).rewards = { 4865 }
W.questsDone[301] = true
local rabbit = Book.Meet(721, "Rabbit")
rabbit.creatureType = "Critter"

local function names()
    local list = {}
    for _, item in ipairs(Filter.Items(journal.db)) do list[#list + 1] = item.rec.name end
    return table.concat(list, ",")
end

W.Slash("/fc")
local window = ForeverCompendiumJournal
check(window and window:IsShown(), "/fc opens the journal")
eq(names(), "Orgrimmar Grunt,Mottled Boar", "listed last seen first, critters left out")
local function shownRows() return under(window, function(f) return rawget(f, "entry") ~= nil and f:IsShown() end) end
local function rowText(row)
    if row.item.header then return "[" .. row.head.name:GetText() .. "]" end
    return row.entry.name:GetText()
end
local function listed()
    local out = {}
    for _, row in ipairs(shownRows()) do out[#out + 1] = rowText(row) end
    return table.concat(out, ",")
end
local listScroll = shownRows()[1]:GetParent():GetParent()
function listScroll:GetHeight() return 400 end -- room for every row
Journal.Refresh()
eq(listed(), "[1411],Mottled Boar,[Unknown Place],Orgrimmar Grunt", "under a header per zone (never the world or a continent), an unknown place last")
local rows = shownRows()
rows[1]:Fire("OnClick", "LeftButton")
eq(listed(), "[1411],[Unknown Place],Orgrimmar Grunt", "a header folds its zone")
check(journal.db.collapsed["map:1411"], "and stays folded")
ns.ShowCreature(3100)
eq(listed(), "[1411],Mottled Boar,[Unknown Place],Orgrimmar Grunt", "showing a creature unfolds its zone")
ns:SetOption("Journal", "groupZones", false)
eq(listed(), "Orgrimmar Grunt,Mottled Boar", "no headers when grouping is off")
ns:SetOption("Journal", "groupZones", true)
local tabs = under(window, function(f) return f._template == "LargeSideTabButtonTemplate" and f:IsShown() end)
eq(#tabs, 4, "a side tab for each page: Creatures, Items, Trophies, Badges")
check(tabs[1]:GetChecked() and not tabs[2]:GetChecked(), "the open page's tab checked")
W.ClickSideTab(tabs[2])
check(tabs[2]:GetChecked(), "a side tab opens its page")
W.ClickSideTab(tabs[1])

-- Sorting, searching and filtering.
ns:SetOption("Journal", "sort", "level")
eq(names(), "Orgrimmar Grunt,Mottled Boar", "highest level first")
ns:SetOption("Journal", "reverse", true)
eq(names(), "Mottled Boar,Orgrimmar Grunt", "the other way round")
ns:SetOption("Journal", "reverse", false)
ns:SetOption("Journal", "sort", "kills")
eq(names(), "Mottled Boar,Orgrimmar Grunt", "most killed first")
ns:SetOption("Journal", "critters", true)
check(names():find("Rabbit", 1, true) ~= nil, "critters when asked")
ns:SetOption("Journal", "critters", false)
local search = under(window, function(f) return f._template == "SearchBoxTemplate" and f:IsVisible() end)[1]
local function find(text)
    search:SetText(text)
    search:Fire("OnTextChanged")
end
find("trials")
eq(names(), "Mottled Boar", "search finds subzones")
Filter.mode = "loot"
find("spring water")
eq(names(), "Orgrimmar Grunt", "by loot: what it sells")
find("boar meat; spring")
eq(names(), "Mottled Boar,Orgrimmar Grunt", "several terms")
Filter.mode = "quest"
find("sarkoth")
eq(names(), "Mottled Boar", "by quest: a title the game gave")
Filter.mode = "name"
find("")
Filter.Toggle("reaction", "friendly")
eq(names(), "Orgrimmar Grunt", "filtered to friendly")
Filter.Clear()

-- Pinning: first in the list, whatever the order.
ns:SetOption("Journal", "sort", "name")
Journal.TogglePin(3296)
eq(names(), "Orgrimmar Grunt,Mottled Boar", "pinned first")
check(grunt.pinned, "pinned")
Journal.Refresh()
rows = shownRows()
eq(rowText(rows[1]) .. "," .. rowText(rows[2]), "[Pinned],Orgrimmar Grunt", "pinned ones under their own header")
rows[2]:Fire("OnClick", "RightButton")
eq(grunt.pinned, nil, "right-click unpins")

-- A creature's page.
local function text(fs) return fs:GetText() or "" end
local function shownTexts()
    local all = {}
    for _, f in ipairs(under(window, function(f) return f._kind == "FontString" and f:IsVisible() end)) do
        all[#all + 1] = text(f)
    end
    return table.concat(all, "\n")
end
W.quests = { { questID = 300, title = "Cutting Teeth", level = 4 } } -- in your log: it wants the boar
ns.ShowCreature(3100)
local shown = shownTexts()
W.quests = {}
check(shown:find("Mottled Boar", 1, true) ~= nil, "the creature's name")
check(shown:find("Level 3-5", 1, true) ~= nil, "its level range")
check(shown:find("Valley of Trials", 1, true) ~= nil, "where")
check(shown:find("Rabies", 1, true) ~= nil, "an ability, beside the model")
check(shown:find(ns.L.CDETAIL_BEST_DROPS, 1, true) ~= nil, "its best drops beside the model")
check(shown:find("Cutting Teeth", 1, true) ~= nil, "a quest in your log that wants it, beside the model")
local creatureTabs = under(window, function(f) return f._template == "TabSystemButtonTemplate" end)
eq(#creatureTabs, 5, "Loot, Wares, Rewards, Quests, Notes")
check(shown:find("75%", 1, true) ~= nil, "a drop rate: 3 of 4 corpses")
-- The loot grid fills the pane's width, however wide it turns out: as many slots across as fit.
local slots = under(window, function(f) return rawget(f, "corner") ~= nil and f:IsVisible() end)
eq(#slots, 12, "a slot per kind of loot")
local lootScroll = slots[1]:GetParent():GetParent()
function lootScroll:GetWidth() return 420 end -- (36 + 6) * 10 = 420: ten across
ns.ShowCreature(3100)
eq(select(4, slots[10]:GetPoint()), 9 * 42, "the tenth slot still in the first row")
eq(select(5, slots[11]:GetPoint()), -42, "the eleventh starts the second")
eq(select(4, slots[11]:GetPoint()), 0, "at the left edge")
local searchBox = under(window, function(f) return f._template == "SearchBoxTemplate" and f:IsVisible() end)[1]
eq(searchBox:GetParent()._template, "InsetFrameTemplate", "the search box sits at the top of the list's inset, as in the Mount Journal")
local portraits = under(window, function(f) return rawget(f, "face") ~= nil and f:IsVisible() end)
check(#portraits >= 2, "creatures shown with their portraits")

local models = under(window, function(f) return f._template == "ModelWithZoomTemplate" end)
eq(models[1]._creature, 3100, "its model from its creature ID")
ns.ShowCreature(3296)
eq(models[1]._display, 4259, "a creature with a known model shows that")

-- Its tabs: quests by name, wares, rewards, notes.
check(text(creatureTabs[2]):find("(1)", 1, true) ~= nil, "Wares counts what it sells")
ns.ShowCreature(3100)
creatureTabs[4]:Fire("OnClick")
shown = shownTexts()
check(shown:find("Cutting Teeth", 1, true) ~= nil, "its quest by title")
check(shown:find("Sarkoth", 1, true) ~= nil, "a quest known by number shows the game's title")
check(not shown:find("Quest #305", 1, true), "never the bare number once known")
check(shown:find(ns.L.JOURNAL_STATE_LOG, 1, true) ~= nil and shown:find(ns.L.JOURNAL_ROLE_SLAY_SHORT, 1, true) ~= nil,
    "a legend of the quest icons")
creatureTabs[5]:Fire("OnClick")
local note = under(window, function(f) return f._kind == "EditBox" and f:IsVisible() and f._template == nil end)[1]
note:SetText("Watch for its charge.")
note:Fire("OnTextChanged")
eq(boar.note, "Watch for its charge.", "the note is kept as you type")
creatureTabs[1]:Fire("OnClick")

-- A quest: one in the log opens Blizzard's quest log on it; any other its giver's Quests tab.
W.quests = { { questID = 300, title = "Cutting Teeth", level = 4 } }
ns.ShowQuest(300)
eq(W.openedQuest, 300, "a quest in the log opens in the quest log")
W.quests = {}
Book.QuestRecord(301).giver = { npc = 3296, name = "Orgrimmar Grunt" }
ns.ShowQuest(301)
shown = shownTexts()
check(shown:find("A Peon's Burden", 1, true) ~= nil, "any other on its giver's Quests tab")
check(shown:find("Orgrimmar Grunt", 1, true) ~= nil, "the giver shown")
creatureTabs[1]:Fire("OnClick")

-- The Items page.
ns.ShowItem(769)
shown = shownTexts()
check(shown:find("Chunk of Boar Meat", 1, true) ~= nil, "the items page shows its item")
check(shown:find("Mottled Boar", 1, true) ~= nil, "and who drops it")
local card = under(window, function(f) return f._template == "GameTooltipTemplate" and f:IsShown() end)[1]
check(card ~= nil, "its own tooltip docked in the page")
check(shown:find("[3-5]", 1, true) ~= nil, "a dropper's level beside its name")
Journal.Show("creatures")

-- Trophies: the rares and bosses met, defeated ones in colour; a first defeat is news.
local rare = Book.Meet(3270, "Elder Mystic Razorsnout")
rare.classification, rare.reaction = "rare", 2
local boss = Book.Meet(3295, "Sludge Anomaly")
boss.skull = true
local news = {}
ns:OnNews(journal, function(_, event, npc) news[#news + 1] = event .. ":" .. tostring(npc) end)
ns.RecorderCombat.Kill(ns.modules.Recorder, "Creature-0-0-0-0-3270-0000000001")
check(table.concat(news, ","):find("TROPHY:3270", 1, true) ~= nil, "a rare's first defeat is a trophy")
news = {}
ns.RecorderCombat.Kill(ns.modules.Recorder, "Creature-0-0-0-0-3270-0000000002")
check(not table.concat(news, ","):find("TROPHY", 1, true), "not its second")
Journal.Show("trophies")
shown = shownTexts()
check(shown:find(string.format(ns.L.JOURNAL_COUNT, 1, 1), 1, true) ~= nil, "trophies: the rares tile, 1 of 1 defeated")
check(shown:find(ns.L.TROPHY_ELITES, 1, true) ~= nil, "a tile for elites too")
check(shown:find("Elder Mystic Razorsnout", 1, true) ~= nil and shown:find(string.format(ns.L.TROPHY_KILLS, 2), 1, true) ~= nil,
    "a defeated rare with its kills")
check(shown:find("Sludge Anomaly", 1, true) ~= nil and shown:find(ns.L.TROPHY_OPEN, 1, true) ~= nil, "a boss not yet defeated")
check(not shown:find("Mottled Boar", 1, true), "no ordinary creatures")
Journal.Show("creatures")

-- Met while open: listed on the next frame.
W.place = { map = 1411, x = 0.5, y = 0.5 }
W.Creature("target", 3102, "Bloodtalon Scythemaw", { level = 6, creatureType = "Beast" })
W.Fire("PLAYER_TARGET_CHANGED")
W.RunTimers()
check(names():find("Bloodtalon", 1, true) ~= nil, "a new creature listed")
check(journal:DebugLine():find(ns.L.JOURNAL_TAB_CREATURES, 1, true) ~= nil, "Debug line names the page")

-- Off: closed, and /fc opens its settings instead.
ns:SetEnabled("Journal", false)
check(not window:IsShown(), "closed when turned off")
W.Slash("/fc")
check(not window:IsShown(), "not opened while off")
check(W.opened ~= nil, "the settings instead")
finish()
