--[[
    Forever runtime - Shared/Settings/General.lua
    The Settings page, at the top of Settings > AddOns > Forever: the suite's own settings, not a
    module's.

      * The modules of the "settings" category (Minimap Button, Update Notice; no category page
        lists them): their sections, drawn from their options like any module's (Shared/Settings/Section.lua).
      * Chat: Mute All Chat Messages (ns.db.quiet: what modules say by themselves, Module:Print;
        replies to slash commands still print) and Show Log in Chat (ns.db.debug).
      * Reset All Modules, after asking.
      * Every slash command (ns.commands).
]]

local _, ns = ...
local Kit, Section, L = ns.Kit, ns.Section, ns.L

local ipairs, format = ipairs, string.format

local function addCommands(stack)
    Kit.AddHeaderRow(stack, L.COMMANDS)
    local commands = {}
    for _, member in ipairs(ns.members) do
        commands[#commands + 1] = { table.concat(member.slash, ", "),
            member == ns.member and L.CMD_OPEN or format(L.CMD_OPEN_MEMBER, member.title) }
    end
    -- Every command is the addon's own slash with a word after it (/<slash> <module>).
    local slash = ns.member.slash[1]
    local example = ns.modules[ns.order[1]]
    if example then
        commands[#commands + 1] = { slash .. " <module>", format(L.CMD_MODULE, slash, strlower(example.title or example.name)) }
    end
    for _, command in ipairs(ns.commands) do
        commands[#commands + 1] = { slash .. " " .. command.name .. (command.usage and (" " .. command.usage) or ""),
            command.description }
    end
    for _, command in ipairs(commands) do
        local row = CreateFrame("Frame", nil, stack)
        row:SetSize(stack:GetWidth(), 18)
        local left = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        left:SetPoint("LEFT", 4, 0)
        left:SetText(command[1])
        local right = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        right:SetPoint("LEFT", 260, 0)
        right:SetPoint("RIGHT", -8, 0)
        right:SetJustifyH("LEFT")
        right:SetText(command[2])
        Kit.AddEntry(stack, row, nil, 2)
    end
end

function ns.BuildGeneralPage(frame)
    local stack = Kit.NewRowPage(frame, L.SETTINGS)
    local refreshers = {}

    for _, name in ipairs(Section.ModulesIn("settings")) do
        Section.AddToPage(name, stack, refreshers, function() Kit.Layout(stack) end)
    end

    Kit.AddHeaderRow(stack, L.SECTION_CHAT)
    local quiet = Kit.AddCheckRow(stack, L.GENERAL_QUIET, function() return ns.db.quiet end,
        function(checked) ns.db.quiet = checked or nil end, L.GENERAL_QUIET_TIP)
    refreshers[#refreshers + 1] = quiet.Refresh
    local log = Kit.AddCheckRow(stack, L.DEBUG_LOG_CHAT, function() return ns.db.debug end,
        function(checked) ns.db.debug = checked or nil end, L.DEBUG_LOG_CHAT_TIP)
    refreshers[#refreshers + 1] = log.Refresh

    Kit.AddHeaderRow(stack, L.GENERAL_SECTION_RESET)
    Kit.AddButtonRow(stack, L.GENERAL_RESET, SETTINGS_DEFAULTS, function()
        ns:Confirm(Kit.owner, "DEFAULTS", L.DEFAULTS_CONFIRM, function() ns:ResetAll() end)
    end, L.GENERAL_RESET_TIP)

    addCommands(stack)

    local function refresh()
        for _, fn in ipairs(refreshers) do fn() end
        Kit.Layout(stack)
    end
    refresh()
    Kit.Layout(stack)
    frame:HookScript("OnShow", refresh)
    ns:OnChanged(Kit.owner, function(_, name)
        if frame:IsShown() and ns:CategoryOf(ns.modules[name] or {}) == "settings" then refresh() end
    end)
end
