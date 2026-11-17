--[[
    Forever Gearbox - Modules/Quests/QuestMarkersRead.lua
    What Quest Markers (Modules/Quests/QuestMarkers.lua) draws, read from a unit's tooltip:
    its objective lines are the game's own word on which quest a creature belongs to and how far
    along it is (C_TooltipInfo.GetUnit; line types QuestTitle, QuestPlayer, QuestObjective). In a
    group the tooltip puts a QuestPlayer line with a name before each member's objectives (lines
    before any name are yours), and a party's progress can be added up or the lowest taken.
    The tooltip doesn't say what kind an objective is (kill, item, object), so the quest log's
    objectives are indexed by their text with the numbers and punctuation taken out.
    Adapted from Forever++'s Quest Nameplates by xIGBClutchIx (MIT License).
]]

local _, ns = ...

local ipairs, pairs, tonumber, floor = ipairs, pairs, tonumber, math.floor
local Plain = ns.Plain

local Read = {}
ns.QuestMarkersRead = Read

local kinds   -- normalized objective text -> objective type, nil until needed
local matched -- normalized tooltip text -> objective type, or false

local function normalize(text)
    return (text:lower():gsub("%d+", ""):gsub("[%p%s]+", " "):gsub("^ ", ""):gsub(" $", ""))
end

-- The quest log changed: index its objectives again when next asked.
function Read.Forget() kinds, matched = nil, {} end

local function indexObjectives()
    kinds, matched = {}, {}
    ns.EachLogQuest(function(questID)
        for _, objective in ipairs(C_QuestLog.GetQuestObjectives(questID) or {}) do
            local text, kind = Plain(objective.text), Plain(objective.type)
            if text and kind then
                text = normalize(text)
                if #text >= 3 then kinds[text] = kind end
            end
        end
    end)
end

local function objectiveKind(text)
    if not kinds then indexObjectives() end
    text = normalize(text)
    local kind = matched[text]
    if kind == nil then
        kind = false
        if #text >= 3 then
            for key, objectiveType in pairs(kinds) do
                if key == text or key:find(text, 1, true) or text:find(key, 1, true) then
                    kind = objectiveType
                    break
                end
            end
        end
        matched[text] = kind
    end
    return kind
end

-- Whether a QuestPlayer line names you. Forever's names may carry a surname after the name.
local function isMe(text, me)
    return me and (text == me or text:sub(1, #me + 1) == me .. " ")
end

-- One objective's progress as `party` counts it: Combined adds everyone's up (percentages are
-- averaged), Lowest is the member with the most left.
local function tally(objective, party)
    local members = objective.members
    if party == "combined" then
        local current, needed = 0, 0
        for _, member in ipairs(members) do current, needed = current + member[1], needed + member[2] end
        if objective.percent then return floor(current / #members), 100 end
        return current, needed
    end
    local worst = members[1]
    for _, member in ipairs(members) do
        if member[2] - member[1] > worst[2] - worst[1] then worst = member end
    end
    return worst[1], worst[2]
end

-- "0/8 Boars", "Boars: 0/8" and "Escort (45%)" read the same in every language.
local function progressOf(text)
    local current, needed = text:match("(%d+)%s*/%s*(%d+)")
    local percent = not current and text:match("(%d+)%%")
    if percent then current, needed = percent, 100 end
    return tonumber(current), tonumber(needed), percent and true or nil
end

local LINE = Enum.TooltipDataLineType

-- The unit's quest objectives, in tooltip order: { text, percent, members = { { current, needed } } }.
-- Two empty answers mean different things: an empty list when the unit has no tooltip data
-- (it has no objectives: the plate is cleared), nil when a line is secret (in combat, in an
-- instance: the game won't say, so the plate keeps what it shows).
local function objectivesOf(unit, party)
    local data = C_TooltipInfo.GetUnit(unit)
    if not (data and data.lines) then return {} end
    local me = Plain(UnitName("player"))
    local quest, mine, inQuest = 0, true, false
    local byKey, order = {}, {}
    for _, line in ipairs(data.lines) do
        local text, kind = Plain(line.leftText), Plain(line.type)
        if not (text and kind) then return nil end
        if kind == LINE.QuestTitle then
            inQuest, mine, quest = true, true, quest + 1
        elseif kind == LINE.QuestPlayer then
            mine = isMe(text, me)
        elseif (mine or party ~= "own") and (inQuest or kind == LINE.QuestObjective) then
            local current, needed, percent = progressOf(text)
            if current and needed then
                local key = quest .. ":" .. normalize(text)
                local objective = byKey[key]
                if not objective then
                    objective = { text = text, percent = percent, members = {} }
                    byKey[key], order[#order + 1] = objective, objective
                end
                objective.members[#objective.members + 1] = { current, needed }
            end
        end
    end
    return order
end

-- What the unit's plate shows: `current, needed, kind, percent` for its first objective not done
-- (`kind` the quest log's objective type, or false), the same with kind "done" when every one is,
-- false when it has none, or nil when the game won't say (the plate keeps what it shows).
function Read.Progress(unit, party)
    local objectives = objectivesOf(unit, party)
    if not objectives then return nil end
    local done
    for _, objective in ipairs(objectives) do
        local current, needed = tally(objective, party)
        if current < needed then return current, needed, objectiveKind(objective.text), objective.percent end
        done = done or { current, needed, objective.percent }
    end
    if done then return done[1], done[2], "done", done[3] end
    return false
end
