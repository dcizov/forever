--[[
    Forever runtime - Shared/Settings/ModulesPage.lua
    A member addon's Modules page (Shared/Settings/Modules.lua registers one per member), laid out like
    Forever++'s and Plumber's control panels: on the left, each of the member's modules under its
    category's label, each with its on/off checkbox; on the right, the selected one's own page:
    its section (Shared/Settings/Section.lua: title, description, notices, every option), then what its
    BuildPage(stack, width) adds (the Autobuy list, Full Bags' kept items; it may return a
    function redrawing that). At the top, a search box narrowing the list (by name, description
    and options, lighting up the matching option rows) and a Defaults button for the selected
    module.

    Inside a category, modules that share a `group` (a label: Fishing, Gathering, Combat) sit
    together under a small heading of that name, after the category's ungrouped modules.

    ModulesPage.Index(mod) adds a module to what the search looks through; ModulesPage.New(member)
    makes a page's controller: Group() (false when the member has no module for it), Frame(),
    Select(name) and Changed(name).

    Layout and approach adapted from Forever++ by xIGBClutchIx (MIT License).
]]

local _, ns = ...
local Kit, Section, L = ns.Kit, ns.Section, ns.L

local ipairs, pairs, format, strlower = ipairs, pairs, string.format, string.lower

local LIST_WIDTH = 186
local FLASH = 1.5 -- seconds a row a conflict's button went to stays lit

local ModulesPage = {}
ns.ModulesPage = ModulesPage

local searchText = {}   -- module name -> lowercase text the search looks through

function ModulesPage.Index(mod)
    local text = { strlower(mod.title .. "\n" .. (mod.description or "")) }
    for _, option in ipairs(mod.options) do
        text[#text + 1] = strlower((option.label or "") .. "\n" .. (option.tooltip or ""))
    end
    searchText[mod.name] = table.concat(text, "\n")
end

-- A member's Modules page.
-- A category's label in the list, with how many of its modules are on; shown while any of
-- its modules matches the search (matches(name)).
local function addGroupHeader(list, group, first, matches)
    local header = CreateFrame("Frame", nil, list)
    header:SetSize(LIST_WIDTH, 22)
    local label = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOMLEFT", 4, 3)
    label:SetText(group.label)
    local count = header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    count:SetPoint("BOTTOMRIGHT", -4, 3)
    function group.Refresh()
        local on = 0
        for _, name in ipairs(group.names) do
            if ns.modules[name].db.enabled then on = on + 1 end
        end
        count:SetText(format("%d/%d", on, #group.names))
    end
    Kit.AddEntry(list, header, function()
        for _, name in ipairs(group.names) do
            if matches(name) then return true end
        end
        return false
    end, first and 0 or 10)
end

-- A group's small heading inside its category, indented; shown while any of its modules matches.
local function addSubHeader(list, label, names, matches)
    local header = CreateFrame("Frame", nil, list)
    header:SetSize(LIST_WIDTH, 18)
    local text = header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    text:SetPoint("BOTTOMLEFT", 10, 2)
    text:SetText(label)
    Kit.AddEntry(list, header, function()
        for _, name in ipairs(names) do
            if matches(name) then return true end
        end
        return false
    end, 4)
end

function ModulesPage.New(member)
    local redraws = {}      -- module name -> functions that redraw it from what's saved
    local groups = {}       -- { key, label, names } per category with modules, in order

    -- The page once built: split (Kit.NewSplit), rows (name -> list row), views (name -> its pane
    -- stack, built when first shown), sections (name -> its Section view), search, empty.
    local page
    local selected          -- the module shown on the right
    local filter            -- lowercase search text, or nil

    local function matches(name)
        return not filter or (searchText[name] or ""):find(filter, 1, true) ~= nil
    end

    local function firstMatch()
        for _, group in ipairs(groups) do
            for _, name in ipairs(group.names) do
                if matches(name) then return name end
            end
        end
    end

    -- Adds a redraw for module `name` and runs it once.
    local function addRedraw(name, fn)
        redraws[name] = redraws[name] or {}
        table.insert(redraws[name], fn)
        fn()
    end

    local function redraw(name)
        for _, fn in ipairs(redraws[name] or {}) do fn() end
    end

    ---------------------------------------------------------------------------
    -- The pane: the selected module's page
    ---------------------------------------------------------------------------

    -- Lays module `name`'s pane out again, lighting up the rows the search finds.
    local function relayoutView(name)
        local view, section = page.views[name], page.sections[name]
        if not view then return end
        Kit.Layout(section)
        for _, entry in ipairs(section.found) do
            entry.highlight:SetShown(filter ~= nil and entry.text:find(filter, 1, true) ~= nil)
        end
        Kit.Layout(view)
    end

    -- Module `name`'s pane drawn again from what's saved, and laid out again.
    local function refreshView(name)
        redraw(name)
        relayoutView(name)
    end

    -- Scrolls to option `key`'s row in section `view` and lights it for a moment (a conflict's button).
    local function goToOption(section, key)
        local entry = section.optionRows[key]
        if not (entry and selected) then return end
        Kit.ScrollTo(page.split.pane, page.views[selected], entry.row)
        entry.highlight:Show()
        ns:After(Kit.owner, FLASH, function()
            entry.highlight:SetShown(filter ~= nil and entry.text:find(filter, 1, true) ~= nil)
        end)
    end

    -- What a section asks of the page it's on (see Shared/Settings/Section.lua).
    local sectionPage = {
        GoTo = goToOption,
        Refresh = refreshView,
    }

    local function buildView(name)
        local split = page.split
        local view = Kit.NewStack(split.pane, split.paneWidth, 0)
        view.bottom = 12
        local section, redrawSection = Section.Build(name, view, split.paneWidth, sectionPage)
        Kit.AddEntry(view, section)
        page.views[name], page.sections[name] = view, section
        addRedraw(name, redrawSection)
        local mod = ns.modules[name]
        if mod.BuildPage then
            -- The module's own part of its page, under its options.
            local ok, redrawExtra = ns.ChargedCall(mod, "settings page", ns.Succeeded, mod.BuildPage, mod, view, split.paneWidth)
            if ok and redrawExtra then addRedraw(name, redrawExtra) end
        end
        -- Seen: its NEW labels go the next time the page is built.
        member.db.seenModules[name] = ns.version
        return view
    end

    local function show(name)
        selected = name
        for _, row in pairs(page.rows) do Kit.Paint(row) end
        for other, view in pairs(page.views) do view:SetShown(other == name) end
        if not name then return end
        local view = page.views[name] or buildView(name)
        view:Show()
        page.split.pane:SetScrollChild(view)
        page.split.pane:SetVerticalScroll(0)
        refreshView(name)
        -- Built after the window inked the page: its words in the look's ink too.
        ns.SettingsWindow.Ink(view)
    end

    ---------------------------------------------------------------------------
    -- The list
    ---------------------------------------------------------------------------

    local function refreshRow(name)
        local row = page and page.rows[name]
        if row then row.Refresh() end
    end

    local function refreshList()
        for name in pairs(page.rows) do refreshRow(name) end
        for _, group in ipairs(groups) do group.Refresh() end
        page.empty.text:SetText(format(L.NO_MODULES_MATCH, filter or ""))
        Kit.Layout(page.split.list)
    end

    local function addModuleRow(list, name)
        local mod = ns.modules[name]
        local row = Kit.NewListButton(list, function() return selected == name end)
        local box = Kit.NewCheckbox(row, 18, function(checked) ns:SetEnabled(name, checked) end)
        box:SetPoint("LEFT", 2, 0)
        local title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("LEFT", 24, 0)
        title:SetPoint("RIGHT", -4, 0)
        title:SetJustifyH("LEFT")
        title:SetWordWrap(false)
        title:SetText(mod.title)
        if Section.IsNew(name, mod.added) then
            local label = Kit.NewLabel(row, title)
            label:ClearAllPoints()
            label:SetPoint("RIGHT", -18, 0)
            label:SetScale(0.8)
            title:SetPoint("RIGHT", -52, 0)
        end
        row:SetScript("OnClick", function()
            if selected ~= name then show(name) end
        end)
        Kit.AddTooltip(row, mod.title, mod.description, box)
        function row.Refresh()
            local on = mod.db.enabled
            box:SetChecked(on)
            title:SetFontObject(on and "GameFontHighlight" or "GameFontDisable")
        end
        page.rows[name] = row
        Kit.AddEntry(list, row, function() return matches(name) end)
    end

    local function buildPage(frame)
        page = { rows = {}, views = {}, sections = {} }
        Kit.AddPageTitle(frame, member.title)
        page.split = Kit.NewSplit(frame, LIST_WIDTH)

        local defaults = Kit.AddDefaultsButton(frame, function()
            local mod = selected and ns.modules[selected]
            if not mod then return end
            ns:Confirm(Kit.owner, "DEFAULTS_MODULE", L.DEFAULTS_CONFIRM_MODULE, function() ns:ResetAll({ selected }) end, mod.title)
        end)
        page.search = Kit.AddSearchBox(frame, defaults, L.SEARCH_MODULES, function(text)
            filter = text ~= "" and strlower(text) or nil
            refreshList()
            if not (selected and matches(selected)) then
                show(firstMatch())
            else
                relayoutView(selected)
            end
        end)

        local list = page.split.list
        page.empty = Kit.NewEmptyRow(list, LIST_WIDTH)
        Kit.AddEntry(list, page.empty, function() return firstMatch() == nil end)
        for i, group in ipairs(groups) do
            addGroupHeader(list, group, i == 1, matches)
            local current
            for _, name in ipairs(group.names) do
                local label = ns.modules[name].group
                if label and label ~= current then
                    local members = {}
                    for _, other in ipairs(group.names) do
                        if ns.modules[other].group == label then members[#members + 1] = other end
                    end
                    addSubHeader(list, label, members, matches)
                end
                current = label
                addModuleRow(list, name)
            end
        end
        refreshList()
        show(selected or firstMatch())
    end

    -- Redraw a changed module once, on the next frame, and only while the page is open: it
    -- redraws everything when it's shown anyway.
    local waiting = {} -- module name -> true, changed since the last redraw
    local function redrawWaiting()
        local names = waiting
        waiting = {}
        for name in pairs(names) do
            if page.views[name] then refreshView(name) end
        end
        refreshList()
    end

    local controller = {}

    function controller.Changed(name)
        if not page then return end
        waiting[name] = true
        ns:Soon(Kit.owner, redrawWaiting)
    end

    -- Lists the member's modules that no page of its own takes, by category, then title.
    function controller.Group()
        local names = {}
        for _, name in ipairs(member.order) do
            local mod = ns.modules[name]
            if ns:CategoryOf(mod) ~= "settings" and not ns:PageOf(mod) then names[#names + 1] = name end
        end
        table.sort(names, function(a, b)
            local ma, mb = ns.modules[a], ns.modules[b]
            local ra, rb = ns:CategoryRank(ma), ns:CategoryRank(mb)
            if ra ~= rb then return ra < rb end
            -- Ungrouped first, then each group by its label.
            local ga, gb = ma.group or "", mb.group or ""
            if ga ~= gb then return ga < gb end
            return strlower(ma.title) < strlower(mb.title)
        end)
        local byKey = {}
        for _, name in ipairs(names) do
            local key = ns:CategoryOf(ns.modules[name])
            if not byKey[key] then
                byKey[key] = { key = key, label = ns:CategoryLabel(key), names = {} }
                groups[#groups + 1] = byKey[key]
            end
            table.insert(byKey[key].names, name)
        end
        return #names > 0
    end

    function controller.Frame()
        local frame = Kit.CanvasFrame(buildPage)
        frame:HookScript("OnShow", function()
            refreshList()
            if selected then refreshView(selected) end
        end)
        return frame
    end

    -- Selects module `name` (shown when the page is next drawn, or now).
    function controller.Select(name)
        if page then
            if not matches(name) then page.search:SetText("") end
            show(name)
        else
            selected = name
        end
    end

    return controller
end

