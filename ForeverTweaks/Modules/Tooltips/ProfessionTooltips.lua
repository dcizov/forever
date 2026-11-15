--[[
    Forever Tweaks - Profession Tooltips
    The skill a herb, vein, skinnable beast, or locked lockbox or chest needs, in its tooltip,
    colored against your skill the way a trainer colors recipes: red can't yet, then orange,
    yellow, green and gray as it gets easier. Herbs, ore and stone in your bags say the skill that
    gathers them; skeleton keys say what they open. Gathering shows only for professions you have,
    or always (red without it); Lockpicking only for characters who can pick locks (a rogue's, or
    with Blacksmithing, what the best skeleton key you can make opens). Blizzard's own "Requires
    Herbalism (75)" line is recolored in place instead of repeated, and taught to
    Lib/Professions.lua, so any language and Forever's changes fill in. The lines on items are
    ProfessionItems.lua's, on creatures (Skinning) ProfessionCreatures.lua's, on herbs, veins,
    chests and minimap pins ProfessionObjects.lua's; this file has the module, its data and what
    they share. Lines go right under the
    name, before quest lines (pre and line calls keep the data until then). Left to Forever++'s
    Profession Tooltips while that's on. Adapted from Forever++ by xIGBClutchIx (MIT License),
    whose ideas came from GatherSkillTooltip.
]]

local _, ns = ...
local L = ns.L

local type, ipairs, setmetatable, tonumber = type, ipairs, setmetatable, tonumber
local format, match, find = string.format, string.match, string.find
local Professions, Kit, OtherAddons, Plain = ns.Professions, ns.TooltipKit, ns.OtherAddons, ns.Plain

local HERB, MINE, SKIN = Professions.HERBALISM, Professions.MINING, Professions.SKINNING
local LOCK, SMITH = Professions.LOCKPICKING, Professions.BLACKSMITHING
local COVERS = { { "ForeverPlusPlus", "ProfessionTooltips" } }
local GATHERING, LOCKS = L.PROFTOOLTIPS_SECTION_GATHERING, L.PROFTOOLTIPS_SECTION_LOCKS

local M = ns:NewModule("ProfessionTooltips", {
    title = L.PROFTOOLTIPS_TITLE,
    category = "tooltips",
    description = L.PROFTOOLTIPS_DESC,
    added = "2.2.0",
    defaults = {
        show = "known", herbalism = true, mining = true, skinning = true, lockpicking = true,
        blacksmithing = true, items = true,
        learned = {}, -- data: what the game taught, { nodes, lockboxes } (Lib/Professions.lua)
    },
    options = {
        { key = "show", type = "dropdown", label = L.PROFTOOLTIPS_SHOW, tooltip = L.PROFTOOLTIPS_SHOW_TIP, section = GATHERING,
          choices = { { "known", L.PROFTOOLTIPS_SHOW_KNOWN }, { "always", L.PROFTOOLTIPS_SHOW_ALWAYS } } },
        { key = "herbalism", type = "checkbox", label = L.PROFTOOLTIPS_HERBALISM, tooltip = L.PROFTOOLTIPS_HERBALISM_TIP },
        { key = "mining", type = "checkbox", label = L.PROFTOOLTIPS_MINING, tooltip = L.PROFTOOLTIPS_MINING_TIP },
        { key = "skinning", type = "checkbox", label = L.PROFTOOLTIPS_SKINNING, tooltip = L.PROFTOOLTIPS_SKINNING_TIP },
        { key = "lockpicking", type = "checkbox", label = L.PROFTOOLTIPS_LOCKPICKING, tooltip = L.PROFTOOLTIPS_LOCKPICKING_TIP,
          section = LOCKS },
        { key = "blacksmithing", type = "checkbox", label = L.PROFTOOLTIPS_BLACKSMITHING, tooltip = L.PROFTOOLTIPS_BLACKSMITHING_TIP },
        { key = "items", type = "checkbox", label = L.PROFTOOLTIPS_ITEMS, tooltip = L.PROFTOOLTIPS_ITEMS_TIP,
          section = L.PROFTOOLTIPS_SECTION_ITEMS },
    },
})

M.notice = OtherAddons.CoveredNotices(M, COVERS, L.PROFTOOLTIPS_WHAT)

local function inCharge() return M.active and not OtherAddons.CoveredBy(M, COVERS) end

-- Data ---------------------------------------------------------------------------------------
-- The skill each gathers at, from Classic. Forever may change some; fix them here. Herbs and
-- veins are in Lib/Professions, which Gathering Map shares and which learns them in game.

local NODES = setmetatable({ -- object name -> { skill line, skill }
    -- Locked chests in the world; add more (and doors) here as they're confirmed in game.
    ["Solid Chest"] = { LOCK, 1 },
    ["Large Solid Chest"] = { LOCK, 1 },
}, {
    -- Herbs and veins, seeded and learned, once their skill is known.
    __index = function(_, name)
        local node = Professions.Node(name)
        if node and node[1] and node[2] then
            return node
        end
    end,
})

-- Locked boxes: item ID -> the Lockpicking skill to open them. The seed is every lockbox in the
-- client's tables (Lib/LockboxSkills.lua, generated); the skill in Blizzard's "Requires
-- Lockpicking (25)" line on a box's tooltip is learned over it, and a box the seed lacks is
-- learned from that line too.


-- Blacksmiths make skeleton keys that open locks like Lockpicking: item ID, the skill it opens
-- up to, and the Blacksmithing skill that makes it. From Classic; fix them here.
local KEYS = {
    { id = 15869, skill = 100, smith = 100 }, -- Silver Skeleton Key
    { id = 15870, skill = 150, smith = 150 }, -- Golden Skeleton Key
    { id = 15871, skill = 200, smith = 200 }, -- Truesilver Skeleton Key
    { id = 15872, skill = 275, smith = 275 }, -- Arcanite Skeleton Key
}
local KEY_SKILL = {}
for _, key in ipairs(KEYS) do
    KEY_SKILL[key.id] = key.skill
end

local OPTION = { [HERB] = "herbalism", [MINE] = "mining", [SKIN] = "skinning", [LOCK] = "lockpicking" }
local FALLBACK_NAME = {
    [HERB] = L.PROFTOOLTIPS_HERBALISM_NAME,
    [MINE] = L.PROFTOOLTIPS_MINING_NAME,
    [SKIN] = L.PROFTOOLTIPS_SKINNING_NAME,
    [LOCK] = L.PROFTOOLTIPS_LOCKPICKING_NAME,
}


-- The Lockpicking skill the player can open locks with: a rogue's own, or, with the Blacksmithing
-- option, that of the best skeleton key their Blacksmithing lets them make (0 when none yet).
-- Nil for anyone with neither.
local function lockRank()
    local rank, name = Professions.Rank(LOCK)
    if M.db.blacksmithing then
        local smith = Professions.Rank(SMITH)
        if smith then
            local best = 0
            for _, key in ipairs(KEYS) do
                if smith >= key.smith and key.skill > best then
                    best = key.skill
                end
            end
            rank = rank and rank > best and rank or best
        end
    end
    return rank, name
end

-- The line for a skill line and skill, colored, or nil when it's off or the player doesn't have
-- the profession and `show` is "known". Without the profession it's red: you can't gather it.
-- Lockpicking is never shown to characters who can't pick locks, whatever `show` says.
-- `text` is L.PROFTOOLTIPS_REQUIRES or _GATHERED.
local function skillLine(line, need, text)
    if not M.db[OPTION[line]] then
        return nil
    end
    local rank, name
    if line == LOCK then
        rank, name = lockRank()
        if not rank then
            return nil
        end
    else
        rank, name = Professions.Rank(line)
        if not rank and M.db.show ~= "always" then
            return nil
        end
    end
    local color = Professions.Difficulty(rank, need)
    return format(text, name or FALLBACK_NAME[line], need), color, rank, name or FALLBACK_NAME[line]
end

-- The "your skill" text that stands in for a bare profession name line under Blizzard's
-- requirement, colored like it: nil when the player has no skill to show.
local function yourSkill(color, rank, name)
    if rank then
        return Kit.Text(color, format(L.PROFTOOLTIPS_YOURS, name, rank))
    end
end

local function addLine(tooltip, text, color)
    tooltip:AddLine(text, color.r, color.g, color.b)
end

-- Blizzard's own "Requires Mining (1)" line on a node or creature: it's recolored in place
-- instead of adding ours. The pattern comes from its string, so it works in any language.
local REQUIRES = "^" .. Kit.FormatPattern(ITEM_MIN_SKILL, true) .. "$"

-- World objects and minimap pins -------------------------------------------------------------

-- An object's name without the color codes, icons, and spaces a tooltip may wrap it in.
local function clean(text)
    return strtrim(Kit.StripCodes(text))
end

local leftLine = Kit.LeftLine

-- The skill line and its color for the node named in `text`, or nil.
local function nodeLine(text)
    local node = NODES[clean(text)]
    if node then
        return skillLine(node[1], node[2], L.PROFTOOLTIPS_REQUIRES)
    end
end

-- For Blizzard's requirement line `text` of skill line `line`: its color (nil when the option is
-- off or the profession not shown), its text without codes, and the player's rank and profession
-- name. Nothing when `text` isn't such a line.
local function requiresColor(text, line)
    local plain = clean(text)
    local _, digits = match(plain, REQUIRES)
    local need = tonumber(digits)
    if need then
        local _, color, rank, name = skillLine(line, need, L.PROFTOOLTIPS_REQUIRES)
        return color, plain, rank, name
    end
end

-- Whether `text` is just the profession's name (Blizzard or another addon repeating it under the
-- requirement), in either the client's language or ours.
local function isProfessionName(text, line)
    local plain = clean(text)
    local _, name = Professions.Rank(line)
    return plain == FALLBACK_NAME[line] or (name ~= nil and plain == name)
end

-- The index of the line after `index` in data when it only repeats the profession's name, or nil.
local function findNameLine(data, index, line)
    local entry = data.lines[index + 1]
    local text = entry and Plain(entry.leftText)
    if type(text) == "string" and isProfessionName(text, line) then
        return index + 1
    end
end

-- The first of data's lines after the first that is Blizzard's requirement line: its index, or nil.
local function findRequires(data)
    local lines = Plain(data.lines)
    if type(lines) ~= "table" then
        return nil
    end
    for i = 2, #lines do
        local text = lines[i] and Plain(lines[i].leftText)
        if type(text) == "string" and match(clean(text), REQUIRES) then
            return i
        end
    end
end

-- Recolors Blizzard's requirement line on `tooltip`, once it's drawn: `job` is { index, skill
-- line, text, index of a bare name line under it?, skill? }. With a skill, the line at index is a
-- bare profession name line that ours replaces.
local function restyle(tooltip, job)
    local fontString = leftLine(tooltip, job[1])
    if job[5] then
        -- Data lines and drawn lines don't always line up (the game may skip some): when the one
        -- at the data's index isn't the line we mean, find the drawn line with its text. Object
        -- tooltip text isn't secret; a secret one never matches.
        local want = clean(job[3])
        local function drawn(fs)
            local text = fs and Plain(fs:GetText())
            return type(text) == "string" and clean(text) == want
        end
        if not drawn(fontString) then
            fontString = nil
            for i = 2, tooltip:NumLines() do
                local fs = leftLine(tooltip, i)
                if drawn(fs) then
                    fontString = fs
                    break
                end
            end
        end
        -- Blizzard's bare profession name line: it says what we would, so ours replaces it.
        local text, color = skillLine(job[2], job[5], L.PROFTOOLTIPS_REQUIRES)
        if fontString and text then
            fontString:SetText(Kit.Text(color, text))
        end
        return
    end
    local color, _, rank, name = requiresColor(job[3], job[2])
    if fontString and color then
        fontString:SetText(Kit.Text(color, clean(job[3])))
        -- A bare name line below it becomes the player's skill against that requirement.
        local nameString = job[4] and leftLine(tooltip, job[4])
        local text = nameString and yourSkill(color, rank, name)
        if text then
            nameString:SetText(text)
        end
    end
end

-- What ProfessionObjects.lua, ProfessionCreatures.lua and ProfessionItems.lua need from this file:
-- functions and constants only, no state (each keeps its own). Each reaches the module itself
-- with assert(ns.modules.ProfessionTooltips) and joins it with M:AddPart.
ns.ProfessionTooltipsShared = {
    InCharge = inCharge, SkillLine = skillLine, LockRank = lockRank, AddLine = addLine,
    IsProfessionName = isProfessionName, KEY_SKILL = KEY_SKILL, FindRequires = findRequires,
    FindNameLine = findNameLine, Restyle = restyle, NODES = NODES, Clean = clean,
    NodeLine = nodeLine, RequiresColor = requiresColor, YourSkill = yourSkill, REQUIRES = REQUIRES,
}

function M:OnInitialize() Professions.Attach(self.db.learned) end

function M:OnEnable()
    self:RegisterEvent("SKILL_LINES_CHANGED", Professions.Forget)
    self:RegisterEvent("CHAT_MSG_SKILL", Professions.Forget)
end
