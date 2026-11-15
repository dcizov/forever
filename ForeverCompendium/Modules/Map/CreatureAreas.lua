--[[
    Forever Compendium - Creature Areas
    Where creatures live, drawn on the world map and the minimap as soft patches in a colour of
    each creature's own: every spot of the map's grid it was seen in (Lib/Places.lua),
    deeper where it was seen more. Which creatures:
      * Pinned ones (the journal's star, or right-click in its list).
      * Wanted ones: those a quest in your log has you kill, loot or speak to.
      * The one you clicked a location of in the journal (for a few minutes).
    Point at a patch for the creatures there; right-click it (world map) to open the journal on
    the first. Drawn under the quest pins. Uses Forever Core's UI/MapPins.lua.
]]

local _, ns = ...
local L = ns.L

local ipairs, pairs, format, math, GetTime = ipairs, pairs, string.format, math, GetTime
local Book, Places = ns.Book, ns.Places

local DISC = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local SPAN = 1.7 / Places.GRID -- a patch's width on the map: wider than a cell, so cells run together
local FOCUS_FOR = 300 -- seconds a creature clicked in the journal stays drawn
local COLORS = {
    { 1, 0.3, 0.3 }, { 0.3, 0.6, 1 }, { 0.3, 1, 0.4 }, { 1, 0.75, 0.2 }, { 0.8, 0.4, 1 },
    { 0.2, 0.95, 0.95 }, { 1, 0.5, 0.8 }, { 0.75, 1, 0.3 },
}

local M = ns:NewModule("CreatureAreas", {
    title = L.AREAS_TITLE,
    category = "map",
    description = L.AREAS_DESC,
    added = "2.3.0",
    defaults = { pinned = true, wanted = true, worldMap = true, minimap = true, opacity = 0.45 },
    options = {
        { key = "pinned", type = "checkbox", label = L.AREAS_PINNED, tooltip = L.AREAS_PINNED_TIP },
        { key = "wanted", type = "checkbox", label = L.AREAS_WANTED, tooltip = L.AREAS_WANTED_TIP },
        { key = "worldMap", type = "checkbox", label = L.PINS_WORLD, tooltip = L.PINS_WORLD_TIP },
        { key = "minimap", type = "checkbox", label = L.PINS_MINIMAP, tooltip = L.PINS_MINIMAP_TIP },
        { key = "opacity", type = "slider", label = L.AREAS_OPACITY, tooltip = L.AREAS_OPACITY_TIP,
          min = 0.15, max = 0.8, step = 0.05, format = "%.2f" },
    },
})

local focus -- { npc, at } the creature clicked in the journal

-- The creatures to draw now: npcID -> true.
local function shownCreatures()
    local db, list = M.db, {}
    local log = db.wanted and Book.LogQuests()
    for npcID, rec in pairs(Book.Creatures()) do
        if (db.pinned and rec.pinned) or (log and Book.WantedBy(rec, log)) then list[npcID] = true end
    end
    if focus and GetTime() - focus.at < FOCUS_FOR then list[focus.npc] = true end
    return list
end

local function colorOf(npcID)
    local c = COLORS[npcID % #COLORS + 1]
    return c[1], c[2], c[3]
end

-- The patches on `mapID`: one per creature and cell, and which creatures share each cell.
local function specsOn(mapID)
    local specs, byCell = {}, {}
    local opacity = M.db.opacity
    for npcID in pairs(shownCreatures()) do
        local rec = Book.Creature(npcID)
        local zone = rec and rec.zones and rec.zones[mapID]
        if zone then
            local most = 1
            for _, n in pairs(zone.cells) do most = math.max(most, n) end
            local r, g, b = colorOf(npcID)
            for cell, n in pairs(zone.cells) do
                local x, y = Places.CellCenter(cell)
                local here = byCell[cell] or {}
                byCell[cell] = here
                here[#here + 1] = npcID
                specs[#specs + 1] = { x = x, y = y, texture = DISC, span = SPAN, npc = npcID, cell = cell, here = here,
                    color = { r, g, b, opacity * (0.55 + 0.45 * n / most) } }
            end
        end
    end
    return specs
end

local function tooltip(owner, pin)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    for _, npcID in ipairs(pin.here) do
        local rec = Book.Creature(npcID)
        local r, g, b = colorOf(npcID)
        GameTooltip:AddLine(rec.name, r, g, b)
        GameTooltip:AddLine(ns.JournalText.Kind(rec), 1, 1, 1)
    end
    if owner:GetObjectType() == "Button" then GameTooltip:AddLine(L.AREAS_HINT, 0.1, 1, 0.1) end
    GameTooltip:Show()
end

local pins = ns.MapPins.Both(M, {
    specs = specsOn,
    tooltip = tooltip,
    click = function(_, spec) ns.ShowCreature(spec.npc) end,
    world = { shown = function() return M.db.worldMap end, size = function() return 16 end },
    minimap = { shown = function() return M.db.minimap end, size = function() return 16 end },
})


local refresh = pins.Refresh

local function refreshSoon() M:Soon(refresh) end

-- Shows a creature's area for a while (the journal's location lines call this before opening the map).
function ns.FocusCreature(npcID)
    focus = { npc = npcID, at = GetTime() }
    if M.active then refresh() end
end

M:OnNews(function(_, event)
    if event == "CREATURE_PINNED" or event == "BOOK_MERGED" or event == "QUEST_PLACE" then refreshSoon() end
end)

function M:OnEnable()
    for _, event in ipairs({ "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN" }) do self:RegisterEvent(event, refreshSoon) end
end

function M:DebugLine()
    return format(L.AREAS_DEBUG, Book.Count(shownCreatures()))
end
