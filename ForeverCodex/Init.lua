--[[
    Forever Codex - Init.lua
    Loaded last: the saved variables are read as the game says the addon has loaded, and at login
    everything starts.
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
    ns.SafeCall(ns.Start, ns)
    -- The settings window in the journal's look: the spellbook's parchment, its words in the
    -- parchment's ink, fading while you move, the journal's sounds.
    ns.SettingsWindow.SetLook({ Page = ns.JournalKit.Page, Ink = ns.JournalKit.InkTree,
        Fade = ns.Journal.FadeWhileMoving, Sound = ns.Sound })
    ns.SafeCall(ns.RegisterSettings, ns)
    ns.SafeCall(ns.RegisterSlash, ns)
    ns:Announce("READY")
end)
