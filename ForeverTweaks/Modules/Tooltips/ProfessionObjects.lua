--[[
    Forever Tweaks - Modules/Tooltips/ProfessionObjects.lua
    Profession Tooltips: world objects and minimap pins
    Profession Tooltips' line on a herb, vein or locked chest under the mouse, and in a minimap
    pin's tooltip. A world object's tooltip has its name alone on the first line, and the skill
    line goes right under it, before quest objectives (its data is kept from the pre call, and the
    line added once the first line is drawn); Blizzard's own requirement line, or a bare "Mining"
    line under a vein, is recolored or replaced instead. A minimap pin's first line holds every
    pin under the mouse on lines of its own, so the skill line goes into that text under its
    node's name. Blizzard's requirement lines teach Lib/Professions.lua what a node needs.
    Adapted from Forever++'s Profession Tooltips by xIGBClutchIx (MIT License).
]]

local _, ns = ...

local type, setmetatable = type, setmetatable
local gsub, gmatch, match, find, concat = string.gsub, string.gmatch, string.match, string.find, table.concat
local Professions, Kit, Plain = ns.Professions, ns.TooltipKit, ns.Plain
local Shared = assert(ns.ProfessionTooltipsShared, "ProfessionObjects.lua loads after ProfessionTooltips.lua")
local M = assert(ns.modules.ProfessionTooltips, "ProfessionObjects.lua loads after ProfessionTooltips.lua")
local inCharge, NODES, clean = Shared.InCharge, Shared.NODES, Shared.Clean
local restyling = setmetatable({}, { __mode = "k" }) -- tooltip -> the restyle job for its post call
local findRequires, findNameLine, restyle = Shared.FindRequires, Shared.FindNameLine, Shared.Restyle
local nodeLine, requiresColor, yourSkill, isProfessionName = Shared.NodeLine, Shared.RequiresColor, Shared.YourSkill, Shared.IsProfessionName
local addLine, REQUIRES, leftLine = Shared.AddLine, Shared.REQUIRES, Kit.LeftLine

-- A herb or vein under the mouse, or a minimap pin. A world object's tooltip has its name alone
-- on the first line, and the skill line is added after it. A minimap pin's first line holds
-- everything on separate lines, overlapping pins and their quest objectives too, so the skill
-- line goes into that text under its node's name.
-- A world object: its name alone on the first line, `text`.
local function addObjectLine(tooltip, data, text)
    -- Blizzard's own requirement line names the profession and skill in the client's language:
    -- what a herb or vein needs is learned from it, for every language and patch.
    local skill, need = Professions.TooltipRequires(data)
    if skill then Professions.LearnRequirement(clean(text), skill, need) end
    local node = NODES[clean(text)]
    if not node then return end
    -- Blizzard already says what it needs: recolor that once it's drawn, don't add another.
    local index = findRequires(data)
    if index then
        restyling[tooltip] = { index, node[1], data.lines[index].leftText, findNameLine(data, index, node[1]) }
        return
    end
    -- The game's own "Mining" line under a vein: ours takes its place instead of repeating it.
    for i = 2, #data.lines do
        local other = data.lines[i] and Plain(data.lines[i].leftText)
        if type(other) == "string" and isProfessionName(other, node[1]) then
            restyling[tooltip] = { i, node[1], other, nil, node[2] }
            return
        end
    end
    local line, color = nodeLine(text)
    if line then addLine(tooltip, line, color) end
end

-- One node's lines in a pin's text, at raw[i]: added to `parts`. Returns the next index and
-- whether anything changed.
local function pinNode(raw, i, parts)
    local part, nextPart = raw[i], raw[i + 1]
    parts[#parts + 1] = part
    if nextPart then
        local skill, need = Professions.Requires(clean(nextPart))
        if skill then Professions.LearnRequirement(clean(part), skill, need) end
    end
    local node = NODES[clean(part)]
    if node and nextPart and match(clean(nextPart), REQUIRES) then
        -- Blizzard's own line follows the name: color it, and a bare name line after it becomes
        -- the player's skill.
        local color, plain, rank, skillName = requiresColor(nextPart, node[1])
        if not color then
            parts[#parts + 1] = nextPart
            return i + 2, false
        end
        parts[#parts + 1] = Kit.Text(color, plain)
        local after = raw[i + 2]
        local yours = after and isProfessionName(after, node[1]) and yourSkill(color, rank, skillName)
        if yours then
            parts[#parts + 1] = yours
            return i + 3, true
        end
        return i + 2, true
    end
    local line, lineColor = nodeLine(part)
    if not line then return i + 1, false end
    parts[#parts + 1] = Kit.Text(lineColor, line)
    -- The game's own bare name line after it is replaced, not repeated.
    if node and nextPart and isProfessionName(nextPart, node[1]) then return i + 2, true end
    return i + 1, true
end

-- A minimap pin: every pin under the mouse on lines of its own, in the first line's `text`.
local function addPinLines(tooltip, text)
    local raw, parts, changed = {}, {}, false
    for part in gmatch(text .. "\n", "(.-)\n") do raw[#raw + 1] = part end
    local i = 1
    while i <= #raw do
        local found
        i, found = pinNode(raw, i, parts)
        changed = changed or found
    end
    local fontString = changed and leftLine(tooltip, 1)
    if fontString then fontString:SetText(concat(parts, "\n")) end
end

local function addNodeLines(tooltip, data)
    if not (inCharge() and type(Plain(data.lines)) == "table") then return end
    local first = data.lines[1]
    local text = first and Plain(first.leftText)
    if type(text) ~= "string" then return end
    text = gsub(text, "|n", "\n")
    if find(text, "\n", 1, true) then
        addPinLines(tooltip, text)
    else
        addObjectLine(tooltip, data, text)
    end
end

-- The lines go right under the name, before quest objectives and anything else Blizzard adds:
-- the tooltip's data is kept from its pre call, and they're added once its first line is drawn.
-- Without line calls they go at the end, from the post call.
local pending = setmetatable({}, { __mode = "k" }) -- tooltip -> object data not yet handled

local function onObjectPre(_, tooltip, data)
    pending[tooltip] = data
    restyling[tooltip] = nil
end

local function onLinePost(_, tooltip, lineData)
    local data = pending[tooltip]
    local lines = data and Plain(data.lines)
    if type(lines) == "table" and lines[1] == lineData then
        pending[tooltip] = nil
        addNodeLines(tooltip, data)
    end
end

local function onObject(_, tooltip, data)
    local waiting = pending[tooltip]
    pending[tooltip] = nil
    if data and waiting then
        addNodeLines(tooltip, data)
    end
    local job = restyling[tooltip]
    restyling[tooltip] = nil
    if job then
        restyle(tooltip, job)
    end
end

local function postCall(key, kind, fn)
    M:HookCallback(TooltipDataProcessor, key, function(hook) TooltipDataProcessor.AddTooltipPostCall(kind, hook) end, fn)
end
local function preCall(key, kind, fn)
    M:HookCallback(TooltipDataProcessor, key, function(hook) TooltipDataProcessor.AddTooltipPreCall(kind, hook) end, fn)
end

M:AddPart({
    Enable = function()
        local types = Enum.TooltipDataType
        preCall("object pre", types.Object, onObjectPre)
        preCall("pin pre", types.MinimapMouseover, onObjectPre)
        postCall("object", types.Object, onObject)
        postCall("pin", types.MinimapMouseover, onObject)
        M:HookCallback(TooltipDataProcessor, "lines", function(hook)
            TooltipDataProcessor.AddLinePostCall(TooltipDataProcessor.AllTypes, hook)
        end, onLinePost)
    end,
})
