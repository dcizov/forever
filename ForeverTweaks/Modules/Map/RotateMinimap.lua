--[[
    Forever Tweaks - Rotate Minimap
    Turns the minimap with you, so up is the way you face: the game's own rotateMinimap console
    variable, which Forever's Options have no setting for and which the game resets at login, so
    it's set again on every loading screen. Turning the module off puts back what the variable
    was before (Lib/CVars.lua). Map pins (Forever Core's UI/MapPins.lua) follow it by themselves, and so does
    Forever's minimap (docs/forever-api.md).
]]

local _, ns = ...
local L = ns.L

local CVars = ns.CVars

local CVAR = "rotateMinimap"

local M = ns:NewModule("RotateMinimap", {
    title = L.ROTATE_TITLE,
    category = "map",
    description = L.ROTATE_DESC,
    added = "2.6.0",
    defaults = { enabled = false, saved = {} },
})

local function apply() CVars.Set(M.db.saved, CVAR, "1") end

-- Its key binding turns it on or off (Bindings.xml, Forever Core's Core/Bindings.lua).
ns:AddBinding(nil, "FOREVERTWEAKS_ROTATE", function() ns:SetEnabled(M.name, not M.active) end)

function M:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", apply)
    apply()
end

function M:OnDisable() CVars.Restore(self.db.saved) end
