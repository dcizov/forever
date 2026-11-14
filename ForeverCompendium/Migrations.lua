--[[
    Forever Compendium - Migrations.lua
    The steps that bring an older layout of Forever Compendium's saved variables up to date
    (Part.lua's layout is the newest). How steps run is in Forever Core's Core/Store.lua.
]]

local _, ns = ...

-- 2.0.0 joined the Forever suite: the suite has one minimap button (Forever Core's) and keeps the
-- chat settings itself, so what Compendium kept for its own button and those goes.
ns:Migrate(2, function(db)
    if db.settings then db.settings.MinimapButton = nil end
    if db.data then db.data.MinimapButton = nil end
    if db.seenModules then db.seenModules.MinimapButton = nil end
    db.quiet, db.debug = nil, nil
end)
