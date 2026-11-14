--[[
    Forever Tweaks - Part.lua
    Joins Forever Tweaks to the Forever suite (Forever Core's Core/Members.lua): loaded first, so
    every file after it reads the suite's namespace through its own.
]]

local addonName, ns = ...

ForeverCore:NewMember(addonName, ns, {
    title = "Forever Tweaks",
    short = "Tweaks",
    saved = "ForeverTweaksDB",
    charSaved = "ForeverTweaksCharDB",
    layout = 11,     -- Core/Migrations.lua has the steps up to it
    charLayout = 1,
    slash = { "/ft", "/forevertweaks" },
    -- The Modules page lists them in this order; "addons" has a page of its own (Settings/Addons.lua).
    categories = { "interface", "chat", "tooltips", "quests", "bags", "merchant", "gathering", "map", "addons" },
})

ns.bagIcon = "Interface\\AddOns\\" .. addonName .. "\\Media\\Bag"
