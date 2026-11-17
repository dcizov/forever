--[[
    Forever Codex - OpenMap (module key OpenMap)
    Forever Codex with OpenMap (MIT), the way OpenMap works with Questie, through OpenMap's own
    API for other addons (OpenMapAPI, its docs/api.md; nothing of its is changed):

      * Townsfolk and rare mobs: OpenMap draws them from Questie's NPC database. Without Questie,
        QuestieDB (the same database, Shared/Lib/QuestieDB.lua) is handed to it in Questie's shape
        (RegisterTownsfolkProvider: every NPC, its flags, and its fields copied as it asks), so
        its Townsfolk work with QuestieDB alone. With Questie loaded, OpenMap reads Questie's own.
      * Codex's map layers in OpenMap's menu: Quest Pins, Rare Pins and Creature Areas as
        switches there (RegisterMenuToggle), as OpenMap shows Questie's icons there.
      * A dungeon's map card (RegisterDungeonSection): the creatures you've met in it (Lib/Book.lua,
        what you saw yourself), most killed first.
    The pins themselves follow OpenMap's stitched map in UI/MapPins.lua (every zone in view).
    OpenMap's calls are protected: an error of its is logged, never stops ours. Only while OpenMap
    is loaded (locked off without it).
]]

local addonName, ns = ...
local L = ns.L

local ipairs, pairs, format, pcall, type, tostring, sort = ipairs, pairs, string.format, pcall, type, tostring, table.sort
local Book, QuestieDB = ns.Book, ns.QuestieDB

local OWNER = addonName -- our name to OpenMap
local LAYERS = { "QuestPins", "RarePins", "CreatureAreas" } -- Codex's map layers, as switches in its menu
local MOST_LINES = 40 -- OpenMap shows at most this many lines on a card

local M = ns:NewModule("OpenMap", {
    title = L.OPENMAP_TITLE,
    category = "map",
    description = L.OPENMAP_DESC,
    added = "3.3.0",
    defaults = { townsfolk = true, menu = true, dungeons = true },
    options = {
        { key = "townsfolk", type = "checkbox", label = L.OPENMAP_TOWNSFOLK, tooltip = L.OPENMAP_TOWNSFOLK_TIP },
        { key = "menu", type = "checkbox", label = L.OPENMAP_MENU, tooltip = L.OPENMAP_MENU_TIP },
        { key = "dungeons", type = "checkbox", label = L.OPENMAP_DUNGEONS, tooltip = L.OPENMAP_DUNGEONS_TIP },
    },
})

if not C_AddOns.IsAddOnLoaded("OpenMap") then
    M.locked, M.lockedText = true, L.OPENMAP_LOCKED
    M.notice = { { text = L.OPENMAP_NEEDED } }
end

local function api()
    local open = _G.OpenMapAPI
    return type(open) == "table" and open or nil
end

-- Calls OpenMap's `name`(...) protected, logging an error of its.
local function call(name, ...)
    local open = api()
    local fn = open and open[name]
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if not ok then M:Debug("OpenMap " .. name .. ":", tostring(err)) end
end

---------------------------------------------------------------------------
-- Townsfolk: QuestieDB in Questie's shape
---------------------------------------------------------------------------

local provider -- what OpenMap was given, once made

local function makeProvider()
    local npcs = {}
    for _, npcID in ipairs(QuestieDB.Ids("Npc")) do npcs[npcID] = true end
    return {
        db = {
            NPCPointers = npcs,
            npcFlags = QuestieDB.NpcFlags(),
            QueryNPCSingle = function(npcID, field) return QuestieDB.Field(M, "Npc", npcID, field) end,
            QueryObjectSingle = function(objectID, field) return QuestieDB.Field(M, "Object", objectID, field) end,
        },
        zones = { GetUiMapIdByAreaId = function(_, areaID) return QuestieDB.UiMapID(areaID) end },
    }
end

-- Questie has its own (OpenMap reads it then): ours only without it.
local function wantTownsfolk()
    return M.active and M.db.townsfolk and not C_AddOns.IsAddOnLoaded("Questie")
end

local function applyTownsfolk()
    if not wantTownsfolk() then
        if provider then call("RegisterTownsfolkProvider", OWNER, nil) end
        provider = nil
        return
    end
    QuestieDB.OnReady(M, function()
        if not wantTownsfolk() or provider then return end
        provider = makeProvider()
        call("RegisterTownsfolkProvider", OWNER, provider)
    end)
end

---------------------------------------------------------------------------
-- Codex's layers in OpenMap's menu
---------------------------------------------------------------------------

local toggled = false -- registered once: OpenMap's menu has no way to take one off

local function applyMenu()
    if toggled or not (M.active and M.db.menu) then return end
    toggled = true
    for _, name in ipairs(LAYERS) do
        local layer = ns.modules[name]
        if layer then
            call("RegisterMenuToggle", OWNER, {
                id = name, label = layer.title, section = L.OPENMAP_SECTION,
                icon = "Interface\\AddOns\\" .. addonName .. "\\Media\\Icon",
                -- Off with this module or its Menu option: the switch shows the layer off and does nothing.
                get = function() return M.active and M.db.menu and layer.db.enabled and true or false end,
                set = function(on)
                    if M.active and M.db.menu then ns:SetEnabled(name, on) end
                end,
            })
        end
    end
end

---------------------------------------------------------------------------
-- A dungeon's map card: the creatures you've met in it
---------------------------------------------------------------------------

local function dungeonSection(info)
    if not (M.active and M.db.dungeons and type(info) == "table" and type(info.mapID) == "number") then return nil end
    local met = {}
    for _, rec in pairs(Book.Creatures()) do
        if rec.zones and rec.zones[info.mapID] then met[#met + 1] = rec end
    end
    if #met == 0 then return nil end
    sort(met, function(a, b)
        if (a.kills or 0) ~= (b.kills or 0) then return (a.kills or 0) > (b.kills or 0) end
        return (a.name or "") < (b.name or "")
    end)
    local lines = {}
    for i = 1, math.min(#met, MOST_LINES) do
        local rec = met[i]
        lines[i] = format(L.OPENMAP_DUNGEON_LINE, rec.name or "?", rec.kills or 0)
    end
    return L.OPENMAP_DUNGEON_TITLE, lines
end

---------------------------------------------------------------------------
-- On and off
---------------------------------------------------------------------------

local function applyAll()
    applyTownsfolk()
    applyMenu()
    call("RegisterDungeonSection", OWNER, M.active and M.db.dungeons and dungeonSection or nil)
end

function M:OnEnable()
    if self.locked or not api() then return end
    applyAll()
end

function M:OnDisable()
    if not api() then return end
    applyAll()
end

function M:OnSettingChanged()
    if api() then applyAll() end
end
