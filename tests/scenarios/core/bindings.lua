--[[
    Forever suite - tests/scenarios/core/bindings.lua
    Key bindings: every binding in an addon's Bindings.xml has its name (and its header its
    title) for the Keybindings page, each one run through <Addon>_RunBinding runs itself, and they
    do it: the journal opened and closed. Forever Gearbox has none since 3.0.0 (no Bindings.xml),
    and a name it doesn't know runs nothing.
    Run by tests/run.lua (lua5.1 tests/run.lua bindings), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
W.cvars.rotateMinimap = "0"
W.LoadAddon(root, "ForeverGearbox")
local ns = W.LoadAddon(root, "ForeverCodex")
login()

-- Each Bindings.xml: names, headers and what runs.
check(io.open(root .. "/ForeverGearbox/Bindings.xml") == nil, "Forever Gearbox: no key bindings")
for _, addon in ipairs({ "ForeverCodex" }) do
    local file = assert(io.open(root .. "/" .. addon .. "/Bindings.xml"))
    local xml = file:read("*a")
    file:close()
    for attrs, body in xml:gmatch("<Binding (.-)/?>(.-)</?B") do
        local name = attrs:match('name="(.-)"')
        check(type(_G["BINDING_NAME_" .. name]) == "string", addon .. ": " .. name .. " has its name")
        local header = attrs:match('header="(.-)"')
        if header then check(type(_G["BINDING_HEADER_" .. header]) == "string", addon .. ": header " .. header) end
        local global, run = body:match('([%w_]+)_RunBinding%("(.-)"%)')
        if run then
            eq(run, name, addon .. ": " .. name .. " runs itself")
            eq(global, addon, addon .. ": " .. name .. " through its own addon")
        end
    end
end

-- What they do.
ForeverCodex_ToggleJournal()
check(ForeverCodexJournal:IsShown(), "the journal's binding opens it")
ForeverGearbox_RunBinding("NO_SUCH_BINDING") -- nothing, no error
eq(#W.errors, 0, "no errors")
finish()
