--[[
    Forever Codex - Modules/Journal/QuestPage.lua
    A quest's page: a small window of its own, on the journal's parchment, for a quest named in
    the journal that's neither in your log (Blizzard's quest log shows those) nor in Spoken's
    Azeroth's Compendium (its words are there): ns.ShowQuest (Journal.lua) picks between them.

      * A card: the icon of where it stands with you, its title, its level, the level it needs,
        where it's listed, its kind, where it stands with you, and Show on Map (Blizzard's map
        pin where to go next: whoever gives it). Shift-click its title links it.
      * Below: what it's about, who starts it (an NPC, an object or an item), what it asks, who
        takes it in, what it gives (rewards and choices, once you saw its window), its chain
        (the quests before and after it; a click goes there; one you haven't discovered is a
        nameless padlock), and what else to know (the quest it leads to as a breadcrumb, the ones
        it shuts out, if discovered; the item it hands you). A quest not discovered shows nothing.
    Every name is a link: a creature or NPC you met opens its page, one you haven't puts the
    map pin on where it stands (QuestieDB's spawns), an item opens on the Items page (Shift-click
    links it). What comes from QuestieDB and what you saw read alike; without QuestieDB only what
    you saw is there, and a line says so.
]]

local _, ns = ...
local L = ns.L

local ipairs, pairs, next, format, table = ipairs, pairs, next, string.format, table
local CreateFrame = CreateFrame
local Book, Places, QuestieDB, QuestIndex = ns.Book, ns.Places, ns.QuestieDB, ns.QuestIndex
local Text = assert(ns.JournalText, "QuestPage.lua loads after JournalText.lua")
local J = assert(ns.JournalKit, "QuestPage.lua loads after JournalKit.lua")

local Detail = {}
ns.QuestPage = Detail

local WIDTH, HEIGHT = 520, 600

local NPC_ICON, OBJECT_ICON = "atlas:Waypoint-MapPin-Untracked", "Interface\\Icons\\INV_Box_01"

local pane = {}

---------------------------------------------------------------------------
-- Places: where a giver, an object or an ender stands
---------------------------------------------------------------------------

-- The first spawn QuestieDB has for an NPC or object ({ uiMapID, x, y }), or nil.
local function spawnOf(kind, id)
    local rec = kind == "npc" and QuestieDB.Npc(id) or QuestieDB.Object(id)
    return rec and rec.spawns[1], rec
end

-- Puts the map pin on `spot` ({ map, x, y } or { uiMapID, x, y }).
local function pinOn(spot)
    if spot then Places.Waypoint(spot.map or spot.uiMapID, spot.x, spot.y) end
end

---------------------------------------------------------------------------
-- Lines naming things
---------------------------------------------------------------------------

-- An NPC (or creature): its face and name if you met it (a click opens its page), else its name
-- from QuestieDB (`hint`: the name an objective gives it) with a map pin (a click puts
-- Blizzard's pin where it stands).
local function npcLine(lines, npcID, tag, hint)
    local rec = Book.Creature(npcID)
    local spawn, info = spawnOf("npc", npcID)
    local name = (rec and rec.name) or (info and info.name) or hint or format(L.QUESTS_NPC_ID, npcID)
    local display = rec and (rec.display or next(rec.displays or {}))
    local where = tag or (spawn and Text.MapName(spawn.uiMapID)) or (rec and Text.Where(rec)) or nil
    if rec then
        return lines:Line(Text.WHITE .. name .. "|r", { display = display, icon = not display and NPC_ICON or nil, tag = where,
            link = { "creature", npcID } })
    end
    return lines:Line(Text.GRAY .. name .. "|r", { icon = NPC_ICON, tag = where,
        onClick = spawn and function() pinOn(spawn) end or nil })
end

local function objectLine(lines, objectID, hint, tag)
    local spawn, info = spawnOf("object", objectID)
    local name = info and info.name or hint or format(L.QUESTS_OBJECT_ID, objectID)
    return lines:Line(name, { icon = OBJECT_ICON, tag = tag or (spawn and Text.MapName(spawn.uiMapID)),
        onClick = spawn and function() pinOn(spawn) end or nil })
end

local function itemLine(lines, itemID, tag)
    local r, g, b = Text.ItemColor(itemID)
    return lines:Line(Text.Color(r, g, b) .. Text.ItemName(itemID) .. "|r", { icon = Text.ItemIcon(itemID), tag = tag,
        link = { "item", itemID } })
end

---------------------------------------------------------------------------
-- The sections
---------------------------------------------------------------------------

local function addStart(lines, q, seen)
    local starters = q and q.starters or { npcs = {}, objects = {}, items = {} }
    local giver = seen and seen.giver
    if #starters.npcs + #starters.objects + #starters.items == 0 and not giver and not (seen and seen.startItem) then return end
    lines:Head(L.QUESTS_START)
    local listed = {}
    for _, npcID in ipairs(starters.npcs) do
        npcLine(lines, npcID)
        listed[npcID] = true
    end
    if giver and giver.npc and not listed[giver.npc] then npcLine(lines, giver.npc, Text.MapName(giver.map)) end
    if giver and not giver.npc and giver.name then lines:Line(giver.name, { icon = OBJECT_ICON, tag = Text.MapName(giver.map) }) end
    for _, objectID in ipairs(starters.objects) do objectLine(lines, objectID) end
    local items = {}
    for _, itemID in ipairs(starters.items) do items[itemID] = true end
    if seen and seen.startItem then items[seen.startItem] = true end
    for itemID in pairs(items) do itemLine(lines, itemID, L.QUESTS_STARTS_IT) end
end

-- What an objective's line says at its right: an item is collected, an object used; a creature's
-- line says nothing (QuestieDB doesn't tell a kill from a talk).
local KIND_TAG = { item = L.QUESTS_OBJ_ITEM, object = L.QUESTS_OBJ_USE }

local function addObjectives(lines, q, seen)
    local text = q and q.objectivesText or {}
    local asked = seen and seen.objectives or {}
    local needed = q and q.objectives or {}
    if #text + #asked + #needed == 0 then return end
    lines:Head(L.QUESTS_OBJECTIVES)
    if #text > 0 then lines:Line(table.concat(text, " "), { font = "QuestFont" }) end
    for _, objective in ipairs(asked) do lines:Line("- " .. objective.text, { font = "GameFontHighlightSmall" }) end
    for _, o in ipairs(needed) do
        if o.kind == "item" then
            itemLine(lines, o.id, KIND_TAG.item)
        elseif o.kind == "npc" then
            npcLine(lines, o.id, nil, o.text)
        else
            objectLine(lines, o.id, o.text, KIND_TAG.object)
        end
    end
end

local function addFinish(lines, q, seen)
    local finishers = q and q.finishers or { npcs = {}, objects = {} }
    local ender = seen and seen.ender
    if #finishers.npcs + #finishers.objects == 0 and not ender then return end
    lines:Head(L.QUESTS_FINISH)
    local listed = {}
    for _, npcID in ipairs(finishers.npcs) do
        npcLine(lines, npcID)
        listed[npcID] = true
    end
    if ender and ender.npc and not listed[ender.npc] then npcLine(lines, ender.npc, Text.MapName(ender.map)) end
    for _, objectID in ipairs(finishers.objects) do objectLine(lines, objectID) end
end

local function addRewards(lines, seen)
    lines:Head(L.QUESTS_REWARDS)
    local rewards, choices = seen and seen.rewards or {}, seen and seen.choices or {}
    for _, itemID in ipairs(rewards) do itemLine(lines, itemID) end
    for _, itemID in ipairs(choices) do itemLine(lines, itemID, L.QUESTS_CHOICE) end
    if #rewards + #choices == 0 then lines:Line(Text.GRAY .. L.QUESTS_NO_REWARDS .. "|r", { font = "GameFontHighlightSmall" }) end
end

-- One step of a chain: its line when discovered, else a nameless padlock.
local function chainStep(lines, id, tag)
    if QuestIndex.Discovered(id) then return lines:Quest(id, tag) end
    return lines:Line(Text.GRAY .. L.QUESTS_UNDISCOVERED .. "|r", { icon = Text.STATE_ICONS.locked, tag = tag })
end

local function addChain(lines, questID)
    local before, after = QuestIndex.Chain(questID)
    if #before + #after == 0 then return end
    lines:Head(L.QUESTS_CHAIN, #before + #after + 1)
    for i, id in ipairs(before) do chainStep(lines, id, format(L.QUESTS_STEP, i)) end
    lines:Quest(questID, L.QUESTS_THIS).hl:Show()
    for i, id in ipairs(after) do chainStep(lines, id, format(L.QUESTS_STEP, #before + 1 + i)) end
end

local function addNotes(lines, q)
    if not q then return end
    local notes = {}
    if q.breadcrumbFor and QuestIndex.Discovered(q.breadcrumbFor) then notes[#notes + 1] = { L.QUESTS_BREADCRUMB, q.breadcrumbFor } end
    -- The quests it shuts out, once each by title: one of the same title is the same quest for
    -- another race or class, and says nothing.
    local titles = { [Book.QuestName(q.id)] = true }
    for _, id in ipairs(q.exclusiveTo) do
        local title = Book.QuestName(id)
        if QuestIndex.Discovered(id) and not titles[title] then
            titles[title] = true
            notes[#notes + 1] = { L.QUESTS_EXCLUSIVE, id }
        end
    end
    if #notes == 0 and not q.sourceItemID then return end
    lines:Head(L.QUESTS_NOTES)
    for _, note in ipairs(notes) do lines:Quest(note[2], note[1]) end
    if q.sourceItemID then itemLine(lines, q.sourceItemID, L.QUESTS_GIVEN) end
end

---------------------------------------------------------------------------
-- The card
---------------------------------------------------------------------------

-- Where Show on Map points: the ender once the quest is yours, else the giver; what you saw first.
local function nextSpot(questID, q, seen)
    local state = Text.QuestState(questID)
    local taken = state == "log" or state == "ready"
    local place = seen and (taken and seen.ender or seen.giver)
    if place and place.map then return place end
    local group = q and (taken and q.finishers or q.starters)
    for _, npcID in ipairs(group and group.npcs or {}) do
        local spawn = spawnOf("npc", npcID)
        if spawn then return spawn end
    end
    for _, objectID in ipairs(group and group.objects or {}) do
        local spawn = spawnOf("object", objectID)
        if spawn then return spawn end
    end
end

local function metaLine(questID, q, seen)
    local parts = {}
    local level = QuestIndex.Level(questID)
    if level then parts[#parts + 1] = format(L.JOURNAL_LEVEL, level) end
    if q and q.requiredLevel then parts[#parts + 1] = format(L.QUESTS_REQUIRES, q.requiredLevel) end
    local _, group = QuestIndex.GroupOf(q)
    if q then parts[#parts + 1] = group end
    local kind = seen and Text.QuestKind(seen)
    if kind then parts[#parts + 1] = kind elseif q and q.repeatable then parts[#parts + 1] = L.JOURNAL_CAT_DAILY end
    return table.concat(parts, "  \194\183  ")
end

-- The card's buttons, right to left from its bottom right corner, only those shown.
local function placeButtons(card)
    local previous
    for _, b in ipairs({ card.map }) do
        if b and b:IsShown() then
            b:ClearAllPoints()
            if previous then b:SetPoint("RIGHT", previous, "LEFT", -6, 0) else b:SetPoint("BOTTOMRIGHT", -12, 12) end
            previous = b
        end
    end
end

local function buildCard(parent)
    local card = J.Panel(parent)
    card:SetPoint("TOPLEFT")
    card:SetPoint("TOPRIGHT")
    card:SetHeight(104)
    card.state = card:CreateTexture(nil, "ARTWORK")
    card.state:SetSize(22, 22)
    card.state:SetPoint("TOPLEFT", 16, -18)
    card.title = card:CreateFontString(nil, "OVERLAY", J.TITLE_FONT)
    J.InkFont(card.title)
    card.title:SetPoint("LEFT", card.state, "RIGHT", 8, 0)
    card.title:SetPoint("RIGHT", -16, 0)
    card.title:SetJustifyH("LEFT")
    card.title:SetWordWrap(false)
    card.meta = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    card.meta:SetPoint("TOPLEFT", card.state, "BOTTOMLEFT", 0, -10)
    card.meta:SetPoint("RIGHT", -16, 0)
    card.meta:SetJustifyH("LEFT")
    J.InkFont(card.meta, "inkSoft")
    card.stateText = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.stateText:SetPoint("TOPLEFT", card.meta, "BOTTOMLEFT", 0, -6)
    J.InkFont(card.stateText, "heading")
    local divider = J.Divider(card)
    divider:SetPoint("BOTTOMLEFT", 10, 0)
    divider:SetPoint("BOTTOMRIGHT", -10, 0)
    card.map = ns.Kit.NewButton(card, L.QUESTS_SHOW_MAP, 120, function() ns.FocusQuest(pane.questID, pane.spot) end)
    -- Shift-click on the title links the quest in chat.
    card.titleButton = CreateFrame("Button", nil, card)
    card.titleButton:SetAllPoints(card.title)
    card.titleButton:SetScript("OnClick", function() J.Link("quest", pane.questID) end)
    return card
end

local function build(parent)
    pane.card = buildCard(parent)
    local body = J.Panel(parent)
    body:SetPoint("TOPLEFT", pane.card, "BOTTOMLEFT", 0, -6)
    body:SetPoint("BOTTOMRIGHT")
    pane.lines = J.NewLines(body, 400)
    pane.lines.scroll:SetPoint("TOPLEFT", 14, -10)
    pane.lines.scroll:SetPoint("BOTTOMRIGHT", -24, 10)
end

-- The window, made the first time a quest is shown: Blizzard's portrait window with the
-- parchment in it; it moves, and Escape closes it.
local window
local function buildWindow()
    window = CreateFrame("Frame", "ForeverCodexQuest", UIParent, "PortraitFrameTemplate")
    ns.Journal.FadeWhileMoving(window)
    window:SetSize(WIDTH, HEIGHT)
    window:SetPoint("CENTER", 200, 0)
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:SetClampedToScreen(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Book_08")
    window:SetTitle(L.QUESTS_WINDOW)
    tinsert(UISpecialFrames, "ForeverCodexQuest")
    local page, paper = J.Page(window)
    page:SetPoint("TOPLEFT", 4, -60)
    page:SetPoint("BOTTOMRIGHT", -6, 5)
    build(paper)
end

-- Opens the window on quest `questID`.
function Detail.Open(questID)
    if not window then buildWindow() end
    window:Show()
    Detail.Show(questID)
    ns.Sound("open")
end

-- Whether the window is open.
function Detail.IsOpen() return window ~= nil and window:IsShown() end

-- Shows quest `questID` in the window (nil: none).
function Detail.Show(questID)
    pane.questID = questID
    local lines, card = pane.lines, pane.card
    card:SetShown(questID ~= nil)
    lines:Begin()
    if not (questID and QuestIndex.Discovered(questID)) then
        card:Hide()
        lines:Line(Text.GRAY .. (questID and L.QUESTS_NOT_DISCOVERED or L.QUESTS_EMPTY) .. "|r")
        return lines:End()
    end
    local q, seen = QuestIndex.Quest(questID), Book.Quest(questID)
    local state = Text.QuestState(questID)
    J.SetIcon(card.state, Text.STATE_ICONS[state])
    card.title:SetText(Book.QuestName(questID))
    card.meta:SetText(metaLine(questID, q, seen))
    card.stateText:SetText(Text.QuestStateLabel(state))
    pane.spot = nextSpot(questID, q, seen)
    card.map:SetEnabled(pane.spot ~= nil)
    placeButtons(card)
    if QuestieDB.Status() ~= "ready" then
        lines:Line(Text.GRAY .. L.QUESTS_NO_QUESTIEDB .. "|r", { font = "GameFontHighlightSmall" })
    end
    addStart(lines, q, seen)
    addObjectives(lines, q, seen)
    addFinish(lines, q, seen)
    addRewards(lines, seen)
    addChain(lines, questID)
    addNotes(lines, q)
    lines:End()
    lines.scroll:SetVerticalScroll(0)
end

