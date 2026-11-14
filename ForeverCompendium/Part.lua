--[[
    Forever Compendium - Part.lua
    Joins Forever Compendium to the Forever suite (Forever Core's Core/Members.lua): loaded first,
    so every file after it reads the suite's namespace through its own. /fc and a click on the
    suite's minimap button open the journal (Modules/Journal/Journal.lua).
]]

local addonName, ns = ...

ForeverCore:NewMember(addonName, ns, {
    title = "Forever Compendium",
    short = "Compendium",
    saved = "ForeverCompendiumDB",
    charSaved = "ForeverCompendiumCharDB",
    layout = 2,      -- Migrations.lua has the steps up to it
    charLayout = 1,
    slash = { "/fc", "/forevercompendium" },
    categories = { "journal", "map", "tooltips", "social", "notifications" },
    open = function() ns.ToggleJournal() end,
    openLabel = "JOURNAL_TITLE", -- the locale key naming what open opens
})
