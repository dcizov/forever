--[[
    Forever runtime - Shared/UI/Windows.lua
    Kit's windows (UI/Kit.lua has the Settings page pieces): a movable window that Escape closes,
    one holding a scrolling stack of rows (a module's own window: the Autobuy list, the Gathering
    window), and a scrolling box of text to read or copy (the copy window).
]]

local _, ns = ...

local CreateFrame = CreateFrame
local Kit = ns.Kit

-- A movable window with a title, in front of the game's own, closed by Escape: Forever's own
-- window chrome (ButtonFrameTemplate, the metal frame of the gossip and quest windows), without
-- the portrait.
function Kit.NewWindow(name, width, height)
    local f = CreateFrame("Frame", name, UIParent, "ButtonFrameTemplate")
    ButtonFrameTemplate_HidePortrait(f)
    f:SetSize(width, height)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    tinsert(UISpecialFrames, name)
    f:Hide()
    return f
end

-- A window of a module's own (the Autobuy list, the Gathering window): Kit.NewWindow with
-- `title`, and a scrolling stack filling it for rows (Kit.AddHeaderRow and the like; lay it out
-- with Kit.Layout). Named, so the game keeps where it was dragged to (a moved window is
-- user-placed). Returns the window and its stack.
function Kit.NewStackWindow(name, title, width, height)
    local f = Kit.NewWindow(name, width, height)
    f:SetTitle(title)
    f:SetFrameStrata("HIGH")
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetUserPlaced(true)
    end)
    local scroll = Kit.NewScroll(f)
    scroll:SetPoint("TOPLEFT", 12, -30)
    scroll:SetPoint("BOTTOMRIGHT", -30, 32)
    local stack = Kit.NewStack(scroll, width - 48, 0)
    stack.bottom = 12
    scroll:SetScrollChild(stack)
    return f, stack
end

-- A scrolling multi-line box in `window` (Escape in it closes the window), and a Select All
-- button for it. The caller places both.
function Kit.NewTextBox(window, width)
    local scroll = Kit.NewScroll(window)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(width)
    edit:SetScript("OnEscapePressed", function() window:Hide() end)
    scroll:SetScrollChild(edit)
    local selectAll = Kit.NewButton(window, ns.L.SELECT_ALL, 110, function()
        edit:SetFocus()
        edit:HighlightText()
    end)
    return scroll, edit, selectAll
end

-- A window with text to copy, many lines (Debug's Copy Debug Info, the Profiler report); one
-- line in a popup is ns:ShowCopyText (UI/Popups.lua).
local copyWindow

function Kit.ShowCopyWindow(title, text)
    if not copyWindow then
        local f = Kit.NewWindow(ns.name .. "CopyWindow", 580, 420)
        local scroll, edit, selectAll = Kit.NewTextBox(f, 520)
        scroll:SetPoint("TOPLEFT", 14, -32)
        scroll:SetPoint("BOTTOMRIGHT", -32, 42)
        selectAll:SetPoint("BOTTOMLEFT", 12, 12)
        Kit.NewButton(f, CLOSE, 110, function() f:Hide() end):SetPoint("BOTTOMRIGHT", -12, 12)
        f.edit = edit
        copyWindow = f
    end
    copyWindow:SetTitle(title)
    copyWindow.edit:SetText(text)
    copyWindow:Show()
    copyWindow.edit:SetFocus()
    copyWindow.edit:HighlightText()
end
