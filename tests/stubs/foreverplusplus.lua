--[[
    Forever suite - tests/stubs/foreverplusplus.lua
    A stand-in for Forever++ (the addon Forever Gearbox is a companion of): ForeverPlusPlusAPI.v1
    with what Forever Gearbox calls, checked the way Forever++'s Lib/Plugins.lua checks it (a
    module registered after login, a field it has no use for, an option it couldn't draw: each an
    error), and its Modules page for tests to click (W.FPP).

    Upgrade Arrows' answers (GetItemUpgradeInfo) come from W.FPP.upgrades (item link -> its info),
    while FPP.own.UpgradeArrows is on; W.FPP.Fire(event, ...) tells the API's listeners an event.

    W.LoadAddon loads it for an addon that depends on ForeverPlusPlus. At PLAYER_LOGIN, before any
    addon hears it (Forever++ is loaded first), it loads its "saved variables" (ForeverPlusPlusDB),
    turns on the modules that are on and says READY.
]]

local FPP = { modules = {}, order = {}, callbacks = {}, opened = nil, upgrades = {} }
W.addonMeta.ForeverPlusPlus = { Title = "Forever++", Version = "1.6.1" }
W.FPP = FPP

local FIELDS = {
    title = "string", category = "string", added = "string", quickToggle = "string",
    options = "table", actions = "table", notice = "table", perCharacter = "table",
    oldKeys = "table", oldNames = "table",
    OnEnable = "function", OnDisable = "function", OnOptionChanged = "function",
    IsAvailable = "function", Problem = "function",
}
local OPTION_FIELDS = {
    key = "string", name = "string", description = "string", section = "string", added = "string",
    requires = "string", slider = "string", choices = "table", shown = "function",
    min = "number", max = "number", step = "number", format = "string", editMode = "boolean",
}

local function fail(text) error("Forever++: " .. text, 3) end

local function checkOption(option, defaults, index)
    local copy = {}
    for field, kind in pairs(OPTION_FIELDS) do
        local value = option[field]
        if value ~= nil then
            if type(value) ~= kind then fail("option " .. index .. ": " .. field .. " must be a " .. kind) end
            copy[field] = value
        end
    end
    local key, default = copy.key, defaults[copy.key or ""]
    if not key or not copy.name then fail("option " .. index .. " needs a key and a name") end
    if key == "enabled" or default == nil or type(default) == "table" then
        fail("option " .. key .. " needs a default that isn't a table")
    end
    if copy.choices then
        local found = false
        for _, choice in ipairs(copy.choices) do
            if type(choice[1]) ~= "string" or type(choice[2]) ~= "string" then
                fail("option " .. key .. ": each choice is { value, name }, both text")
            end
            found = found or choice[1] == default
        end
        if not found then fail("option " .. key .. ": its default isn't one of its choices") end
    elseif copy.min or copy.max then
        if not (copy.min and copy.max and copy.min < copy.max and type(default) == "number"
            and default >= copy.min and default <= copy.max) then
            fail("option " .. key .. ": a slider needs min under max and a default between them")
        end
        if copy.format and not pcall(string.format, copy.format, default) then
            fail("option " .. key .. ": its format doesn't take a number")
        end
    elseif type(default) ~= "boolean" then
        fail("option " .. key .. ": a checkbox needs true or false for its default")
    end
    return copy
end

local function checkOptions(options, defaults)
    local copies, keys = {}, {}
    for index, option in ipairs(options) do
        local copy = checkOption(option, defaults, index)
        if keys[copy.key] then fail("two options are called " .. copy.key) end
        keys[copy.key], copies[index] = copy, copy
    end
    for _, copy in ipairs(copies) do
        for _, field in ipairs({ "requires", "slider" }) do
            if copy[field] and not keys[copy[field]] then fail("option " .. copy.key .. ": no option called " .. copy[field]) end
        end
    end
    return copies
end

local function plainData(value)
    local kind = type(value)
    if kind == "table" then
        for _, inner in pairs(value) do
            if not plainData(inner) then return false end
        end
        return true
    end
    return kind == "boolean" or kind == "string" or kind == "number"
end

-- The profile: ForeverPlusPlusDB.settings[module][key], from login on.
local function settings(module)
    local db = _G.ForeverPlusPlusDB
    db.settings = db.settings or {}
    db.settings[module.name] = db.settings[module.name] or {}
    return db.settings[module.name]
end

local function value(module, key)
    local saved = settings(module)[key]
    if saved == nil then return module.defaults[key] end
    return saved
end

local function view(module)
    return setmetatable({}, {
        __index = function(_, key)
            if module.defaults[key] ~= nil then return value(module, key) end
        end,
        __newindex = function(_, key, v)
            local default = module.defaults[key]
            if default == nil then fail("db has no \"" .. tostring(key) .. "\"") end
            if key == "enabled" then fail("db.enabled is the player's to set, on the Modules page") end
            if v ~= nil and type(v) ~= type(default) then fail("db." .. key .. " takes a " .. type(default)) end
            settings(module)[key] = v
        end,
    })
end

local function register(name, description, defaults, addon)
    if FPP.started then fail("RegisterModule is for the time a plugin loads, before PLAYER_LOGIN") end
    if type(name) ~= "string" or not name:match("^[%a][%w_]*$") then fail("RegisterModule needs a name") end
    if type(description) ~= "string" or type(defaults) ~= "table" then fail("RegisterModule(name, description, defaults)") end
    if FPP.modules[name] then fail("there is already a module called " .. name) end
    local own = {}
    for key, v in pairs(defaults) do
        if type(key) ~= "string" or not plainData(v) then fail("the default " .. tostring(key) .. " can't be saved") end
        own[key] = v
    end
    if own.enabled == nil then own.enabled = false end
    local module = { name = name, description = description, defaults = own, addon = addon, fields = {} }
    local handle = setmetatable({}, {
        __index = function(_, key)
            if key == "name" then return name end
            if key == "enabled" then return module.enabled or false end
            if key == "db" then return FPP.started and view(module) or nil end
        end,
        __newindex = function(_, key, v)
            local kind = FIELDS[key]
            if not kind then fail("a plugin's module has no \"" .. tostring(key) .. "\" to set") end
            if type(v) ~= kind then fail(key .. " must be a " .. kind) end
            if key == "options" then
                if FPP.started then fail("options is set while the plugin loads") end
                v = checkOptions(v, own)
            elseif key == "notice" then
                for _, row in ipairs(v[1] and v or { v }) do
                    if type(row.text) ~= "string" then fail("a notice needs a text") end
                end
            elseif key == "actions" then
                for _, action in ipairs(v) do
                    if type(action.name) ~= "string" or type(action.button) ~= "string" or type(action.fn) ~= "function" then
                        fail("a button needs a name, a button text, and a function")
                    end
                end
            end
            module.fields[key] = v
        end,
    })
    module.handle = handle
    FPP.modules[name] = module
    FPP.order[#FPP.order + 1] = name
    return handle
end

local function call(module, method, ...)
    local fn = module.fields[method]
    if fn then return fn(module.handle, ...) end
end

local function fire(event, ...)
    for _, listener in ipairs(FPP.callbacks) do
        if listener.event == event then listener.fn(event, ...) end
    end
end

FPP.Fire = fire

-- The module named `name`, or the Forever Gearbox one called "ForeverGearbox" .. name.
function FPP.Module(name)
    return FPP.modules[name] or FPP.modules["ForeverGearbox" .. name]
end

-- What Forever++'s Modules page does when its checkbox is clicked.
function FPP.SetEnabled(name, on)
    local module = assert(FPP.Module(name), "no Forever++ module " .. tostring(name))
    on = on and true or false
    if FPP.started then settings(module).enabled = on else module.defaults.enabled = on end
    if not FPP.started or (module.enabled or false) == on then return end
    module.enabled = on
    call(module, on and "OnEnable" or "OnDisable")
    fire("MODULE_TOGGLED", module.name, on)
end

-- What it does when an option is changed there.
function FPP.SetOption(name, key, v)
    local module = assert(FPP.Module(name), "no Forever++ module " .. tostring(name))
    settings(module)[key] = v
    if module.enabled then call(module, "OnOptionChanged", key) end
    fire("OPTION_CHANGED", module.name, key, v)
end

-- Forever++'s own modules, which plugins ask about (IsModuleEnabled, GetModuleOption,
-- GetModuleInfo): those Forever Gearbox adds to (Core/Attach.lua), on as the player has them, and
-- any a test puts here. FPP.SetOwn turns one on or off as its Modules page does.
FPP.own = {} -- name -> { enabled, title, options = { key = value } }
for name, title in pairs({ QuestTracker = "Quest Tracker", WorldMap = "World Map", UpgradeArrows = "Upgrade Arrows",
    FishingCast = "Fishing Cast", MovableWindows = "Movable Windows", QuestNameplates = "Quest Nameplates" }) do
    FPP.own[name] = { enabled = true, title = title, options = {} }
end

function FPP.SetOwn(name, on)
    local own = assert(FPP.own[name], "no Forever++ module " .. tostring(name))
    own.enabled = on and true or false
    fire("MODULE_TOGGLED", name, own.enabled)
end

-- What Forever++'s Plugins.Migrate does at login: a plugin module's settings saved under one of its
-- oldNames (a plugin module it has seen: db.plugins) move to its name now, in every profile; then
-- every plugin module is noted as seen.
local function migrate(db)
    local seen = type(db.plugins) == "table" and db.plugins or {}
    local roots = { db }
    for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do roots[#roots + 1] = profile end
    for _, name in ipairs(FPP.order) do
        for _, old in ipairs(FPP.modules[name].fields.oldNames or {}) do
            if seen[old] and not FPP.modules[old] then
                for _, root in ipairs(roots) do
                    for _, part in ipairs({ "settings", "data" }) do
                        local byName = root[part]
                        if type(byName) == "table" then
                            if byName[old] ~= nil and byName[name] == nil then byName[name] = byName[old] end
                            byName[old] = nil
                        end
                    end
                end
            end
        end
    end
    db.plugins = seen
    for _, name in ipairs(FPP.order) do seen[name] = true end
end

local function start()
    if FPP.started then return end
    _G.ForeverPlusPlusDB = _G.ForeverPlusPlusDB or {}
    migrate(_G.ForeverPlusPlusDB)
    FPP.started = true
    for _, name in ipairs(FPP.order) do
        local module = FPP.modules[name]
        if value(module, "enabled") then
            module.enabled = true
            call(module, "OnEnable")
        end
    end
    fire("READY")
end

-- Forever++ is loaded before its plugins, so it hears PLAYER_LOGIN first.
local fireEvent = W.Fire
function W.Fire(event, ...)
    if event == "PLAYER_LOGIN" then start() end
    return fireEvent(event, ...)
end

local v1 = {
    GetVersion = function() return 1, "1.6.1" end,
    IsReady = function() return FPP.started or false end,
    IsModuleEnabled = function(name)
        local own = FPP.own[name]
        if own then return own.enabled end
        local module = FPP.modules[name]
        if not module then return nil end -- one it doesn't have
        return module.enabled or false
    end,
    GetModuleInfo = function(name)
        local own, module = FPP.own[name], FPP.modules[name]
        if own then return { title = own.title or name, enabled = own.enabled } end
        if module then return { title = module.fields.title or name, enabled = module.enabled or false } end
    end,
    GetModuleOption = function(name, key)
        local own = FPP.own[name]
        if own then return own.options and own.options[key] end
        local module = FPP.modules[name]
        return module and FPP.started and value(module, key) or nil
    end,
    OpenSettings = function(name)
        FPP.opened = name or true
        return true
    end,
    RegisterCallback = function(event, fn, owner)
        FPP.callbacks[#FPP.callbacks + 1] = { event = event, fn = fn, owner = owner }
    end,
    UnregisterCallback = function(event, owner)
        for i = #FPP.callbacks, 1, -1 do
            local listener = FPP.callbacks[i]
            if listener.event == event and listener.owner == owner then table.remove(FPP.callbacks, i) end
        end
    end,
    RegisterModule = register,
    HasUpgradeScores = function() return FPP.own.UpgradeArrows ~= nil and FPP.own.UpgradeArrows.enabled == true end,
    GetItemUpgradeInfo = function(link)
        local own = FPP.own.UpgradeArrows
        if not (own and own.enabled) then return nil end
        local info = FPP.upgrades[link]
        if info == nil then return nil end
        local copy = {}
        for k, v in pairs(info) do copy[k] = v end
        return copy
    end,
}
ForeverPlusPlusAPI = { v1 = v1 }
