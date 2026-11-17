--[[
    Forever runtime - Shared/UI/KitRows.lua
    Kit's row pages (Shared/UI/Kit.lua): a scrolling stack under a page's title, of headings, text,
    a part's big heading (AddPartRow), a boxed line about what's going on now (AddInfoRow), side by
    side columns (AddColumns), and rows with a gold label on the left and Blizzard's control at
    PAGE_CONTROL (or a column's own `control`): buttons, checkbox, slider, dropdown, text box, a
    link to copy. The home, Settings, Debug and Advanced Graphics pages are made of them.

    Layout and approach adapted from Forever++ by xIGBClutchIx (MIT License),
    https://github.com/xIGBClutchIx/ForeverPlusPlus
]]

local _, ns = ...
local Kit = ns.Kit

local CreateFrame, ipairs, math, tostring, unpack = CreateFrame, ipairs, math, tostring, unpack

local PAGE_CONTROL, PAGE_ROW = 200, 36

---------------------------------------------------------------------------
-- Row pages (home, Settings, Debug): a scrolling stack under the title, of headers, text, and rows with
-- a gold label on the left and a control at PAGE_CONTROL (or the stack's own `control`: a column's).
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

-- Where a row's control starts on `stack`: its own `control` (a column, Kit.AddColumns), else PAGE_CONTROL.
local function controlLeft(stack) return stack.control or PAGE_CONTROL end

-- A big heading opening a part of a page of its own (a line across, then the title), well apart
-- from what's above it.
function Kit.AddPartRow(stack, text, gap)
    local row = CreateFrame("Frame", nil, stack)
    row:SetSize(stack:GetWidth(), 52)
    local divider = row:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    divider:SetPoint("TOP", 0, 0)
    local line = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
    line:SetPoint("BOTTOMLEFT", 4, 4)
    line:SetText(text)
    Kit.AddEntry(stack, row, nil, gap or 28)
    return row
end

-- A line about what's going on now, in a faint box of its own (row.text), apart from the rows
-- around it.
function Kit.AddInfoRow(stack, text, gap)
    local row = CreateFrame("Frame", nil, stack)
    row:SetWidth(stack:GetWidth())
    local back = row:CreateTexture(nil, "BACKGROUND")
    back:SetColorTexture(1, 1, 1, 0.06)
    back:SetPoint("TOPLEFT", 0, 0)
    back:SetPoint("BOTTOMRIGHT", -8, 0)
    local line = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line:SetPoint("TOPLEFT", 10, -7)
    line:SetWidth(stack:GetWidth() - 28)
    line:SetJustifyH("LEFT")
    row.text = line
    function row.SetText(_, value)
        line:SetText(value)
        row:SetHeight(line:GetStringHeight() + 14)
    end
    row:SetText(text)
    Kit.AddEntry(stack, row, nil, gap or 10)
    return row
end

-- Side by side columns on `stack` (count of them, `gap` apart), each a stack of its own whose rows
-- put their controls `control` in. Laid out with the stack (Kit.Layout); returns the columns.
function Kit.AddColumns(stack, count, control, gap)
    gap = gap or 20
    local holder = CreateFrame("Frame", nil, stack)
    local width = math.floor((stack:GetWidth() - gap * (count - 1)) / count)
    holder:SetWidth(stack:GetWidth())
    local columns = {}
    for i = 1, count do
        local column = Kit.NewStack(holder, width, 0)
        column.control = control
        column:SetPoint("TOPLEFT", (i - 1) * (width + gap), 0)
        columns[i] = column
    end
    Kit.AddEntry(stack, holder, nil, 0)
    stack.entries[#stack.entries].layout = function()
        local tallest = 1
        for _, column in ipairs(columns) do
            Kit.Layout(column)
            tallest = math.max(tallest, column:GetHeight())
        end
        holder:SetHeight(tallest)
    end
    return columns
end

local function labeledRow(stack, label, height)
    local row = CreateFrame("Frame", nil, stack)
    row:EnableMouse(true)
    row:SetSize(stack:GetWidth(), height or PAGE_ROW)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetPoint("LEFT", 4, 0)
    row.label:SetWidth(controlLeft(stack) - 12)
    row.label:SetJustifyH("LEFT")
    row.label:SetText(label)
    Kit.AddEntry(stack, row, nil, 0)
    return row
end

-- A label with buttons beside it, { text, fn [, width] } each, sharing the room right of the label
-- (at most 210 wide each, or the width given), so they fit the narrow pane beside the module list too.
function Kit.AddButtonsRow(stack, label, buttons, tooltip)
    local row = labeledRow(stack, label)
    local gap, left = 6, controlLeft(stack)
    local room = stack:GetWidth() - left - 8
    local width = math.min(210, math.floor((room - gap * (#buttons - 1)) / #buttons))
    local made, x = {}, left
    for i, spec in ipairs(buttons) do
        local own = math.min(spec[3] or width, width)
        local button = Kit.NewButton(row, spec[1], own, spec[2])
        button:SetPoint("LEFT", x, 0)
        x = x + own + gap
        made[i] = button
    end
    Kit.AddTooltip(row, label, tooltip, unpack(made))
    return row, unpack(made)
end

function Kit.AddButtonRow(stack, label, buttonText, fn, tooltip, width)
    return Kit.AddButtonsRow(stack, label, { { buttonText, fn, width } }, tooltip)
end

function Kit.AddCheckRow(stack, label, get, set, tooltip)
    local row = labeledRow(stack, label)
    local box = Kit.NewCheckbox(row, 30, set)
    box:SetPoint("LEFT", controlLeft(stack) - 4, 0)
    function row.Refresh() box:SetChecked(get() and true or false) end
    row.Refresh()
    Kit.AddTooltip(row, label, tooltip, box)
    return row
end

-- A slider of Blizzard's (steppers, its value at the right) for a value of the page's own (not a
-- module option: those use Controls.Slider). spec: min, max, step, format (its value text, e.g.
-- "%d%%"; whole numbers without). row.Refresh(enabled) draws it from get().
function Kit.AddSliderRow(stack, label, spec, get, set, tooltip)
    local row = labeledRow(stack, label)
    local slider = CreateFrame("Frame", nil, row, "MinimalSliderWithSteppersTemplate")
    slider:SetWidth(math.min(250, stack:GetWidth() - controlLeft(stack) - 60))
    slider:SetPoint("LEFT", controlLeft(stack), 0)
    local step = spec.step or 1
    local options = Settings.CreateSliderOptions(spec.min, spec.max, step)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
        if spec.format then return string.format(spec.format, value) end
        return tostring(math.floor(value + 0.5))
    end)
    slider:Init(get() or spec.min, options.minValue, options.maxValue, options.steps, options.formatters)
    local updating
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        if not updating then set(math.floor((value - spec.min) / step + 0.5) * step + spec.min) end
    end, slider)
    function row.Refresh(enabled)
        updating = true
        slider:SetValue(get() or spec.min)
        updating = false
        slider:SetEnabled(enabled ~= false)
        row.label:SetFontObject(enabled ~= false and "GameFontNormal" or "GameFontDisable")
    end
    row.slider = slider
    row.Refresh(true)
    Kit.AddTooltip(row, label, tooltip, slider)
    return row
end

-- A dropdown of Blizzard's: setup(root) fills its menu, text() names what's chosen.
function Kit.AddDropdownRow(stack, label, setup, text, tooltip)
    local row = labeledRow(stack, label)
    local dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
    dropdown:SetWidth(math.min(220, stack:GetWidth() - controlLeft(stack) - 8))
    dropdown:SetPoint("LEFT", controlLeft(stack), 0)
    dropdown:SetupMenu(function(_, root) setup(root) end)
    dropdown:SetSelectionText(function() return text() end)
    function row.Refresh() dropdown:GenerateMenu() end
    row.dropdown = dropdown
    Kit.AddTooltip(row, label, tooltip, dropdown)
    return row
end

-- A box to type in: Enter keeps what's typed (set(text)), Escape drops it.
function Kit.AddEditRow(stack, label, get, set, tooltip)
    local row = labeledRow(stack, label)
    local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    box:SetSize(math.min(250, stack:GetWidth() - controlLeft(stack) - 20), 20)
    box:SetPoint("LEFT", controlLeft(stack) + 6, 0)
    box:SetAutoFocus(false)
    box:SetScript("OnEnterPressed", function(self)
        set(self:GetText() or "")
        self:ClearFocus()
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    function row.Refresh() if not box:HasFocus() then box:SetText(get() or "") end end
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
