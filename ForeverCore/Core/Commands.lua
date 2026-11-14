--[[
    Forever Core - Core/Commands.lua
    /forever and its subcommands, and each member addon's own slash (Forever Tweaks' /ft, Forever
    Compendium's /fc: Core/Members.lua), which takes the same subcommands for its own modules.
    Modules add their own with ns:AddCommand; set, toggle and options work on any module's
    options from their definitions.
]]

local _, ns = ...

local ipairs, format, strlower = ipairs, string.format, string.lower
local L = ns.L

ns.commands = {} -- in order: { name, usage, description, fn, module }

-- /forever <name> <rest>: fn(rest), one shape for every command. With `module` (the module object),
-- only while that module is on, and run as its code; without, charged to the core's commands.
function ns:AddCommand(name, usage, description, fn, module)
    assert(module == nil or getmetatable(module) == ns.Module, "AddCommand: module must be a module")
    self.commands[#self.commands + 1] = { name = name, usage = usage, description = description,
        fn = fn, module = module }
end

-- The same, for a module's own command.
function ns.Module:AddCommand(name, usage, description, fn)
    ns:AddCommand(name, usage, description, fn, self)
end

-- What the core's own commands are charged to by the Profiler (a module's are charged to it).
local commandsOwner = { name = "Commands" }

local function available(command)
    return not command.module or command.module.active
end

-- Whether `mod` is one the slash of `member` speaks for: /forever every module, a member's slash
-- its own.
local function speaksFor(member, mod)
    return member == ns.member or mod.member == member
end

local function findOption(mod, query)
    if not query or query == "" then return end
    query = strlower(query)
    for _, option in ipairs(mod.options) do
        if strlower(option.key) == query then return option end
    end
    local wanted = query:gsub("%s", "")
    for _, option in ipairs(mod.options) do
        if strlower(option.label or ""):gsub("%s", ""):find(wanted, 1, true) == 1 then return option end
    end
end

local valueText, parse = ns.Options.ValueText, ns.Options.Parse

local function listModules(member)
    for _, name in ipairs(ns.order) do
        local mod = ns.modules[name]
        if speaksFor(member, mod) then
            ns:PrintLine(format("  %s (%s): %s", mod.title, name, ns:StateText(mod.db.enabled)))
        end
    end
end

local function listOptions(mod)
    ns:Print(format(L.CMD_OPTIONS_OF, mod.title, ns:StateText(mod.db.enabled)))
    for _, option in ipairs(mod.options) do
        ns:PrintLine(format("  %s (%s): %s", option.label, option.key, valueText(option, mod.db[option.key])))
    end
end

local function help(member)
    ns.Print(member.ns, L.CMD_HELP)
    for _, command in ipairs(ns.commands) do
        if available(command) and (not command.module or speaksFor(member, command.module)) then
            ns:PrintLine(format("  |cffffd100%s %s|r %s", member.slash[1], command.usage and (command.name .. " " .. command.usage)
                or command.name, command.description))
        end
    end
end

-- Built-in subcommands.
-- Each is given the text after it and the member whose slash was typed.
ns:AddCommand("list", nil, L.CMD_LIST, function(_, member)
    ns.Print(member.ns, L.CMD_MODULES)
    listModules(member)
end)
ns:AddCommand("options", "<module>", L.CMD_OPTIONS, function(rest)
    local mod = ns:GetModule(rest)
    if not mod then return ns:Print(format(L.CMD_NO_MODULE, rest)) end
    listOptions(mod)
end)
ns:AddCommand("toggle", "<module> [option]", L.CMD_TOGGLE, function(rest)
    local query, optionQuery = rest:match("^(%S+)%s*(.-)$")
    local mod = ns:GetModule(query)
    if not mod then return ns:Print(format(L.CMD_NO_MODULE, rest)) end
    if optionQuery == "" then
        ns:SetEnabled(mod.name, not mod.db.enabled)
        return ns:Print(mod.title, ns:StateText(mod.db.enabled))
    end
    local option = findOption(mod, optionQuery)
    if not (option and option.type == "checkbox") then return ns:Print(format(L.CMD_NO_OPTION, optionQuery, mod.title)) end
    ns:SetOption(mod.name, option.key, not mod.db[option.key])
    ns:Print(format("%s: %s %s", mod.title, option.label, ns:StateText(mod.db[option.key])))
end)
ns:AddCommand("set", "<module> <option> [value]", L.CMD_SET, function(rest)
    local query, more = rest:match("^(%S+)%s*(.-)$")
    local optionQuery, value = (more or ""):match("^(%S*)%s*(.-)$")
    local mod = ns:GetModule(query)
    if not mod then return ns:Print(format(L.CMD_NO_MODULE, query or rest)) end
    local option = findOption(mod, optionQuery)
    if not option then return ns:Print(format(L.CMD_NO_OPTION, optionQuery or "", mod.title)) end
    local parsed, why = parse(option, value, mod.db[option.key])
    if parsed == nil then return ns:Print(why) end
    ns:SetOption(mod.name, option.key, parsed)
    ns:Print(format("%s: %s = %s", mod.title, option.label, valueText(option, mod.db[option.key])))
end)
ns:AddCommand("reset", nil, L.CMD_RESET, function()
    ns:Confirm(commandsOwner, "DEFAULTS", L.DEFAULTS_CONFIRM, function() ns:ResetAll() end)
end)
ns:AddCommand("settings", nil, L.CMD_SETTINGS, function(_, member) ns:OpenMember(member) end)
ns:AddCommand("help", nil, L.CMD_HELP_DESC, function(_, member) help(member) end)

-- What `member`'s slash does with `msg`.
local function onSlash(member, msg)
    msg = strtrim(msg or "")
    if msg == "" then
        if member.open then return ns.RunCall(commandsOwner, member.slash[1], member.open) end
        return ns:OpenMember(member)
    end
    local name, rest = msg:match("^(%S+)%s*(.-)$")
    name = strlower(name)
    for _, command in ipairs(ns.commands) do
        if command.name == name then
            if available(command) then
                return ns.RunCall(command.module or commandsOwner, member.slash[1] .. " " .. name, command.fn, rest, member)
            end
            local mod = command.module
            return ns.Print(member.ns, format(L.CMD_MODULE_OFF, mod.title, member.slash[1], strlower(mod.name)))
        end
    end
    -- /ft <module>: that module's page, on it ("/ft full bags").
    local mod = ns:GetModule(msg)
    if mod then return ns:OpenSettings(mod.name) end
    help(member)
end

-- Every member's slashes. Says so in chat (once, at login) when another addon already has one.
function ns:RegisterSlash()
    for _, member in ipairs(ns.members) do
        local got = {}
        local key = member.name:upper()
        local added = ns.Slash.Add(key, member.slash, function(msg) onSlash(member, msg) end)
        for _, slash in ipairs(added) do got[slash] = true end
        for _, slash in ipairs(member.slash) do
            if not got[slash] then ns.Print(member.ns, format(L.SLASH_TAKEN, slash)) end
        end
    end
end
