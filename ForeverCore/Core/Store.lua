--[[
    Forever Core - Core/Store.lua
    How each member's saved variables are laid out (Core/Members.lua: member.saved and
    member.charSaved name them), the steps that bring an older layout up to date, and the table
    each module reads its settings and data through (module.db). For Forever Tweaks:

      ForeverTweaksDB = {
          version = member.layout,                       -- the layout; each step runs once
          settings = { [module] = { [key] = value } },   -- only what the player changed
          data = { [module] = { [key] = table } },       -- what modules keep (originals, lists)
          installed, seenModules                         -- the member's version when installed,
      }                                                  -- and the modules whose page was seen
      ForeverTweaksCharDB = {
          version = member.charLayout,                   -- the character's layout, its own steps
          data = { [module] = { [key] = table } },
      }

    Forever Core's own (ForeverCoreDB) also keeps quiet and debug (ns.db: the General page's
    Chat checkboxes). Each member's are loaded when the game says it has loaded (Core/Init.lua),
    the core's first: the game loads an addon's dependencies before it.

    A module's settings are its scalar defaults. What the player sets is saved even when it
    equals the default, so a later release changing that default doesn't change their choice;
    only a reset (the undo arrow, Defaults, /forever reset) forgets it, and then a newer default
    reaches them. Its data is every default that is a table; Defaults never touches it. Keys in
    module.perCharacter keep their data in the character's table. A saved setting of the wrong
    type for its default, or not one of its dropdown's choices, is dropped when it loads.

    Each member adds its own steps (ns:Migrate from its own files: Forever Tweaks' are in its
    Core/Migrations.lua). A step reads only the saved tables and what it's written with, never
    the modules as they are now: it must do the same thing in every later release. A step that
    fails stops the ones after it, and the layout stays at the last one that worked, so it's
    tried again next time.

    Layout adapted from Forever++ by xIGBClutchIx (MIT License).
]]

local _, ns = ...

local pairs, ipairs, type, tostring, setmetatable = pairs, ipairs, type, tostring, setmetatable
local _G = _G

local Store = {}
ns.Store = Store

-- Adds a step, fn(db, coreDB), that runs once for the calling member's account file older than
-- `version` (its layout). coreDB is Forever Core's account table, loaded before any member's.
function ns:Migrate(version, fn)
    local steps = self.member.steps
    steps[#steps + 1] = { version = version, fn = fn }
end

-- Adds a step, fn(charDB), that runs once for the calling member's character file older than
-- `version` (its charLayout). The character's file is read on whichever character logs in, so it
-- keeps its own version.
function ns:MigrateChar(version, fn)
    local steps = self.member.charSteps
    steps[#steps + 1] = { version = version, fn = fn }
end

-- A table that t[key] holds, made when it isn't one.
local function child(t, key)
    local value = t[key]
    if type(value) ~= "table" then
        value = {}
        t[key] = value
    end
    return value
end

-- module.db: reads the player's setting, else the default; table defaults read the module's
-- data table (the account's, or the character's for perCharacter keys). Writes go to the same.
local function newModuleDB(mod, settings, data, charData)
    local defaults, perCharacter = mod.defaults, mod.perCharacter or {}
    mod.settings = settings
    return setmetatable({}, {
        __index = function(_, key)
            local default = defaults[key]
            if type(default) == "table" then
                return child(perCharacter[key] and charData or data, key)
            end
            local value = settings[key]
            if value == nil then return default end
            return value
        end,
        __newindex = function(_, key, value)
            if type(defaults[key]) == "table" then
                (perCharacter[key] and charData or data)[key] = value
            else
                settings[key] = value
            end
        end,
    })
end

-- Whether `value` can be the setting `key`: the default's type, and one of its option's values
-- (a dropdown's choice, a slider's number in range: ns.Options.Fits).
local function fits(mod, key, value)
    local default = mod.defaults[key]
    if default == nil then return true end -- not ours to judge (a key from a newer version)
    if type(value) ~= type(default) then return false end
    for _, option in ipairs(mod.options) do
        if option.key == key then return ns.Options.Fits(option, value) end
    end
    return true
end

local function dropUnfit(mod, settings)
    for key, value in pairs(settings) do
        if not fits(mod, key, value) then
            settings[key] = nil
            ns:Debug(mod.name, "dropped saved", key, "=", tostring(value))
        end
    end
end

local owner = { name = "Store" } -- what migrations are reported and charged as

-- Runs the steps in `list` a layout older than `latest` needs, in order, each given db and
-- `extra` (coreDB for an account's steps). Returns the layout reached.
local function migrate(db, list, latest, extra)
    local version = db.version
    table.sort(list, function(a, b) return a.version < b.version end)
    for _, step in ipairs(list) do
        if version < step.version then
            -- A failed step is reported (with its stack) and stops here; the next login tries it again.
            if not ns.RunCall(owner, "migration", ns.Succeeded, step.fn, db, extra) then return version end
            version = step.version
        end
    end
    return latest
end

-- Forgets the player's setting `key`.
function Store.Forget(mod, key)
    mod.settings[key] = nil
end

-- Whether `key` is at its default because the player never set it.
function Store.IsDefault(mod, key)
    return mod.settings[key] == nil
end

-- Loads member's saved variables (made when new), brings them up to date, and gives each of its
-- modules its db.
function Store.Init(member)
    local db, charDB = _G[member.saved], _G[member.charSaved]
    local fresh, freshChar = db == nil, charDB == nil
    db, charDB = db or {}, charDB or {}
    _G[member.saved], _G[member.charSaved] = db, charDB

    if fresh then
        db.version, db.installed = member.layout, member.version
    end
    if freshChar then charDB.version = member.charLayout end
    -- Files from before there were versions: the account's is layout 1, the character's 0.
    db.version, charDB.version = db.version or 1, charDB.version or 0
    db.version = migrate(db, member.steps, member.layout, ns.db or db)
    charDB.version = migrate(charDB, member.charSteps, member.charLayout)

    db.settings, db.data, db.seenModules = db.settings or {}, db.data or {}, db.seenModules or {}
    charDB.data = charDB.data or {}
    -- A removed module's character data (each character's file is only read when it logs in).
    for name in pairs(charDB.data) do
        if not ns.modules[name] then charDB.data[name] = nil end
    end
    member.db, member.charDB = db, charDB
    if member == ns.member then ns.db, ns.charDB = db, charDB end

    for _, name in ipairs(member.order) do Store.Attach(ns.modules[name]) end
end

-- Gives a module its db from its member's saved tables (Store.Init has made them), then runs
-- its OnInitialize: done for every module as its member loads; a test's own module goes
-- through it too.
function Store.Attach(mod)
    local name, db, charDB = mod.name, mod.member.db, mod.member.charDB
    local settings = child(db.settings, name)
    dropUnfit(mod, settings)
    mod.db = newModuleDB(mod, settings, child(db.data, name), child(charDB.data, name))
    if mod.OnInitialize then ns.Run(mod, "OnInitialize", mod.OnInitialize) end
end
