--[[
    Forever Gearbox - Lib/OtherAddons.lua
    What modules ask of the player's other addons: whether one is loaded, whether a Forever++
    module is on and a way to open Forever++'s settings on it (for the settings hints, module
    notices), whether a feature Forever Gearbox shares with Forever++, WilduTools or Plumber is on
    there (CoveredBy: Forever Gearbox then leaves it to them), Auctionator's auction prices (Full Bags; QuestieDB is Shared/Lib/QuestieDB.lua's). Their public APIs
    (docs/forever-api.md, Other addons) are other addons': each is looked up when asked, and every
    call goes through OtherAddons.Call, which logs its errors. Baganator's are in UI/BagButtons.lua,
    LibDBIcon's in the Button Bag, both through OtherAddons.Call too.
]]

local _, ns = ...

local pcall, type, ipairs, format = pcall, type, ipairs, string.format

local OtherAddons = {}
ns.OtherAddons = OtherAddons

-- The addons a module's notice can name (its `addon`), by folder, with the name shown for it, in
-- the order the Tweaks for Addons page lists them.
-- Every addon here, and QuestieDB and ForeverDungeonJournal, is in ForeverGearbox.toc's
-- OptionalDeps: the rule is that every addon Forever Gearbox reads or changes is listed, so the game
-- loads them first and a module never meets one half set up.
OtherAddons.KNOWN = {
    { "ForeverPlusPlus", "Forever++" },
    { "ForeverCodex", "Forever Codex" },
    { "Baganator", "Baganator" },
    { "Auctionator", "Auctionator" },
    { "Chattynator", "Chattynator" },
    { "MinimapButtonButton", "Minimap Button Button" },
    { "!WilduTools", "WilduTools" },
    { "Plumber", "Plumber" },
}

function OtherAddons.Loaded(name) return C_AddOns.IsAddOnLoaded(name) and true or false end

-- The name shown for an addon's folder (KNOWN), or the folder.
function OtherAddons.Title(folder)
    for _, known in ipairs(OtherAddons.KNOWN) do
        if known[1] == folder then return known[2] end
    end
    return folder
end

-- Calls another addon's fn(...): true and its results, or false when it errored, the error
-- logged (not reported: it isn't ours) to `owner`'s log line ("Button Bag: LibDBIcon: ...") or
-- the core's. Every call into another addon goes through here.
local function checked(owner, label, ok, ...)
    if not ok then
        (owner or ns):Debug(label .. ":", (...))
        return false
    end
    return true, ...
end

function OtherAddons.Call(owner, label, fn, ...)
    return checked(owner, label, pcall(fn, ...))
end
local call = OtherAddons.Call

-- Forever++'s API while Forever++ Integration is on (Core/Plugin.lua); else nil, as if it weren't
-- there: Forever Gearbox leaves Forever++ alone by default.
local function foreverPlusPlus()
    if not ns.Plugin.Integrated() then return nil end
    return _G.ForeverPlusPlusAPI.v1
end

-- Forever Codex's API while Forever Codex Integration is on (Core/Plugin.lua); else nil, as if
-- it weren't there: Forever Gearbox leaves Forever Codex alone by default.
local function foreverCodex()
    if not ns.Plugin.CodexIntegrated() then return nil end
    return _G.ForeverCodexAPI.v1
end

-- Whether Forever++'s module `name` is on: true or false, or nil without Forever++ (or a module
-- it doesn't have).
function OtherAddons.ForeverPlusPlusOn(name)
    local api = foreverPlusPlus()
    if not api then return nil end
    local ok, on = call(nil, "Forever++ IsModuleEnabled", api.IsModuleEnabled, name)
    if not ok or on == nil then return nil end
    return on and true or false
end

-- The value of Forever++'s module `name`'s setting `key` while that module is on, else nil.
function OtherAddons.ForeverPlusPlusOption(name, key)
    local api = foreverPlusPlus()
    if not api or not OtherAddons.ForeverPlusPlusOn(name) then return nil end
    local ok, value = call(nil, "Forever++ GetModuleOption", api.GetModuleOption, name, key)
    if ok then return value end
end

-- Whether Forever Codex's module `name` is on: true or false, or nil without Forever Codex (or
-- a module it doesn't have).
function OtherAddons.ForeverCodexOn(name)
    local api = foreverCodex()
    if not api then return nil end
    local ok, on = call(nil, "Forever Codex IsModuleEnabled", api.IsModuleEnabled, name)
    if not ok or on == nil then return nil end
    return on and true or false
end

-- Opens Forever++'s settings on its module `name`.
function OtherAddons.OpenForeverPlusPlus(name)
    local api = foreverPlusPlus()
    if not api then return end
    call(nil, "Forever++ OpenSettings", api.OpenSettings, name)
end

-- Opens Forever++'s Console Variables searched for `cvar` (its /fpp cvar command; there's no API
-- call for it), where the player can set and lock it.
function OtherAddons.OpenForeverPlusPlusCVar(cvar)
    local command = _G.SlashCmdList and _G.SlashCmdList.FOREVERPLUSPLUS
    if type(command) ~= "function" then return end
    call(nil, "Forever++ /fpp cvar", command, "cvar " .. cvar)
end

-- A notice for a Forever++ module that helps one of ours: shown while it's off, with a button
-- opening Forever++'s settings on it.
function OtherAddons.ForeverPlusPlusNotice(name, text, advice)
    return {
        text = text,
        addon = "ForeverPlusPlus",
        advice = advice,
        button = ns.L.OPEN_FOREVERPP,
        shown = function() return OtherAddons.ForeverPlusPlusOn(name) == false end,
        fn = function() OtherAddons.OpenForeverPlusPlus(name) end,
    }
end

---------------------------------------------------------------------------
-- Covered features: Forever Gearbox does what Forever++, WilduTools or Plumber also do, for players
-- without them, and leaves it to them while their own is on, so nothing runs twice. A module
-- keeps, for each such feature, its `covers`: { { folder, setting }, ... }, the other addons'
-- module or setting doing the same. Asked at the moment of acting (a merchant opening, a cast),
-- so turning the other one on or off needs nothing from us.
---------------------------------------------------------------------------

-- A setting of another addon that keeps its settings in its saved variables (no API): its value
-- for this character, or nil (unsaved: its default, which for every setting asked here is off).
-- Read only, through OtherAddons.Call: it's their data.
local function wilduSetting(key)
    local db = _G.WilduToolsDB
    if type(db) ~= "table" or type(db.profiles) ~= "table" then return nil end
    local name, realm = UnitName("player"), GetRealmName()
    local keys = type(db.profileKeys) == "table" and db.profileKeys or {}
    -- AceDB names a character "Name - Realm"; WilduTools' file has "Name Realm".
    local profile = keys[name .. " - " .. realm] or keys[name .. " " .. realm] or "Default"
    local settings = db.profiles[profile]
    return type(settings) == "table" and settings[key] or nil
end

local function plumberSetting(key)
    local db = _G.PlumberDB
    return type(db) == "table" and db[key] or nil
end

local IS_ON = {
    ForeverPlusPlus = function(name) return OtherAddons.ForeverPlusPlusOn(name) end,
    ForeverCodex = function(name) return OtherAddons.ForeverCodexOn(name) end,
    ["!WilduTools"] = wilduSetting,
    Plumber = plumberSetting,
}

-- Whether `cover` ({ folder, setting }) is loaded and on.
local function coverOn(owner, cover)
    local folder, setting = cover[1], cover[2]
    if not OtherAddons.Loaded(folder) then return false end
    local ok, on = call(owner, OtherAddons.Title(folder), IS_ON[folder], setting)
    return ok and on == true
end

-- The first of `covers` that's loaded and on, or nil: then the feature is left to it.
function OtherAddons.CoveredBy(owner, covers)
    for _, cover in ipairs(covers or {}) do
        if coverOn(owner, cover) then return cover end
    end
end

-- A notice for each of `covers`, shown while that one is on: "<addon> does <what>, so Forever
-- Gearbox leaves it to it." Forever++'s has a button opening its settings on that module.
function OtherAddons.CoveredNotices(owner, covers, what, list)
    list = list or {}
    for _, cover in ipairs(covers) do
        local folder, setting = cover[1], cover[2]
        local notice = {
            text = format(ns.L.COVERED_BY, OtherAddons.Title(folder), what),
            shown = function() return coverOn(owner, cover) end,
        }
        if folder == "ForeverPlusPlus" then
            notice.button = ns.L.OPEN_FOREVERPP
            notice.fn = function() OtherAddons.OpenForeverPlusPlus(setting) end
        end
        list[#list + 1] = notice
    end
    return list
end

---------------------------------------------------------------------------
-- Auctionator's prices
---------------------------------------------------------------------------

local CALLER = "Forever Gearbox" -- how Auctionator's API is told who's asking

local function auctionator()
    local api = _G.Auctionator and _G.Auctionator.API and _G.Auctionator.API.v1
    return type(api) == "table" and api or nil
end

-- One Auctionator API call, or nil. An error in it is logged and taken as no price.
local function askAuctionator(api, method, item)
    local get = api[method]
    if type(get) ~= "function" or item == nil then return end
    local ok, price = call(nil, "Auctionator " .. method, get, CALLER, item)
    if ok and type(price) == "number" and price > 0 then return price end
end

-- Whether auction prices can be had: Auctionator is there with a price call this uses (Full
-- Bags' and the Gathering counter's notices say so when they can't).
function OtherAddons.HasAuctionPrices()
    local api = auctionator()
    return api ~= nil and (type(api.GetAuctionPriceByItemLink) == "function"
        or type(api.GetAuctionPriceByItemID) == "function")
end

-- Auctionator's price for one, or nil: by link (exact for gear with suffixes), else by item ID
-- (the call Forever++ uses).
function OtherAddons.AuctionPrice(link, itemID)
    local api = auctionator()
    if not api then return end
    return askAuctionator(api, "GetAuctionPriceByItemLink", link)
        or askAuctionator(api, "GetAuctionPriceByItemID", itemID)
end
