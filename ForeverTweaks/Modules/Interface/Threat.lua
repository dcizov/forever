--[[
    Forever Tweaks - Threat
    Your threat on what you're fighting, as a line you place in Edit Mode: "Threat 87%" for your
    target, in Blizzard's threat colours (grey, yellow, orange, red: the status the game gives),
    "Tanking" while it attacks you. Only while your target is an enemy you have threat on; the
    game may keep threat secret (in some instances), and then the line hides.
    And on a hostile creature's tooltip, its aggro range: about 20 yards at your level, a yard more
    for each level it's above you and a yard less for each below, between 5 and 45 (Classic's
    rule, as AzerothCore has it; a skull-level creature is 45). The game gives no positions for
    enemies, so it's an estimate, not a measurement.
    The threat functions and events are Forever's (Blizzard_APIDocumentationGenerated/
    UnitDocumentation.lua on the forever branch). Ideas from threat meters and Platynator's threat
    text; none of their code.
]]

local _, ns = ...
local L = ns.L

local format, floor, math = string.format, math.floor, math
local Plain = ns.Plain

local ANCHOR = { "TOP", "BOTTOM", 0, -110 } -- under the minimap, below Fishing
-- Blizzard's threat status colours (GetThreatStatusColor): 0 none, 1 about to pull, 2 tanking
-- without being the highest, 3 tanking.
local STATUS_COLOR = { [0] = "b0b0b0", [1] = "ffff78", [2] = "ff9900", [3] = "ff0000" }
local AGGRO_BASE, AGGRO_MIN, AGGRO_MAX = 20, 5, 45
local HOSTILE = 4 -- UnitReaction below this: hostile

local M = ns:NewModule("Threat", {
    title = L.THREAT_TITLE,
    category = "interface",
    group = L.GROUP_COMBAT,
    description = L.THREAT_DESC,
    added = "2.7.0",
    defaults = ns.Widgets.DisplayDefaults({ display = true, raw = false, aggro = true }, ANCHOR),
    options = ns.Widgets.DisplayOptions({
        { key = "display", type = "checkbox", label = L.THREAT_DISPLAY, tooltip = L.THREAT_DISPLAY_TIP },
        { key = "raw", type = "checkbox", label = L.THREAT_RAW, tooltip = L.THREAT_RAW_TIP, requires = "display" },
        { key = "aggro", type = "checkbox", label = L.THREAT_AGGRO, tooltip = L.THREAT_AGGRO_TIP },
    }),
    features = { "display", "aggro" },
})

local display -- added below

-- The aggro range of a creature at `level` against yours, in yards (Classic's rule).
function M.AggroRange(level, playerLevel)
    if level == -1 then return AGGRO_MAX end -- a skull: far above you
    return math.min(AGGRO_MAX, math.max(AGGRO_MIN, AGGRO_BASE + level - playerLevel))
end

-- "Threat 87%" for the target, coloured by status, or nil when there's nothing to say.
local function threatLine()
    if not Plain(UnitExists("target")) or Plain(UnitCanAttack("player", "target")) ~= true then return nil end
    local tanking, status, scaled, raw = UnitDetailedThreatSituation("player", "target")
    tanking, status, scaled, raw = Plain(tanking), Plain(status), Plain(scaled), Plain(raw)
    local percent = M.db.raw and raw or scaled
    if not (status and percent) then return nil end
    if percent <= 0 and not tanking then return nil end
    local text = tanking and L.THREAT_TANKING or format(L.THREAT_PERCENT, floor(percent + 0.5))
    return format(L.THREAT_LINE, "|cff" .. (STATUS_COLOR[status] or STATUS_COLOR[0]) .. text .. "|r")
end

local function showThreat()
    local line = M.db.display and threatLine()
    display:SetLine(line or "")
    display:SetShown(line ~= nil)
end

local function fillTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(L.THREAT_TITLE, 1, 0.82, 0)
    GameTooltip:AddLine(L.THREAT_TOOLTIP, 1, 1, 1, true)
    GameTooltip:Show()
end

display = ns.Widgets.AddDisplay(M, { name = "ForeverTweaksThreat", relativeTo = Minimap, onEnter = fillTooltip,
    sample = format(L.THREAT_LINE, "|cffffff78" .. format(L.THREAT_PERCENT, 87) .. "|r") })

-- A hostile creature's tooltip: its aggro range.
local function aggroLine(_, tooltip)
    if not M.db.aggro then return end
    local _, unit = tooltip:GetUnit()
    unit = Plain(unit)
    if not unit or Plain(UnitIsPlayer(unit)) ~= false or Plain(UnitIsDeadOrGhost(unit)) then return end
    local reaction = Plain(UnitReaction(unit, "player"))
    local level, mine = Plain(UnitLevel(unit)), Plain(UnitLevel("player"))
    if not (reaction and reaction < HOSTILE and level and mine) then return end
    tooltip:AddLine(format(L.THREAT_AGGRO_LINE, M.AggroRange(level, mine)), 0.7, 0.7, 0.7)
end

function M:OnEnable()
    for _, event in ipairs({ "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE", "PLAYER_TARGET_CHANGED",
        "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED" }) do
        self:RegisterEvent(event, showThreat)
    end
    self:HookCallback(TooltipDataProcessor, "unit", function(hook)
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, hook)
    end, aggroLine)
    showThreat()
end

function M:OnSettingChanged() showThreat() end
