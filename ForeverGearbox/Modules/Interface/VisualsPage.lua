--[[
    Forever Gearbox - Modules/Interface/VisualsPage.lua
    The Advanced Graphics page (Visuals.lua), its own entry under Forever++ in Settings while the
    module is on, as Forever++'s Console Variables page is. Rows as the suite's other Settings pages
    (Kit.NewRowPage: a gold label left and Blizzard's control right):
      * The graphics settings in two columns (Kit.AddColumns): Look (Preset: Visuals.PRESETS,
        "Custom" once a value is changed by hand; Protect Values), Image (with a line while Dynamic
        Light sets Brightness, Contrast and Gamma) and World Detail on the left; Lighting &
        Atmosphere and Camera & Interaction on the right. A row per setting this client has (a
        slider or a checkbox); one another addon makes its own (Visuals.Conflict) is greyed and its
        tooltip says why.
      * Then Dynamic Light across the page, well apart under a divider and a big heading of its
        own (DynamicLightPage.lua).
    With Forever++ the entry is found as Forever++ gives its own to Blizzard's Settings
    (Settings.RegisterAddOnCategory, hooked as it's called at Forever++'s login, after this file
    loads; matched by its title as UI/ForeverPage.lua does), and kept in its list of pages as
    Forever++ keeps its tools' (Settings shows a category's GetSubcategories). Forever++ redraws
    that list when one of its own tools turns on or off, so ours is put back each time Settings
    opens. It's always under Forever Gearbox' own entry (Settings/Alone.lua) and, with Forever++
    Integration, under Forever++'s too, the same way. Page.UseHost(category, keepLast, fpp) puts it
    under one.
]]

local _, ns = ...
local L, Kit, Controls = ns.L, ns.Kit, ns.Controls

local ipairs, format, math, type, unpack = ipairs, string.format, math, type, unpack

local Page = {}
ns.VisualsPage = Page

local owner = { name = "Visuals page" } -- what this file's work is charged to
local ROW_CONTROL = 200   -- where a full-width row's control starts (Kit's PAGE_CONTROL)
local COLUMN_CONTROL = 125 -- and a column's
-- Which column each part of the graphics settings is in: Look, Image, World Detail on the left;
-- Lighting & Atmosphere, Camera & Interaction on the right. Dynamic Light comes after both,
-- across the page.
local RIGHT = { new = true, view = true }

local wanted -- whether ours is listed (the module is on)
local refreshers = {}

local function Visuals() return ns.Visuals end

-- Whether Dynamic Light's rows are live (it's on).
function Page.Enabled() return Visuals().module.db.dynamic and true or false end

-- What a page draws again with the others (each row's Refresh).
function Page.AddRefresh(fn) refreshers[#refreshers + 1] = fn end

function Page.Redraw()
    for _, refresh in ipairs(refreshers) do ns.ChargedCall(owner, "visuals row", refresh) end
end

-- A row of the module's own option (a checkbox or a slider), drawn from and setting it.
function Page.AddOptionRow(stack, key, enabled)
    local mod = Visuals().module
    local option
    for _, o in ipairs(mod.options) do
        if o.key == key then option = o end
    end
    if option.type == "checkbox" then
        local row = Kit.AddCheckRow(stack, option.label, function() return mod.db[key] end,
            function(checked) ns:SetOption(mod.name, key, checked) end, option.tooltip)
        Page.AddRefresh(row.Refresh)
        return row
    end
    local row = Kit.AddButtonsRow(stack, option.label, {}, option.tooltip)
    local left = stack.control or ROW_CONTROL
    local slider = Controls.Slider(row, mod, option, math.min(250, stack:GetWidth() - left - 60))
    slider:SetPoint("LEFT", left, 0)
    Page.AddRefresh(function() slider.Refresh(not enabled or enabled()) end)
    return row
end

---------------------------------------------------------------------------
-- Visuals
---------------------------------------------------------------------------

local function settingRow(stack, def)
    local V = Visuals()
    local function tip()
        local why = V.Conflict(def) and format(L.VISUALS_CONFLICT, V.Conflict(def)) or V.Dynamic(def) and L.VISUALS_DAYTIME
        return def.tip .. "\n\n" .. format(L.VISUALS_CVAR, def.cvar, C_CVar.GetCVarDefault(def.cvar) or "?")
            .. (why and ("\n\n" .. why) or "")
    end
    -- Dynamic Light's daytime value while it's on: yours, not what it eases the screen to now.
    local function value()
        if V.Dynamic(def) then return V.module.db.values[def.cvar] or V.Get(def.cvar) end
        return V.Get(def.cvar)
    end
    local row
    if def.kind == "checkbox" then
        row = Kit.AddCheckRow(stack, def.label, function() return value() == 1 end,
            function(checked) V.Apply(def, checked and 1 or 0, true) end, def.tip)
        Page.AddRefresh(row.Refresh)
    else
        row = Kit.AddSliderRow(stack, def.label, def, value, function(v) V.Apply(def, v, true) end, def.tip)
        Page.AddRefresh(function() row.Refresh(not V.Conflict(def)) end)
    end
    -- The tooltip says where the value comes from, read when it shows.
    row:SetScript("OnEnter", function(self) Kit.ShowTooltip(self, def.label, tip()) end)
end

local function fillVisuals(frame)
    local V = Visuals()
    local stack = Kit.NewRowPage(frame, L.VISUALS_TITLE)
    local left, right = unpack(Kit.AddColumns(stack, 2, COLUMN_CONTROL, 24))
    Kit.AddHeaderRow(left, L.VISUALS_KEEP)
    local preset = Kit.AddDropdownRow(left, L.VISUALS_PRESET, function(root)
        for _, p in ipairs(V.PRESETS) do
            local radio = root:CreateRadio(p.label, function(key) return V.module.db.preset == key end,
                function(key) V.ApplyPreset(key) end, p.key)
            radio:SetTitleAndTextTooltip(p.label, p.tip)
        end
    end, function()
        for _, p in ipairs(V.PRESETS) do
            if p.key == V.module.db.preset then return p.label end
        end
        return L.VISUALS_PRESET_CUSTOM
    end, L.VISUALS_PRESET_TIP)
    Page.AddRefresh(preset.Refresh)
    Page.AddOptionRow(left, "protect")
    local light
    for _, section in ipairs(V.SECTIONS) do
        local column = RIGHT[section.key] and right or left
        local rows = {}
        for _, def in ipairs(V.SETTINGS) do
            if def.section == section.key and V.Has(def.cvar) then rows[#rows + 1] = def end
        end
        if #rows > 0 then
            Kit.AddHeaderRow(column, section.title)
            if section.key == "image" then
                Kit.AddTextRow(column, L.VISUALS_DAYTIME, "GameFontNormalSmall", 4)
                Kit.ShowWhen(column, Page.Enabled)
            end
            for _, def in ipairs(rows) do settingRow(column, def) end
        end
        light = light or section.light
    end
    -- Dynamic Light: a part of the page of its own, under both columns.
    if light then ns.DynamicLightPage.AddTo(stack) end
    Page.AddRefresh(function() Kit.Layout(stack) end)
    Kit.Layout(stack)
    frame:HookScript("OnShow", Page.Redraw)
    Page.Redraw()
end

---------------------------------------------------------------------------
-- The entries: under Forever Gearbox' own, and under Forever++'s with Forever++ Integration
---------------------------------------------------------------------------

local PAGE = { title = L.VISUALS_TITLE, fill = fillVisuals }
local hosts = {} -- { category (the entry), keepLast, page (ours under it), fpp } each

-- Whether our page is listed under `host` now: while the module is on, and under Forever++'s only
-- with Forever++ Integration.
local function listedUnder(host)
    if not wanted then return false end
    if host.fpp then return ns.Plugin.Integrated() end
    return true
end

-- Ours in each entry's list of pages (before its last keepLast) while listed, else out of it.
local function listPages()
    for _, host in ipairs(hosts) do
        local list = host.category:GetSubcategories()
        for i = #list, 1, -1 do
            if list[i] == host.page then table.remove(list, i) end
        end
        if listedUnder(host) then table.insert(list, math.max(1, #list - host.keepLast + 1), host.page) end
    end
end

function Page.Show(on)
    wanted = on
    listPages()
end

-- Opens the page in Settings (under Forever Gearbox' own entry) while the module is on; else the
-- module, to turn it on.
function Page.Open()
    for _, host in ipairs(hosts) do
        if not host.fpp and wanted then return Kit.Open(host.page) end
    end
    ns:OpenSettings(Visuals().module.name)
end
ns.Visuals.Redraw = Page.Redraw

-- Our page under `category`, before its last `count` pages; `fpp` for Forever++'s entry.
function Page.UseHost(category, count, fpp)
    local page = Settings.RegisterCanvasLayoutSubcategory(category, Kit.CanvasFrame(function(frame)
        ns.ChargedCall(owner, "visuals page", PAGE.fill, frame)
    end), PAGE.title)
    hosts[#hosts + 1] = { category = category, keepLast = count, page = page, fpp = fpp }
    listPages()
end

hooksecurefunc(Settings, "RegisterCanvasLayoutCategory", function(frame, name)
    if name ~= "Forever++" or type(W.categories) ~= "table" then return end
    for _, host in ipairs(hosts) do if host.fpp then return end end
    local category = W.categories[name]
    if type(category) == "table" then Page.UseHost(category, 2, true) end
end)

-- Forever++ draws its list of pages again when one of its tools turns on or off: ours put back.
SettingsPanel:HookScript("OnShow", function() ns.ChargedCall(owner, "visuals entries", listPages) end)

-- No Forever++ host: Gearbox stays standalone.
