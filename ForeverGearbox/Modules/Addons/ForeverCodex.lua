--[[
    Forever Gearbox - Forever Codex Integration (module key ForeverCodex)
    Forever Gearbox works on its own. With Forever Codex installed this marks the bridge between
    them as on: off by default, offered only while Forever Codex is loaded. It keeps ownership
    clear where both addons could overlap: Codex owns map pins, OpenMap menu switches and its
    QuestieDB wrapper, while Gearbox keeps its own nameplate and minimap-button behavior.
]]

local _, ns = ...
local L = ns.L

local M = ns:NewModule("ForeverCodex", {
    title = L.FCODEX_TITLE,
    category = "addons",
    description = L.FCODEX_DESC,
    added = "3.3.0",
    addon = "ForeverCodex",
    defaults = { enabled = false },
    notice = {
        { text = L.FCODEX_OWNERS },
        { text = L.FCODEX_NO_API, shown = function() return not ns.Plugin.CodexLoaded() end },
    },
})

-- What asks Plugin.CodexIntegrated() hears ns:OnChanged(_, "ForeverCodex", "enabled") and can
-- draw again: turned on or off from the list that's said already; at login, once every module is on.
function M:OnEnable()
    self:Soon(function() ns:NotifyChanged(self.name, "enabled") end)
end