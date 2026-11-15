--[[
    Forever Tweaks - Lib/CVars.lua
    Console variables a module sets while it's on and gives back when it's off (Rotate Minimap,
    Loot Sparkle): the player's own value is kept in the module's data (a table default, so it
    outlives a reload) the first time the module sets it, and put back only if the variable still
    holds the module's value: one the player changed since is theirs to keep (OneCast's lease idea,
    our own code).
]]

local _, ns = ...

local pairs = pairs

local CVars = {}
ns.CVars = CVars

-- Sets `cvar` to `value`, keeping the player's own value in `saved` the first time.
function CVars.Set(saved, cvar, value)
    local now = C_CVar.GetCVar(cvar)
    if saved[cvar] == nil then saved[cvar] = { own = now or "", set = value } end
    saved[cvar].set = value
    if now ~= value then C_CVar.SetCVar(cvar, value) end
end

-- Puts back every value kept in `saved` that's still the module's, and forgets them all.
function CVars.Restore(saved)
    for cvar, lease in pairs(saved) do
        if C_CVar.GetCVar(cvar) == lease.set and lease.own ~= "" then C_CVar.SetCVar(cvar, lease.own) end
        saved[cvar] = nil
    end
end
