--[[
    Forever Codex - Rare Pins
    The rare creatures you've met (Lib/Book.lua: a rare or rare elite), at the spot
    on each map where you saw them most, on the world map and the minimap (UI/MapPins.lua).
    Point at one for what it is and when you last saw it; right-click it on the
    world map to open the journal on it. Drawn again when the Recorder meets a new creature.
]]

local _, ns = ...
local L = ns.L

local pairs, format, date = pairs, string.format, date
local Book, Places = ns.Book, ns.Places

local RARE = { rare = true, rareelite = true }

local M = ns:NewModule("RarePins", {
    title = L.RPINS_TITLE,
    category = "map",
    description = L.RPINS_DESC,
    added = "2.1.0",
    defaults = { worldMap = true, size = 20, minimap = true, minimapSize = 14 },
    options = {
        { key = "worldMap", type = "checkbox", label = L.PINS_WORLD, tooltip = L.PINS_WORLD_TIP, slider = "size" },
        { key = "size", type = "slider", label = L.PINS_SIZE, min = 12, max = 32, step = 2, format = "%d px",
          requires = "worldMap", tooltip = L.PINS_SIZE_TIP },
        { key = "minimap", type = "checkbox", label = L.PINS_MINIMAP, tooltip = L.PINS_MINIMAP_TIP, slider = "minimapSize" },
        { key = "minimapSize", type = "slider", label = L.PINS_SIZE, min = 8, max = 24, step = 1, format = "%d px",
          requires = "minimap", tooltip = L.PINS_SIZE_TIP },
    },
})

-- The cell of `zone` (Places) seen in most.
local function busiestCell(zone)
    local best, most
    for cell, n in pairs(zone.cells) do
        if not most or n > most then best, most = cell, n end
    end
    return best
end

local function pinsOn(mapID)
    local pins = {}
    for npc, rec in pairs(Book.Creatures()) do
        local zone = RARE[rec.classification] and rec.zones[mapID]
        local cell = zone and busiestCell(zone)
        if cell then
            local x, y = Places.CellCenter(cell)
            pins[#pins + 1] = { x = x, y = y, atlas = "VignetteKill", npc = npc }
        end
    end
    return pins
end

local function tooltip(owner, pin)
    local rec = Book.Creature(pin.npc)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(rec.name, 1, 0.82, 0)
    GameTooltip:AddLine(rec.maxLevel and format(L.RPINS_LEVEL, rec.maxLevel) or L.RPINS_RARE, 1, 1, 1)
    GameTooltip:AddLine(format(L.RPINS_SEEN, date("%b %d", rec.last), rec.kills or 0), 0.7, 0.7, 0.7)
    GameTooltip:AddLine(L.RPINS_HINT, 0.1, 1, 0.1)
    GameTooltip:Show()
end

local pins = ns.MapPins.Both(M, {
    specs = pinsOn,
    tooltip = tooltip,
    click = function(_, pin) ns.ShowCreature(pin.npc) end,
    world = { shown = function() return M.db.worldMap end, size = function() return M.db.size end, level = 10 },
    minimap = { shown = function() return M.db.minimap end, size = function() return M.db.minimapSize end, level = 1 },
})


local refresh = pins.Refresh

M:OnNews(function(_, event)
    if event == "CREATURE_NEW" or event == "BOOK_MERGED" then M:Soon(refresh) end
end)
