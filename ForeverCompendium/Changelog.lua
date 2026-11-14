--[[
    Forever Compendium - Changelog.lua
    Forever Compendium's releases from before the Forever suite (up to 0.3.0), newest first.
    New releases go in Forever Core's Changelog.lua.

    Each change: { module = "ModuleName" (or a title for a removed module), kind = "Added" |
    "Changed" | "Fixed" | "Removed", text = "..." }. Without a module it goes under General.
]]

local _, ns = ...

ns.changelog = {
    {
        version = "0.3.0",
        date = "2026-11-13",
        changes = {
            { module = "Journal", kind = "Added", text = "The journal window (/fc or the minimap button): every creature you've met, searchable and sorted, with its model, level and kind, where you saw it, its loot with drop rates, and its quests." },
            { module = "Recorder", kind = "Added", text = "Remembers each creature's model when you target or mouse over it, for the journal." },
        },
    },
    {
        version = "0.2.0",
        date = "2026-11-13",
        changes = {
            { module = "Recorder", kind = "Added", text = "Learns as you play: each creature you meet (level, kind, where you saw it, kills), what its corpses held, and where quests are given, turned in and done." },
        },
    },
    {
        version = "0.1.0",
        date = "2026-11-13",
        changes = {
            { kind = "Added", text = "First version: the settings pages, /fc, and a minimap button." },
            { module = "MinimapButton", kind = "Added", text = "A button on the minimap, in the addon menu, or both." },
        },
    },
}
