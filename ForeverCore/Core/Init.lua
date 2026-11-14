--[[
    Forever Core - Core/Init.lua
    Loaded last of Forever Core's files. Each member addon loads after it (the game loads an
    addon's dependencies first), and its saved variables are read as the game says it has loaded;
    at login every member has, and everything starts.
]]

local _, ns = ...

local boot = { name = "Core" }

ns:On("ADDON_LOADED", boot, function(_, _, name)
    local member = ns.membersByName[name]
    if member then ns.Store.Init(member) end
end)

-- Fires on login and /reload, before PLAYER_ENTERING_WORLD. Each step runs on its own, so one
-- that fails doesn't stop the rest.
ns:On("PLAYER_LOGIN", boot, function()
    ns:Off("PLAYER_LOGIN", boot)
    ns:Off("ADDON_LOADED", boot)
    ns.Call(ns.Start, ns)
    ns.Call(ns.RegisterSettings, ns)
    ns.Call(ns.RegisterSlash, ns)
    ns:Announce("READY")
end)
