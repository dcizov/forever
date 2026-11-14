--[[
    Forever Core - Settings/Controls.lua
    The control an option row in a module's section gets, from the option's definition (README.md,
    "Option fields"): a slider (with a box to type an exact value in when option.input is set),
    a dropdown, and the text the row's undo arrow names as the default. Each sets the option
    through ns:SetOption and is redrawn from what's saved.

    Layout and approach adapted from Forever++ by xIGBClutchIx (MIT License).
]]

local _, ns = ...
local Kit, L = ns.Kit, ns.L

local ipairs, type, format, math, tostring = ipairs, type, string.format, math, tostring

local Controls = {}
ns.Controls = Controls

local SLIDER_WIDTH = 180  -- 160 with a value box
local BOX_WIDTH    = 52
local BOX_ROOM     = BOX_WIDTH + 44  -- the box, its gap and its unit
local TEXT_ROOM    = 64   -- a slider's value text, right of it
local FLASH        = 1.5  -- seconds the box stays red after a value it couldn't use as typed

local Options = ns.Options
local sliderText, parseTyped = Options.SliderText, Options.ParseNumber

-- A dragged value: on the nearest step, then kept in range and to the option's precision the
-- way a typed one is (so 1.2 is stored as 1.2, not 1.2000000000000002).
local function roundToStep(option, value)
    local step = option.step or 1
    value = math.floor((value - option.min) / step + 0.5) * step + option.min
    return (Options.FitSlider(option, value))
end

-- A slider value as the box beside it shows it: to its precision, without trailing zeros.
local function numberText(option, value)
    local decimals = ns.Options.Precision(option)
    if decimals == 0 then return tostring(math.floor(value + 0.5)) end
    return (format("%." .. decimals .. "f", value):gsub("0+$", ""):gsub("%.$", ""))
end

-- The unit after the box: option.unit, else the format string without its number ("%d%%" -> "%").
local function unitOf(option)
    if option.unit then return option.unit end
    local fmt = type(option.format) == "string" and option.format or ""
    return (strtrim(fmt:gsub("%%[%-%d%.]*[dfgs]", ""):gsub("%%%%", "%%")))
end

-- A slider. With option.input, a box beside it takes an exact value (Enter sets it, Escape or
-- clicking away drops the edit), in place of the value text. A typed value can fall between the
-- slider's steps; the slider shows the nearest step and leaves the value alone until it's
-- dragged. Text outside the range is kept in it, and the box flashes red when what was typed
-- couldn't be used as is.
function Controls.Slider(parent, mod, option, width)
    local slider = CreateFrame("Frame", nil, parent, "MinimalSliderWithSteppersTemplate")
    slider:SetWidth(width)
    local options = Settings.CreateSliderOptions(option.min, option.max, option.step or 1)
    if not option.input then
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
            return sliderText(option, value)
        end)
    end
    slider:Init(mod.db[option.key], options.minValue, options.maxValue, options.steps, options.formatters)
    local updating
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        if updating then return end
        value = roundToStep(option, value)
        if value ~= mod.db[option.key] then ns:SetOption(mod.name, option.key, value) end
    end, slider)

    local box, unit, showSaved, paint
    if option.input then
        box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        box:SetSize(BOX_WIDTH, 20)
        box:SetPoint("LEFT", slider, "RIGHT", 10, 0)
        box:SetAutoFocus(false)
        box:SetJustifyH("RIGHT")
        box:SetMaxLetters(10)
        slider.Box = box

        unit = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        unit:SetPoint("LEFT", box, "RIGHT", 3, 0)
        unit:SetText(unitOf(option))

        function paint(r, g, b)
            box:SetTextColor(r, g, b)
            for _, key in ipairs({ "Left", "Middle", "Right" }) do
                local part = box[key]
                if part and part.SetVertexColor then part:SetVertexColor(r, g, b) end
            end
        end
        function showSaved()
            box:SetText(numberText(option, mod.db[option.key]))
            box:SetCursorPosition(0)
        end
        local function flash()
            paint(1, 0.3, 0.3)
            ns:After(ns.Kit.owner, FLASH, function()
                if box:IsEnabled() then paint(1, 1, 1) else paint(0.5, 0.5, 0.5) end
            end)
        end

        -- Read the text before clearing focus: losing focus puts the saved value back in the box.
        box:SetScript("OnEnterPressed", function(self)
            local value, adjusted = parseTyped(option, self:GetText() or "")
            self:ClearFocus()
            if not value then
                flash()
                return showSaved()
            end
            if adjusted then flash() end
            if value ~= mod.db[option.key] then ns:SetOption(mod.name, option.key, value) end
            showSaved()
        end)
        box:HookScript("OnEditFocusLost", showSaved)
        box:HookScript("OnEditFocusGained", function(self) self:HighlightText() end)
    end

    -- Draws it from what's saved, without the slider's own change writing back a rounded value.
    function slider.Refresh(enabled)
        updating = true
        slider:SetValue(mod.db[option.key])
        updating = false
        slider:SetEnabled(enabled)
        if not box then return end
        box:SetEnabled(enabled)
        if not box:HasFocus() then showSaved() end
        local shade = enabled and 1 or 0.5
        paint(shade, shade, shade)
        unit:SetTextColor(shade, shade, shade)
    end
    return slider
end

function Controls.Dropdown(parent, mod, option, width)
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetWidth(width)
    dropdown:SetupMenu(function(_, root)
        for _, choice in ipairs(option.choices) do
            root:CreateRadio(choice[2], function(value) return mod.db[option.key] == value end,
                function(value) ns:SetOption(mod.name, option.key, value) end, choice[1])
        end
    end)
    return dropdown
end

-- One dropdown for a group of checkbox options (option.group, README "Option fields"): its menu
-- ticks each, and its button counts the ticked ones with the group's format ("21 hidden").
function Controls.GroupDropdown(parent, mod, options, width)
    local group = options[1].group
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetWidth(width)
    dropdown:SetSelectionText(function()
        local count = 0
        for _, option in ipairs(options) do
            if mod.db[option.key] then count = count + 1 end
        end
        return format(group.format, count)
    end)
    dropdown:SetupMenu(function(_, root)
        for _, option in ipairs(options) do
            local box = root:CreateCheckbox(option.label, function() return mod.db[option.key] end,
                function() ns:SetOption(mod.name, option.key, not mod.db[option.key]) end)
            if option.tooltip then box:SetTitleAndTextTooltip(option.label, option.tooltip) end
        end
    end)
    return dropdown
end

-- The default as the undo arrow's tooltip says it.
function Controls.DefaultText(mod, option)
    local value = mod.defaults[option.key]
    if option.type == "slider" then return sliderText(option, value) end
    if option.type == "dropdown" then return ns.Options.ChoiceLabel(option, value) end
    return value and L.CHECKED or L.UNCHECKED
end

-- How wide a slider is: narrower with a value box, leaving `beside` for what's left of it.
function Controls.SliderWidth(option, room, beside)
    if option.input then return math.min(SLIDER_WIDTH - 20, room - beside - BOX_ROOM) end
    return math.min(SLIDER_WIDTH, room - beside - TEXT_ROOM)
end

-- The control for each non-checkbox option type: (view, row, mod, option, on), placed at the
-- view's controlLeft with controlRoom to fill. A checkbox's box goes in front of its label
-- instead (Settings/Section.lua).
local attach = {}

function attach.slider(view, row, mod, option, on)
    local slider = Controls.Slider(row, mod, option, Controls.SliderWidth(option, view.controlRoom, 6))
    slider:SetPoint("LEFT", view.controlLeft + 6, 0)
    table.insert(view.updates, function() slider.Refresh(on()) end)
    Kit.AddTooltip(row, option.label, option.tooltip, slider.Slider, slider.Box)
end

function attach.dropdown(view, row, mod, option, on)
    local dropdown = Controls.Dropdown(row, mod, option, math.min(180, view.controlRoom - 16))
    dropdown:SetPoint("LEFT", view.controlLeft + 6, 0)
    table.insert(view.updates, function()
        dropdown:GenerateMenu()
        dropdown:SetEnabled(on())
    end)
    Kit.AddTooltip(row, option.label, option.tooltip, dropdown)
end

-- Puts a slider or dropdown option's control in its row (at view.controlLeft, view.controlRoom
-- wide), redrawn with the view's other updates and greyed while on() is false.
function Controls.Attach(view, row, mod, option, on)
    attach[option.type](view, row, mod, option, on)
end
