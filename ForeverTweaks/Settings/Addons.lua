--[[
    Forever Tweaks - Settings/Addons.lua
    The Tweaks for Addons page, in the sidebar under Forever (ns:AddSettingsPage): one section per installed
    addon, one under the other, the way WilduTools lays out its own Tweaks for Addons page.

      * The modules of the "addons" category, which change another addon (Dungeon Journal):
        each its own section with its on/off checkbox, notices and options (Settings/Section.lua),
        shown while its addon (module.addon) is loaded. The Modules page doesn't list them.
      * Then each addon Forever Tweaks works with (ns.OtherAddons.KNOWN), while it's loaded: a
        title like a module's and what to set in it, from the module notices that name it
        (`addon`, `advice`): which module it helps, whether it's done, and the notice's button
        where it has one.
]]

local _, ns = ...
local Kit, Section, L = ns.Kit, ns.Section, ns.L

local ipairs, format = ipairs, string.format

local DONE = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t "
local TO_DO = "|TInterface\\RaidFrame\\ReadyCheck-Waiting:14|t "
local BUTTON_WIDTH = 130

-- Every notice naming `folder`, with its module: { mod, notice } each.
local function adviceFor(folder)
    local list = {}
    for _, name in ipairs(ns.order) do
        local mod = ns.modules[name]
        for _, notice in ipairs(mod.notice or {}) do
            if notice.addon == folder and notice.advice then list[#list + 1] = { mod = mod, notice = notice } end
        end
    end
    return list
end

-- Done, to do, or off with its module (then nothing to do for it).
local function stateText(mod, notice)
    if not mod.active then return format(L.ADDONS_FOR_OFF, mod.title) end
    local todo = notice.shown and notice.shown(mod.db)
    return (todo and TO_DO or DONE) .. format(L.ADDONS_FOR, mod.title)
end

local function addAdviceRow(stack, folder, entry, refresh)
    local row = CreateFrame("Frame", nil, stack)
    row:SetWidth(stack:GetWidth())
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", 18, -2)
    text:SetWidth(stack:GetWidth() - BUTTON_WIDTH - 40)
    text:SetJustifyH("LEFT")
    text:SetText(entry.notice.advice)
    local state = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    state:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -3)
    local notice, mod = entry.notice, entry.mod
    if notice.fn then
        local button = Kit.NewButton(row, notice.button or L.SETTINGS, BUTTON_WIDTH, function()
            Section.RunNotice(mod, notice.fn, refresh)
        end)
        button:SetPoint("TOPRIGHT", -8, 0)
    end
    function row.Refresh()
        state:SetText(stateText(mod, notice))
        row:SetHeight(text:GetStringHeight() + state:GetStringHeight() + 12)
    end
    Kit.AddEntry(stack, row, function() return ns.OtherAddons.Loaded(folder) end, 2)
    return row
end

-- Each installed addon's section: what to set in it. Returns its rows (each with Refresh).
local function addOtherAddons(stack, refresh)
    local rows = {}
    for _, known in ipairs(ns.OtherAddons.KNOWN) do
        local folder, title = known[1], known[2]
        local entries = adviceFor(folder)
        if #entries > 0 then
            Section.AddTitle(stack, title, format(L.ADDONS_SETTINGS_IN, title))
            Kit.ShowWhen(stack, function() return ns.OtherAddons.Loaded(folder) end)
            for _, entry in ipairs(entries) do rows[#rows + 1] = addAdviceRow(stack, folder, entry, refresh) end
        end
    end
    return rows
end

local function buildPage(frame)
    local stack = Kit.NewRowPage(frame, L.CATEGORY_ADDONS)
    Kit.AddTextRow(stack, L.ADDONS_PAGE_INTRO, "GameFontHighlightSmall", 10)
    local refreshers, names = {}, Section.ModulesIn("addons")
    for _, name in ipairs(names) do
        Section.AddToPage(name, stack, refreshers, function() Kit.Layout(stack) end)
        local addon = ns.modules[name].addon
        if addon then Kit.ShowWhen(stack, function() return ns.OtherAddons.Loaded(addon) end) end
    end

    local adviceRows
    local function refresh()
        for _, fn in ipairs(refreshers) do fn() end
        for _, row in ipairs(adviceRows) do row.Refresh() end
        Kit.Layout(stack)
    end
    adviceRows = addOtherAddons(stack, refresh)
    refresh()
    frame:HookScript("OnShow", refresh)
    ns:OnChanged(Kit.owner, function(_, name)
        if frame:IsShown() and ns:CategoryOf(ns.modules[name] or {}) == "addons" then refresh() end
    end)
end

ns:AddSettingsPage("addons", L.CATEGORY_ADDONS, buildPage)
