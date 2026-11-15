--[[
    Forever Tweaks - Quest Nameplates
    A quest icon and what's left to do (3/8, or how many more) beside the health bar of a
    creature that's part of one of your quests; nothing once its objective is done. The icon and
    the count are each shown or hidden on their own, the count goes on any side of the icon, and
    the pair goes left, right or above the bar, nudged by the offset sliders. What it
    shows comes from the unit's tooltip (Modules/Quests/QuestNameplatesRead.lua): only quests in
    your log, as the game itself would tell you, so nothing is given away. It's drawn as a small
    frame of ours beside the game's health bar (plate.UnitFrame). A nameplate addon that draws its
    own plate takes Blizzard's UnitFrame off the nameplate (Platynator parents it to a hidden
    frame), so then the box goes on the nameplate itself, beside its edge. A plate the game won't
    let addons touch (friendly ones in instances) is left alone. Quest events come in bursts,
    so the plates are looked at again once they settle.
    Left to Forever++'s Quest Nameplates or Plumber's Quest Indicator while those are on.
    Adapted from Forever++'s Quest Nameplates by xIGBClutchIx (MIT License).
]]

local _, ns = ...
local L = ns.L

local pairs, floor, max, format, tostring, setmetatable = pairs, math.floor, math.max, string.format, tostring, setmetatable
local Plain, Usable = ns.Plain, ns.Usable
local OtherAddons = ns.OtherAddons
local Read = assert(ns.QuestNameplatesRead, "QuestNameplates.lua loads after QuestNameplatesRead.lua")

local COVERS = { { "ForeverPlusPlus", "QuestNameplates" }, { "Plumber", "NameplateQuest" } }

local M = ns:NewModule("QuestNameplates", {
    title = L.QNP_TITLE,
    category = "quests",
    group = L.GROUP_NAMEPLATES,
    description = L.QNP_DESC,
    added = "1.9.1",
    defaults = { icon = "kind", size = 90, progress = "count", textAt = "below", textSize = 100,
        party = "combined", side = "left", x = 0, y = 0 },
    options = {
        { key = "icon", type = "dropdown", label = L.QNP_ICON, tooltip = L.QNP_ICON_TIP, added = "2.6.0",
          choices = { { "kind", L.QNP_ICON_KIND }, { "quest", L.QNP_ICON_QUEST }, { "off", L.QNP_ICON_OFF } } },
        { key = "size", type = "slider", label = L.QNP_SIZE, tooltip = L.QNP_SIZE_TIP,
          min = 50, max = 200, step = 10, format = "%d%%" },
        { key = "progress", type = "dropdown", label = L.QNP_PROGRESS, tooltip = L.QNP_PROGRESS_TIP,
          section = L.QNP_SECTION_TEXT,
          choices = { { "count", L.QNP_PROGRESS_COUNT }, { "remaining", L.QNP_PROGRESS_REMAINING },
              { "off", L.QNP_PROGRESS_OFF } } },
        { key = "textAt", type = "dropdown", label = L.QNP_TEXT_AT, tooltip = L.QNP_TEXT_AT_TIP, added = "2.6.0",
          choices = { { "below", L.QNP_AT_BELOW }, { "above", L.QNP_AT_ABOVE }, { "right", L.QNP_AT_RIGHT },
              { "left", L.QNP_AT_LEFT } } },
        { key = "textSize", type = "slider", label = L.QNP_TEXT_SIZE, tooltip = L.QNP_TEXT_SIZE_TIP, added = "2.6.0",
          min = 50, max = 200, step = 10, format = "%d%%" },
        { key = "party", type = "dropdown", label = L.QNP_PARTY, tooltip = L.QNP_PARTY_TIP,
          choices = { { "own", L.QNP_PARTY_OWN }, { "combined", L.QNP_PARTY_COMBINED },
              { "lowest", L.QNP_PARTY_LOWEST } } },
        { key = "side", type = "dropdown", label = L.QNP_SIDE, tooltip = L.QNP_SIDE_TIP, section = L.QNP_SECTION_PLACE,
          choices = { { "left", L.QNP_SIDE_LEFT }, { "right", L.QNP_SIDE_RIGHT }, { "top", L.QNP_SIDE_TOP } } },
        { key = "x", type = "slider", label = L.QNP_X, tooltip = L.QNP_X_TIP, added = "2.6.0",
          min = -50, max = 50, step = 1, format = "%d" },
        { key = "y", type = "slider", label = L.QNP_Y, tooltip = L.QNP_Y_TIP, added = "2.6.0",
          min = -50, max = 50, step = 1, format = "%d" },
    },
})

-- Quest creatures are enemies or neutral: with Blizzard's enemy nameplates off there's no plate.
M.notice = OtherAddons.CoveredNotices(M, COVERS, L.QNP_WHAT,
    { { requires = { { cvar = "nameplateShowEnemies", value = "1" } }, tooltip = L.QNP_NEEDS_PLATES } })

local ICON_SIZE, TEXT_SIZE, GAP, PAD, LIFT = 18, 12, 2, 8, 2
-- Blizzard's own art for each objective type (all in Forever's AtlasInfo).
local ATLAS = { monster = "Crosshair_Attack_32", player = "worldquest-icon-pvp-ffa", item = "Crosshair_pickup_32",
    object = "Crosshair_interact_32" }
local QUEST_ATLAS = "QuestNormal" -- the yellow "!" of a quest giver
local GOLD = { 1, 0.82, 0 }

local plates = {} -- nameplate unit -> its UnitFrame, while on screen
local boxes = setmetatable({}, { __mode = "k" }) -- UnitFrame -> our box

-- Where a unit's box goes: Blizzard's UnitFrame while it's on the nameplate, else the nameplate
-- (another addon draws the plate and has hidden Blizzard's).
local function frameFor(unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not Usable(plate) then return nil end
    local frame = plate.UnitFrame
    if Usable(frame) and frame:GetParent() == plate then return frame end
    return plate
end

local function newBox(frame)
    local box = CreateFrame("Frame", nil, frame)
    box:Hide()
    box.icon = box:CreateTexture(nil, "OVERLAY")
    box.text = box:CreateFontString(nil, "OVERLAY")
    box.text:SetFontObject("SystemFont_NamePlate")
    return box
end

local function hide(frame)
    local box = boxes[frame]
    if box then
        box:Hide()
        box.shows = nil
    end
end

-- The elite dragon at the bar's left end while it shows, or nil.
local function eliteMark(frame)
    local mark = frame.classificationIndicator
        or frame.ClassificationFrame and frame.ClassificationFrame.classificationIndicator
    return mark and Plain(mark:IsVisible()) and mark or nil
end

local function label(current, needed, percent)
    local how = M.db.progress
    if how == "count" then
        return percent and current .. "%" or current .. "/" .. needed
    elseif how == "remaining" then
        return max(needed - current, 0) .. (percent and "%" or "")
    end
end

-- Where the count goes against the icon: the count's point, the icon's point it meets, and the
-- direction of the gap between them.
local BESIDE = {
    below = { "TOP", "BOTTOM", 0, -1 }, above = { "BOTTOM", "TOP", 0, 1 },
    right = { "LEFT", "RIGHT", 1, 0 }, left = { "RIGHT", "LEFT", -1, 0 },
}
-- The icon sits at the box's edge away from the count: the opposite of the point the count meets.
local OPPOSITE = { TOP = "BOTTOM", BOTTOM = "TOP", LEFT = "RIGHT", RIGHT = "LEFT" }

-- Lays out the icon and the count inside the box, sized to hold both; returns whether the pair
-- is stacked (then it sits a little above the bar's middle, which looks centred).
local function arrange(box, iconSize, shown)
    local icon, text = box.icon, box.text
    icon:ClearAllPoints()
    text:ClearAllPoints()
    local tw, th = shown and text:GetStringWidth() or 0, shown and text:GetStringHeight() or 0
    if iconSize == 0 or not shown then
        local only = iconSize > 0 and icon or text
        box:SetSize(iconSize > 0 and iconSize or tw, iconSize > 0 and iconSize or th)
        only:SetPoint("CENTER", box, "CENTER")
        return false
    end
    local at = BESIDE[M.db.textAt] or BESIDE.below
    local stacked = at[3] == 0
    if stacked then
        box:SetSize(max(iconSize, tw), iconSize + GAP + th)
    else
        box:SetSize(iconSize + GAP + tw, max(iconSize, th))
    end
    local edge = OPPOSITE[at[2]]
    icon:SetPoint(edge, box, edge)
    text:SetPoint(at[1], icon, at[2], at[3] * GAP, at[4] * GAP)
    return stacked
end

local function place(box, frame, current, needed, kind, percent)
    local anchor = frame.HealthBarsContainer or frame.healthBar or frame -- the nameplate's edge
    local db = M.db
    local side, pad = db.side, PAD
    -- The level badge sits at the bar's right end, an elite's dragon at its left: go past them.
    if side == "right" and frame.LevelFrame then
        anchor = frame.LevelFrame
    elseif side == "left" and eliteMark(frame) then
        anchor, pad = eliteMark(frame), 2
    end
    local iconSize = 0
    if db.icon ~= "off" then
        iconSize = floor(ICON_SIZE * db.size / 100 + 0.5)
        box.icon:SetAtlas(db.icon == "quest" and QUEST_ATLAS or ATLAS[kind] or QUEST_ATLAS, false)
        box.icon:SetSize(iconSize, iconSize)
        box.icon:Show()
    else
        box.icon:Hide()
    end
    local text = box.text
    text:SetFontHeight(TEXT_SIZE * db.textSize / 100)
    text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    local shown = label(current, needed, percent)
    text:SetText(shown or "")
    if iconSize == 0 and not shown then return box:Hide() end
    local stacked = arrange(box, iconSize, shown)
    box:ClearAllPoints()
    local lift = stacked and LIFT or 0
    if side == "top" then
        box:SetPoint("BOTTOM", frame.name or anchor, "TOP", db.x, GAP + db.y)
    elseif side == "right" then
        box:SetPoint("LEFT", anchor, "RIGHT", pad + db.x, lift + db.y)
    else
        box:SetPoint("RIGHT", anchor, "LEFT", -pad + db.x, lift + db.y)
    end
    box:Show()
end

local function update(unit, frame)
    if Plain(UnitIsPlayer(unit)) ~= false then return hide(frame) end
    local current, needed, kind, percent = Read.Progress(unit, M.db.party)
    if current == nil then return end -- the game won't say now: keep what it shows
    -- A creature whose objective is done shows nothing: there's nothing more to do to it.
    if not current or kind == "done" then return hide(frame) end
    local box = boxes[frame] or newBox(frame)
    boxes[frame] = box
    -- Quest events come often and mostly change nothing on a plate; plates are pooled, so an
    -- elite's dragon is part of what it shows.
    local shows = current .. "/" .. needed .. ":" .. tostring(kind) .. ":" .. tostring(percent)
        .. (eliteMark(frame) and ":elite" or "")
    if box.shows == shows then return end
    box.shows = shows
    place(box, frame, current, needed, kind, percent)
end

local function covered() return OtherAddons.CoveredBy(M, COVERS) ~= nil end

-- Finds the unit's box a place again (another addon may have taken Blizzard's UnitFrame off
-- the nameplate since), moving it off the old one.
local function hostFor(unit)
    local frame = frameFor(unit)
    if plates[unit] and plates[unit] ~= frame then hide(plates[unit]) end
    plates[unit] = frame
    return frame
end

local function refreshAll()
    Read.Forget()
    local off = covered()
    for unit in pairs(plates) do
        local frame = hostFor(unit)
        if frame then
            if off then hide(frame) else update(unit, frame) end
        end
    end
end

local function onAdded(_, _, unit)
    local frame = hostFor(unit)
    if frame and not covered() then update(unit, frame) end
end

local function onRemoved(_, _, unit)
    local frame = plates[unit]
    plates[unit] = nil
    if frame then hide(frame) end
end

local function refreshSoon() M:Soon(refreshAll) end

function M:OnEnable()
    for _, plate in pairs(C_NamePlate.GetNamePlates()) do
        local unit = Usable(plate) and plate.namePlateUnitToken
        if unit then plates[unit] = frameFor(unit) end
    end
    self:RegisterEvent("NAME_PLATE_UNIT_ADDED", onAdded)
    self:RegisterEvent("NAME_PLATE_UNIT_REMOVED", onRemoved)
    for _, event in pairs({ "QUEST_LOG_UPDATE", "UNIT_QUEST_LOG_CHANGED", "QUEST_WATCH_UPDATE", "GROUP_ROSTER_UPDATE",
        "PLAYER_REGEN_ENABLED" }) do -- (after combat: a plate whose tooltip was secret gets another look)
        self:RegisterEvent(event, refreshSoon)
    end
    refreshAll()
end

function M:OnDisable()
    for _, frame in pairs(plates) do hide(frame) end
    plates = {}
end

-- The look changed: every plate is laid out again.
function M:OnSettingChanged()
    for _, box in pairs(boxes) do box.shows = nil end
    refreshAll()
end

function M:DebugLine()
    local n = 0
    for _, box in pairs(boxes) do if box:IsShown() then n = n + 1 end end
    return format(L.QNP_DEBUG, n)
end
