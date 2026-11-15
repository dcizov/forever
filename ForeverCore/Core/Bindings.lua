--[[
    Forever Core - Core/Bindings.lua
    Key bindings (Settings > Keybindings > AddOns > Forever ...). Each member's Bindings.xml runs
    ForeverCore.RunBinding("<NAME>") for its bindings, so no member needs a global of its own;
    the module that does it says what with ns:AddBinding(owner, name, fn), and it runs (charged
    to the owner, isolated) only while that module is on. Without an owner it always runs (a
    binding that turns a module on or off). A binding that must cast or use something is a
    CLICK binding on a secure button instead, which never comes through here (Fishing Cast's).
]]

local _, ns = ...

local bindings = {} -- name -> { owner, fn }

function ns:AddBinding(owner, name, fn)
    bindings[name] = { owner, fn }
end

function ns.RunBinding(name)
    local binding = bindings[name]
    if not binding then return end
    local owner = binding[1]
    if owner and not owner.active then return end
    ns.ChargedCall(owner or ns, "binding " .. name, binding[2])
end
