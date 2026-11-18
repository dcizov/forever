--[[
        Forever Gearbox - Modules/Interface/VisualsPage.lua
        Advanced Graphics' page (Visuals.lua), its own entry under Forever++ in Settings while the
        module is on, as Forever++'s Console Variables page is. Rows as the suite's other Settings
        pages (Kit.NewRowPage: a gold label left and Blizzard's control right):
            * The graphics settings in one column, in this order: Look (Preset: Visuals.PRESETS,
                "Custom" once a value is changed by hand; Protect Values), Image (with a line while
                Dynamic Light sets Brightness, Contrast and Gamma), World Detail, Lighting & Atmosphere,
                then Camera & Interaction. A row per setting this client has (a slider or a checkbox);
                one another addon makes its own (Visuals.Conflict) is greyed and its tooltip says why.
            * Dynamic Light (and Sky) on its own sibling page under the same host entry
                (DynamicLightPage.lua), listed just after Advanced Graphics.
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

local ipairs, format, math = ipairs, string.format, math

local Page = {}
ns.VisualsPage = Page

local owner = { name = "Visuals page" } -- what this file's work is charged to
local ROW_CONTROL = 200  -- where a full-width row's control starts (Kit's PAGE_CONTROL)
local MAX_WIDTH = 620    -- content width cap: keeps labels and sliders readable on wider panels
-- The settings page's own order (Visuals.SECTIONS keeps data order for module wiring).
local ORDER = { "image", "world", "new", "view" }

local wanted -- whether ours is listed (the module is on)
local refreshers = {}

local function Visuals() return ns.Visuals end

local function sectionByKey(key)
    for _, section in ipairs(Visuals().SECTIONS) do
        if section.key == key then return section end
    end
end

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
    stack:SetWidth(math.min(stack:GetWidth(), MAX_WIDTH))
    Kit.AddHeaderRow(stack, L.VISUALS_KEEP)
    local preset = Kit.AddDropdownRow(stack, L.VISUALS_PRESET, function(root)
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
    Page.AddOptionRow(stack, "protect")
    Kit.AddHeaderRow(stack, L.VISUALS_DYNAMIC)
    Page.AddOptionRow(stack, "dynamic")
    Page.AddOptionRow(stack, "dynamicStrength", Page.Enabled)
    local _, open = Kit.AddButtonRow(stack, L.VISUALS_DYNAMIC_PAGE, L.VISUALS_OPEN_BUTTON, function()
        Page.OpenDynamicLight()
    end, L.VISUALS_DYNAMIC_PAGE_TIP)
    Page.AddRefresh(function()
        open:SetEnabled(Page.Enabled())
        open:SetAlpha(Page.Enabled() and 1 or 0.5)
    end)
    local note = Kit.AddTextRow(stack, "", "GameFontDisableSmall", 4)
    Page.AddRefresh(function()
        note:SetText(Page.Enabled() and L.VISUALS_DYNAMIC_NOTE_ON or L.VISUALS_DYNAMIC_NOTE_OFF)
    end)
    for _, key in ipairs(ORDER) do
        local section = sectionByKey(key)
        local rows = {}
        for _, def in ipairs(V.SETTINGS) do
            if def.section == section.key and V.Has(def.cvar) then rows[#rows + 1] = def end
        end
        if #rows > 0 then
            Kit.AddHeaderRow(stack, section.title)
            if section.key == "image" then
                Kit.AddTextRow(stack, L.VISUALS_DAYTIME, "GameFontNormalSmall", 4)
                Kit.ShowWhen(stack, Page.Enabled)
            end
            for _, def in ipairs(rows) do settingRow(stack, def) end
            if section.key == "image" then
                Kit.AddTextRow(stack, L.VISUALS_SHARPEN_MONITOR_NOTICE, "GameFontDisableSmall", 4)
            end
        end
    end
    Page.AddRefresh(function() Kit.Layout(stack) end)
    Kit.Layout(stack)
    frame:HookScript("OnShow", Page.Redraw)
    Page.Redraw()
end

---------------------------------------------------------------------------
-- The entries: under Forever Gearbox' own, and under Forever++'s with Forever++ Integration
---------------------------------------------------------------------------

local PAGE = { title = L.VISUALS_TITLE, fill = fillVisuals }
local hosts = {} -- { category, keepLast, visualsPage, dynamicPage, fpp } each

-- Whether one of our pages is listed under `host` now:
--   * parent while Advanced Graphics is on,
--   * child while Advanced Graphics and Dynamic Light are both on,
-- and for Forever++'s host only while Forever++ Integration is on.
local function listedUnder(host, child)
    if not wanted then return false end
    if host.fpp and not ns.Plugin.Integrated() then return false end
    if child then return Page.Enabled() end
    return true
end

-- Writes the whole list from what should be in it, preserving this host's own pages in place:
-- everything before its keepLast tail, our pages (if listed), then that tail as it is now.
local function listPages()
    for _, host in ipairs(hosts) do
        local list = host.category.GetSubcategories and host.category:GetSubcategories()
        if list then
            local base = {}
            for _, page in ipairs(list) do
                if page ~= host.visualsPage and page ~= host.dynamicPage then
                    base[#base + 1] = page
                end
            end
            local tailCount = math.min(host.keepLast or 0, #base)
            local keep = #base - tailCount
            local want = {}
            for i = 1, keep do want[#want + 1] = base[i] end
            if listedUnder(host, false) then want[#want + 1] = host.visualsPage end
            if listedUnder(host, true) then want[#want + 1] = host.dynamicPage end
            for i = keep + 1, #base do want[#want + 1] = base[i] end

            local same = #list == #want
            for i = 1, #want do
                same = same and list[i] == want[i]
            end
            if not same then
                for i = #list, 1, -1 do list[i] = nil end
                for i, page in ipairs(want) do list[i] = page end
            end
        end
    end
end

Page.UpdateEntries = listPages

function Page.Show(on)
    wanted = on
    listPages()
end

-- Opens the page in Settings (under Forever Gearbox' own entry) while the module is on; else the
-- module, to turn it on.
function Page.Open()
    for _, host in ipairs(hosts) do
        if not host.fpp and listedUnder(host, false) then return Kit.Open(host.visualsPage) end
    end
    ns:OpenSettings(Visuals().module.name)
end

function Page.OpenDynamicLight()
    for _, host in ipairs(hosts) do
        if not host.fpp and listedUnder(host, true) and host.dynamicPage then return Kit.Open(host.dynamicPage) end
    end
    if wanted then return Page.Open() end
    ns:OpenSettings(Visuals().module.name)
end
ns.Visuals.Redraw = Page.Redraw

-- Our page under `category`, before its last `count` pages; `fpp` for Forever++'s entry.
function Page.UseHost(category, count, fpp)
    local visualsPage = Settings.RegisterCanvasLayoutSubcategory(category, Kit.CanvasFrame(function(frame)
        ns.ChargedCall(owner, "visuals page", PAGE.fill, frame)
    end), PAGE.title)
    local dynamicPage = Settings.RegisterCanvasLayoutSubcategory(category, Kit.CanvasFrame(function(frame)
        ns.ChargedCall(owner, "dynamic light page", ns.DynamicLightPage.Fill, frame)
    end), L.DLIGHT_TITLE)
    hosts[#hosts + 1] = {
        category = category,
        keepLast = count,
        visualsPage = visualsPage,
        dynamicPage = dynamicPage,
        fpp = fpp,
    }
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

-- Forever++ Integration turned on or off: both hosts' lists rebuilt from the same predicate.
ns:OnChanged(owner, function(_, name, key)
    if name == "ForeverPlusPlus" and key == "enabled" then listPages() end
end)

-- No Forever++ host: Gearbox stays standalone.
