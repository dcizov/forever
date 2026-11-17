--[[
    Forever suite - tests/scenarios/core/lint.lua
    Source checks no game is needed for, over every file each addon's TOC loads:

      * A name a file makes local at its top (`local a, b = a, b`, `local X = ns.X`) is used in
        it: names left behind when code moved out are the commonest leftover of a split.
      * A string key (`L.KEY = ...`) is defined once in each addon (the runtime's strings
        included): every file writes to the addon's one table, so a second definition would
        silently replace the first.
      * Only the runtime's Core.lua calls issecretvalue: everywhere else asks ns.Plain, the one
        way a secret value is turned away (a file that must tell a secret value from nil says so
        on that line with "secret apart from nil").
      * Each file starts with its addon's name: a module's file then its title, any other file
        its path in the addon ("Forever Gearbox - Lib/QuestLog.lua"); the runtime's files (Shared/)
        "Forever runtime - Shared/Core/Core.lua". A file is found from its header and a moved
        file's header can't go stale unnoticed.
      * Each addon's copy of the runtime (<Addon>/Shared/) is the same as the repository's
        Shared/, file for file (Forever Gearbox' leaves the settings window, Shared/Settings/,
        out): scripts/sync-shared.sh makes them so.
    Run by tests/run.lua (lua5.1 tests/run.lua lint), which passes its helpers in.
]]

local T = ...
local check, finish, root = T.check, T.finish, T.root

local ADDONS = { "ForeverGearbox", "ForeverCodex" }
local TITLES = { ForeverGearbox = "Forever Gearbox", ForeverCodex = "Forever Codex" }

-- Every file an addon's TOC loads, as paths from the repository root.
local function filesOf(addon)
    local files = {}
    for line in io.lines(root .. "/" .. addon .. "/" .. addon .. ".toc") do
        local path = line:match("^([^#].-%.lua)%s*$")
        if path then files[#files + 1] = addon .. "/" .. path:gsub("\\", "/") end
    end
    return files
end

local function read(path)
    local f = assert(io.open(root .. "/" .. path))
    local text = f:read("*a")
    f:close()
    return text
end

-- Whether `name` appears as a whole word in `text`.
local function uses(text, name)
    return text:find("%f[%w_]" .. name:gsub("%p", "%%%0") .. "%f[^%w_]") ~= nil
end

for _, addon in ipairs(ADDONS) do
    local keys = {} -- L key -> the file that defined it first
    for _, path in ipairs(filesOf(addon)) do
        local text = read(path)
        local lines = {}
        for line in (text .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
        local inAddon = path:sub(#addon + 2)
        local runtime = inAddon:find("^Shared/") ~= nil
        local title, rest = (lines[2] or ""):match("^%s*(Forever %a+) %- (.-)%s*$")
        local want = runtime and "Forever runtime" or TITLES[addon]
        check(title == want, path .. ": header names " .. tostring(title) .. ", not " .. want)
        if not text:find("ns:NewModule(", 1, true) and not text:find("function ns:NewModule", 1, true) then
            check(rest == inAddon, path .. ": a file that isn't a module is headed with its path, not " .. tostring(rest))
        end
        if runtime then check(text == read(inAddon), path .. ": the same as the repository's " .. inAddon
            .. " (scripts/sync-shared.sh)") end
        for i, line in ipairs(lines) do
            -- A top-level local (not a function): each of its names used on another line.
            local names = line:match("^local%s+([%w_,%s]+)%s*=")
            if names then
                local others = table.concat(lines, "\n", 1, i - 1) .. "\n" .. table.concat(lines, "\n", i + 1)
                for name in names:gmatch("[%w_]+") do
                    if name ~= "_" then check(uses(others, name), path .. ":" .. i .. ": local " .. name .. " is never used") end
                end
            end
            local key = line:match("^L%.([%w_]+)%s*=")
            if key then
                check(keys[key] == nil, "L." .. key .. " defined in " .. path .. " and in " .. tostring(keys[key]))
                keys[key] = keys[key] or path
            end
            if line:find("issecretvalue", 1, true) and inAddon ~= "Shared/Core/Core.lua" then
                check(line:find("secret apart from nil", 1, true) ~= nil,
                    path .. ":" .. i .. ": issecretvalue outside ns.Plain (Shared/Core/Core.lua)")
            end
        end
    end
end
finish()
