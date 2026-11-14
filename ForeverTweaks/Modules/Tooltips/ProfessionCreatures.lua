--[[
    Forever Tweaks - Profession Tooltips: creatures
    Profession Tooltips' Skinning line on a creature that can be skinned (a Beast or Dragonkin,
    dead or one you could fight; not players, pets or a friendly flight master's gryphon): the
    Skinning its level needs, colored against yours, or Blizzard's own requirement line recolored.
    It goes under the name and level, before the quest lines: added just before the first quest
    line is drawn, or at the end when there's none. Adapted from Forever++'s Profession Tooltips by
    xIGBClutchIx (MIT License).
]]

local _, ns = ...
local L = ns.L

local type, ipairs, setmetatable = type, ipairs, setmetatable
local Professions, Plain = ns.Professions, ns.Plain
local Shared = ns.ProfessionTooltipParts
local M, inCharge, skillLine, addLine = Shared.module, Shared.InCharge, Shared.SkillLine, Shared.AddLine
local findRequires, findNameLine, restyle, restyling = Shared.FindRequires, Shared.FindNameLine, Shared.Restyle, Shared.restyling
local SKIN = Professions.SKINNING

-- Beast and Dragonkin, the creature types that can be skinned (UnitCreatureType's second value).
local SKINNABLE_TYPES = { [1] = true, [2] = true }
local SKINNABLE_NAMES = { [L.PROFTOOLTIPS_BEAST] = true, [L.PROFTOOLTIPS_DRAGONKIN] = true }

-- Creatures ----------------------------------------------------------------------------------

-- Unit state can be secret; then it counts as no.
local function yes(value) return Plain(value) == true end

local function canSkin(unit)
    if yes(UnitIsPlayer(unit)) or yes(UnitPlayerControlled(unit)) then
        return false
    end
    -- Probe: the type's ID is a second value on Mainline; without it, the name the game shows.
    local name, kind = UnitCreatureType(unit)
    kind, name = Plain(kind), Plain(name)
    if type(kind) == "number" then
        if not SKINNABLE_TYPES[kind] then
            return false
        end
    elseif not SKINNABLE_NAMES[name or ""] then
        return false
    end
    -- Dead ones, or ones you could fight: not a friendly flight master's gryphon.
    return yes(UnitIsDead(unit)) or yes(UnitCanAttack("player", unit))
end

local unitData = setmetatable({}, { __mode = "k" }) -- tooltip -> the unit's tooltip data

local function addSkinLine(tooltip)
    if not (inCharge() and M.db.skinning) then
        return
    end
    local _, unit = tooltip:GetUnit()
    unit = Plain(unit)
    if type(unit) ~= "string" or not canSkin(unit) then
        return
    end
    -- Blizzard already says what it needs: recolor that once it's drawn, don't add another.
    local data = unitData[tooltip]
    local index = data and findRequires(data)
    if index then
        restyling[tooltip] = { index, SKIN, data.lines[index].leftText, findNameLine(data, index, SKIN) }
        return
    end
    local level = Plain(UnitLevel(unit))
    if not (type(level) == "number" and level > 0) then
        return -- a "??" boss, or secret
    end
    local line, color = skillLine(SKIN, Professions.SkinningNeed(level), L.PROFTOOLTIPS_REQUIRES)
    if line then
        addLine(tooltip, line, color)
    end
end

-- The line goes under the name and level, before the quest lines: it's added just before the
-- first quest line is drawn, or at the end when there's none.
local unitPending = setmetatable({}, { __mode = "k" }) -- tooltip -> true until the line is added

local function onUnitPre(_, tooltip, data)
    unitPending[tooltip] = true
    unitData[tooltip] = data
    restyling[tooltip] = nil
end

local function onQuestLinePre(_, tooltip)
    if unitPending[tooltip] then
        unitPending[tooltip] = nil
        addSkinLine(tooltip)
    end
end

local function onUnit(_, tooltip, data)
    local waiting = unitPending[tooltip]
    unitPending[tooltip] = nil
    if data and waiting then
        addSkinLine(tooltip)
    end
    local job = restyling[tooltip]
    restyling[tooltip] = nil
    unitData[tooltip] = nil
    if job then
        restyle(tooltip, job)
    end
end

M:AddPart({
    Enable = function()
        M:HookCallback(TooltipDataProcessor, "unit pre", function(hook)
            TooltipDataProcessor.AddTooltipPreCall(Enum.TooltipDataType.Unit, hook)
        end, onUnitPre)
        M:HookCallback(TooltipDataProcessor, "unit", function(hook)
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, hook)
        end, onUnit)
        for _, key in ipairs({ "QuestTitle", "QuestObjective", "QuestPlayer" }) do
            M:HookCallback(TooltipDataProcessor, "quest line " .. key, function(hook)
                TooltipDataProcessor.AddLinePreCall(Enum.TooltipDataLineType[key], hook)
            end, onQuestLinePre)
        end
    end,
})
