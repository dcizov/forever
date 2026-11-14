--[[
    Forever Tweaks - Quest Nameplates
    A quest icon and what's left to do (3/8, or how many more) beside the health bar of a
    creature that's part of one of your quests, a green check once its objective is done. What it
    shows comes from the unit's tooltip (Modules/Quests/QuestNameplatesRead.lua): only quests in
    your log, as the game itself would tell you, so nothing is given away. It's drawn as a small
    frame of ours on the game's plate (plate.UnitFrame, which Platynator keeps); a plate the game
    won't let addons touch (friendly ones in instances) is left alone. Quest events come in bursts,
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
    description = L.QNP_DESC,
    added = "1.9.1",
    defaults = { progress = "count", party = "combined", completed = true, side = "left", size = 90 },
    options = {
        { key = "progress", type = "dropdown", label = L.QNP_PROGRESS, tooltip = L.QNP_PROGRESS_TIP,
          choices = { { "count", L.QNP_PROGRESS_COUNT }, { "remaining", L.QNP_PROGRESS_REMAINING },
              { "off", L.QNP_PROGRESS_OFF } } },
        { key = "party", type = "dropdown", label = L.QNP_PARTY, tooltip = L.QNP_PARTY_TIP,
          choices = { { "own", L.QNP_PARTY_OWN }, { "combined", L.QNP_PARTY_COMBINED },
              { "lowest", L.QNP_PARTY_LOWEST } } },
        { key = "completed", type = "checkbox", label = L.QNP_COMPLETED, tooltip = L.QNP_COMPLETED_TIP },
        { key = "side", type = "dropdown", label = L.QNP_SIDE, tooltip = L.QNP_SIDE_TIP,
          choices = { { "left", L.QNP_SIDE_LEFT }, { "right", L.QNP_SIDE_RIGHT } } },
        { key = "size", type = "slider", label = L.QNP_SIZE, tooltip = L.QNP_SIZE_TIP,
          min = 50, max = 200, step = 10, format = "%d%%" },
    },
})

-- Quest creatures are enemies or neutral: with Blizzard's enemy nameplates off there's no plate.
M.notice = OtherAddons.CoveredNotices(M, COVERS, L.QNP_WHAT,
    { { requires = { { cvar = "nameplateShowEnemies", value = "1" } }, tooltip = L.QNP_NEEDS_PLATES } })

local ICON_SIZE, TEXT_SIZE, GAP, PAD, LIFT = 18, 12, 2, 8, 2
-- Blizzard's own art for each objective type (all in Forever's AtlasInfo).
local ATLAS = { monster = "Crosshair_Attack_32", player = "worldquest-icon-pvp-ffa", item = "Crosshair_pickup_32",
    object = "Crosshair_interact_32", done = "common-icon-checkmark" }
local DEFAULT_ATLAS = "QuestNormal"

local plates = {} -- nameplate unit -> its UnitFrame, while on screen
local boxes = setmetatable({}, { __mode = "k" }) -- UnitFrame -> our box

local function frameFor(unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    local frame = Usable(plate) and plate.UnitFrame
    return Usable(frame) and frame or nil
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

local function label(current, needed, done, percent)
    local how = M.db.progress
    if how == "count" or (done and how == "remaining") then
        return percent and current .. "%" or current .. "/" .. needed
    elseif how == "remaining" then
        return max(needed - current, 0) .. (percent and "%" or "")
    end
end

local function place(box, frame, current, needed, kind, percent)
    local anchor = frame.HealthBarsContainer or frame.healthBar
    if not anchor then return end
    local db = M.db
    local right, pad = db.side == "right", PAD
    -- The level badge sits at the bar's right end, an elite's dragon at its left: go past them.
    if right and frame.LevelFrame then
        anchor = frame.LevelFrame
    elseif not right and eliteMark(frame) then
        anchor, pad = eliteMark(frame), 2
    end
    local scale = db.size / 100
    local size = floor(ICON_SIZE * scale + 0.5)
    local done = kind == "done"
    box.icon:SetAtlas(ATLAS[kind] or DEFAULT_ATLAS, false)
    box.icon:SetSize(size, size)
    local text = box.text
    text:SetFontHeight(TEXT_SIZE * scale)
    if done then text:SetTextColor(0.1, 1, 0.1) else text:SetTextColor(1, 0.82, 0) end
    local shown = label(current, needed, done, percent)
    text:SetText(shown or "")
    box.icon:ClearAllPoints()
    text:ClearAllPoints()
    box:ClearAllPoints()
    -- The icon above the count, both centred in a column as wide as the wider of the two.
    box:SetSize(max(size, shown and text:GetStringWidth() or 0),
        size + (shown and (GAP + text:GetStringHeight()) or 0))
    box.icon:SetPoint("TOP", box, "TOP")
    text:SetPoint("TOP", box.icon, "BOTTOM", 0, -GAP)
    local lift = shown and LIFT or 0 -- a lone icon sits on the bar's middle
    if right then
        box:SetPoint("LEFT", anchor, "RIGHT", pad, lift)
    else
        box:SetPoint("RIGHT", anchor, "LEFT", -pad, lift)
    end
    box:Show()
end

local function update(unit, frame)
    if Plain(UnitIsPlayer(unit)) ~= false then return hide(frame) end
    local current, needed, kind, percent = Read.Progress(unit, M.db.party)
    if current == nil then return end -- the game won't say now: keep what it shows
    if not current or (kind == "done" and not M.db.completed) then return hide(frame) end
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

local function refreshAll()
    Read.Forget()
    local off = covered()
    for unit, frame in pairs(plates) do
        if off then hide(frame) else update(unit, frame) end
    end
end

local function onAdded(_, _, unit)
    local frame = frameFor(unit)
    plates[unit] = frame
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
