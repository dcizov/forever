--[[
    Forever Codex - tests/scenarios/compendium/pins.lua
    Quest Pins and Rare Pins on the world map and the minimap: givers only for quests not taken
    or done, turn-ins grey until ready, objectives only while unfinished (at their busiest
    places), quests at one spot sharing a pin, each kind's checkbox, redrawing as the log
    changes, rares where they were seen most, and the minimap's reach.
    Run by tests/run.lua (lua5.1 tests/run.lua pins), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverCodex")
login()
local Book, Places = ns.Book, ns.Places
local MAP = 1411

-- What the Recorder learned.
local function quest(questID, title, giver, ender)
    local rec = Book.QuestRecord(questID)
    rec.title, rec.level, rec.giver, rec.ender = title, 5, giver, ender
    return rec
end
local at = { npc = 3143, map = MAP, x = 0.40, y = 0.60 }
quest(1, "Offered", at)
quest(2, "Also Offered", at) -- the same giver: one pin
quest(3, "Done Already", { npc = 3143, map = MAP, x = 0.1, y = 0.1 })
W.questsDone[3] = true
local taken = quest(4, "Taken", at, { npc = 3144, map = MAP, x = 0.45, y = 0.62 })
taken.marks = { [1] = { [MAP] = { cells = { [Places.Cell(0.5, 0.5)] = 9, [Places.Cell(0.7, 0.7)] = 2 } } },
    [2] = { [MAP] = { cells = { [Places.Cell(0.2, 0.8)] = 5 } } } }
quest(5, "Elsewhere", { npc = 1, map = 999, x = 0.5, y = 0.5 })
W.quests = { { title = "Taken", questID = 4, objectives = {
    { type = "monster", text = "Boars: 2/6", numFulfilled = 2, numRequired = 6, finished = false },
    { type = "item", text = "Tusks: 4/4", numFulfilled = 4, numRequired = 4, finished = true } } } }

-- The world map.
W.worldMapID, W.canvasScale = MAP, 1
WorldMapFrame:Show()
ns:SetOption("QuestPins", "size", 20) -- a change draws again
W.RunTimers()
local function pins(module, kind)
    local list = {}
    for _, f in ipairs(W.frames) do
        local spec = rawget(f, "spec")
        if spec and f:IsShown() and f._kind == (kind or "Button") and (module ~= "rare" or spec.npc) and (module ~= "quest" or spec.entries) then
            list[#list + 1] = f
        end
    end
    return list
end
local function ofKind(kind, list)
    local found = {}
    for _, pin in ipairs(list or pins("quest")) do if pin.spec.kind == kind then found[#found + 1] = pin end end
    return found
end
local givers = ofKind("giver")
eq(#givers, 1, "two quests from one giver: one pin; done ones and other maps: none")
eq(givers[1] and #givers[1].spec.entries, 2, "both quests at it")
eq(givers[1] and givers[1].icon._atlas, "QuestNormal", "a !")
local enders = ofKind("ender")
eq(#enders, 1, "the taken quest's turn-in")
eq(enders[1] and enders[1].spec.gray, true, "grey until ready")
eq(#ofKind("objective"), 2, "the unfinished objective's places, not the finished one's")
eq(#ofKind("giver"), 1, "a taken quest's giver isn't shown")

-- OpenMap: above its stitched art, and drawn again as its view moves.
local heard = {}
OpenMapAPI = { ArtTopLevel = function() return 5000 end,
    RegisterCallback = function(owner, event, fn) heard[event] = fn end }
ns:SetOption("QuestPins", "size", 21)
W.RunTimers()
check(givers[1]:GetParent():GetFrameLevel() > 5000, "OpenMap: the pins over its stitched art")
check(heard.OpenMap_ViewChanged ~= nil and heard.OpenMap_StitchedChanged ~= nil, "listening to its view and map")
heard.OpenMap_ViewChanged("OpenMap_ViewChanged", 0.5, 0.5, 2)
W.RunTimers()
eq(#ofKind("giver"), 1, "drawn again as the view moves")
-- Its stitched map, as Questie's pins are there: the zone beside the one underneath (999, right of
-- it on the stitched world) has its pins drawn too, carried onto the map underneath.
W.maps[MAP], W.maps[999], W.maps[1414] = 1414, 1414, 947
W.mapTypes[1414], W.mapTypes[947] = Enum.UIMapType.Continent, Enum.UIMapType.World
local LEFT = { [MAP] = 0, [999] = 0.5 }
OpenMapAPI.IsStitched = function() return true end
OpenMapAPI.GetView = function() return 0.5, 0.5, 1 end
OpenMapAPI.WorldFromMap = function(mapID, x, y) if LEFT[mapID] then return LEFT[mapID] + x * 0.5, y end end
OpenMapAPI.MapFromWorld = function(mapID, u, v) if mapID == MAP then return u / 0.5, v end end
heard.OpenMap_ViewChanged("OpenMap_ViewChanged", 0.5, 0.5, 1)
W.RunTimers()
local beside
for _, pin in ipairs(ofKind("giver")) do
    if pin.spec.entries[1] and pin.spec.entries[1].questID == 5 then beside = pin end
end
check(beside ~= nil, "OpenMap: the next zone's quest giver on its stitched map")
eq(beside and beside._point[4], 1.5 * WorldMapFrame.ScrollContainer.Child:GetWidth(), "where it is on the stitched world")
eq(#ofKind("giver"), 2, "and the zone underneath's still")
OpenMapAPI.IsStitched = function() return false end
heard.OpenMap_StitchedChanged("OpenMap_StitchedChanged", false)
W.RunTimers()
eq(#ofKind("giver"), 1, "Blizzard's own map: only its zone's")
W.maps[MAP], W.maps[999], W.maps[1414] = nil, nil, nil
OpenMapAPI = nil
ns:SetOption("QuestPins", "size", 20)
W.RunTimers()

-- Ready: the turn-in goes yellow once the log says so.
W.questsReady[4] = true
W.Fire("QUEST_LOG_UPDATE")
W.RunTimers()
eq(ofKind("ender")[1].spec.gray, false, "yellow once ready")

-- The tooltip, as Forever++'s: "[level] Title" for each quest, then what it's there for; what
-- clicks do only while Shift is held.
local tipLines = {}
function GameTooltip:AddLine(text) tipLines[#tipLines + 1] = text end
function GameTooltip:AddDoubleLine(left) tipLines[#tipLines + 1] = left end
givers[1]:Fire("OnEnter")
eq(tipLines[1], "[5] Offered", "the tooltip names the first quest and its level")
eq(tipLines[2], "[5] Also Offered", "then the next quest at it")
eq(tipLines[3], ns.L.QPINS_GIVES, "then what it's there for")
check(tipLines[#tipLines] ~= ns.L.QPINS_HINT, "no click hints without Shift")
givers[1]:Fire("OnLeave")
tipLines = {}
W.shift = true
givers[1]:Fire("OnEnter")
eq(tipLines[#tipLines], ns.L.QPINS_HINT, "with Shift: Shift-click shows the quest")
check(givers[1]:IsMouseClickEnabled(), "and the pin takes clicks while it's held")
givers[1]:Fire("OnLeave")
check(not givers[1]:IsMouseClickEnabled(), "clicks go through to the map otherwise")
-- A quest in your log: its pin says the quest log, and a Shift-click opens it there.
tipLines = {}
local objective = ofKind("objective")[1]
objective:Fire("OnEnter")
eq(tipLines[#tipLines], ns.L.QPINS_HINT_LOG, "its tooltip: the quest log")
objective:Fire("OnClick", "LeftButton")
eq(W.openedQuest, 4, "a Shift-click opens it in your quest log")
objective:Fire("OnLeave")
W.shift = false

-- Each kind's checkbox.
ns:SetOption("QuestPins", "objectives", false)
W.RunTimers()
eq(#ofKind("objective"), 0, "Objectives off")
ns:SetOption("QuestPins", "givers", false)
W.RunTimers()
eq(#ofKind("giver"), 0, "Givers off")
ns:SetOption("QuestPins", "worldMap", false)
W.RunTimers()
eq(#pins("quest"), 0, "World Map off: none")
ns:SetOption("QuestPins", "worldMap", true)
W.RunTimers()
eq(#ofKind("ender"), 1, "back on")

-- The minimap: what's within reach of where you stand.
W.mapSizes[MAP] = { 4000, 3000 }
W.place = { map = MAP, x = 0.45, y = 0.62 }
W.Fire("ZONE_CHANGED")
W.RunTimers()
eq(#pins("quest", "Frame"), 1, "the turn-in you stand at, on the minimap")
-- Rotate Minimap: turning moves the pins, without setting their art again (that lagged).
local turning = pins("quest", "Frame")[1]
local arts = 0
local setAtlas = turning.icon.SetAtlas
turning.icon.SetAtlas = function(self, ...) arts = arts + 1; return setAtlas(self, ...) end
W.cvars.rotateMinimap = "1"
W.place = { map = MAP, x = 0.452, y = 0.622 } -- a step away, so turning swings it round
W.Advance(0.05)
local before = { select(4, turning:GetPoint()) }
W.facing = 1.2
W.Advance(0.05)
local after = { select(4, turning:GetPoint()) }
check(before[1] ~= after[1] or before[2] ~= after[2], "turning moves the pin")
eq(arts, 0, "its art isn't set again")
turning.icon.SetAtlas = setAtlas
W.cvars.rotateMinimap, W.facing = nil, nil
W.place = { map = MAP, x = 0.95, y = 0.05 }
W.Advance(0.3)
eq(#pins("quest", "Frame"), 0, "out of reach once you walk away")

-- Rare Pins: rares only, where seen most; a right-click opens the journal on it.
local rare = Book.Meet(500, "Rare Boar")
rare.classification, rare.maxLevel = "rare", 8
rare.zones[MAP] = { cells = { [Places.Cell(0.3, 0.3)] = 1, [Places.Cell(0.6, 0.2)] = 7 } }
Book.Meet(501, "Plain Boar").zones[MAP] = { cells = { [Places.Cell(0.3, 0.3)] = 4 } }
ns:Announce("CREATURE_NEW", 500)
W.RunTimers()
local rares = pins("rare")
eq(#rares, 1, "one rare pin, none for a plain creature")
local x, y = Places.CellCenter(Places.Cell(0.6, 0.2))
eq(rares[1] and rares[1].spec.x, x, "where it was seen most")
eq(rares[1] and rares[1].spec.y, y, "(both ways)")
rares[1]:Fire("OnClick", "RightButton")
check(ForeverCodexJournal:IsShown(), "a right-click opens the journal")

-- Above the map: Blizzard's own map art and pins start at frame level 2000, so a holder just
-- over the canvas would be drawn under the map (the pins never showed in game).
local anyPin = pins("quest")[1]
check(anyPin and anyPin:GetParent():GetFrameLevel() > 2000, "pins drawn above the map's own")

-- Quest titles from the game for a quest known only by number; a daily giver's blue mark;
-- an item that starts a quest; a zone's pins on its continent's map.
W.questsReady[4] = nil
ns:SetOption("QuestPins", "givers", true)
local daily = Book.QuestRecord(20)
daily.giver, daily.daily = { npc = 3150, map = MAP, x = 0.8, y = 0.2 }, true
W.questTitles[20] = "Daily Chores"
local starts = Book.QuestRecord(21)
starts.startItem, starts.itemFrom = 4866, { npc = 3100, map = MAP, x = 0.3, y = 0.3 }
W.Fire("QUEST_LOG_UPDATE")
W.RunTimers()
local dailyPin
for _, pin in ipairs(ofKind("giver")) do
    if pin.spec.entries[1].questID == 20 then dailyPin = pin end
end
eq(dailyPin and dailyPin.icon._atlas, "QuestNormal", "a daily's giver: the !")
eq(dailyPin and dailyPin.spec.color and dailyPin.spec.color[3], 1, "tinted blue, as a repeatable quest's")
check(dailyPin and dailyPin.icon._desaturated, "the yellow taken out first")
tipLines = {}
dailyPin:Fire("OnEnter")
check(tipLines[1] and tipLines[1]:find("Daily Chores", 1, true), "its title from the game, not its number")
eq(#ofKind("item"), 1, "an item that starts a quest")
W.maps[MAP], W.mapTypes[12] = 12, 2
W.mapRects[MAP] = { [12] = { 0.5, 0.75, 0.25, 0.5 } }
W.worldMapID = 12
ns:SetOption("QuestPins", "size", 22)
W.RunTimers()
local onContinent = ofKind("giver")
check(#onContinent >= 1, "givers on the continent's map")
local first = onContinent[1] and onContinent[1].spec
check(first and first.x >= 0.5 and first.x <= 0.75, "placed in the zone's part of it")
eq(#ofKind("objective"), 0, "objectives stay on the zone's own map")
W.worldMapID = MAP
ns:SetOption("QuestPins", "size", 20)
W.RunTimers()

-- Creature Areas: a pinned creature's places, under the pins.
local wolf = Book.Meet(3101, "Dire Wolf")
wolf.zones = { [MAP] = { cells = { [Places.Cell(0.5, 0.5)] = 3, [Places.Cell(0.6, 0.5)] = 1 } } }
wolf.pinned = true
ns:Announce("CREATURE_PINNED", 3101, true)
W.RunTimers()
local patches = {}
for _, f in ipairs(W.frames) do
    local spec = rawget(f, "spec")
    if spec and spec.span and f:IsShown() then patches[#patches + 1] = f end
end
eq(#patches, 2, "a patch for each place it was seen")
check(patches[1] and patches[1]:GetParent():GetFrameLevel() < anyPin:GetParent():GetFrameLevel(), "under the quest pins")
W.place = { map = MAP, x = 0.5, y = 0.5 }
W.Fire("ZONE_CHANGED")
W.RunTimers()
local cut
for _, f in ipairs(W.frames) do
    local spec = rawget(f, "spec")
    if spec and spec.span and f._kind == "Frame" and f:IsShown() then cut = rawget(f, "masked") and rawget(f, "maskShape") end
end
eq(cut, "Interface\\CharacterFrame\\TempPortraitAlphaMask", "on the minimap, an area is cut to its round edge")
ns:SetOption("CreatureAreas", "pinned", false)
W.RunTimers()
local left = 0
for _, f in ipairs(patches) do if f:IsShown() then left = left + 1 end end
eq(left, 0, "Pinned Creatures off: none")

-- Off: nothing drawn.
ns:SetEnabled("QuestPins", false)
ns:SetEnabled("RarePins", false)
W.RunTimers()
eq(#pins(), 0, "modules off: no pins")
finish()
