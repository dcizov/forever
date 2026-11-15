--[[
    Forever Compendium - tests/scenarios/compendium/pins.lua
    Quest Pins and Rare Pins on the world map and the minimap: givers only for quests not taken
    or done, turn-ins grey until ready, objectives only while unfinished (at their busiest
    places), quests at one spot sharing a pin, each kind's checkbox, redrawing as the log
    changes, rares where they were seen most, and the minimap's reach.
    Run by tests/run.lua (lua5.1 tests/run.lua pins), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverCompendium")
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
OpenMapAPI = nil
ns:SetOption("QuestPins", "size", 20)
W.RunTimers()

-- Ready: the turn-in goes yellow once the log says so.
W.questsReady[4] = true
W.Fire("QUEST_LOG_UPDATE")
W.RunTimers()
eq(ofKind("ender")[1].spec.gray, false, "yellow once ready")

-- The tooltip names each quest and what it's there for.
local tipLines = {}
function GameTooltip:AddLine(text) tipLines[#tipLines + 1] = text end
givers[1]:Fire("OnEnter")
eq(tipLines[1], "Offered (5)", "the tooltip names the first quest and its level")
eq(tipLines[2], ns.L.QPINS_GIVES, "and what it's there for")
eq(tipLines[4], "Also Offered (5)", "then the next quest at it")

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
check(ForeverCompendiumJournal:IsShown(), "a right-click opens the journal")

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
eq(dailyPin and dailyPin.icon._atlas, "QuestDaily", "a daily's giver is blue")
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
