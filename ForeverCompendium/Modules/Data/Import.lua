--[[
    Forever Compendium - Bestiary Import
    Brings what Forever Bestiary (by Arxie) learned into the journal, so switching loses nothing.
    Bestiary's saved variables load only while it's enabled, so it has to be on for this (and can
    be turned off after). It reads ForeverBestiaryCharDB (this character's) and ForeverBestiaryDB
    (shared ones), and runs from the button on this page or /fc import; running it again only
    fills in what's still missing.

    Bestiary keys creatures by name; each one is matched to a creature ID from its model list
    (variants), its name index, or a creature of that name already in the journal. One with no ID
    anywhere (named only by quest text) is left out. How a creature comes in is
    ImportCreatures.lua's, quests ImportQuests.lua's.
]]

local _, ns = ...
local L = ns.L

local pairs, ipairs, type, format = pairs, ipairs, type, string.format
local Book = ns.Book
local ImportCreatures = assert(ns.ImportCreatures, "Import.lua loads after ImportCreatures.lua")
local ImportQuests = assert(ns.ImportQuests, "Import.lua loads after ImportQuests.lua")

local M = ns:NewModule("Import", {
    title = L.IMPORT_TITLE,
    category = "data",
    description = L.IMPORT_DESC,
    added = "2.3.0",
    defaults = { enabled = true },
})

local function bestiaryDBs()
    local list = {}
    if type(ForeverBestiaryCharDB) == "table" then list[#list + 1] = ForeverBestiaryCharDB end
    if type(ForeverBestiaryDB) == "table" then list[#list + 1] = ForeverBestiaryDB end
    return list
end

local function available()
    for _, db in ipairs(bestiaryDBs()) do
        if next(db.creatures or {}) or next(db.quests or {}) then return true end
    end
    return false
end

-- The creature ID for a Bestiary entry: from its models, its name index, or the journal.
local function npcOf(name, e, byName)
    local known = Book.Named(name)[1]
    if known then return known end
    for _, v in ipairs(e.variants or {}) do
        if type(v.npcID) == "number" then return v.npcID end
    end
    return byName[name]
end

---------------------------------------------------------------------------
-- Running it
---------------------------------------------------------------------------

function M.Run()
    local dbs = bestiaryDBs()
    if not available() then return M:Reply(L.IMPORT_NONE) end
    local faction = UnitFactionGroup("player")
    local creatures, added, skipped, quests = 0, 0, 0, 0
    for _, db in ipairs(dbs) do
        local byName = {}
        for npcID, name in pairs(db.npcIndex or {}) do byName[name] = byName[name] or npcID end
        for name, e in pairs(db.creatures or {}) do
            local npcID = type(e) == "table" and not e.placeholder and npcOf(name, e, byName)
            if npcID then
                creatures = creatures + 1
                if ImportCreatures.Import(npcID, name, e, faction) then added = added + 1 end
            else
                skipped = skipped + 1
            end
        end
        Book.ForgetIndex() -- the next database matches names against what this one added
        quests = quests + ImportQuests.Import(db)
    end
    Book.Merged()
    M:Reply(format(L.IMPORT_DONE, creatures, added, quests, skipped))
end

M.notice = {
    { text = L.IMPORT_READY, button = L.IMPORT_BUTTON, fn = M.Run, shown = function() return available() end },
    { text = L.IMPORT_MISSING, shown = function() return not available() end },
}

M:AddCommand("import", nil, L.CMD_IMPORT, M.Run)
