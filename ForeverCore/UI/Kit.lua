--[[
    Forever Core - UI/Kit.lua
    The addon's shared UI toolkit: the pieces our Settings pages are drawn from, and its windows
    (the copy window). Blizzard's own templates and atlases (the Settings
    panel's title and divider, minimal checkboxes, sidebar highlight, search box), so a page
    looks like the game's own and none of Blizzard's pooled Settings rows are touched. It loads
    before the modules, so any of them may use it.
    Every template and atlas used here is in Forever's client (checked against its UI source),
    so there are no fallbacks for older clients.

    Layout and approach adapted from Forever++ by xIGBClutchIx (MIT License),
    https://github.com/xIGBClutchIx/ForeverPlusPlus
]]

local _, ns = ...

local CreateFrame, ipairs, math = CreateFrame, ipairs, math

local Kit = {}
ns.Kit = Kit

-- What the Settings pages' own timers and listeners are charged to by the Profiler.
Kit.owner = { name = "Settings" }

local LIST_LEFT, LIST_ROW = 7, 20
local PAGE_CONTROL, PAGE_ROW = 200, 36

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------

-- A canvas page filled by build(frame) the first time it's shown. It starts hidden: Settings
-- showing a frame that's already shown wouldn't fire OnShow.
function Kit.CanvasFrame(build)
    local frame = CreateFrame("Frame")
    frame:Hide()
    local built = false
    frame:SetScript("OnShow", function(self)
        if not built then
            built = true
            build(self)
        end
    end)
    return frame
end

-- Opens a Settings category (after combat), through the client's own call so Blizzard's pages
-- aren't set up from our code.
function Kit.Open(category)
    if not category then return end
    if InCombatLockdown() then ns:Print(ns.L.AFTER_COMBAT) end
    ns:AfterCombat(Kit.owner, function() C_SettingsUtil.OpenSettingsPanel(category:GetID()) end)
end

function Kit.AddPageTitle(frame, text)
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
    title:SetPoint("TOPLEFT", 7, -22)
    title:SetText(text)
    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    divider:SetPoint("TOP", 0, -50)
    return title
end

-- A scroll frame with Blizzard's modern thin scroll bar (MinimalScrollBar, the one in the Legacy
-- System and Professions windows) just right of it, the caller leaving it room (about 20). The
-- bar shows only while the frame shows and has something to scroll. scroll.ScrollBar is the bar.
function Kit.NewScroll(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 6, -2)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 6, 2)
    ScrollUtil.InitScrollFrameWithScrollBar(scroll, bar)
    scroll:EnableMouseWheel(true)
    scroll.ScrollBar = bar
    local function showBar() bar:SetShown(scroll:IsShown() and (scroll:GetVerticalScrollRange() or 0) > 0) end
    scroll:HookScript("OnScrollRangeChanged", showBar)
    scroll:HookScript("OnShow", showBar)
    scroll:HookScript("OnHide", showBar)
    showBar()
    return scroll
end

-- The Defaults button at a page's top right; onClick asks before resetting anything.
function Kit.AddDefaultsButton(frame, onClick)
    local button = Kit.NewButton(frame, SETTINGS_DEFAULTS, 96, onClick)
    button:SetPoint("TOPRIGHT", -10, -18)
    return button
end

---------------------------------------------------------------------------
-- Tooltips
---------------------------------------------------------------------------

function Kit.ShowTooltip(owner, title, text)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 1, 1)
    if text and text ~= "" then
        GameTooltip:AddLine(text, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
    end
    GameTooltip:Show()
end

function Kit.HideTooltip()
    GameTooltip:Hide()
end

-- The tooltip a row shows over itself and its controls (...), like Blizzard's settings rows.
function Kit.AddTooltip(row, title, text, ...)
    if not text or text == "" then return end
    local function enter() Kit.ShowTooltip(row, title, text) end
    for _, frame in ipairs({ row, ... }) do
        frame:HookScript("OnEnter", enter)
        frame:HookScript("OnLeave", Kit.HideTooltip)
    end
end

---------------------------------------------------------------------------
-- Controls
---------------------------------------------------------------------------

-- A checkbox in the Settings panel's minimal art.
function Kit.NewCheckbox(parent, size, onClick)
    local box = CreateFrame("CheckButton", nil, parent)
    box:SetSize(size, size)
    box:SetNormalAtlas("checkbox-minimal")
    box:SetPushedAtlas("checkbox-minimal")
    local check = box:CreateTexture(nil, "ARTWORK")
    check:SetAtlas("checkmark-minimal")
    check:SetAllPoints()
    box:SetCheckedTexture(check)
    local grey = box:CreateTexture(nil, "ARTWORK")
    grey:SetAtlas("checkmark-minimal-disabled")
    grey:SetAllPoints()
    box:SetDisabledCheckedTexture(grey)
    box:SetScript("OnClick", function(self)
        local checked = self:GetChecked() and true or false
        PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        onClick(checked)
    end)
    return box
end

function Kit.NewButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetText(text)
    if onClick then button:SetScript("OnClick", function() onClick() end) end
    return button
end

-- Blizzard's NEW label after `text` (a font string in `parent`).
function Kit.NewLabel(parent, text)
    local label = CreateFrame("Frame", nil, parent, "NewFeatureLabelTemplate")
    label:SetPoint("LEFT", text, "RIGHT", 18, 0)
    label:SetFrameLevel(parent:GetFrameLevel() + 2)
    return label
end

-- The undo arrow at a row's right end, like the Talents and Transmog windows'.
function Kit.NewResetButton(row, size, onClick)
    local button = CreateFrame("Button", nil, row)
    button:SetSize(size, size)
    button:SetPoint("RIGHT", -2, 0)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAtlas("common-icon-undo")
    icon:SetSize(16, 16)
    icon:SetPoint("CENTER")
    button:SetHighlightAtlas("common-icon-undo", "ADD")
    button:GetHighlightTexture():SetAllPoints(icon)
    button:SetScript("OnMouseDown", function(self)
        if self:IsEnabled() then icon:SetPoint("CENTER", 1, -1) end
    end)
    button:SetScript("OnMouseUp", function() icon:SetPoint("CENTER") end)
    button:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        onClick()
    end)
    return button, icon
end

-- A search box at a page's top right (left of `anchor` if given).
function Kit.AddSearchBox(frame, anchor, instructions, onChange)
    local box = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
    box:SetSize(200, 20)
    if anchor then
        box:SetPoint("RIGHT", anchor, "LEFT", -12, 0)
    else
        box:SetPoint("TOPRIGHT", -12, -19)
    end
    box:SetAutoFocus(false)
    box.Instructions:SetText(instructions)
    box:HookScript("OnTextChanged", function(self) onChange(strtrim(self:GetText())) end)
    return box
end

-- A small checkbox with `text` after it, left of `anchor`, in a page's title row (Changelog's
-- By Module). Clicking the word clicks the box.
function Kit.AddLabeledCheck(frame, anchor, text, onClick)
    local box = Kit.NewCheckbox(frame, 22, onClick)
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetText(text)
    label:SetPoint("RIGHT", anchor, "LEFT", -12, 0)
    box:SetPoint("RIGHT", label, "LEFT", -2, 0)
    box:SetHitRectInsets(0, -(label:GetUnboundedStringWidth() + 2), 0, 0)
    return box
end

---------------------------------------------------------------------------
-- Stacks: entries ({ frame, shown, gap }) placed one under another, each only while shown().
---------------------------------------------------------------------------

function Kit.NewStack(parent, width, gap)
    local stack = CreateFrame("Frame", nil, parent)
    stack:SetWidth(width)
    stack.entries, stack.gap, stack.top, stack.bottom = {}, gap, 0, 0
    return stack
end

function Kit.AddEntry(stack, frame, shown, gap)
    stack.entries[#stack.entries + 1] = { frame = frame, shown = shown, gap = gap }
end

-- The entries added last (`count` of them, else one) show only while shown() is true.
function Kit.ShowWhen(stack, shown, count)
    for i = #stack.entries - (count or 1) + 1, #stack.entries do stack.entries[i].shown = shown end
end

function Kit.Layout(stack)
    local y, any = -stack.top, false
    for _, entry in ipairs(stack.entries) do
        local shown = not entry.shown or entry.shown() and true or false
        entry.frame:SetShown(shown)
        if shown then
            if any then y = y - (entry.gap or stack.gap) end
            entry.frame:ClearAllPoints()
            entry.frame:SetPoint("TOPLEFT", 0, y)
            y = y - entry.frame:GetHeight()
            any = true
        end
    end
    stack:SetHeight(math.max(-y + stack.bottom, 1))
end

---------------------------------------------------------------------------
-- Split pages (Modules, Changelog): a narrow list on the left with sidebar-style rows, a faint
-- gold line, and a scrolling pane on the right.
---------------------------------------------------------------------------

function Kit.NewSplit(frame, listWidth)
    local width = frame:GetWidth()
    width = width > 0 and width or 615
    local paneLeft = LIST_LEFT + listWidth + 41
    local split = {}

    local list = Kit.NewScroll(frame)
    list:SetPoint("TOPLEFT", LIST_LEFT, -60)
    list:SetPoint("BOTTOMLEFT", LIST_LEFT, 8)
    list:SetWidth(listWidth)
    split.listScroll = list
    split.list = Kit.NewStack(list, listWidth, 2)
    split.list.bottom = 8
    list:SetScrollChild(split.list)

    local line = frame:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 0.25)
    line:SetWidth(1)
    line:SetPoint("TOPLEFT", paneLeft - 12, -66)
    line:SetPoint("BOTTOMLEFT", paneLeft - 12, 14)

    local pane = Kit.NewScroll(frame)
    pane:SetPoint("TOPLEFT", paneLeft, -60)
    pane:SetPoint("BOTTOMRIGHT", -32, 8)
    split.pane, split.paneWidth = pane, width - paneLeft - 32
    split.paneContent = CreateFrame("Frame", nil, pane)
    split.paneContent:SetWidth(split.paneWidth)
    pane:SetScrollChild(split.paneContent)
    return split
end

-- The sidebar's highlight while a list row is selected or under the mouse.
function Kit.Paint(row)
    if row.isSelected() then
        row.highlight:SetAtlas("Options_List_Active")
        row.highlight:Show()
    elseif row.over then
        row.highlight:SetAtlas("Options_List_Hover")
        row.highlight:Show()
    else
        row.highlight:Hide()
    end
end

function Kit.Hover(row, over)
    row.over = over
    Kit.Paint(row)
end

function Kit.NewListButton(list, isSelected)
    local row = CreateFrame("Button", nil, list)
    row:SetSize(list:GetWidth(), LIST_ROW)
    row.isSelected = isSelected
    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints()
    row:SetScript("OnEnter", function() Kit.Hover(row, true) end)
    row:SetScript("OnLeave", function() Kit.Hover(row, false) end)
    return row
end

function Kit.NewEmptyRow(list, width)
    local empty = CreateFrame("Frame", nil, list)
    empty:SetSize(width, 40)
    empty.text = empty:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    empty.text:SetPoint("TOPLEFT", 2, -4)
    empty.text:SetWidth(width - 4)
    empty.text:SetJustifyH("LEFT")
    return empty
end

-- Moves `scroll` so `frame` (inside `content`) is in view, on the next frame.
function Kit.ScrollTo(scroll, content, frame)
    if not frame then return end
    ns:After(Kit.owner, 0, function()
        local top, inner = content:GetTop(), frame:GetTop()
        if not (top and inner) then return end
        scroll:SetVerticalScroll(math.min(math.max(top - inner - 4, 0), scroll:GetVerticalScrollRange()))
    end)
end

---------------------------------------------------------------------------
-- Row pages (home, Settings, Debug): a scrolling stack under the title, of headers, text, and rows with
-- a gold label on the left and a control at PAGE_CONTROL.
---------------------------------------------------------------------------

function Kit.NewRowPage(frame, title)
    Kit.AddPageTitle(frame, title)
    local scroll = Kit.NewScroll(frame)
    scroll:SetPoint("TOPLEFT", 7, -60)
    scroll:SetPoint("BOTTOMRIGHT", -32, 8)
    local width = frame:GetWidth()
    local stack = Kit.NewStack(scroll, (width > 0 and width or 615) - 45, 0)
    stack.bottom = 12
    scroll:SetScrollChild(stack)
    return stack
end

function Kit.AddHeaderRow(stack, text)
    local row = CreateFrame("Frame", nil, stack)
    row:SetSize(stack:GetWidth(), 34)
    local line = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    line:SetPoint("BOTTOMLEFT", 4, 4)
    line:SetText(text)
    Kit.AddEntry(stack, row, nil, 8)
    return row
end

function Kit.AddTextRow(stack, text, font, gap)
    local row = CreateFrame("Frame", nil, stack)
    row:SetWidth(stack:GetWidth())
    local line = row:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    line:SetPoint("TOPLEFT", 4, 0)
    line:SetWidth(stack:GetWidth() - 12)
    line:SetJustifyH("LEFT")
    line:SetText(text)
    row:SetHeight(line:GetStringHeight() + 2)
    row.text = line
    Kit.AddEntry(stack, row, nil, gap or 4)
    return row
end

local function labeledRow(stack, label, height)
    local row = CreateFrame("Frame", nil, stack)
    row:EnableMouse(true)
    row:SetSize(stack:GetWidth(), height or PAGE_ROW)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetPoint("LEFT", 4, 0)
    row.label:SetWidth(PAGE_CONTROL - 12)
    row.label:SetJustifyH("LEFT")
    row.label:SetText(label)
    Kit.AddEntry(stack, row, nil, 0)
    return row
end

-- A label with buttons beside it, { text, fn } each, sharing the room right of the label (at
-- most 210 wide each), so they fit the narrow pane beside the module list too.
function Kit.AddButtonsRow(stack, label, buttons, tooltip)
    local row = labeledRow(stack, label)
    local gap = 6
    local room = stack:GetWidth() - PAGE_CONTROL - 8
    local width = math.min(210, math.floor((room - gap * (#buttons - 1)) / #buttons))
    local made = {}
    for i, spec in ipairs(buttons) do
        local button = Kit.NewButton(row, spec[1], width, spec[2])
        button:SetPoint("LEFT", PAGE_CONTROL + (i - 1) * (width + gap), 0)
        made[i] = button
    end
    Kit.AddTooltip(row, label, tooltip, unpack(made))
    return row, unpack(made)
end

function Kit.AddButtonRow(stack, label, buttonText, fn, tooltip)
    return Kit.AddButtonsRow(stack, label, { { buttonText, fn } }, tooltip)
end

function Kit.AddCheckRow(stack, label, get, set, tooltip)
    local row = labeledRow(stack, label)
    local box = Kit.NewCheckbox(row, 30, set)
    box:SetPoint("LEFT", PAGE_CONTROL - 4, 0)
    function row.Refresh() box:SetChecked(get() and true or false) end
    row.Refresh()
    Kit.AddTooltip(row, label, tooltip, box)
    return row
end

-- A read-only box with text to copy (a link).
function Kit.AddCopyRow(stack, label, text)
    local row = labeledRow(stack, label, 28)
    local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    box:SetSize(stack:GetWidth() - PAGE_CONTROL - 20, 20)
    box:SetPoint("LEFT", PAGE_CONTROL + 6, 0)
    box:SetAutoFocus(false)
    box:SetText(text)
    box:SetCursorPosition(0)
    box:SetScript("OnTextChanged", function(self, user)
        if user then self:SetText(text) self:HighlightText() end
    end)
    box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return row
end

---------------------------------------------------------------------------
-- Windows: a movable dialog that Escape closes, and a scrolling box of text to read or copy.
---------------------------------------------------------------------------

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
        local f = Kit.NewWindow("ForeverCoreCopyWindow", 580, 420)
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
