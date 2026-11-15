--[[
    Forever Tweaks - Lib/OtherAddons.lua
    What modules ask of the player's other addons: whether one is loaded, whether a Forever++
    module is on and a way to open Forever++'s settings on it (for the settings hints, module
    notices), whether a feature Forever Tweaks shares with Forever++, WilduTools or Plumber is on
    there (CoveredBy: Forever Tweaks then leaves it to them), Auctionator's auction prices (Full Bags and the Gathering counter), and what
    QuestieDB knows of quests and items (Quest Items, the quest library). Their public APIs
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
-- Every addon here, and QuestieDB and ForeverDungeonJournal, is in ForeverTweaks.toc's
-- OptionalDeps: the rule is that every addon Forever Tweaks reads or changes is listed, so the game
-- loads them first and a module never meets one half set up.
OtherAddons.KNOWN = {
    { "ForeverPlusPlus", "Forever++" },
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

local function foreverPlusPlus()
    local api = _G.ForeverPlusPlusAPI and _G.ForeverPlusPlusAPI.v1
    return type(api) == "table" and api or nil
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

-- Opens Forever++'s settings on its module `name`.
function OtherAddons.OpenForeverPlusPlus(name)
    local api = foreverPlusPlus()
    if not api then return end
    call(nil, "Forever++ OpenSettings", api.OpenSettings, name)
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
-- Covered features: Forever Tweaks does what Forever++, WilduTools or Plumber also do, for players
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
-- Tweaks leaves it to it." Forever++'s has a button opening its settings on that module.
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

local CALLER = "Forever Tweaks" -- how Auctionator's API is told who's asking

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

---------------------------------------------------------------------------
-- QuestieDB (LibQuestieDB): what it knows of quests and items
---------------------------------------------------------------------------

local QUESTIE_ITEM_OBJECTIVES = 3 -- objectives: creature, object, item, ... groups (QuestieDB questMeta)

local function questie()
    local db = _G.LibQuestieDB
    return type(db) == "table" and db or nil
end

-- The items QuestieDB says quest `questID` needs (its item objectives, the item it starts with,
-- the items it takes), added to `ids` (itemID -> true). Nothing without QuestieDB.
function OtherAddons.QuestieQuestItems(owner, questID, ids)
    local db = questie()
    if not (db and db.Quest) then return end
    call(owner, "QuestieDB", function()
        local objectives = db.Quest.Get(questID, "objectives")
        for _, objective in ipairs(objectives and objectives[QUESTIE_ITEM_OBJECTIVES] or {}) do
            if objective[1] then ids[objective[1]] = true end
        end
        local source = db.Quest.Get(questID, "sourceItemId")
        if source then ids[source] = true end
        for _, id in ipairs(db.Quest.Get(questID, "requiredSourceItems") or {}) do ids[id] = true end
    end)
end

-- The quests QuestieDB says item `itemID` was for: { { name, done } }, at most `max`; empty
-- without QuestieDB.
function OtherAddons.QuestieItemQuests(owner, itemID, max)
    local quests = {}
    local db = questie()
    if not (db and db.Item and db.Quest) then return quests end
    call(owner, "QuestieDB", function()
        for _, questID in ipairs(db.Item.Get(itemID, "relatedQuests") or {}) do
            local name = db.Quest.Get(questID, "name")
            if name and #quests < max then
                quests[#quests + 1] = { name = name, done = C_QuestLog.IsQuestFlaggedCompleted(questID) }
            end
        end
    end)
    return quests
end
