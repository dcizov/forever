--[[
    Forever Codex - tests/stubs/compendium.lua
    The stand-in game's pieces only Forever Codex uses, loaded last by tests/wow.lua: the
    journal window's tabs, quest titles the game loads on request (W.questTitles: questID ->
    title; W.titleRequests lists what was asked), quest window rewards (W.questRewards,
    W.questChoices: item IDs), instances (W.instance = { name, kind }), map rectangles
    (W.mapRects[child][parent] = { left, right, top, bottom }) and players by GUID
    (W.playersByGUID[guid] = name).
]]

W.questTitles, W.titleRequests, W.questRewards, W.questChoices = {}, {}, {}, {}
W.mapRects, W.playersByGUID = {}, {}

C_QuestLog.GetTitleForQuestID = function(questID) return W.questTitles[questID] end
C_QuestLog.RequestLoadQuestByID = function(questID) W.titleRequests[#W.titleRequests + 1] = questID end
C_QuestLog.GetQuestTagInfo = function() return nil end
function QuestMapFrame_OpenToQuestDetails(questID) W.openedQuest = questID end
function SetPortraitTextureFromCreatureDisplayID(texture, displayID) texture._portrait = displayID end
C_QuestLog.IsOnQuest = C_QuestLog.IsOnQuest or function(questID)
    for _, q in ipairs(W.quests) do
        if q.questID == questID then return true end
    end
    return false
end

function GetNumQuestRewards() return #W.questRewards end
function GetNumQuestChoices() return #W.questChoices end
function GetQuestItemLink(kind, i)
    local id = (kind == "choice" and W.questChoices or W.questRewards)[i]
    return id and ("item:" .. id)
end
function GetQuestItemInfo(kind, i)
    local id = (kind == "choice" and W.questChoices or W.questRewards)[i]
    return id and ("Item " .. id), 134400, 1, 2
end

function GetInstanceInfo()
    local i = W.instance
    if not i then return "Kalimdor", "none" end
    return i.name, i.kind
end

C_Map.GetMapRectOnMap = function(child, parent)
    local r = W.mapRects[child] and W.mapRects[child][parent]
    if r then return r[1], r[2], r[3], r[4] end
end
C_Map.OpenWorldMap = function(mapID) W.openedMap = mapID end
function OpenWorldMap(mapID) W.openedMap = mapID end

function GetPlayerInfoByGUID(guid)
    local name = W.playersByGUID[guid]
    if name then return "Warrior", "WARRIOR", "Orc", "Orc", 2, name, "" end
end
function GetUnitName(unit) return UnitName(unit) end
function Ambiguate(name) return (name:gsub("%-.*$", "")) end
function BreakUpLargeNumbers(n) return tostring(n) end
function HandleModifiedItemClick() end
LEVEL = "Level"
FACTION_STANDING_INCREASED = "Your %s reputation has increased by %d."
FACTION_STANDING_DECREASED = "Your %s reputation has decreased by %d."
for q = 0, 7 do _G["ITEM_QUALITY" .. q .. "_DESC"] = "Quality " .. q end
SOUNDKIT.IG_CHARACTER_INFO_TAB = 841
SOUNDKIT.IG_SPELLBOOK_OPEN = 829
SOUNDKIT.IG_SPELLBOOK_CLOSE = 830
SOUNDKIT.IG_MAINMENU_OPTION = 852

-- Blizzard_SharedXML's tab functions: the selected tab kept on the holder.
function PanelTemplates_TabResize() end
function PanelTemplates_SetNumTabs(frame, n) frame.numTabs = n end
function PanelTemplates_SetTab(frame, id) frame.selectedTab = id end
C_Spell.GetSpellTexture = function(id) return W.spells[id] and 136243 end

-- Links, trying on, and the map pin (the journal's buttons and links): what was asked is kept in
-- W.linked (chat links, in order), W.triedOn (the last link tried on), W.waypoint ({ map, x, y },
-- tracked). Quest links are "quest:<id>". W.areas[areaID] = the area's name (C_Map.GetAreaInfo).
W.linked, W.areas = {}, {}
function GetQuestLink(questID) return "quest:" .. questID end
function ChatFrameUtil.InsertLink(link)
    if not W.chatOpen then return false end
    W.linked[#W.linked + 1] = link
    return true
end
function ChatFrameUtil.OpenChat(text) W.chatOpen = true; W.linked[#W.linked + 1] = text end
function DressUpLink(link) W.triedOn = link end
C_Item.IsDressableItemByID = function(itemID) return W.items and W.dressable and W.dressable[itemID] or false end
UiMapPoint = { CreateFromCoordinates = function(map, x, y) return { uiMapID = map, x = x, y = y } end }
C_Map.CanSetUserWaypointOnMap = function() return true end
C_Map.SetUserWaypoint = function(point) W.waypoint = { map = point.uiMapID, x = point.x, y = point.y } end
C_Map.GetAreaInfo = function(areaID) return W.areas[areaID] end
C_QuestLog.GetAllCompletedQuestIDs = function()
    local list = {}
    for questID, isDone in pairs(W.questsDone) do if isDone then list[#list + 1] = questID end end
    table.sort(list)
    return list
end
C_SuperTrack = { SetSuperTrackedUserWaypoint = function(on) W.waypointTracked = on end }
-- The player's race and class (IDs: 2 Orc, 1 Warrior unless W.race / W.class say otherwise).
function UnitRace() return "Orc", "Orc", W.race or 2 end
local unitClass = UnitClass
function UnitClass(unit)
    if unit == "player" and not (W.unitInfo[unit] and W.unitInfo[unit].class) then return "Warrior", "WARRIOR", W.class or 1 end
    return unitClass(unit)
end
-- Atlases: where each is in its file (all in one stand-in file, the whole of it).
C_Texture = { GetAtlasInfo = function(name)
    return { file = "atlas:" .. name, width = 64, height = 64, leftTexCoord = 0, rightTexCoord = 1, topTexCoord = 0, bottomTexCoord = 1 }
end }
-- A font string's font object (by the name it was set with) and a button's own text (none here).
function W.FrameMethods:GetFontObject()
    local font = self._fontObject
    return font and { GetName = function() return type(font) == "string" and font or nil end }
end
function W.FrameMethods:GetFontString() return self._fontString end
-- An item's tooltip data (C_TooltipInfo.GetHyperlink, GetItemByID): W.itemTips[itemID] = { lines },
-- each { leftText, rightText, price, leftColor = { r, g, b } }; else just its name.
W.itemTips = {}
local function itemTip(itemID)
    return { lines = W.itemTips[itemID] or { { leftText = "item " .. tostring(itemID) } } }
end
C_TooltipInfo.GetItemByID = function(itemID) return itemTip(itemID) end
C_TooltipInfo.GetHyperlink = function(link) return itemTip(tonumber(tostring(link):match("item:(%d+)"))) end
