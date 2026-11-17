--[[
    Forever Codex - tests/scenarios/compendium/journal.lua
    The journal window: /codex opens it on its Creatures tab; the list sorts, searches (by name, by
    loot, by quest) and filters, leaves critters out unless asked, keeps pinned creatures first
    (right-click pins); a row shows its creature (model, kind, places, abilities, kills, loot
    rates, quests by their titles, never "Quest 1234" once the game knows the title) and its note
    is kept; ns.ShowQuest opens the quest log on a quest in it, else the journal's quest page (its
    status, giver, Show on Map; Shift-click links one); a creature's quests have one status icon
    and their role in words; the Items page shows what it holds (a dropper with a face shows its
    name); zones fold; a creature met while it's open shows
    up; ns.ShowCreature picks one; turning the module off closes it.
    Run by tests/run.lua (lua5.1 tests/run.lua journal), which passes its helpers in.
]]

local T = ...
local L
local check, eq, login, finish, root, under = T.check, T.eq, T.login, T.finish, T.root, T.under

W.Strict()
local ns = W.LoadAddon(root, "ForeverCodex")
L = ns.L
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

W.Slash("/codex")
local window = ForeverCodexJournal
check(window and window:IsShown(), "/codex opens the journal")
eq(names(), "Orgrimmar Grunt,Mottled Boar", "listed last seen first, critters left out")
local function shownRows() return under(window, function(f) return rawget(f, "entry") ~= nil and f:IsShown() end) end
local function rowText(row)
    if row.item.banner then return "{" .. row.banner.name:GetText() .. "}" end
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
W.maps[1411], W.mapTypes[1414], W.mapNames[1414] = 1414, Enum.UIMapType.Continent, "Kalimdor"
Journal.Refresh()
eq(listed(), "{Kalimdor},[1411],Mottled Boar,{Unknown Place},Orgrimmar Grunt",
    "a banner per continent (as the Compendium's) with a header per zone under it, an unknown place last")
local rows = shownRows()
rows[2]:Fire("OnClick", "LeftButton")
eq(listed(), "{Kalimdor},[1411],{Unknown Place},Orgrimmar Grunt", "a header folds its zone")
check(journal.db.collapsed["map:1411"], "and stays folded")
shownRows()[1]:Fire("OnClick", "LeftButton")
eq(listed(), "{Kalimdor},{Unknown Place},Orgrimmar Grunt", "a banner folds its continent")
ns.ShowCreature(3100)
eq(listed(), "{Kalimdor},[1411],Mottled Boar,{Unknown Place},Orgrimmar Grunt", "showing a creature unfolds its zone and continent")
-- Back and Forward in the band over the page, as the quest log's Back: through what you opened.
local listPage
for _, p in ipairs(Journal.pages) do if p.key == "creatures" then listPage = p end end
local gruntRow
for _, row in ipairs(shownRows()) do if rowText(row) == "Orgrimmar Grunt" then gruntRow = row end end
gruntRow:Fire("OnClick", "LeftButton")
local gruntID = listPage.Selected()
check(gruntID ~= 3100 and Journal.CanBack(), "a creature clicked after one linked: Back can go to it")
Journal.Back()
eq(listPage.Selected(), 3100, "Back: the one before")
check(Journal.CanForward(), "and Forward is there")
Journal.Forward()
eq(listPage.Selected(), gruntID, "Forward: back again")
check(not Journal.CanForward(), "nothing further ahead")
check(type(Journal.Back) == "function" and type(Journal.Forward) == "function", "history still exists without a button strip")
ns:SetOption("Journal", "groupZones", false)
eq(listed(), "Orgrimmar Grunt,Mottled Boar", "no headers when grouping is off")
ns:SetOption("Journal", "groupZones", true)
local tabs = under(window, function(f) return f._template == "PanelTabButtonTemplate" and f:IsShown() end)
eq(#tabs, 5, "a tab along the foot for each page: Creatures, NPCs, Items, Trophies, Badges")
eq(window.selectedTab, 1, "the open page's tab chosen")
tabs[2]:Fire("OnClick")
eq(window.selectedTab, 2, "a tab opens its page")
tabs[1]:Fire("OnClick")

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
eq(rowText(rows[1]) .. "," .. rowText(rows[2]), "{Pinned},Orgrimmar Grunt", "pinned ones under their own banner")
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
check(shown:find("Valley of Trials", 1, true) ~= nil, "where")
check(shown:find("Rabies", 1, true) ~= nil, "an ability, beside the model")
check(shown:find(ns.L.CDETAIL_BEST_DROPS, 1, true) ~= nil, "its best drops beside the model")
check(shown:find("Cutting Teeth", 1, true) ~= nil, "a quest in your log that wants it, beside the model")
check(shown:find(ns.L.CDETAIL_IDENTITY, 1, true) ~= nil, "what it is first: Identification")
check(shown:find("3-5", 1, true) ~= nil, "its levels")
check(shown:find(ns.L.CDETAIL_ZONE, 1, true) ~= nil, "its places under Zone")
check(shown:find(ns.L.CDETAIL_TOTAL_KILLS, 1, true) ~= nil, "its total kills")
check(under(window, function(f) return f._template == "TabSystemButtonTemplate" end)[1] == nil, "no tabs under the model")
local function boxTitles()
    local all = {}
    for _, f in ipairs(under(window, function(f) return f._kind == "FontString" and f:IsVisible() end)) do
        local t = tostring(text(f))
        if t:find("^" .. ns.L.CTABS_LOOT .. " %(") or t:find("^" .. ns.L.CTABS_QUESTS .. " %(") then all[#all + 1] = t end
    end
    return table.concat(all, "|")
end
check(boxTitles():find(ns.L.CTABS_LOOT .. " (", 1, true) ~= nil, "the Loot box, with how much")
check(boxTitles():find(ns.L.CTABS_QUESTS .. " (", 1, true) ~= nil, "the Quests box beside it: it has quests")
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
for _, scroll in ipairs(under(window, function(f) return f._kind == "ScrollFrame" and rawget(f, "ScrollBar") ~= nil end)) do
    function scroll:GetTop() return 19 end
end
local searchBox = under(window, function(f) return f._template == "SearchBoxTemplate" and f:IsVisible() end)[1]
local filter = under(window, function(f) return f._template == "WowStyle1FilterDropdownTemplate" and f:IsVisible() end)[1]
local listScroll = under(searchBox:GetParent(), function(f) return rawget(f, "ScrollBar") ~= nil and f:IsVisible() end)[1]
check(searchBox:GetHeight() > 0, "the search box keeps its native height")
check(filter and filter:GetHeight() > 0, "the filter keeps its template height")
eq(searchBox:GetHeight(), filter:GetHeight(), "search and filter share the same native height")
check(listScroll and listScroll:GetTop() < searchBox:GetTop(), "the list starts below the search row")
eq(searchBox:GetParent()._template, "InsetFrameTemplate", "the search box sits at the top of the list's inset, as in the Mount Journal")
-- A search is forgotten when the journal closes: it opens again on the whole list.
searchBox:SetText("boar")
searchBox:Fire("OnTextChanged")
eq(ns.CreatureFilter.terms[1], "boar", "searching")
window:Hide()
eq(searchBox:GetText(), "", "closed: the search box empty")
eq(#ns.CreatureFilter.terms, 0, "and the list unfiltered")
window:Show()
local portraits = under(window, function(f) return rawget(f, "face") ~= nil and f:IsVisible() end)
check(#portraits >= 2, "creatures shown with their portraits")

local models = under(window, function(f) return f._template == "ModelWithZoomTemplate" end)
eq(models[1]._creature, 3100, "its model from its creature ID")
local cleared = 0
local clear = models[1].ClearModel
models[1].ClearModel = function(self) cleared = cleared + 1; return clear(self) end
ns.ShowCreature(3296)
eq(models[1]._display, 4259, "a creature with a known model shows that")
check(cleared > 0, "the last creature's model cleared first (one still loading would stay)")
models[1].ClearModel = clear

-- Its boxes: wares from the loot box's header, quests by name, and the note on the stage.
local function viewButton(label)
    return under(window, function(f) return f._kind == "Button" and f:IsVisible() and rawget(f, "text")
        and text(f.text):find(label, 1, true) == 1 end)[1]
end
check(viewButton(ns.L.CTABS_WARES) ~= nil and text(viewButton(ns.L.CTABS_WARES).text):find("(1)", 1, true) ~= nil,
    "Wares in the loot box's header, with what it sells")
check(viewButton(ns.L.CTABS_REWARDS) ~= nil, "Rewards too: the quest it gives has one")
viewButton(ns.L.CTABS_WARES):Fire("OnClick")
check(shownTexts():find(ns.L.CTABS_NO_WARES, 1, true) == nil, "its wares shown")
Book.Meet(3197, "Bloodtalon Taillasher")
ns.ShowCreature(3197)
check(not boxTitles():find(ns.L.CTABS_QUESTS .. " (", 1, true), "no Quests box for a creature without quests")
ns.ShowCreature(3100)
shown = shownTexts()
check(shown:find("Cutting Teeth", 1, true) ~= nil, "its quest by title")
check(shown:find("Sarkoth", 1, true) ~= nil, "a quest known by number shows the game's title")
check(not shown:find("Quest #305", 1, true), "never the bare number once known")
local noteButton = under(window, function(f) return f._kind == "Button" and f:IsVisible() and rawget(f, "title") == nil
    and rawget(f, "icon") and f.icon._texture == "Interface\\Icons\\INV_Misc_Note_01" end)[1]
check(noteButton ~= nil, "a note button on the stage")
noteButton:Fire("OnClick")
local note = under(window, function(f) return f._kind == "EditBox" and f:IsVisible() and f._template == nil end)[1]
note:SetText("Watch for its charge.")
note:Fire("OnTextChanged")
eq(boar.note, "Watch for its charge.", "the note is kept as you type")
check(not noteButton.icon._desaturated, "the note button lit once it has one")

-- A quest named in the journal: one in your log opens Blizzard's quest log; any other the
-- journal's quest page (who gives it, Show on Map); Shift-click on its line links it in chat.
W.quests = { { questID = 300, title = "Cutting Teeth", level = 4 } }
Book.QuestRecord(300).title = "Cutting Teeth"
ns.ShowQuest(300)
eq(W.openedQuest, 300, "a quest in your log opens in the quest log")
W.quests = {}
Book.QuestRecord(301).giver = { npc = 3296, name = "Orgrimmar Grunt", map = 1411, x = 0.5, y = 0.5 }
ns.ShowQuest(301)
local questPage = ForeverCodexQuest
local function pageTexts()
    local all = {}
    for _, f in ipairs(under(questPage, function(f) return f._kind == "FontString" and f:IsVisible() end)) do
        all[#all + 1] = tostring(text(f))
    end
    return table.concat(all, "\n")
end
shown = pageTexts()
check(shown:find("A Peon's Burden", 1, true) ~= nil, "any other on the journal's quest page")
check(shown:find("Orgrimmar Grunt", 1, true) ~= nil, "who gives it")
local mapButton = under(questPage, function(f) return f._template == "UIPanelButtonTemplate" and f:IsVisible() and text(f) == L.QUESTS_SHOW_MAP end)[1]
mapButton:Fire("OnClick")
eq(W.waypoint and W.waypoint.map, 1411, "Show on Map: Blizzard's map pin where its giver stands")
local giverLine = under(questPage, function(f) return f._kind == "FontString" and f:IsVisible() and tostring(text(f)):find("Orgrimmar Grunt", 1, true) end)[1]
W.shift = true
ns.JournalKit.Link("quest", 301, "LeftButton")
W.shift = false
eq(W.linked[#W.linked], "quest:301", "Shift-click links a quest in chat")
giverLine:GetParent():Fire("OnClick", "LeftButton")
check(shownTexts():find("Orgrimmar", 1, true) ~= nil, "a click on its giver opens the giver's page")
-- A creature's quests: one icon for where each stands, its role in words at the right.
ns.ShowCreature(3296, "quests")
shown = shownTexts()
check(shown:find(L.JOURNAL_ROLE_STARTS_SHORT, 1, true) ~= nil, "a creature's quest says what it does for it in words")
-- Moving: the journal fades (as the game's map does), whole again when you stop.
local journalWindow = ForeverCodexJournal
W.Fire("PLAYER_STARTED_MOVING")
eq(journalWindow:GetAlpha(), 0.5, "faded while you move")
W.Fire("PLAYER_STOPPED_MOVING")
eq(journalWindow:GetAlpha(), 1, "whole again when you stop")
ns:SetOption("Journal", "fade", false)
W.Fire("PLAYER_STARTED_MOVING")
eq(journalWindow:GetAlpha(), 1, "Fade While Moving off: never faded")
W.Fire("PLAYER_STOPPED_MOVING")
ns:SetOption("Journal", "fade", true)
eq(ns.JournalText.STATE_ICONS.done, "Interface\\RaidFrame\\ReadyCheck-Ready", "a done quest's tick is the green one")

-- The Items page.
ns.ShowItem(769)
shown = shownTexts()
check(shown:find("Chunk of Boar Meat", 1, true) ~= nil, "the items page shows its item")
check(shown:find("Mottled Boar", 1, true) ~= nil, "and who drops it")
-- A dropper with a known look: its face, and its name beside it (the name was left unplaced).
Book.Creature(3100).display = 4259
ns.ShowItem(769)
local dropper = under(window, function(f) return f._kind == "FontString" and f:IsVisible() and tostring(text(f)):find("Mottled Boar", 1, true) end)[1]
check(dropper ~= nil and dropper:GetPoint() ~= nil, "a dropper with a face still shows its name")
check(dropper:GetParent().icon._portrait == 4259, "and its face")
Book.Creature(3100).display = nil
ns.ShowItem(769)
check(under(window, function(f) return f._template == "GameTooltipTemplate" and f:IsShown() end)[1] == nil,
    "no tooltip in the page")
check(shown:find("[3-5]", 1, true) ~= nil, "a dropper's level beside its name")
-- What its tooltip says, written on the page: from the link it was seen with, a sell price as money.
W.itemTips[769] = { { leftText = "Chunk of Boar Meat" }, { leftText = "Binds when picked up", leftColor = { r = 1, g = 1, b = 1 } },
    { leftText = "Sell Price:", price = 4 } }
Book.Item(769).link = "|cffffffff|Hitem:769::::::::|h[Chunk of Boar Meat]|h|r"
ns.ShowItem(769)
shown = shownTexts()
check(shown:find(L.JITEMS_DETAILS, 1, true) ~= nil, "its tooltip's lines as Details")
check(shown:find("Binds when picked up", 1, true) ~= nil, "each line")
check(shown:find(ns.MoneyText(4), 1, true) ~= nil, "its sell price as money")
eq(select(2, shown:gsub("Chunk of Boar Meat", "")) >= 1, true, "its name the page's title")

-- An item you carry: a click on its icon opens Blizzard's bags on it, its buttons aglow.
W.items["[Chunk of Boar Meat]"] = { id = 769 }
W.bags[0] = { [2] = { link = "[Chunk of Boar Meat]", count = 3 } }
W.owned[769] = 3
local slot = under(window, function(f) return rawget(f, "itemID") == 769 and rawget(f, "_width") == 52 and f:IsVisible() end)[1]
local opened = W.bagsOpened
slot:Fire("OnClick", "LeftButton")
W.Advance(0.3)
eq(W.bagsOpened, opened + 1, "clicking its icon opens the bags")
local lit = 0
for _, b in ipairs(ContainerFrameCombinedBags._items) do
    for _, c in ipairs(b._children or {}) do if c._atlas == "bags-glow-white" and c:IsShown() then lit = lit + 1 end end
end
eq(lit, 1, "the slot holding it glows")
W.Advance(3)
lit = 0
for _, b in ipairs(ContainerFrameCombinedBags._items) do
    for _, c in ipairs(b._children or {}) do if c._atlas == "bags-glow-white" and c:IsShown() then lit = lit + 1 end end
end
eq(lit, 0, "for a few seconds")
CloseAllBags()
W.owned[769], W.bags[0] = nil, nil
slot:Fire("OnClick", "LeftButton")
W.Advance(0.3)
eq(W.bagsOpened, opened + 1, "not in your bags: nothing opens")
Journal.Show("creatures")

-- Trophies: the rares and bosses met, defeated ones in colour; a first defeat is news.
local rare = Book.Meet(3270, "Elder Mystic Razorsnout")
rare.classification, rare.reaction = "rare", 2
local boss = Book.Meet(3295, "Sludge Anomaly")
boss.skull = true
local news = {}
ns:OnNews(journal, function(_, event, npc) news[#news + 1] = event .. ":" .. tostring(npc) end)
ns.RecorderCombat.OnPartyKill(ns.modules.Recorder, "Creature-0-0-0-0-3270-0000000001")
check(table.concat(news, ","):find("TROPHY:3270", 1, true) ~= nil, "a rare's first defeat is a trophy")
news = {}
ns.RecorderCombat.OnPartyKill(ns.modules.Recorder, "Creature-0-0-0-0-3270-0000000002")
check(not table.concat(news, ","):find("TROPHY", 1, true), "not its second")
Journal.Show("trophies")
shown = shownTexts()
check(shown:find(string.format(ns.L.TROPHY_TOTAL, 1, 2), 1, true) ~= nil, "trophies: 1 of the 2 met defeated")
check(shown:find("Elder Mystic Razorsnout", 1, true) ~= nil
    and shown:find(string.format(ns.L.TROPHY_SUB, ns.L.TROPHY_RARE, string.format(ns.L.TROPHY_KILLS, 2)), 1, true) ~= nil,
    "a defeated rare: what it is and its kills")
check(shown:find("Sludge Anomaly", 1, true) ~= nil
    and shown:find(string.format(ns.L.TROPHY_SUB, ns.L.TROPHY_BOSS, ns.L.TROPHY_OPEN), 1, true) ~= nil, "a boss not yet defeated")
check(not shown:find("Mottled Boar", 1, true), "no ordinary creatures")
Journal.Show("creatures")

-- Met while open: listed on the next frame.
W.place = { map = 1411, x = 0.5, y = 0.5 }
W.Creature("target", 3102, "Bloodtalon Scythemaw", { level = 6, creatureType = "Beast" })
W.Fire("PLAYER_TARGET_CHANGED")
W.RunTimers()
check(names():find("Bloodtalon", 1, true) ~= nil, "a new creature listed")
check(journal:DebugLine():find(ns.L.JOURNAL_TAB_CREATURES, 1, true) ~= nil, "Debug line names the page")

-- Open On: where you left it (the default), your zone's creatures, or the first pinned one.
local creaturesPage
for _, p in ipairs(Journal.pages) do if p.key == "creatures" then creaturesPage = p end end
Journal.Show("items")
ns.ToggleJournal()
ns.ToggleJournal()
check(ns.JournalKit and window:IsShown(), "open again")
local shownItems = shownTexts():find(L.JITEMS_DETAILS, 1, true) ~= nil
check(shownItems, "Where You Left It: back on the Items page")
ns.ToggleJournal()
ns:SetOption("Journal", "openOn", "zone")
W.place = { map = 1411, x = 0.5, y = 0.5 }
creaturesPage.Select(3296)
Journal.Show("items")
ns.ToggleJournal()
eq(creaturesPage.Selected(), 3102, "Your Zone: on the Creatures page at the first creature listed in the zone you're in")
check(not journal.db.collapsed["map:1411"], "its zone unfolded")
ns.ToggleJournal()
W.place = { map = 9999, x = 0.5, y = 0.5 }
creaturesPage.Select(3296)
ns.ToggleJournal()
eq(creaturesPage.Selected(), 3296, "a zone with no creature known: where you left it")
ns.ToggleJournal()
ns:SetOption("Journal", "openOn", "pinned")
Book.SetPinned(3296, true)
creaturesPage.Select(3100)
ns.ToggleJournal()
eq(creaturesPage.Selected(), 3296, "Pinned Creature: the first pinned one")
Book.SetPinned(3296, false)
ns:SetOption("Journal", "openOn", "last")

-- Off: closed, and /codex opens its settings instead.
ns:SetEnabled("Journal", false)
check(not window:IsShown(), "closed when turned off")
W.Slash("/codex")
check(not window:IsShown(), "not opened while off")
check(ns.SettingsWindow.Current() ~= nil, "the settings instead")
finish()
