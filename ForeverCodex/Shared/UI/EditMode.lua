--[[
    Forever runtime - Shared/UI/EditMode.lua
    Edit Mode for our own frames, made to look and work like Blizzard's own: while the player is
    in Blizzard's Edit Mode, a registered frame gets the same blue selection box, which turns gold
    when clicked. It drags with snapping to the screen's middle and edges and to our other frames,
    opens a small settings dialog (size and reset), and has a right-click menu; while the dialog
    is up, the arrow keys nudge the frame a pixel (ten with Shift). Edit Mode has no way for an
    addon to add a frame to its layouts (that needs protected code), so the place stays the
    module's own setting. Nothing is hooked until a frame registers.

    Adapted from Forever++ by xIGBClutchIx (MIT License).
]]

local _, ns = ...

local pairs, abs, min, max, format = pairs, math.abs, math.min, math.max, string.format
local CreateFrame, UIParent, hooksecurefunc, GetCursorPosition = CreateFrame, UIParent, hooksecurefunc, GetCursorPosition
local L = ns.L

-- Calls one of a frame's callbacks (info.moveTo, info.size.set, ...) as its module's code:
-- isolated, and charged to the module (info.owner) by the Profiler.
local function callFor(info, fn, ...) return ns.ChargedCall(info.owner, "Edit Mode", fn, ...) end

local EditMode = {}
ns.EditMode = EditMode

local SNAP = 10
local GOLD = { NORMAL_FONT_COLOR:GetRGB() }

local registered = {} -- frame -> info { label, owner, moveTo, size, reset, settings, selection }
local hooked = false
local selected

function EditMode.IsActive()
    return EditModeManagerFrame:IsShown()
end

---------------------------------------------------------------------------
-- Positions, in UIParent units
---------------------------------------------------------------------------

local function clamp(center, length, size)
    return max(length / 2, min(size - length / 2, center))
end

-- A frame's center, width and height in UIParent units.
local function box(frame)
    local cx, cy = frame:GetCenter()
    if not cx then return end
    local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return cx * ratio, cy * ratio, frame:GetWidth() * ratio, frame:GetHeight() * ratio
end
EditMode.Box = box

---------------------------------------------------------------------------
-- Snapping
---------------------------------------------------------------------------

local guides

local function guide(index)
    guides = guides or {}
    if not guides[index] then
        local line = UIParent:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.8)
        line:SetDrawLayer("OVERLAY", 7)
        line:Hide()
        guides[index] = line
    end
    return guides[index]
end

local function hideGuides()
    if guides then
        for _, line in pairs(guides) do line:Hide() end
    end
end

-- The lines on one axis to snap to: the screen's edges and middle, and our other frames.
local function snapLines(frame, axis)
    local size = axis == 1 and UIParent:GetWidth() or UIParent:GetHeight()
    local list = { 0, size / 2, size }
    for other in pairs(registered) do
        if other ~= frame and other:IsShown() then
            local cx, cy, w, h = box(other)
            if cx then
                local center, length = axis == 1 and cx or cy, axis == 1 and w or h
                list[#list + 1] = center - length / 2
                list[#list + 1] = center
                list[#list + 1] = center + length / 2
            end
        end
    end
    return list
end

local function snap(frame, center, length, axis)
    local best, bestLine
    for _, line in pairs(snapLines(frame, axis)) do
        for _, edge in pairs({ -length / 2, 0, length / 2 }) do
            local off = line - (center + edge)
            if abs(off) <= SNAP and (not best or abs(off) < abs(best)) then
                best, bestLine = off, line
            end
        end
    end
    if best then return center + best, bestLine end
    return center
end

local function showGuides(vertical, horizontal)
    if vertical then
        local line = guide(1)
        line:ClearAllPoints()
        line:SetPoint("TOP", UIParent, "BOTTOMLEFT", vertical, UIParent:GetHeight())
        line:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", vertical, 0)
        line:SetWidth(2)
        line:Show()
    elseif guides and guides[1] then
        guides[1]:Hide()
    end
    if horizontal then
        local line = guide(2)
        line:ClearAllPoints()
        line:SetPoint("LEFT", UIParent, "BOTTOMLEFT", 0, horizontal)
        line:SetPoint("RIGHT", UIParent, "BOTTOMRIGHT", 0, horizontal)
        line:SetHeight(2)
        line:Show()
    elseif guides and guides[2] then
        guides[2]:Hide()
    end
end

local function dragUpdate(selection)
    local frame = selection:GetParent()
    local info = registered[frame]
    if not (info and info.grab) then return end
    local mx, my = GetCursorPosition()
    local ratio = UIParent:GetEffectiveScale()
    local _, _, width, height = box(frame)
    if not width then return end
    local cx, vertical = snap(frame, mx / ratio + info.grab[1], width, 1)
    local cy, horizontal = snap(frame, my / ratio + info.grab[2], height, 2)
    callFor(info, info.moveTo, clamp(cx, width, UIParent:GetWidth()), clamp(cy, height, UIParent:GetHeight()))
    showGuides(vertical, horizontal)
end

local function dragStart(frame, info)
    local cx, cy = box(frame)
    if not cx then return end
    local mx, my = GetCursorPosition()
    local ratio = UIParent:GetEffectiveScale()
    info.grab = { cx - mx / ratio, cy - my / ratio }
    info.selection:SetScript("OnUpdate", ns.Profiler.Wrap(info.owner, "Edit Mode drag", dragUpdate))
end

local refreshDialog

local function dragStop(info)
    info.grab = nil
    info.selection:SetScript("OnUpdate", nil)
    hideGuides()
    if selected then refreshDialog() end
end

---------------------------------------------------------------------------
-- The selection box: Blizzard's blue box while it can be picked, gold once picked.
---------------------------------------------------------------------------

local KITS = { [false] = "editmode-actionbar-highlight", [true] = "editmode-actionbar-selected" }
local LAYOUT = {
    TopRightCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = 8, y = 8 },
    TopLeftCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = -8, y = 8 },
    BottomLeftCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = -8, y = -8 },
    BottomRightCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = 8, y = -8 },
    TopEdge = { atlas = "_%s-NineSlice-EdgeTop" },
    BottomEdge = { atlas = "_%s-NineSlice-EdgeBottom" },
    LeftEdge = { atlas = "!%s-NineSlice-EdgeLeft" },
    RightEdge = { atlas = "!%s-NineSlice-EdgeRight" },
    Center = { layer = "BORDER", atlas = "%s-NineSlice-Center", x = -8, y = 8, x1 = 8, y1 = -8 },
}

local function showHint(selection, isSelected)
    selection.hint:SetText(isSelected and selection.info.label or L.EDITMODE_CLICK_TO_EDIT)
    selection.hint:SetShown(selection.hovered or isSelected or false)
end

local function paintSelection(selection, isSelected)
    showHint(selection, isSelected)
    NineSliceUtil.ApplyLayout(selection, LAYOUT, KITS[isSelected])
end

local pick, deselect

local function openMenu(selection, frame, info)
    MenuUtil.CreateContextMenu(selection, function(_, root)
        root:CreateTitle(info.label)
        local size = info.size
        if size then
            local sub = root:CreateButton(L.EDITMODE_SIZE)
            for value = size.min, size.max, size.step * 2 do
                sub:CreateRadio(format(size.format, value), function() return size.get() == value end,
                    function() callFor(info, size.set, value) end)
            end
        end
        root:CreateButton(L.EDITMODE_RESET_POSITION, function() callFor(info, info.reset) end)
        root:CreateButton(L.SETTINGS, function() callFor(info, info.settings) end)
    end)
end

local function newSelection(frame, info)
    local selection = CreateFrame("Frame", nil, frame)
    selection:SetPoint("TOPLEFT", -4, 4)
    selection:SetPoint("BOTTOMRIGHT", 4, -4)
    selection:SetFrameLevel(frame:GetFrameLevel() + 10)
    selection:EnableMouse(true)
    selection:RegisterForDrag("LeftButton")
    selection.info = info
    selection.hint = selection:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    selection.hint:SetPoint("BOTTOM", selection, "TOP", 0, 2)
    -- Blizzard's Edit Mode art can load after us: draw the box each time it shows.
    selection:SetScript("OnShow", function(self)
        self.hovered = false
        paintSelection(self, selected == frame)
    end)
    selection:SetScript("OnEnter", function(self)
        self.hovered = true
        showHint(self, selected == frame)
    end)
    selection:SetScript("OnLeave", function(self)
        self.hovered = false
        showHint(self, selected == frame)
    end)
    selection:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then pick(frame) end
    end)
    selection:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            pick(frame)
            openMenu(self, frame, info)
        end
    end)
    -- Ctrl + mouse wheel sizes it, like the dialog's slider.
    selection:EnableMouseWheel(true)
    selection:SetScript("OnMouseWheel", function(_, delta)
        local size = info.size
        if size and IsControlKeyDown() then
            callFor(info, size.set, min(size.max, max(size.min, size.get() + delta * size.step)))
            if selected == frame then refreshDialog() end
        end
    end)
    selection:SetScript("OnDragStart", function() pick(frame) dragStart(frame, info) end)
    selection:SetScript("OnDragStop", function() dragStop(info) end)
    selection:Hide()
    return selection
end

---------------------------------------------------------------------------
-- The settings dialog
---------------------------------------------------------------------------

local dialog
local downKeys = {}
local NUDGE = { UP = { 0, 1 }, DOWN = { 0, -1 }, LEFT = { -1, 0 }, RIGHT = { 1, 0 } }

local function nudge(key)
    local frame = selected
    local info = frame and registered[frame]
    local step = NUDGE[key]
    if not (info and step) then return end
    local cx, cy, width, height = box(frame)
    if not cx then return end
    local amount = (downKeys.LSHIFT or downKeys.RSHIFT) and 10 or 1
    callFor(info, info.moveTo, clamp(cx + step[1] * amount, width, UIParent:GetWidth()),
        clamp(cy + step[2] * amount, height, UIParent:GetHeight()))
end

local function newDialog()
    local frame = CreateFrame("Frame", ns.name .. "EditModeDialog", UIParent, "DialogBorderTranslucentTemplate")
    frame:SetFrameStrata("DIALOG")
    frame:SetSize(380, 144) -- title, size slider, Reset Position
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    -- Like Blizzard's dialog, it takes the keyboard while a frame is selected: arrows nudge,
    -- Escape lets go, Print Screen still takes a picture.
    frame:EnableKeyboard(true)
    frame:SetScript("OnKeyDown", function(_, key)
        downKeys[key] = true
        if key == "PRINTSCREEN" then
            Screenshot()
        elseif key == "ESCAPE" then
            deselect()
        else
            nudge(key)
        end
    end)
    frame:SetScript("OnKeyUp", function(_, key) downKeys[key] = nil end)
    frame:SetScript("OnHide", function() wipe(downKeys) end)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.title:SetPoint("TOP", 0, -15)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function() deselect() end)

    frame.sizeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.sizeLabel:SetPoint("TOPLEFT", 20, -50)
    frame.sizeLabel:SetText(L.EDITMODE_SIZE)
    frame.slider = CreateFrame("Slider", nil, frame, "MinimalSliderWithSteppersTemplate")
    frame.slider:SetPoint("LEFT", frame.sizeLabel, "LEFT", 90, 0)
    frame.slider:SetWidth(200)
    frame.slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        local info = selected and registered[selected]
        if info and not frame.refreshing then callFor(info, info.size.set, value) end
    end, frame)

    frame.reset = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.reset:SetSize(200, 24)
    frame.reset:SetPoint("TOP", 0, -90)
    frame.reset:SetText(L.EDITMODE_RESET_POSITION)
    frame.reset:SetScript("OnClick", function()
        local info = selected and registered[selected]
        if info then callFor(info, info.reset) end
    end)
    frame:Hide()
    return frame
end

function refreshDialog()
    local frame = selected
    local info = frame and registered[frame]
    if not info then
        if dialog then dialog:Hide() end
        return
    end
    dialog = dialog or newDialog()
    dialog.title:SetText(info.label)
    local size = info.size
    dialog.sizeLabel:SetShown(size ~= nil)
    dialog.slider:SetShown(size ~= nil)
    if size then
        dialog.refreshing = true
        local formatter = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right,
            function(value) return format(size.format, value) end)
        dialog.slider:Init(size.get(), size.min, size.max, (size.max - size.min) / size.step,
            { [MinimalSliderWithSteppersMixin.Label.Right] = formatter })
        dialog.refreshing = false
    end
    -- Beside the frame on the side with room, else above or below it.
    local cx, cy, width = box(frame)
    dialog:ClearAllPoints()
    if cx then
        local left, right = cx - width / 2, UIParent:GetWidth() - (cx + width / 2)
        if left >= dialog:GetWidth() + 10 or right >= dialog:GetWidth() + 10 then
            if right >= left then
                dialog:SetPoint("LEFT", frame, "RIGHT", 10, 0)
            else
                dialog:SetPoint("RIGHT", frame, "LEFT", -10, 0)
            end
        elseif cy > UIParent:GetHeight() / 2 then
            dialog:SetPoint("TOP", frame, "BOTTOM", 0, -10)
        else
            dialog:SetPoint("BOTTOM", frame, "TOP", 0, 10)
        end
    else
        dialog:SetPoint("CENTER")
    end
    dialog:Show()
end

function EditMode.Refresh()
    if selected then refreshDialog() end
end

---------------------------------------------------------------------------
-- Selecting
---------------------------------------------------------------------------

local selecting = false

function deselect()
    if selected then
        local info = registered[selected]
        selected = nil
        if info then
            info.selection:SetScript("OnUpdate", nil)
            paintSelection(info.selection, false)
        end
    end
    hideGuides()
    refreshDialog()
end

function pick(frame)
    if selected == frame then return end
    deselect()
    local info = registered[frame]
    if not info then return end
    selected = frame
    -- One selection at a time, so Blizzard's own goes. Never in combat: ClearSelectedSystem only
    -- runs through a secure delegate out of combat (Forever++'s finding, EditModeManager.lua).
    -- pcall, not ns.SafeCall: `selecting` must be put back even if Blizzard's code errors.
    if not InCombatLockdown() then
        selecting = true
        local ok, err = pcall(EditModeManagerFrame.ClearSelectedSystem, EditModeManagerFrame)
        selecting = false
        if not ok then ns:Debug("ClearSelectedSystem:", err) end
    end
    paintSelection(info.selection, true)
    refreshDialog()
end

local function setActive(active)
    if not active then deselect() end
    for _, info in pairs(registered) do
        info.selection:SetShown(active)
        if info.onActive then callFor(info, info.onActive, active) end
    end
end

local function install()
    if hooked then return end
    hooked = true
    hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function() setActive(true) end)
    hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function() setActive(false) end)
    -- Picking one of Blizzard's frames lets go of ours.
    hooksecurefunc(EditModeManagerFrame, "SelectSystem", function()
        if not selecting then deselect() end
    end)
end

---------------------------------------------------------------------------
-- Registering
---------------------------------------------------------------------------

--[[
    EditMode.Register(frame, info)
      info.label     the dialog's and menu's title
      info.owner     the module (charged by the Profiler)
      info.moveTo    function(cx, cy): put the frame's center there (UIParent units) and save it
      info.size      optional { min, max, step, format, get(), set(value) } for the dialog's slider,
                     the menu's Size and Ctrl + mouse wheel (none for a frame sized elsewhere)
      info.reset     function(): back to the default place
      info.settings  function(): open its settings
      info.onActive  optional function(active): whether Edit Mode is open for this frame: told on
                     Register, Unregister (false), and as Edit Mode opens and closes
    All but size and onActive are needed. Pass the same info table each time a frame registers again: its selection box is kept in it.
]]
function EditMode.Register(frame, info)
    if registered[frame] then return end
    frame:SetClampedToScreen(true)
    info.selection = info.selection or newSelection(frame, info)
    registered[frame] = info
    install()
    local active = EditMode.IsActive()
    info.selection:SetShown(active)
    if info.onActive then callFor(info, info.onActive, active) end
end

function EditMode.Unregister(frame)
    local info = registered[frame]
    if not info then return end
    if selected == frame then deselect() end
    registered[frame] = nil
    info.selection:Hide()
    if info.onActive then callFor(info, info.onActive, false) end
end
