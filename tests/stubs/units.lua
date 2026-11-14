--[[
    Forever suite - tests/stubs/units.lua
    The stand-in game's units, the player's place, and the quest giver windows, loaded by
    tests/wow.lua after the other stubs (it replaces their simpler unit functions; a unit without
    W.unitInfo answers as those did: W.units' GUIDs, W.unitExists, the one creature name).
      W.unitInfo[unit] = { guid, name, level, classification, creatureType, family, reaction,
                           player, controlled }: what the unit functions answer for `unit`
      W.place           = { map, x, y }: the player's place (nil: no map, as in an instance)
      W.subzone         = the subzone's name
      W.questWindow     = { questID, title }: the quest window open now (QUEST_DETAIL and so on)
      W.gossip          = { available = { GossipQuestUIInfo }, active = { ... } }
      W.greeting        = { available = { { questID, title, level } }, active = { { questID, title } } }
      W.lootSources[slot] = { guid, count, guid, count, ... } (else W.lootSource for every slot)
]]

W.unitInfo, W.lootSources = {}, {}
W.subzone = ""

local function info(unit) return W.unitInfo[unit] end
local function field(key, default)
    return function(unit)
        local u = info(unit)
        if u == nil or u[key] == nil then return default end
        return u[key]
    end
end

local simpleGUID, simpleExists, simpleName, simplePlayer = UnitGUID, UnitExists, UnitName, UnitIsPlayer
function UnitExists(unit) return info(unit) ~= nil or simpleExists(unit) end
function UnitGUID(unit)
    local u = info(unit)
    if u then return u.guid end
    return simpleGUID(unit)
end
function UnitName(unit)
    local u = info(unit)
    if u then return u.name end
    if next(W.unitInfo) == nil then return simpleName(unit) end
end
UnitLevel = field("level", 0)
UnitClassification = field("classification", "normal")
UnitCreatureType = field("creatureType", nil)
UnitCreatureFamily = field("family", nil)
function UnitIsPlayer(unit)
    local u = info(unit)
    if u then return u.player or false end
    return simplePlayer(unit)
end
UnitPlayerControlled = field("controlled", false)
function UnitReaction(unit) local u = info(unit); return u and u.reaction or nil end

-- Makes a creature unit: W.Creature("target", 3296, "Grunt", { level = 12 }).
function W.Creature(unit, npcID, name, extra)
    local u = { guid = "Creature-0-4618-0-3041-" .. npcID .. "-0000" .. string.format("%06X", math.random(0, 0xFFFFFF)),
        name = name, level = 10, creatureType = "Humanoid", reaction = 2 }
    for k, v in pairs(extra or {}) do u[k] = v end
    W.unitInfo[unit] = u
    return u
end

C_Map.GetPlayerMapPosition = function(mapID)
    local p = W.place
    if not p or p.map ~= mapID then return nil end
    return { GetXY = function() return p.x, p.y end }
end
C_Map.GetBestMapForUnit = function() return W.place and W.place.map or W.mapID end
function GetSubZoneText() return W.subzone end

-- Quest windows.
function GetQuestID() return W.questWindow and W.questWindow.questID or 0 end
function GetTitleText() return W.questWindow and W.questWindow.title or "" end
W.gossip = { available = {}, active = {} }
C_GossipInfo = {
    GetAvailableQuests = function() return W.gossip.available end,
    GetActiveQuests = function() return W.gossip.active end,
}
W.greeting = { available = {}, active = {} }
function GetNumAvailableQuests() return #W.greeting.available end
function GetAvailableQuestInfo(i) return false, 0, false, false, W.greeting.available[i].questID end
function GetAvailableTitle(i) return W.greeting.available[i].title end
function GetAvailableLevel(i) return W.greeting.available[i].level end
function GetNumActiveQuests() return #W.greeting.active end
function GetActiveQuestID(i) return W.greeting.active[i].questID end
function GetActiveTitle(i) return W.greeting.active[i].title end

-- The quest log (tests/stubs/quests.lua's W.quests): its size, a quest's index and level.
C_QuestLog.GetNumQuestLogEntries = function() return #W.quests, #W.quests end
C_QuestLog.GetLogIndexForQuestID = function(questID)
    for i, q in ipairs(W.quests) do if q.questID == questID then return i end end
end
local getInfo = C_QuestLog.GetInfo
C_QuestLog.GetInfo = function(i)
    local result = getInfo(i)
    if result then result.level = W.quests[i].level end
    return result
end

-- Area looting: each slot can come from several corpses.
function GetLootSourceInfo(slot)
    if not W.loot[slot] then return end
    if W.lootSources[slot] then return unpack(W.lootSources[slot]) end
    return W.lootSource, W.loot[slot].count or 1
end

-- Model frames: a unit's model shows its display ID, W.displays[guid] (0 until the game has it).
W.displays = {}
function W.FrameMethods:SetUnit(unit) self._unit = unit end
function W.FrameMethods:GetDisplayInfo()
    local u = self._unit and W.unitInfo[self._unit]
    return self._display or (u and W.displays[u.guid]) or 0
end
function W.FrameMethods:SetDisplayInfo(id) self._display, self._creature = id, nil end
function W.FrameMethods:SetCreature(id) self._creature, self._display = id, nil end
function W.FrameMethods:ClearModel() self._unit, self._display, self._creature = nil, nil, nil end

C_QuestLog.IsOnQuest = function(questID) return C_QuestLog.GetLogIndexForQuestID(questID) ~= nil end
