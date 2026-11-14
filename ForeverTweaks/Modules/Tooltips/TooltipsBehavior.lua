--[[
    Forever Tweaks - Tooltips: where they show and what they leave out
      * Anchor to Cursor: after Blizzard places a tooltip at its default spot, it moves to the mouse.
      * Hide Health Bar: the bar under unit tooltips is faded, leaving all of it to Blizzard
        (nothing reads, hooks or runs it).
      * Quest Lines: a quest's lines left out of unit (and object) tooltips as they're built (line
        pre calls); the tooltip data keeps them, so Quest Nameplates still reads them.
    Adapted from Forever++'s Tooltips by xIGBClutchIx (MIT License), whose Quest Lines idea came
    from NoQuestTooltips and cyberox's Hide Quest Tooltips.
]]

local _, ns = ...

local ipairs = ipairs
local GameTooltip = GameTooltip
local Shared = ns.TooltipsParts
local M, guarded, inCharge = Shared.module, Shared.Guarded, Shared.InCharge

-- Anchor to Cursor: after Blizzard places a tooltip at its default spot (bottom right), move it
-- to the mouse instead.
local function onDefaultAnchor(_, tooltip, parent)
    if M.db.anchorCursor and ns.Usable(tooltip) and ns.Usable(parent) then
        tooltip:SetOwner(parent, "ANCHOR_CURSOR")
    end
end

-- Hide Health Bar: GameTooltip.StatusBar hangs under the tooltip and shows, hides, and fills
-- itself from a unit's GUID on every unit tooltip (GameTooltipUnitHealthBarMixin, with secure
-- methods because the health may be secret). Fading it leaves all of that to Blizzard: nothing
-- reads the bar, hooks it, or runs when it shows.
local function fadeHealthBar(hide)
    GameTooltip.StatusBar:SetAlpha(hide and 0 or 1)
end

-- Quest Lines: true leaves a quest line (its title, an objective, or whose they are in a group) out
-- of a unit's tooltip, or an object's too, as the tooltip is built. Idea from NoQuestTooltips and
-- cyberox's Hide Quest Tooltips. Only the tooltip skips them: the data keeps them, so what reads
-- it (Quest Nameplates, through C_TooltipInfo) still sees them. The tooltip's type is never secret,
-- since Blizzard keys its own callback tables by it.
local QUEST_LINES = { "QuestTitle", "QuestObjective", "QuestPlayer" }

local function skipQuestLine(_, tooltip)
    local mode = M.db.questLines
    if mode == "show" then
        return false
    end
    local info = tooltip:GetProcessingTooltipInfo()
    local kind = info and info.tooltipData and info.tooltipData.type
    local types = Enum.TooltipDataType
    return kind == types.Unit or (mode == "all" and kind == types.Object)
end

M:AddPart({
    Enable = function()
        for _, name in ipairs(QUEST_LINES) do
            local lineType = Enum.TooltipDataLineType[name]
            M:HookCallback(TooltipDataProcessor, "line " .. name, function(hook)
                TooltipDataProcessor.AddLinePreCall(lineType, hook)
            end, guarded(skipQuestLine))
        end
        M:Hook("GameTooltip_SetDefaultAnchor", guarded(onDefaultAnchor))
        fadeHealthBar(M.db.hideHealthBar and inCharge())
    end,
    Disable = function() fadeHealthBar(false) end,
    Changed = function(key)
        if key == "hideHealthBar" then fadeHealthBar(M.db.hideHealthBar and inCharge()) end
    end,
})
