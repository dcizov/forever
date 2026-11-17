--[[
    Forever Codex - Part.lua
    The addon's member (Shared/Core/Members.lua): loaded right after the runtime it carries
    (Shared/), before its strings and modules. /codex and a click on its minimap button open the
    journal (Modules/Journal/Journal.lua).
]]

local addonName, ns = ...

ns:NewMember(addonName, ns, {
    title = "Forever Codex",
    short = "Codex",
    saved = "ForeverCodexDB",
    charSaved = "ForeverCodexCharDB",
    -- Its saved variables until 3.3.0, when it was Forever Compendium: taken over once (Store.Init).
    formerSaved = "ForeverCompendiumDB",
    formerCharSaved = "ForeverCompendiumCharDB",
    layout = 5,      -- Migrations.lua has the steps up to it
    charLayout = 1,
    slash = { "/codex", "/forevercodex" },
    categories = { "recorder", "journal", "data", "map", "tooltips", "social", "notifications" },
    open = function() ns.ToggleJournal() end,
    openLabel = "JOURNAL_TITLE", -- the locale key naming what open opens
})
