--[[
    Forever runtime - Shared/Settings/Section.lua
    One module's section: on a member's Modules page, the selected module's (Shared/Settings/Modules.lua),
    and on the Settings and Tweaks for Addons pages, each module of their category ("settings",
    "addons"). Its header with the on/off checkbox, its
    notices, and a row per option, drawn from the module's options
    table (the fields are in README.md, "Option fields") with controls from Settings/Controls.lua.

      * A module that is one feature has its on/off checkbox in front of the title. A module that
        bundles several (`features`, see Core/Module.lua) has none: each feature is a checkbox row
        of its own, and the module runs while any is ticked.
      * Options: a checkbox in front of its label, a slider or dropdown right of it, indented under
        the checkbox it needs, greyed while that's off; an undo arrow while it differs from the
        default; a gray row for each conflict that holds, with a button going to the other option.
      * Notices (module.notice, a list once ns:NewModule has it): { text, tooltip, button, fn, shown = function(db) }: a
        gray row above the options while shown() is true, with a button that fixes it. A notice
        about another addon names it (`addon`, its folder) and says what to change there
        (`advice`), for the Tweaks for Addons page's list (Settings/Addons.lua). A game setting
        the module needs is { requires = { { cvar, value } }, tooltip }: drawn the way Plumber asks
        for one (an orange "You need to change these settings" line, then "- Set CVar name to
        value"), shown while any of them differs, with a button that sets them all.
      * A module or option added since the player last looked at the module (`added`) carries
        Blizzard's NEW label.
      * Labels take the left half of the section, controls the right: it fits the narrow pane
        beside the module list as well as a full page.

    A section keeps view.updates (redraws its controls), view.found (rows the search can light up)
    and view.optionRows (option key -> its row's entry, for page.GoTo).

    Layout and approach adapted from Forever++ by xIGBClutchIx (MIT License).
]]

local _, ns = ...
local Kit, Controls, L = ns.Kit, ns.Controls, ns.L

local ipairs, format, strlower, math = ipairs, string.format, string.lower, math

local Section = {}
ns.Section = Section

local ROW_HEIGHT   = 30
local BASE         = 18   -- a section's rows start this far in from its header
local INDENT       = 24   -- each checkbox an option needs indents it this much more
local BOX          = 28   -- a checkbox and its gap, in front of its label
local CONTROL_MAX  = 300  -- where sliders and dropdowns start, at most (else half the width)
local RESET_SIZE   = 20

---------------------------------------------------------------------------
-- NEW labels: what's newer than the version the player last looked at this module in.
---------------------------------------------------------------------------

-- Kept in the module's member's saved variables: each member was installed at its own version.
local function seenIn(name)
    local db = ns.modules[name].member.db
    return db.seenModules[name] or db.installed
end

local function isNew(name, added)
    return added ~= nil and ns:IsNewer(added, seenIn(name))
end
Section.IsNew = isNew

---------------------------------------------------------------------------
-- A module's section
---------------------------------------------------------------------------

-- A row with a label `left` in (after a checkbox when `hasCheckbox`), greyed while on() is false.
local function addLabelRow(view, text, left, on, shown, hasCheckbox)
    local row = CreateFrame("Frame", nil, view)
    row:EnableMouse(true)
    row:SetWidth(view:GetWidth())
    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local indent = hasCheckbox and BOX or 4
    label:SetPoint("LEFT", left + indent, 0)
    label:SetWidth((hasCheckbox and view:GetWidth() - RESET_SIZE - 8 or view.controlLeft - 8) - left - indent)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    row:SetHeight(math.max(ROW_HEIGHT, label:GetStringHeight() + 8))
    Kit.AddEntry(view, row, shown)
    if on then
        table.insert(view.updates, function()
            label:SetFontObject(on() and "GameFontNormal" or "GameFontDisable")
        end)
    end
    return row, label
end

-- A gray row across the section (a notice or a conflict), shown while spec.shown() is true.
--   spec: text, tooltip, shown, button and fn (a button that runs fn, when given), plain (the
--   text has its own colours, not gray).
local function addGrayRow(view, spec)
    local text = spec.text
    local row, label = addLabelRow(view, spec.plain and text or "|cff999999" .. text .. "|r", BASE, nil, spec.shown)
    if spec.button then
        local button = Kit.NewButton(row, spec.button, math.min(180, view:GetWidth() - view.controlLeft - 16), spec.fn)
        button:SetPoint("LEFT", view.controlLeft + 6, 0)
        Kit.AddTooltip(row, text, spec.tooltip, button)
    else
        label:SetWidth(view:GetWidth() - BASE - 8)
        row:SetHeight(math.max(ROW_HEIGHT, label:GetStringHeight() + 8))
        Kit.AddTooltip(row, text, spec.tooltip)
    end
    return row
end

-- A heading inside a section, for its options' own sections ("Never Suggest").
local function addSubheading(view, text)
    local row = CreateFrame("Frame", nil, view)
    row:SetSize(view:GetWidth(), 26)
    local line = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    line:SetPoint("BOTTOMLEFT", BASE + 4, 4)
    line:SetText(text)
    Kit.AddEntry(view, row, nil, 8)
end

-- The undo arrow for `options` (one option and its paired slider, or a group's): forgets them
-- all; tooltipText() is its tooltip's line. Shown while there's a saved choice to forget, even one
-- equal to today's default (see Core/Store.lua: a saved choice is kept when a later version
-- changes the default).
local function addResetButton(view, row, mod, options, on, tooltipText)
    local button, icon = Kit.NewResetButton(row, RESET_SIZE, function()
        for _, option in ipairs(options) do ns:ResetOption(mod.name, option.key) end
    end)
    button:SetMotionScriptsWhileDisabled(true)
    button:SetScript("OnEnter", function(self) Kit.ShowTooltip(self, L.RESET, tooltipText()) end)
    button:SetScript("OnLeave", Kit.HideTooltip)
    local IsDefault = ns.Store.IsDefault
    table.insert(view.updates, function()
        local changed = false
        for _, option in ipairs(options) do changed = changed or not IsDefault(mod, option.key) end
        button:SetShown(changed)
        button:SetEnabled(on())
        icon:SetDesaturated(not on())
    end)
end

-- Lights a row up while the search finds it, and for a moment when a conflict's button goes to it.
local function addHighlight(view, row, text)
    local highlight = row:CreateTexture(nil, "BACKGROUND")
    highlight:SetAllPoints()
    highlight:SetColorTexture(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 0.12)
    highlight:Hide()
    local entry = { row = row, highlight = highlight, text = strlower(text) }
    view.found[#view.found + 1] = entry
    return entry
end

-- The checkboxes an option needs (its requires chain), nearest first.
local function neededChain(option, byKey)
    local chain = {}
    local up = option.requires and byKey[option.requires]
    while up do
        chain[#chain + 1] = up
        up = up.requires and byKey[up.requires]
    end
    return chain
end

-- Whether option `key`'s row can be changed: the module is on (a features module's features
-- always can be, since ticking one turns it on) and every checkbox it needs is ticked.
local function enabledWhen(mod, key, chain)
    local isFeature = mod.featureSet and mod.featureSet[key]
    return function()
        if not mod.db.enabled and not isFeature then return false end
        for _, needed in ipairs(chain) do
            if not mod.db[needed.key] then return false end
        end
        return true
    end
end

-- A gray row under the option for each conflict, while it holds.
local function addConflictRows(view, mod, option, byKey, page)
    for _, conflict in ipairs(option.conflicts or {}) do
        local other = byKey[conflict.key]
        if other then
            addGrayRow(view, {
                text = conflict.text,
                shown = function() return mod.db.enabled and conflict.when(mod.db) and true or false end,
                button = format(L.GO_TO, other.label),
                fn = function() page.GoTo(view, conflict.key) end,
            })
        end
    end
end

-- A checkbox option's box in front of its label, with its paired slider right of it.
local function attachCheckbox(view, row, left, mod, option, on, pair)
    local box = Kit.NewCheckbox(row, 26, function(checked) ns:SetOption(mod.name, option.key, checked) end)
    box:SetPoint("LEFT", left, 0)
    table.insert(view.updates, function()
        box:SetChecked(mod.db[option.key])
        box:SetEnabled(on())
    end)
    Kit.AddTooltip(row, option.label, option.tooltip, box)
    if not pair then return end
    -- Its slider, like any slider option's, greyed while the checkbox is off too.
    Controls.Attach(view, row, mod, pair, function() return on() and mod.db[option.key] and true or false end)
end

-- An option's row: label (indented under what it needs), NEW label, search highlight, undo
-- arrow, its control (with a paired slider, which then gets no row of its own), and conflicts.
local function addOptionRow(view, mod, option, byKey, done, page)
    local chain = neededChain(option, byKey)
    local on = enabledWhen(mod, option.key, chain)
    local shown = option.shown and function() return option.shown(mod.db) and true or false end
    local left = BASE + #chain * INDENT
    local isBox = option.type == "checkbox"
    local row, label = addLabelRow(view, option.label, left, on, shown, isBox)
    if isNew(mod.name, option.added) then Kit.NewLabel(row, label) end
    local pair = option.slider and byKey[option.slider]
    if pair then done[pair.key] = true end
    view.optionRows[option.key] = addHighlight(view, row, option.label .. " " .. (option.tooltip or "")
        .. (pair and (" " .. pair.label) or ""))
    addResetButton(view, row, mod, { option, pair }, on, function()
        local text = Controls.DefaultText(mod, option)
        if pair then text = text .. ", " .. Controls.DefaultText(mod, pair) end
        return format(L.RESET_TO, text)
    end)
    if isBox then
        attachCheckbox(view, row, left, mod, option, on, pair)
    else
        Controls.Attach(view, row, mod, option, on)
    end
    addConflictRows(view, mod, option, byKey, page)
end

-- A title with its gray description under it, `left` px in (room for a checkbox in front).
local function newTitleRow(parent, text, description, left)
    local row = CreateFrame("Frame", nil, parent)
    row:SetWidth(parent:GetWidth())
    local title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetJustifyH("LEFT")
    title:SetPoint("TOPLEFT", left + 4, -6)
    title:SetText(text)
    local line = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    line:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    line:SetWidth(parent:GetWidth() - left - 8)
    line:SetJustifyH("LEFT")
    line:SetText(description or "")
    row:SetHeight(6 + title:GetStringHeight() + 4 + line:GetStringHeight() + 6)
    return row, title
end

-- The header: the title (with the on/off checkbox in front of it, unless the module's features
-- switch it), and its description under it.
local function addHeader(view, mod)
    local row, title = newTitleRow(view, mod.title, mod.description, mod.features and 0 or BOX)
    row:EnableMouse(true)
    if isNew(mod.name, mod.added) then Kit.NewLabel(row, title) end
    local box
    if not mod.features then
        box = Kit.NewCheckbox(row, 30, function(checked) ns:SetEnabled(mod.name, checked) end)
        box:SetPoint("TOPLEFT", -2, 0)
    end
    Kit.AddTooltip(row, mod.title, mod.description, box)
    table.insert(view.updates, function()
        if box then box:SetChecked(mod.db.enabled) end
        local shade = mod.db.enabled and 1 or 0.6
        title:SetTextColor(shade, shade, shade)
    end)
    Kit.AddEntry(view, row)
end

-- A title like a module's (addHeader, for a module without an on/off checkbox) with its gray
-- description under it, for a page's own headings (Tweaks for Addons' other addons).
function Section.AddTitle(stack, text, description)
    local row = newTitleRow(stack, text, description, 0)
    Kit.AddEntry(stack, row, nil, 4)
    return row
end

-- One row for a group of checkbox options (option.group): its label and a dropdown ticking each,
-- greyed by what the first one needs; the undo arrow forgets them all.
local function addGroupRow(view, mod, options, byKey)
    local group = options[1].group
    local chain = neededChain(options[1], byKey)
    local on = enabledWhen(mod, options[1].key, chain)
    local left = BASE + #chain * INDENT
    local row, label = addLabelRow(view, group.label, left, on)
    local isNewer = false
    local text = { group.label }
    for _, option in ipairs(options) do
        isNewer = isNewer or isNew(mod.name, option.added)
        text[#text + 1] = option.label .. " " .. (option.tooltip or "")
    end
    if isNewer then Kit.NewLabel(row, label) end
    local entry = addHighlight(view, row, table.concat(text, " "))
    for _, option in ipairs(options) do view.optionRows[option.key] = entry end

    addResetButton(view, row, mod, options, on, function() return L.RESET_GROUP end)

    local room = view:GetWidth() - view.controlLeft - RESET_SIZE
    local dropdown = Controls.GroupDropdown(row, mod, options, math.min(220, room - 16))
    dropdown:SetPoint("LEFT", view.controlLeft + 6, 0)
    Kit.AddTooltip(row, group.label, group.tooltip, dropdown)
    table.insert(view.updates, function()
        dropdown:GenerateMenu()
        dropdown:SetEnabled(on())
    end)
end

-- Module `name`'s section, `width` wide in `parent`. `page` is what the section asks of the page
-- it's on: page.GoTo(view, key) shows option `key`'s row, page.Refresh(name) redraws the module.
-- Plumber's way of asking for game settings (its SoftTargetName Req lines): Core/Options.lua.
local Requires = ns.Options.Requires

-- A notice's button: fn as the module's code, then `refresh` a moment later, since what it fixed
-- may be in the game's hands (a CVar) or another addon's.
function Section.RunNotice(mod, fn, refresh)
    ns.ChargedCall(mod, "notice", fn)
    ns:After(Kit.owner, 0.2, refresh)
end

-- What a notice that needs game settings (`requires`) shows and does: its own lines and button.
local function requiresNotice(notice)
    local requires = notice.requires
    return {
        text = Requires.Text(requires), tooltip = notice.tooltip, plain = true,
        shown = function() return Requires.Missing(requires) end,
        button = notice.button or L.REQUIRES_SET,
        fn = function() Requires.Set(Kit.owner, requires) end,
    }
end

-- One notice's row (see the file header).
local function addNotice(view, mod, notice, page, name)
    local spec = notice.requires and requiresNotice(notice) or notice
    local fn = spec.fn
    addGrayRow(view, {
        text = spec.text, tooltip = spec.tooltip, plain = spec.plain, button = spec.button,
        shown = function() return mod.db.enabled and (not spec.shown or spec.shown(mod.db)) and true or false end,
        fn = fn and function() Section.RunNotice(mod, fn, function() page.Refresh(name) end) end,
    })
end

-- The names of the modules of `category`, in load order: the modules a page draws by category.
function Section.ModulesIn(category)
    local names = {}
    for _, name in ipairs(ns.order) do
        if ns:CategoryOf(ns.modules[name]) == category then names[#names + 1] = name end
    end
    return names
end

-- Returns the section and a function that redraws it from what's saved.
function Section.Build(name, parent, width, page)
    local mod = ns.modules[name]
    local view = Kit.NewStack(parent, width, 0)
    view.updates, view.found, view.optionRows = {}, {}, {}
    view.controlLeft = math.min(CONTROL_MAX, math.floor(width / 2))
    view.controlRoom = width - view.controlLeft - RESET_SIZE -- what a control can fill (left of the undo arrow)

    addHeader(view, mod)

    for _, notice in ipairs(mod.notice or {}) do addNotice(view, mod, notice, page, name) end

    local byKey, done = {}, {}
    for _, option in ipairs(mod.options) do byKey[option.key] = option end
    local section
    for i, option in ipairs(mod.options) do
        if option.section and option.section ~= section then
            section = option.section
            addSubheading(view, section)
        end
        if option.group then
            -- The group's row, at its first option; the rest go into it.
            if not done[option.key] then
                local members = {}
                for j = i, #mod.options do
                    local other = mod.options[j]
                    if other.group == option.group then
                        members[#members + 1] = other
                        done[other.key] = true
                    end
                end
                addGroupRow(view, mod, members, byKey)
            end
        elseif not done[option.key] then
            addOptionRow(view, mod, option, byKey, done, page)
        end
    end

    return view, function()
        for _, fn in ipairs(view.updates) do fn() end
    end
end

-- Module `name`'s section as one entry of a page's stack (Kit.NewRowPage), for pages other than
-- the Modules page: the Settings page (the Minimap Button) and Tweaks for Addons. Its redraw
-- goes into `refreshers`; `relayout` lays the page out again after a redraw.
function Section.AddToPage(name, stack, refreshers, relayout)
    if not ns.modules[name] then return end
    local view, redraw
    local page = {
        GoTo = function(_, key)
            local entry = view.optionRows[key]
            if entry then Kit.ScrollTo(stack:GetParent(), stack, entry.row) end
        end,
        Refresh = function()
            redraw()
            relayout()
        end,
    }
    view, redraw = Section.Build(name, stack, stack:GetWidth(), page)
    Kit.AddEntry(stack, view, nil, 4)
    refreshers[#refreshers + 1] = function()
        redraw()
        Kit.Layout(view)
    end
end
