--[[
    Forever Gearbox - UI/ForeverRows.lua
    A module's rows as Forever++ draws them on its Modules page: a gold name on the left (grey
    while it can't be changed) and Blizzard's control after it at Forever++'s measures, gray
    notices across the row, headings, and buttons. Two places draw them:

      * UI/ForeverPage.lua: the "Forever Gearbox" section on a Forever++ module's page (the modules
        attached to it), with Forever++.
      * Settings/AlonePage.lua: the selected module on Forever Gearbox' own Modules page, without
        Forever++.

    A view is { stack (a Kit stack), updates (redraw its controls from what's saved), found (rows
    the search can light up), optionRows (option key -> its found entry, for a conflict's
    button) }: Rows.NewView(stack). Rows.AddBody draws a module's notices, options, conflicts and
    buttons in the order it lists them.

    Layout and approach adapted from Forever++'s Settings/Settings.lua by xIGBClutchIx (MIT License).
]]

local _, ns = ...
local L, Kit, Controls = ns.L, ns.Kit, ns.Controls

local ipairs, format, max, min = ipairs, string.format, math.max, math.min

local Rows = {}
ns.ForeverRows = Rows

-- Forever++'s measures (Settings/Settings.lua), so our rows line up with its own.
local ROW_HEIGHT, INDENT, CONTROL_LEFT, RESET_SIZE = 26, 10, 165, 20
local GRAY = "|cff999999%s|r"
Rows.CONTROL_LEFT = CONTROL_LEFT
Rows.GRAY = GRAY
Rows.LOCK_ATLAS = "LFG-lock" -- Forever++'s padlock for a locked module

function Rows.NewView(stack)
    return { stack = stack, updates = {}, found = {}, optionRows = {} }
end

function Rows.Update(view)
    for _, update in ipairs(view.updates) do update() end
end

-- A row: `text` gold while on() and grey otherwise, the room after it for a control; shown only
-- while shown() is true, when given.
function Rows.AddRow(view, text, indent, on, shown)
    local stack = view.stack
    local row = CreateFrame("Frame", nil, stack)
    row:EnableMouse(true)
    row:SetWidth(stack:GetWidth())
    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", 4 + indent, 0)
    label:SetWidth(CONTROL_LEFT - 8 - indent)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    row:SetHeight(max(ROW_HEIGHT, label:GetStringHeight() + 8))
    Kit.AddEntry(stack, row, shown)
    if on then
        view.updates[#view.updates + 1] = function()
            label:SetFontObject(on() and "GameFontNormal" or "GameFontDisable")
        end
    end
    return row, label
end

-- A line across the view: a section's heading (GameFontHighlightLarge), a smaller one, or a
-- note such as "no options".
function Rows.AddLine(view, font, text, gap)
    local stack = view.stack
    local row = CreateFrame("Frame", nil, stack)
    row:SetSize(stack:GetWidth(), font == "GameFontHighlightLarge" and 24 or ROW_HEIGHT)
    local line = row:CreateFontString(nil, "OVERLAY", font)
    line:SetPoint("LEFT", 4, 0)
    line:SetText(text)
    Kit.AddEntry(stack, row, nil, gap or 16)
end

-- A gray row across the whole view (a notice, a conflict), shown while shown() is true.
local function addGray(view, text, shown)
    local row, label = Rows.AddRow(view, format(GRAY, text), 0, nil, shown)
    label:SetWidth(view.stack:GetWidth() - 8)
    row:SetHeight(max(ROW_HEIGHT, label:GetStringHeight() + 8))
    return row, label
end

-- A row with a button after its name; greyed while on() is false, when given.
function Rows.AddButtonRow(view, text, on, shown, button, fn, tooltip, title)
    local row = Rows.AddRow(view, text, 0, on, shown)
    local control = Kit.NewButton(row, button, min(180, view.stack:GetWidth() - CONTROL_LEFT - 16), fn)
    control:SetPoint("LEFT", CONTROL_LEFT + 6, 0)
    if on then
        view.updates[#view.updates + 1] = function() control:SetEnabled(on()) end
    end
    Kit.AddTooltip(row, title or text, tooltip, control)
    return row, control
end

-- A notice: its gray row while it applies (and the module is on), with the button that fixes it
-- when it has one. A game setting the module needs ({ requires }) says which and sets them.
-- after() runs once its button did its work.
function Rows.AddNotice(view, mod, notice, after)
    local needs = notice.requires
    local Requires = ns.Options.Requires
    local function shown()
        if not mod.db.enabled then return false end
        if needs then return Requires.Missing(needs) and true or false end
        return not notice.shown or notice.shown(mod.db) and true or false
    end
    local text = notice.text or needs and Requires.Text(needs) or ""
    local fn = notice.fn or needs and function() Requires.Set(mod, needs) end
    if not fn then
        local row = addGray(view, text, shown)
        Kit.AddTooltip(row, notice.text or L.REQUIRES_HEADER, notice.tooltip)
        return
    end
    Rows.AddButtonRow(view, format(GRAY, text), nil, shown, notice.button or L.REQUIRES_SET, function()
        ns.ChargedCall(mod, "notice", fn)
        if after then after() end
    end, notice.tooltip, notice.text or L.REQUIRES_HEADER)
    -- With Forever++ Integration: find it in Forever++'s Console Variables too, to lock it there.
    if needs and ns.Plugin.Integrated() then
        Rows.AddButtonRow(view, L.PLUGIN_CVARS, nil, shown, L.PLUGIN_CVARS_BUTTON, function()
            local first = needs[1].cvar
            for _, need in ipairs(needs) do
                if C_CVar.GetCVar(need.cvar) ~= need.value then first = need.cvar break end
            end
            ns.OtherAddons.OpenForeverPlusPlusCVar(first)
        end, L.PLUGIN_CVARS_TIP)
    end
end

-- The undo arrow at the end of an option's row (and the slider in it, `pair`), shown while either
-- differs from its default, putting them back.
local function addReset(view, row, mod, option, pair, on)
    local keys = { option, pair }
    local button, icon = Kit.NewResetButton(row, RESET_SIZE, function()
        for _, each in ipairs(keys) do ns:ResetOption(mod.name, each.key) end
    end)
    local function changed()
        for _, each in ipairs(keys) do
            if mod.db[each.key] ~= mod.defaults[each.key] then return true end
        end
        return false
    end
    button:SetMotionScriptsWhileDisabled(true)
    button:SetScript("OnEnter", function(self)
        Kit.ShowTooltip(self, L.RESET, format(L.RESET_TO, Controls.DefaultText(mod, option)))
    end)
    button:SetScript("OnLeave", Kit.HideTooltip)
    view.updates[#view.updates + 1] = function()
        button:SetShown(changed())
        button:SetEnabled(on())
        icon:SetDesaturated(not on())
    end
end

-- One option: a checkbox (with the slider it pairs with), a slider or a dropdown, indented under
-- the option it needs and greyed while that's off. A feature of a features module is greyed only
-- while featureOn() is false (ticking one turns the module on), when given.
function Rows.AddOption(view, mod, option, byKey, done, moduleOn, featureOn)
    local parent = option.requires and byKey[option.requires]
    local isFeature = featureOn and mod.featureSet and mod.featureSet[option.key]
    local function on()
        if isFeature then return featureOn() end
        if not moduleOn() then return false end
        local up = parent
        while up do
            local value = mod.db[up.key]
            if not value or value == "off" then return false end
            up = up.requires and byKey[up.requires]
        end
        return true
    end
    local depth, up = 0, parent
    while up do depth, up = depth + 1, up.requires and byKey[up.requires] end
    local shown = option.shown and function() return option.shown(mod.db) and true or false end
    local row = Rows.AddRow(view, option.label or option.key, depth * INDENT, on, shown)
    local updates = view.updates
    local room = view.stack:GetWidth() - CONTROL_LEFT - RESET_SIZE
    local pair = option.slider and byKey[option.slider]
    local paired = option.type == "checkbox" and pair and pair.type == "slider"

    -- Lit up like a selected sidebar entry while the search finds it (or the slider in it).
    local highlight = row:CreateTexture(nil, "BACKGROUND")
    highlight:SetAtlas("Options_List_Active")
    highlight:SetAllPoints()
    highlight:SetVertexColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 0.15)
    highlight:Hide()
    local text = (option.label or "") .. "\n" .. (option.tooltip or "")
    if paired then text = text .. "\n" .. (pair.label or "") .. "\n" .. (pair.tooltip or "") end
    local entry = { row = row, highlight = highlight, text = text:lower() }
    view.found[#view.found + 1] = entry
    view.optionRows[option.key] = entry
    addReset(view, row, mod, option, paired and pair or nil, on)

    if option.type == "checkbox" then
        local box = Kit.NewCheckbox(row, 30, function(checked) ns:SetOption(mod.name, option.key, checked) end)
        box:SetPoint("LEFT", CONTROL_LEFT, 0)
        updates[#updates + 1] = function()
            box:SetChecked(mod.db[option.key] and true or false)
            box:SetEnabled(on())
        end
        Kit.AddTooltip(row, option.label, option.tooltip, box)
        if not paired then return end
        done[pair.key] = true
        local slider = Controls.Slider(row, mod, pair, Controls.SliderWidth(pair, room, 36))
        slider:SetPoint("LEFT", box, "RIGHT", 6, 0)
        updates[#updates + 1] = function() slider.Refresh(on() and mod.db[option.key] and true or false) end
        return
    end
    local control
    if option.type == "slider" then
        control = Controls.Slider(row, mod, option, Controls.SliderWidth(option, room, 6))
        updates[#updates + 1] = function() control.Refresh(on()) end
    elseif option.type == "dropdown" then
        control = Controls.Dropdown(row, mod, option, min(180, room - 16))
        updates[#updates + 1] = function()
            control:GenerateMenu()
            control:SetEnabled(on())
        end
    end
    if control then
        control:SetPoint("LEFT", CONTROL_LEFT + 6, 0)
        Kit.AddTooltip(row, option.label, option.tooltip, control.Slider or control)
    end
end

-- Under option `index` of `options`, a gray row for each of its conflicts ({ key, when(db), text })
-- while it holds. A button goes to the other option (goTo(key)), unless it's the row just above
-- or below, or there's nowhere to go.
local function addConflicts(view, mod, options, index, goTo)
    for _, conflict in ipairs(options[index].conflicts or {}) do
        local beside, other = false, nil
        for i, each in ipairs(options) do
            if each.key == conflict.key then other, beside = each, i == index - 1 or i == index + 1 end
        end
        local function shown() return mod.db.enabled and conflict.when(mod.db) and true or false end
        if other and goTo and not beside then
            Rows.AddButtonRow(view, format(GRAY, conflict.text), nil, shown, format(L.ALONE_GO, other.label),
                function() goTo(conflict.key) end, nil, conflict.text)
        else
            addGray(view, conflict.text, shown)
        end
    end
end

--[[
    A module's notices, then its options and buttons in the order it lists them. A locked module
    shows only its notices. opts:
      moduleOn()      whether the module's rows can be changed
      featureOn()     the same for a features module's features (see Rows.AddOption), optional
      sectionFont     a `section`'s heading (default GameFontHighlightLarge), sectionGap its gap
      optionsHeader   the heading over options before the first section, optional
      noOptions       the line for a module with neither options nor buttons, optional
      goTo(key)       a conflict's button goes to option `key`, optional
      after()         after a notice's or a button's work, optional
]]
function Rows.AddBody(view, mod, opts)
    for _, notice in ipairs(mod.notice or {}) do Rows.AddNotice(view, mod, notice, opts.after) end
    if mod.locked then return end
    local options = mod.options
    if #options == 0 and not (mod.actions and mod.actions[1]) then
        if opts.noOptions then Rows.AddLine(view, "GameFontDisable", opts.noOptions) end
        return
    end
    local font, gap = opts.sectionFont or "GameFontHighlightLarge", opts.sectionGap
    -- A button with a `section` sits at the top of that section, under its heading; the rest come
    -- after every option.
    local actionsIn, loose = {}, {}
    for _, action in ipairs(mod.actions or {}) do
        local list = action.section and (actionsIn[action.section] or {}) or loose
        if action.section then actionsIn[action.section] = list end
        list[#list + 1] = action
    end
    local function addActions(list)
        for _, action in ipairs(list or {}) do
            local fn = action.fn
            Rows.AddButtonRow(view, action.name, opts.moduleOn, nil, action.button, function()
                ns.ChargedCall(mod, "button", fn)
                if opts.after then opts.after() end
            end, action.description)
        end
    end
    local byKey, done, section = {}, {}, nil
    for _, option in ipairs(options) do byKey[option.key] = option end
    if opts.optionsHeader and options[1] and not options[1].section then
        Rows.AddLine(view, font, opts.optionsHeader, gap)
    end
    for i, option in ipairs(options) do
        if option.section and option.section ~= section then
            section = option.section
            Rows.AddLine(view, font, section, gap)
            addActions(actionsIn[section])
            actionsIn[section] = nil
        end
        if not done[option.key] then
            Rows.AddOption(view, mod, option, byKey, done, opts.moduleOn, opts.featureOn)
            addConflicts(view, mod, options, i, opts.goTo)
        end
    end
    -- Buttons of a section no option is in, under its own heading, then the rest.
    for _, action in ipairs(mod.actions or {}) do
        local list = action.section and actionsIn[action.section]
        if list then
            Rows.AddLine(view, font, action.section, gap)
            addActions(list)
            actionsIn[action.section] = nil
        end
    end
    addActions(loose)
end
