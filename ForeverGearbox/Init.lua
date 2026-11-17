--[[
    Forever Gearbox - Init.lua
    Loaded last: the saved variables are read as the game says the addon has loaded (with what
    was kept for Forever++ taken in: Core/Plugin.lua), and at login the modules start, as Forever
    Codex's do, its page in Settings > AddOns is made (Settings/Alone.lua) and the slash
    commands come. Forever++ is touched only through Forever++ Integration.
]]

local addonName, ns = ...

local boot = { name = "Core" }

ns:On("ADDON_LOADED", boot, function(_, _, name)
    if name ~= addonName then return end
    ns:Off("ADDON_LOADED", boot)
    ns.SafeCall(ns.Store.Init, ns.member)
    ns.SafeCall(ns.Plugin.SettleAlone, ns.member.db)
    -- Once (Migrations.lua step 20): what Forever++ kept for us while we were its plugin.
    if ns.member.db.takeOverFpp then
        ns.member.db.takeOverFpp = nil
        ns.SafeCall(ns.Plugin.TakeOver)
    end
end)

ns:On("PLAYER_LOGIN", boot, function()
    ns:Off("PLAYER_LOGIN", boot)
    ns.SafeCall(ns.Start, ns)
    ns.SafeCall(ns.RegisterSettings, ns)
    ns.SafeCall(ns.RegisterSlash, ns)
    ns:Announce("READY")
end)
