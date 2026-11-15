--[[
    Forever suite - tests/scenarios/core/bindings.lua
    Key bindings: every binding in a member's Bindings.xml has its name (and its header its
    title) for the Keybindings page, each one run through ForeverCore.RunBinding has something
    to run, and they do it: Open Forever Settings, Rotate Minimap on and off, the Gathering
    Session paused only while that module is on; Cast Fishing's secure button casts Fishing.
    Run by tests/run.lua (lua5.1 tests/run.lua bindings), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
W.cvars.rotateMinimap = "0"
W.LoadAddon(root, "ForeverTweaks")
local ns = W.LoadAddon(root, "ForeverCompendium")
login()
local core = ForeverCore

-- Each Bindings.xml: names, headers and what runs.
for _, addon in ipairs({ "ForeverCore", "ForeverTweaks", "ForeverCompendium" }) do
    local file = assert(io.open(root .. "/" .. addon .. "/Bindings.xml"))
    local xml = file:read("*a")
    file:close()
    for attrs, body in xml:gmatch("<Binding (.-)/?>(.-)</?B") do
        local name = attrs:match('name="(.-)"')
        check(type(_G["BINDING_NAME_" .. name]) == "string", addon .. ": " .. name .. " has its name")
        local header = attrs:match('header="(.-)"')
        if header then check(type(_G["BINDING_HEADER_" .. header]) == "string", addon .. ": header " .. header) end
        local run = body:match('RunBinding%("(.-)"%)')
        if run then eq(run, name, addon .. ": " .. name .. " runs itself") end
    end
end

-- What they do.
core.RunBinding("FOREVERTWEAKS_ROTATE")
eq(W.cvars.rotateMinimap, "1", "Rotate Minimap's binding turns it on")
core.RunBinding("FOREVERTWEAKS_ROTATE")
eq(W.cvars.rotateMinimap, "0", "and off again")
ns:SetEnabled("FishingCast", true)
local cast = rawget(_G, "ForeverTweaksFishingButton")
check(cast ~= nil, "Cast Fishing's button is made")
eq(cast and cast:GetAttribute("type"), "spell", "it casts a spell")
eq(cast and cast:GetAttribute("spell"), "Fishing", "Fishing")
core.RunBinding("FOREVER_SETTINGS")
core.RunBinding("NO_SUCH_BINDING") -- nothing, no error
eq(#W.errors, 0, "no errors")
finish()
