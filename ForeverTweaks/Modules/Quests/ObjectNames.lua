--[[
    Forever Tweaks - Object Names
    When you're near something you can interact with that isn't a creature (a chest, herb, ore,
    a quest object), the game puts its soft-target icon over it. This adds the object's name under
    that icon, yellow when it's in reach and gray when it isn't, and, with Quest Objectives, the
    objective it counts for, from its own tooltip (C_TooltipInfo.GetWorldCursor, the last line of
    type QuestObjective): only quests in your log, as the game would tell you.
    It needs the game to show that icon (console variable SoftTargetIconGameObject) and, for the
    objective, its tooltip (SoftTargetTooltipInteract): the page asks for them with a button.
    While an object is the target, its line is read again five times a second (its count can go
    up as you loot it); nothing runs otherwise.
    Idea from Plumber's Soft Target Name (no code from it). Left to Plumber's while that's on.
]]

local _, ns = ...
local L = ns.L

local Plain, Usable = ns.Plain, ns.Usable
local OtherAddons = ns.OtherAddons

local COVERS = { { "Plumber", "SoftTargetName" } }
local UNIT = "softinteract"
local WATCH_EVERY = 0.2
local YELLOW, GRAY = { 1, 0.82, 0 }, { 0.6, 0.6, 0.6 }

local M = ns:NewModule("ObjectNames", {
    title = L.OBJNAMES_TITLE,
    category = "quests",
    description = L.OBJNAMES_DESC,
    added = "1.9.1",
    defaults = { objectives = true },
    options = {
        { key = "objectives", type = "checkbox", label = L.OBJNAMES_OBJECTIVES, tooltip = L.OBJNAMES_OBJECTIVES_TIP },
    },
})

M.notice = OtherAddons.CoveredNotices(M, COVERS, L.OBJNAMES_WHAT, {
    { requires = { { cvar = "SoftTargetIconGameObject", value = "1" } }, tooltip = L.OBJNAMES_NEEDS_ICON },
    { requires = { { cvar = "SoftTargetTooltipInteract", value = "1" } }, tooltip = L.OBJNAMES_NEEDS_TOOLTIP },
})

local display, ticker, current -- our frame, the objective watch, the object's name now

local function build()
    display = CreateFrame("Frame", nil, UIParent)
    display:SetSize(1, 1)
    display.title = display:CreateFontString(nil, "OVERLAY", "SystemFont_NamePlate")
    display.title:SetPoint("TOP")
    display.sub = display:CreateFontString(nil, "OVERLAY", "SystemFont_NamePlate")
    display.sub:SetPoint("TOP", display.title, "BOTTOM", 0, -2)
    display.probe = display:CreateTexture() -- where the game's cursor art for the object goes
    display.probe:Hide()
    display:Hide()
end

local function stopWatching()
    M:CancelTimer(ticker)
    ticker = nil
end

local function hide()
    stopWatching()
    current = nil
    if display then display:Hide() end
end

-- The objective line under the name: the last QuestObjective line of the object's tooltip, when
-- its first line is this object's name.
local function readObjective()
    if not current then return end
    local text, color
    local info = C_TooltipInfo.GetWorldCursor()
    local lines = info and info.lines
    if lines and Plain(lines[1] and lines[1].leftText) == current then
        local last = lines[#lines]
        if #lines > 1 and Plain(last.type) == Enum.TooltipDataLineType.QuestObjective then
            text, color = Plain(last.leftText), last.leftColor
        end
    end
    display.sub:SetText(text or "")
    if color and color.GetRGB then display.sub:SetTextColor(color:GetRGB()) end
    display.sub:SetShown(text ~= nil)
end

-- Whether the object is in reach: the game's cursor art for it says "unable" when it isn't.
local function inReach()
    if not SetUnitCursorTexture(display.probe, UNIT) then return true end
    local art = display.probe:GetAtlas() or display.probe:GetTexture()
    return not (type(art) == "string" and art:lower():find("unable", 1, true))
end

local function show()
    if OtherAddons.CoveredBy(M, COVERS) or not Plain(UnitIsGameObject(UNIT)) then return hide() end
    local plate = C_NamePlate.GetNamePlateForUnit(UNIT)
    local frame = Usable(plate) and plate.UnitFrame
    local soft = Usable(frame) and frame.SoftTargetFrame
    local name = Plain(UnitName(UNIT))
    if not (soft and soft:IsShown() and name) then return hide() end
    if not display then build() end
    current = name
    display:SetParent(frame)
    display:ClearAllPoints()
    display:SetPoint("TOP", soft.Icon or soft, "BOTTOM", 0, -6)
    display.title:SetText(name)
    local color = inReach() and YELLOW or GRAY
    display.title:SetTextColor(color[1], color[2], color[3])
    display.sub:SetText("")
    display:Show()
    stopWatching()
    if M.db.objectives then
        readObjective()
        ticker = M:NewTicker(WATCH_EVERY, readObjective)
    end
end

local function onChanged() M:Soon(show) end

function M:OnEnable()
    self:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED", onChanged)
    -- The target's plate can come a moment after the target does.
    self:RegisterEvent("NAME_PLATE_UNIT_ADDED", onChanged)
    onChanged()
end

function M:OnDisable() hide() end
function M:OnSettingChanged() onChanged() end

function M:DebugLine() return current or L.OBJNAMES_NONE end
