--[[
    Forever Gearbox - Quest Markers
    A section on Forever++'s Quest Nameplates page (Core/Attach.lua): quest marks drawn the way
    nameplate addons draw them, on Blizzard's nameplates and on a nameplate addon's own (such as
    Platynator, which takes Blizzard's UnitFrame off the plate, so Forever++'s marks, drawn on that
    UnitFrame, don't show there): the quest giver's yellow "!" with what's left (3/8) beside it.

      * Side: left or right of the nameplate, the count on the outer side (left of the mark on the
        left, right of it on the right), as Plumber's quest indicator; or over the name, the count
        under the mark, as Platynator marks quest creatures.
      * Progress, as Plumber's quest indicator offers it: the mark always shows; what's left shows
        always, or on your target, under the mouse, or while Alt is held; as done/needed (3/8) or
        what's left (5), white (as Plumber draws it) or gold (as Forever++ does).
      * Show Party Member's Quest: a creature only a member of your group still needs gets a grey
        mark with the lowest member's progress, as Plumber marks a party member's quest.

    Only creatures one of your quests still needs (from the unit's tooltip: Modules/Quests/
    QuestMarkersRead.lua, as Forever++'s own marks read it). Where ours shows on Blizzard's plate,
    Forever++'s own mark there is hidden (its box on the UnitFrame: a frame with just an icon and a
    text), with Forever++ Integration (Core/Plugin.lua), so a creature is never marked twice;
    turning either off shows it again. X and Y Offset
    move the marker and its progress together, for nameplate addons whose plates are shaped unlike
    Blizzard's (there ours sits against the nameplate's own edge).
    Blizzard's art only (atlas QuestNormal); nothing from Platynator (All Rights Reserved) or
    Plumber (no licence).
]]

local _, ns = ...
local L = ns.L

local pairs, ipairs, floor, max, format, select, setmetatable, tostring = pairs, ipairs, math.floor, math.max, string.format,
    select, setmetatable, tostring
local Plain, Usable = ns.Plain, ns.Usable
local Read = assert(ns.QuestMarkersRead, "QuestMarkers.lua loads after QuestMarkersRead.lua")

local HOST = "QuestNameplates" -- Forever++'s module

local M = ns:NewModule("QuestMarkers", {
    attach = HOST, -- a section on Forever++'s Quest Nameplates page (Core/Attach.lua)
    title = L.QMARK_TITLE,
    category = "quests",
    description = L.QMARK_DESC,
    added = "3.0.0",
    defaults = { enabled = true, side = "left", size = 100, party = true, always = false, onTarget = true,
        onHover = true, onAlt = false, format = "done", color = "white", x = 0, y = 0 },
    options = {
        { key = "side", type = "dropdown", label = L.QMARK_SIDE, tooltip = L.QMARK_SIDE_TIP,
          choices = { { "left", L.QMARK_SIDE_LEFT }, { "right", L.QMARK_SIDE_RIGHT }, { "top", L.QMARK_SIDE_TOP } } },
        { key = "size", type = "slider", label = L.QMARK_SIZE, tooltip = L.QMARK_SIZE_TIP,
          min = 50, max = 200, step = 10, format = "%d%%" },
        { key = "x", type = "slider", label = L.QMARK_X, tooltip = L.QMARK_X_TIP, min = -100, max = 100, step = 1, format = "%d" },
        { key = "y", type = "slider", label = L.QMARK_Y, tooltip = L.QMARK_Y_TIP, min = -100, max = 100, step = 1, format = "%d" },
        { key = "party", type = "checkbox", label = L.QMARK_PARTY, tooltip = L.QMARK_PARTY_TIP },
        -- Progress, as Plumber's quest indicator offers it: on your target, on hover, while a key is held.
        { key = "always", type = "checkbox", label = L.QMARK_ALWAYS, tooltip = L.QMARK_ALWAYS_TIP, section = L.QMARK_PROGRESS },
        { key = "onTarget", type = "checkbox", label = L.QMARK_ON_TARGET, tooltip = L.QMARK_ON_TARGET_TIP,
          shown = function(db) return not db.always end },
        { key = "onHover", type = "checkbox", label = L.QMARK_ON_HOVER, tooltip = L.QMARK_ON_HOVER_TIP,
          shown = function(db) return not db.always end },
        { key = "onAlt", type = "checkbox", label = L.QMARK_ON_ALT, tooltip = L.QMARK_ON_ALT_TIP,
          shown = function(db) return not db.always end },
        { key = "format", type = "dropdown", label = L.QMARK_FORMAT, tooltip = L.QMARK_FORMAT_TIP,
          choices = { { "done", L.QMARK_FORMAT_DONE }, { "left", L.QMARK_FORMAT_LEFT } } },
        { key = "color", type = "dropdown", label = L.QMARK_COLOR, tooltip = L.QMARK_COLOR_TIP,
          choices = { { "white", L.QMARK_COLOR_WHITE }, { "gold", L.QMARK_COLOR_GOLD } } },
    },
})

-- Quest creatures are enemies or neutral: with Blizzard's enemy nameplates off there's no plate.
M.notice = { { requires = { { cvar = "nameplateShowEnemies", value = "1" } }, tooltip = L.QMARK_NEEDS_PLATES } }

local QUEST_ATLAS = "QuestNormal" -- the yellow "!" of a quest giver
local MARK_SIZE, OVER_SIZE, TEXT_SIZE, GAP, PAD = 16, 24, 12, 2, 4
local COLORS = { white = { 1, 1, 1 }, gold = { 1, 0.82, 0 } }
local MOUSEOVER_EVERY = 0.2 -- how often the mouse is looked at while Show is On Mouseover (no event when it leaves)

local plates = {} -- nameplate unit -> { frame = where ours goes, blizzard = its UnitFrame or nil }
local marks = setmetatable({}, { __mode = "k" }) -- frame -> our mark on it
local hiddenTheirs = setmetatable({}, { __mode = "k" }) -- Forever++'s box we hid -> true

-- Where a unit's mark goes: Blizzard's UnitFrame while it's on the nameplate, else the nameplate
-- itself (another addon draws the plate and has hidden Blizzard's).
local function hostFor(unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not Usable(plate) then return nil end
    local frame = plate.UnitFrame
    if Usable(frame) and frame:GetParent() == plate then return frame, frame end
    return plate, nil
end

-- Forever++'s own box on a Blizzard UnitFrame: a frame of just an icon and a text (its
-- QuestNameplates.lua `create`), not ours.
local function theirs(frame)
    for i = 1, select("#", frame:GetChildren()) do
        local child = select(i, frame:GetChildren())
        if child ~= marks[frame] and rawget(child, "icon") and rawget(child, "text") then return child end
    end
end

local function showTheirs(frame)
    local box = frame and theirs(frame)
    if box and hiddenTheirs[box] then
        hiddenTheirs[box] = nil
        box:SetAlpha(1)
    end
end

-- Hidden by alpha, not Hide: Forever++ shows and hides its box itself as progress changes.
local function hideTheirs(frame)
    local box = frame and theirs(frame)
    if box then
        hiddenTheirs[box] = true
        box:SetAlpha(0)
    end
end

local function newMark(frame)
    local mark = CreateFrame("Frame", nil, frame)
    mark:Hide()
    mark.icon = mark:CreateTexture(nil, "OVERLAY")
    mark.icon:SetAtlas(QUEST_ATLAS, false)
    mark.count = mark:CreateFontString(nil, "OVERLAY")
    mark.count:SetFontObject("SystemFont_NamePlate")
    marks[frame] = mark
    return mark
end

-- Whether a unit's progress shows now, as Plumber's quest indicator has it: always, or on your
-- target, under the mouse, or while Alt is held. The mark itself always shows.
local function progressWanted(unit)
    local db = M.db
    if db.always then return true end
    if db.onTarget and Plain(UnitIsUnit(unit, "target")) == true then return true end
    if db.onHover and Plain(UnitIsUnit(unit, "mouseover")) == true then return true end
    return db.onAlt and IsAltKeyDown() and true or false
end

local function hide(frame)
    local mark = frame and marks[frame]
    if mark then
        mark:Hide()
        mark.shows, mark.progress = nil, nil
    end
end

-- The progress as Progress Format says: done/needed (3/8), or what's left (5); a percentage as itself.
local function countText(progress)
    local current, needed, percent = progress[1], progress[2], progress[3]
    if percent then return M.db.format == "left" and (needed - current) .. "%" or current .. "%" end
    if M.db.format == "left" then return tostring(needed - current) end
    return current .. "/" .. needed
end

-- The plate's edge to put the mark against: Blizzard's health bar, else the nameplate.
local function edgeOf(frame)
    return frame.HealthBarsContainer or frame.healthBar or frame
end

-- Lays the mark out: left or right of the plate with the count on the outer side, or over the
-- name with the count under it.
local function place(mark, frame, text)
    local db, scale = M.db, M.db.size / 100
    local icon, count = mark.icon, mark.count
    icon:ClearAllPoints()
    count:ClearAllPoints()
    count:SetFontHeight(TEXT_SIZE * scale)
    local color = COLORS[db.color] or COLORS.white
    icon:SetDesaturated(mark.partyOnly and true or false)
    count:SetTextColor(color[1], color[2], color[3])
    count:SetText(text)
    local tw, th = text ~= "" and count:GetStringWidth() or 0, text ~= "" and count:GetStringHeight() or 0
    mark:ClearAllPoints()
    if db.side == "top" then
        local size = floor(OVER_SIZE * scale + 0.5)
        icon:SetSize(size, size)
        icon:SetPoint("TOP", mark, "TOP")
        count:SetPoint("TOP", icon, "BOTTOM", 0, -GAP)
        mark:SetSize(max(size, tw), size + GAP + th)
        mark:SetPoint("BOTTOM", frame.name or frame, "TOP", db.x, GAP + th + db.y)
    else
        local size = floor(MARK_SIZE * scale + 0.5)
        local right = db.side == "right"
        local inner, outer = right and "LEFT" or "RIGHT", right and "RIGHT" or "LEFT"
        icon:SetSize(size, size)
        icon:SetPoint(inner, mark, inner)
        count:SetPoint(inner, icon, outer, right and GAP or -GAP, 0)
        mark:SetSize(size + GAP + tw, max(size, th))
        mark:SetPoint(inner, edgeOf(frame), outer, (right and PAD or -PAD) + db.x, db.y)
    end
end

-- Draws a unit's mark again from what was read (its progress shown or not by now).
local function draw(unit, mark, frame)
    local text = progressWanted(unit) and countText(mark.progress) or ""
    local db = M.db
    local shows = table.concat({ text, db.side, db.size, db.color, db.x, db.y, tostring(mark.partyOnly) }, ":")
    if mark.shows ~= shows then
        mark.shows = shows
        place(mark, frame, text)
    end
    mark:Show()
end

-- Shows or hides each mark's progress (target, mouse, Alt), without reading tooltips again.
local function showWanted()
    for unit, plate in pairs(plates) do
        local mark = marks[plate.frame]
        if mark and mark.progress then draw(unit, mark, plate.frame) end
    end
end

local function update(unit)
    local plate = plates[unit]
    if not plate then return end
    local frame, blizzard = plate.frame, plate.blizzard
    if Plain(UnitIsPlayer(unit)) ~= false then
        hide(frame)
        return showTheirs(blizzard)
    end
    local current, needed, kind, percent = Read.Progress(unit, "own")
    if current == nil then return end -- the game won't say now: keep what it shows
    local partyOnly = false
    if (not current or kind == "done") and M.db.party then
        -- Show Party Member's Quest: one a member of your group still needs, marked grey.
        current, needed, kind, percent = Read.Progress(unit, "lowest")
        if current == nil then return end
        partyOnly = true
    end
    if not current or kind == "done" then
        hide(frame)
        return showTheirs(blizzard)
    end
    -- Forever++'s own mark there steps aside, with Forever++ Integration only.
    if ns.Plugin.Integrated() then hideTheirs(blizzard) else showTheirs(blizzard) end
    local mark = marks[frame] or newMark(frame)
    mark.unit, mark.partyOnly, mark.progress = unit, partyOnly, { current, needed, percent }
    draw(unit, mark, frame)
end

-- Finds where the unit's mark goes again (another addon may have taken Blizzard's UnitFrame off
-- the nameplate since), taking it off the old place.
local function track(unit)
    local frame, blizzard = hostFor(unit)
    local old = plates[unit]
    if old and old.frame ~= frame then
        hide(old.frame)
        showTheirs(old.blizzard)
    end
    plates[unit] = frame and { frame = frame, blizzard = blizzard } or nil
end

local function refreshAll()
    Read.Forget()
    for unit in pairs(plates) do
        track(unit)
        update(unit)
    end
end

local function refreshSoon() M:Soon(refreshAll) end

-- While progress shows on hover the mouse is looked at a few times a second: the game says when it
-- comes onto a unit, not when it leaves.
local ticker
local function followMouse()
    if M.db.onHover and not M.db.always then
        if not M:IsPending(ticker) then ticker = M:NewTicker(MOUSEOVER_EVERY, showWanted) end
    elseif ticker then
        M:CancelTimer(ticker)
        ticker = nil
    end
end

function M:OnEnable()
    for _, plate in pairs(C_NamePlate.GetNamePlates()) do
        local unit = Usable(plate) and plate.namePlateUnitToken
        if unit then track(unit) end
    end
    self:RegisterEvent("NAME_PLATE_UNIT_ADDED", function(_, _, unit)
        track(unit)
        update(unit)
    end)
    self:RegisterEvent("NAME_PLATE_UNIT_REMOVED", function(_, _, unit)
        local plate = plates[unit]
        plates[unit] = nil
        if plate then
            hide(plate.frame)
            showTheirs(plate.blizzard)
        end
    end)
    -- (After combat: a plate whose tooltip was secret gets another look.)
    for _, event in ipairs({ "QUEST_LOG_UPDATE", "UNIT_QUEST_LOG_CHANGED", "QUEST_WATCH_UPDATE", "GROUP_ROSTER_UPDATE",
        "PLAYER_REGEN_ENABLED" }) do
        self:RegisterEvent(event, refreshSoon)
    end
    for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "MODIFIER_STATE_CHANGED" }) do
        self:RegisterEvent(event, showWanted)
    end
    followMouse()
    refreshAll()
end

-- Forever++ Integration turned on or off: its marks stepped aside or given back.
M:OnChanged(function(_, name)
    if name == "ForeverPlusPlus" then refreshAll() end
end)

function M:OnDisable()
    for _, plate in pairs(plates) do
        hide(plate.frame)
        showTheirs(plate.blizzard)
    end
    plates = {}
end

function M:OnSettingChanged(key)
    followMouse()
    for _, mark in pairs(marks) do mark.shows = nil end
    refreshAll()
end

function M:DebugLine()
    local n = 0
    for _, mark in pairs(marks) do if mark:IsShown() then n = n + 1 end end
    return format(L.QMARK_DEBUG, n)
end
