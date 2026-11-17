--[[
    Forever Gearbox - Forever++ Integration (module key ForeverPlusPlus)
    Forever Gearbox works on its own. With Forever++ installed this turns on what it does with
    Forever++ (Core/Plugin.lua says what): Upgrade Arrows in Baganator by Forever++'s judgement,
    Gearbox' sections on Forever++'s Quest Nameplates, Fishing Cast and Upgrade Arrows pages (and
    Forever++'s own nameplate mark hidden where Quest Markers draws one), Advanced Graphics listed
    under Forever++ too, and buttons finding a console variable in Forever++'s Console Variables.
    Off by default; offered only while Forever++ is loaded. The pages of Forever++ follow after
    a /reload (they're made once, at login), the rest at once.
]]

local _, ns = ...
local L = ns.L

local M = ns:NewModule("ForeverPlusPlus", {
    title = L.FPP_TITLE,
    category = "addons",
    description = L.FPP_DESC,
    added = "3.3.0",
    addon = "ForeverPlusPlus",
    defaults = { enabled = false },
    notice = { { text = L.FPP_RELOAD } },
})

-- What asks Plugin.Integrated() hears ns:OnChanged(_, "ForeverPlusPlus", "enabled") and draws
-- again: turned on or off from the list that's said already; at login, once every module is on.
function M:OnEnable()
    self:Soon(function() ns:NotifyChanged(self.name, "enabled") end)
end
