--[[
    Forever Gearbox - Part.lua
    The addon's member (Shared/Core/Members.lua): loaded right after the runtime it carries
    (Shared/), before its strings and modules. Its modules are Forever++'s too: Core/Plugin.lua.
]]

local addonName, ns = ...

ns:NewMember(addonName, ns, {
    title = "Forever Gearbox",
    short = "Gearbox",
    saved = "ForeverGearboxDB",
    charSaved = "ForeverGearboxCharDB",
    -- Its saved variables until 3.3.0, when it was Forever Tweaks: taken over once (Store.Init).
    formerSaved = "ForeverTweaksDB",
    formerCharSaved = "ForeverTweaksCharDB",
    layout = 21,     -- Migrations.lua has the steps up to it
    charLayout = 2,
    slash = { "/fg", "/gearbox", "/forevergearbox" },
    -- Forever++'s Modules page groups them its own way (Core/Plugin.lua: CATEGORY).
    categories = { "interface", "chat", "quests", "bags", "merchant", "gathering", "map", "addons" },
})

ns.bagIcon = "Interface\\AddOns\\" .. addonName .. "\\Media\\Bag"
