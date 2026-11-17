--[[
    Forever Codex - Migrations.lua
    The steps that bring an older layout of Forever Codex' saved variables (Forever Compendium's until
    3.3.0, taken over as they are by Store.Init before these run) up to date
    (Part.lua's layout is the newest). How steps run is in Shared/Core/Store.lua.
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

-- 3.0.0 left the suite: Forever Core's settings (chat, the settings window's place, the minimap
-- button and the Update Notice) are Compendium's own now. ForeverCoreDB is in the TOC only for
-- this: what it held comes over, and it's cleared, so the game stops saving it.
ns:Migrate(3, function(db)
    local core = _G.ForeverCoreDB
    _G.ForeverCoreDB = nil
    if type(core) ~= "table" then return end
    for _, key in ipairs({ "quiet", "debug", "window", "windowScale" }) do
        if db[key] == nil then db[key] = core[key] end
    end
    for _, part in ipairs({ "settings", "data", "seenModules" }) do
        if type(core[part]) == "table" then
            db[part] = db[part] or {}
            for _, name in ipairs({ "MinimapButton", "Updates" }) do
                if db[part][name] == nil then db[part][name] = core[part][name] end
            end
        end
    end
end)

-- 3.1.0 split NPCs from creatures and stopped learning what can't be fought on sight. In the
-- book already: a friendly NPC something was learned of (its title, wares or quests) becomes an
-- NPC; one only ever seen (scenery, guards, flight masters' mounts) goes, as do critters and
-- battle pets only seen, unless you pinned them or wrote a note.
local SEEN_ONLY_KINDS = { Critter = true, ["Non-combat Pet"] = true, ["Wild Pet"] = true }
local function learnedOf(rec)
    return (rec.kills or 0) > 0 or (rec.looted or 0) > 0 or rec.pinned or rec.note or rec.wares
        or next(rec.starts or {}) or next(rec.ends or {}) or next(rec.quests or {})
end
ns:Migrate(4, function(db)
    local creatures = type(db.data) == "table" and type(db.data.Recorder) == "table" and db.data.Recorder.creatures
    if type(creatures) ~= "table" then return end
    for npcID, rec in pairs(creatures) do
        if type(rec) == "table" then
            if (rec.reaction or 0) >= 5 and not ((rec.kills or 0) > 0) then
                if rec.title or learnedOf(rec) then
                    rec.npc = true
                    rec.services = rec.services or {}
                    if rec.wares then rec.services.vendor = true end
                    if next(rec.starts or {}) or next(rec.ends or {}) then rec.services.quest = true end
                else
                    creatures[npcID] = nil
                end
            elseif SEEN_ONLY_KINDS[rec.creatureType] and not learnedOf(rec) then
                creatures[npcID] = nil
            end
        end
    end
end)

-- 3.2.0 stopped meeting players' pets, guardians and totems; the book drops the ones it has (a
-- title that is an owner line, "Name's Pet"; a totem), unless you pinned them or wrote a note.
ns:Migrate(5, function(db)
    local creatures = type(db.data) == "table" and type(db.data.Recorder) == "table" and db.data.Recorder.creatures
    if type(creatures) ~= "table" then return end
    for npcID, rec in pairs(creatures) do
        if type(rec) == "table" and not (rec.pinned or rec.note) and ns.Book.LooksOwned(rec.title, rec.creatureType) then
            creatures[npcID] = nil
        end
    end
end)
