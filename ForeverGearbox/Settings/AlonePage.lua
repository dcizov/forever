--[[
    Forever Gearbox - Settings/AlonePage.lua
    Forever Gearbox' Modules page, the top of its own entry in Settings > AddOns (Settings/Alone.lua),
    drawn as Forever++ draws its Modules page, so it looks at home beside Forever++:

      * On the left, every module (those for another addon only while it's loaded) under a gold
        label per category, in the order the labels sort, Other last. Clicking a label folds its
        modules away (kept in ForeverGearboxDB). Each module has its on/off checkbox (a padlock
        while `locked`), its title white while on, grey while off, red while it can't work
        (Problem). Clicking one shows it on the right.
      * On the right, its title, category and description (DESCRIPTION_LINES; the whole of it in
        a tooltip when cut short), its Enabled checkbox, then its notices, options, conflicts and
        buttons in Forever++'s rows (UI/ForeverRows.lua), greyed while it's off, and under them
        what its BuildPage(stack, width) adds (Vendor's Autobuy list, Full Bags' kept items).
      * At the top, a search box narrowing the list to the modules whose title, description or
        options have the text (lighting those options up), and Defaults for the selected module.

    Every change goes through ns:SetEnabled and ns:SetOption; the page follows ns:OnChanged, each
    changed module once on the next frame, so /fg and the page agree.

      AlonePage.Frame()       the page's canvas frame, for Settings (built when first shown)
      AlonePage.Select(name)  shows module `name` (now, or when the page is built)

    Layout and approach adapted from Forever++'s Settings/Settings.lua by xIGBClutchIx (MIT License).
]]

local _, ns = ...

local L, Kit, Rows = ns.L, ns.Kit, ns.ForeverRows

local ipairs, pairs, format, strlower, next, type = ipairs, pairs, string.format, string.lower, next, type

local AlonePage = {}
ns.AlonePage = AlonePage

local LIST_WIDTH = 186       -- the module list
local DESCRIPTION_LINES = 4  -- the room a description always takes, so the options stay put
local FLASH = 1.5            -- seconds a row a conflict's button went to stays lit

local listed = {}     -- the modules on the page, by category, then title
local searchText = {} -- module name -> its title, description and options' text, lowercased
local filter, filterText
local page            -- the page's frames, once built: split's, rows, views, search, empty
local selected        -- the module shown on the right
local bound = {}      -- module name -> functions putting what shows of it back to what's saved

---------------------------------------------------------------------------
-- The modules listed, and what the search looks through
---------------------------------------------------------------------------

local function categoryRank(key)
    if key == "other" then return 2, "" end
    return 1, strlower(ns:CategoryLabel(key) or key)
end

-- Every module the player can use here (one for another addon only while it's loaded), by
-- category (their labels' order, Other last), then title.
local function collect()
    for _, name in ipairs(ns.order) do
        local mod = ns.modules[name]
        if not mod.addon or ns.OtherAddons.Loaded(mod.addon) then
            listed[#listed + 1] = name
            local text = { mod.title, mod.description or "" }
            for _, option in ipairs(mod.options) do
                text[#text + 1] = (option.label or "") .. "\n" .. (option.tooltip or "")
            end
            searchText[name] = strlower(table.concat(text, "\n"))
        end
    end
    table.sort(listed, function(a, b)
        local ma, mb = ns.modules[a], ns.modules[b]
        local ra, la = categoryRank(ns:CategoryOf(ma))
        local rb, lb = categoryRank(ns:CategoryOf(mb))
        if ra ~= rb then return ra < rb end
        if la ~= lb then return la < lb end
        return strlower(ma.title) < strlower(mb.title)
    end)
end

local function matches(name)
    return not filter or searchText[name]:find(filter, 1, true) ~= nil
end

local function anyMatch(group)
    for _, name in ipairs(listed) do
        if (not group or ns:CategoryOf(ns.modules[name]) == group) and matches(name) then return true end
    end
    return false
end

-- Whether the player folded a category; a search opens them all, so nothing it finds is hidden.
local function folded(group)
    local folds = ns.db.foldedCategories
    return type(folds) == "table" and folds[group] == true and not filter
end

local function setFolded(group, fold)
    local folds = type(ns.db.foldedCategories) == "table" and ns.db.foldedCategories or {}
    folds[group] = fold or nil
    ns.db.foldedCategories = next(folds) and folds or nil
end

-- Runs `fn` now and whenever module `name` changes.
local function bind(name, fn)
    bound[name] = bound[name] or {}
    table.insert(bound[name], fn)
    fn()
end

---------------------------------------------------------------------------
-- The selected module's view
---------------------------------------------------------------------------

-- The module's on/off checkbox; a locked module's is Forever++'s padlock, saying why on hover.
local function newModuleCheck(parent, name, size)
    local mod = ns.modules[name]
    local box = Kit.NewCheckbox(parent, size, function(checked) ns:SetEnabled(name, checked) end)
    if mod.locked then
        box:SetAlpha(0)
        box:SetEnabled(false)
        local lock = parent:CreateTexture(nil, "OVERLAY")
        lock:SetSize(size * 0.75, size * 0.75)
        lock:SetPoint("CENTER", box)
        lock:SetAtlas(Rows.LOCK_ATLAS)
        box:HookScript("OnEnter", function(self) Kit.ShowTooltip(self, mod.title, mod.lockedText) end)
        box:HookScript("OnLeave", Kit.HideTooltip)
        return box
    end
    bind(name, function() box:SetChecked(mod.db.enabled and true or false) end)
    return box
end

-- Lights up the options of `view` the search finds; with `reveal`, scrolls the first into sight.
local function markFound(view, reveal)
    local first
    for _, entry in ipairs(view.found) do
        local found = filter ~= nil and entry.text:find(filter, 1, true) ~= nil
        entry.highlight:SetShown(found)
        first = first or found and entry.row or nil
    end
    if reveal and first then Kit.ScrollTo(page.pane, page.paneContent, first) end
end

local function layoutView(view)
    Kit.Layout(view.stack)
    page.paneContent:SetHeight(view.stack:GetHeight())
end

-- Scrolls to option `key` of `view` and lights its row for a moment (a conflict's button).
local function goToOption(view, key)
    local entry = view.optionRows[key]
    if not entry then return end
    Kit.ScrollTo(page.pane, page.paneContent, entry.row)
    entry.highlight:Show()
    ns:After(Kit.owner, FLASH, function()
        entry.highlight:SetShown(filter ~= nil and entry.text:find(filter, 1, true) ~= nil)
    end)
end

local refreshModule -- defined with the list

local function buildView(name)
    local mod = ns.modules[name]
    local width = page.paneWidth
    local stack = Kit.NewStack(page.paneContent, width, 4)
    stack:SetPoint("TOPLEFT")
    local view = Rows.NewView(stack)

    local heading = stack:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
    heading:SetPoint("TOPLEFT", 4, -4)
    heading:SetJustifyH("LEFT")
    heading:SetWordWrap(false)
    heading:SetWidth(width - 12)
    heading:SetText(mod.title)
    local group = stack:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    group:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
    group:SetText(ns:CategoryLabel(ns:CategoryOf(mod)))
    local description = stack:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    description:SetPoint("TOPLEFT", group, "BOTTOMLEFT", 0, -10)
    description:SetWidth(width - 12)
    description:SetJustifyH("LEFT")
    description:SetJustifyV("TOP")
    -- The height of DESCRIPTION_LINES lines of this font, measured.
    description:SetText(("X\n"):rep(DESCRIPTION_LINES - 1) .. "X")
    local height = description:GetStringHeight()
    description:SetHeight(height)
    description:SetMaxLines(DESCRIPTION_LINES) -- longer text ends in "..."
    description:SetText(mod.description or "")
    local hit = CreateFrame("Frame", nil, stack)
    hit:SetAllPoints(description)
    hit:EnableMouse(true)
    hit:SetScript("OnEnter", function()
        if description:IsTruncated() then Kit.ShowTooltip(hit, mod.title, mod.description) end
    end)
    hit:SetScript("OnLeave", Kit.HideTooltip)
    stack.top = 4 + heading:GetStringHeight() + 4 + group:GetStringHeight() + 10 + height + 6
    stack.bottom = 12

    local row = Rows.AddRow(view, L.ALONE_ENABLED, 0)
    newModuleCheck(row, name, 30):SetPoint("LEFT", Rows.CONTROL_LEFT, 0)
    local function moduleOn() return mod.db.enabled and not mod.locked and true or false end
    Rows.AddBody(view, mod, {
        moduleOn = moduleOn,
        featureOn = function() return not mod.locked end,
        optionsHeader = L.ALONE_OPTIONS,
        noOptions = not mod.BuildPage and L.ALONE_NO_OPTIONS or nil,
        goTo = function(key) goToOption(view, key) end,
        after = function() refreshModule(name) end,
    })
    if mod.BuildPage and not mod.locked then
        -- The module's own part of its page, under its options.
        local ok, redraw = ns.ChargedCall(mod, "settings page", ns.Succeeded, mod.BuildPage, mod, stack, width)
        if ok and type(redraw) == "function" then
            view.updates[#view.updates + 1] = function() ns.ChargedCall(mod, "settings page", redraw) end
        end
    end
    bind(name, function() Rows.Update(view) end)
    return view
end

-- Shows `name` on the right (nil for none).
local function choose(name)
    selected = name
    for _, row in pairs(page.rows) do Kit.Paint(row) end
    for other, view in pairs(page.views) do view.stack:SetShown(other == name) end
    if not name then return end
    local view = page.views[name]
    if not view then
        view = buildView(name)
        page.views[name] = view
    end
    layoutView(view)
    page.pane:SetVerticalScroll(0)
    markFound(view, true)
end

---------------------------------------------------------------------------
-- The module list
---------------------------------------------------------------------------

-- Lays out the modules the search shows, keeps the selection on one of them (the first, when it
-- hides the selected one), and lays out the selected module's rows.
local function relayout(reveal)
    if not page then return end
    page.empty.text:SetText(format(L.NO_MODULES_MATCH, filterText or ""))
    Kit.Layout(page.list)
    if not (selected and matches(selected)) then
        local first
        for _, name in ipairs(listed) do
            if matches(name) then
                first = name
                break
            end
        end
        choose(first)
    elseif page.views[selected] then
        layoutView(page.views[selected])
        markFound(page.views[selected], reveal)
    end
end

function refreshModule(name)
    for _, fn in ipairs(bound[name] or {}) do fn() end
    relayout()
end

local function refreshAll()
    for _, list in pairs(bound) do
        for _, fn in ipairs(list) do fn() end
    end
    relayout()
end

-- Shows `name` on the right and scrolls the list to it, opening its category if it's folded.
local function selectModule(name)
    local group = ns:CategoryOf(ns.modules[name])
    if folded(group) then
        setFolded(group, false)
        Kit.Layout(page.list)
    end
    choose(name)
    Kit.ScrollTo(page.listScroll, page.list, page.rows[name])
end

-- A row of the list: the module's checkbox and its title. Clicking it selects the module.
local function newListRow(name)
    local mod = ns.modules[name]
    local row = Kit.NewListButton(page.list, function() return selected == name end)
    local box = newModuleCheck(row, name, 22)
    box:SetPoint("LEFT", 0, 0)
    -- The checkbox takes the mouse from the row, so it keeps the row's highlight.
    box:HookScript("OnEnter", function() Kit.Hover(row, true) end)
    box:HookScript("OnLeave", function() Kit.Hover(row, false) end)
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", box, "RIGHT", 2, 0)
    text:SetPoint("RIGHT", -2, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetText(mod.title)
    bind(name, function()
        local font = mod.db.enabled and not mod.locked and GameFontHighlight or GameFontDisable
        text:SetFontObject(font)
        -- Set either way: a color set on the text outlasts a change of font object.
        if mod.Problem and mod.Problem() then
            text:SetTextColor(RED_FONT_COLOR:GetRGB())
        else
            text:SetTextColor(font:GetTextColor())
        end
    end)
    row:SetScript("OnClick", function()
        if selected ~= name then choose(name) end
    end)
    return row
end

-- A category's gold label after Blizzard's minus or plus button: clicking it folds its modules
-- away and opens them again. Folded, it says how many are in it. While searching, every category
-- is open and a click does nothing.
local function newCategoryLabel(group)
    local label = CreateFrame("Button", nil, page.list)
    label:SetSize(LIST_WIDTH, 16)
    local button = label:CreateTexture(nil, "ARTWORK")
    button:SetSize(14, 14)
    button:SetPoint("BOTTOMLEFT", 0, 1)
    local glow = label:CreateTexture(nil, "HIGHLIGHT")
    glow:SetTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
    glow:SetBlendMode("ADD")
    glow:SetAllPoints(button)
    local text = label:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", button, "RIGHT", 3, 0)
    text:SetText(ns:CategoryLabel(group))
    local count = label:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    count:SetPoint("LEFT", text, "RIGHT", 4, 0)
    local total = 0
    for _, name in ipairs(listed) do
        if ns:CategoryOf(ns.modules[name]) == group then total = total + 1 end
    end
    function label.Draw()
        local fold = folded(group)
        button:SetTexture("Interface\\Buttons\\UI-" .. (fold and "Plus" or "Minus") .. "Button-Up")
        button:SetDesaturated(filter ~= nil)
        count:SetText(fold and format("(%d)", total) or "")
    end
    label:SetScript("OnClick", function()
        if filter then return end
        setFolded(group, not folded(group))
        relayout()
    end)
    return label
end

local function build(frame)
    collect()
    Kit.AddPageTitle(frame, ns.title)
    page = Kit.NewSplit(frame, LIST_WIDTH)
    page.rows, page.views = {}, {}

    local defaults = Kit.AddDefaultsButton(frame, function()
        local mod = selected and ns.modules[selected]
        if not mod then return end
        ns:Confirm(Kit.owner, "DEFAULTS_MODULE", L.DEFAULTS_CONFIRM_MODULE, function() ns:ResetAll({ mod.name }) end, mod.title)
    end)
    page.search = Kit.AddSearchBox(frame, defaults, L.SEARCH_MODULES, function(text)
        filter = text ~= "" and strlower(text) or nil
        filterText = text
        relayout(true)
    end)

    page.empty = Kit.NewEmptyRow(page.list, LIST_WIDTH)
    Kit.AddEntry(page.list, page.empty, function() return not anyMatch() end)
    local group
    for _, name in ipairs(listed) do
        local current = ns:CategoryOf(ns.modules[name])
        if current ~= group then
            group = current
            local label = newCategoryLabel(current)
            Kit.AddEntry(page.list, label, function()
                label.Draw()
                return anyMatch(current)
            end, 12)
        end
        page.rows[name] = newListRow(name)
        Kit.AddEntry(page.list, page.rows[name], function() return matches(name) and not folded(current) end)
    end

    -- Opens on the module ns:OpenSettings asked for, else the first.
    if selected then selectModule(selected) end
    relayout()
    -- After /fg changed things while the page was closed, and for notices.
    frame:HookScript("OnShow", refreshAll)
end

function AlonePage.Frame()
    return Kit.CanvasFrame(function(frame) ns.ChargedCall(Kit.owner, "modules page", build, frame) end)
end

function AlonePage.Select(name)
    if not page then
        selected = name
        return
    end
    if not matches(name) then page.search:SetText("") end
    selectModule(name)
end

-- Each changed module drawn again once, on the next frame (a reset changes many options at once).
local waiting = {}
local function redrawWaiting()
    local names = waiting
    waiting = {}
    for name in pairs(names) do
        for _, fn in ipairs(bound[name] or {}) do fn() end
    end
    relayout()
end

ns:OnChanged(Kit.owner, function(_, name)
    if not page then return end
    waiting[name] = true
    ns:Soon(Kit.owner, redrawWaiting)
end)
