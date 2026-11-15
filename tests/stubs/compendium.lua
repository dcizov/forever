--[[
    Forever Compendium - tests/stubs/compendium.lua
    The stand-in game's pieces only Forever Compendium uses, loaded last by tests/wow.lua: the
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
