--[[
    Forever Tweaks - Modules/Tooltips/ProfessionItems.lua
    Profession Tooltips: items
    Profession Tooltips' lines on items: a lockbox's Lockpicking (Blizzard's own "Requires
    Lockpicking (25)" line drawn again in the difficulty color, and learned for the box), what a
    skeleton key opens, and the skill that gathers a herb, ore or stone. Placed with the other item
    tooltip lines (Lib/ItemTooltip.lua). Adapted from Forever++'s Profession Tooltips by
    xIGBClutchIx (MIT License).
]]

local _, ns = ...
local L = ns.L

local type, select, format = type, select, string.format
local Professions, ItemTooltip = ns.Professions, ns.ItemTooltip
local Shared = assert(ns.ProfessionTooltipsShared, "ProfessionItems.lua loads after ProfessionTooltips.lua")
local M = assert(ns.modules.ProfessionTooltips, "ProfessionItems.lua loads after ProfessionTooltips.lua")
local inCharge, skillLine, lockRank, addLine = Shared.InCharge, Shared.SkillLine, Shared.LockRank, Shared.AddLine
local isProfessionName, KEY_SKILL = Shared.IsProfessionName, Shared.KEY_SKILL
local LOCK = Professions.LOCKPICKING

-- Items --------------------------------------------------------------------------------------

-- itemID -> Lockpicking needed by the item's "Requires Lockpicking (N)" line, or false for an
-- item without one: looked for once per item. Where the line is changes with the tooltip (a
-- loot window, a chat link, another addon's lines), so its index is found once per tooltip
-- build (`data`) instead.
local lockNeeds = {}
local lockIndex = setmetatable({}, { __mode = "k" }) -- data -> the line's index, or false

-- An item's Lockpicking line in this build of its tooltip, { index, need }, or false. A box we
-- know counts whatever the skill's name says.
local function lockLine(id, data)
    local known = lockNeeds[id]
    if known == false then return false end
    local index = lockIndex[data]
    if index == nil then
        local skill, need, at = Professions.TooltipRequires(data)
        -- Lockpicking's name in English or the client's language (known only to characters who
        -- can pick locks).
        local isLock = skill and (Professions.Lockbox(id) or isProfessionName(skill, LOCK))
        index = isLock and at or false
        lockIndex[data] = index
        if isLock then
            lockNeeds[id] = need
            Professions.LearnLockbox(id, need)
        elseif type(data.lines) == "table" and #data.lines > 1 then
            -- An item not loaded yet has a lone "Retrieving" line: don't remember that as "none".
            lockNeeds[id] = false
        end
    end
    return index and { index, lockNeeds[id] } or false
end

-- Blizzard's own "Requires Lockpicking (25)" line on a lockbox: learned, and drawn again in the
-- difficulty color instead of adding a second line under it.
local function onItemLine(tooltip, data, lineData)
    if not inCharge() then
        return
    end
    local id = ItemTooltip.ItemID(data)
    local lock = id and lockLine(id, data)
    if not (lock and M.db.items and data.lines[lock[1]] == lineData) then
        return
    end
    local need = lock[2]
    local line, color = skillLine(LOCK, need, L.PROFTOOLTIPS_REQUIRES)
    if line then
        addLine(tooltip, line, color)
        return true
    end
end

-- The skill line and skill an item's line is about: a lockbox's Lockpicking, or a herb's or ore's
-- gathering skill. Nil for a lockbox whose tooltip already says it (onItemLine handles that).
local function itemNeed(id, data)
    local lock = Professions.Lockbox(id)
    if lock then
        if lockLine(id, data) then
            return nil
        end
        return LOCK, lock
    end
    return Professions.ItemSkill(id)
end

local function onItem(tooltip, data)
    if not (inCharge() and M.db.items) then
        return
    end
    local id = ItemTooltip.ItemID(data)
    local keySkill = id and M.db.blacksmithing and KEY_SKILL[id]
    if keySkill then
        local name = select(2, lockRank())
        addLine(tooltip, format(L.PROFTOOLTIPS_KEY, name or L.PROFTOOLTIPS_LOCKPICKING_NAME, keySkill),
            NORMAL_FONT_COLOR)
    end
    local skillLineID, need = nil, nil
    if id then
        skillLineID, need = itemNeed(id, data)
    end
    if skillLineID then
        local text = skillLineID == LOCK and L.PROFTOOLTIPS_REQUIRES or L.PROFTOOLTIPS_GATHERED
        local line, color = skillLine(skillLineID, need, text)
        if line then
            addLine(tooltip, line, color)
        end
    end
end

M:AddPart({
    Enable = function()
        ItemTooltip.OnInfo(M, onItem)
        ItemTooltip.ReplaceLine(M, onItemLine)
    end,
})
