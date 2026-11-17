--[[
    Forever Gearbox - Modules/Interface/DynamicLight.lua
    Visuals' Dynamic Light (Visuals.lua turns it on and off; its own page, DynamicLightPage.lua,
    sets its values): brightness, contrast and gamma that follow the time of day and where you
    are, eased there a little at a time. Its values are data (Visuals' `light`, DL.Defaults below):

      * Time: the game's clock against Sunrise and Sunset, each with a Twilight of that many hours
        round it. As the sun goes down the light goes from Day (its own level, 50/50/1.0 as the
        original DynamicLight's) to Dusk, then to Midnight once fully dark;
        after Moonrise the dark eases to Moonlit until dawn (Moon off: Midnight all night).
      * Places: Indoors eases from Indoor Day to Indoor Night as the sun goes; a Cave (indoors in a
        place named like one, L.DLIGHT_CAVE_WORDS, or any dungeon with Dungeons Are Caves) is Cave
        at any hour; Undercity is always its own; a Capital City (by its map: CAPITALS, else its
        name, L.DLIGHT_CAPITALS) is lifted Capital Lift of the way back to the day.
      * Zones: each zone (and city) can have its own strength and its own Day light (Visuals'
        `zones` and `zoneDay` data, by the zone's map), picked on the page from every zone of
        Kalimdor and the Eastern Kingdoms (DL.ZoneList, from the game's map).
      * Light: buffs named in Light Sources (a torch, a lantern) make it brighter while they're on:
        the first by Light Boost, each further by half the one before, Light Max at most, never
        past the day. A night elf's Night Vision brightens the dark (by how dark it is).
      * Strength: how much of the change happens (Visuals' Strength, then the zone's own, then each
        of Brightness, Contrast and Gamma's own), Gamma Too (off: gamma left alone) and Fade Speed.
      * Fading: 20 steps a second (about one brightness point each), easing in as eyes adjust (fast
        at first, slowing as it arrives; Fade Speed, 100% the original's); walking between a city
        (a capital or Undercity) and the open world blends evenly over City Fade (30 s), as the
        original's capital fade. The time, the place and your buffs are read every half second.
      * Turned on: there at once (later changes are eased). Turned off: brightness, contrast and
        gamma go back to yours (the Visuals page's, else the game's from before).
    Written from the idea of DynamicLight and DynamicLight Zones (no license: none of their code).
]]

local _, ns = ...
local L = ns.L

local math, ipairs, pairs, next, tonumber, type = math, ipairs, pairs, next, tonumber, type
local Plain = ns.Plain

local DL = {}
ns.DynamicLight = DL

local FRAME = 0.05     -- seconds between steps of a fade (about one brightness point each)
local LOOK_EVERY = 10  -- steps between looks at the time, the place and your buffs (half a second)
local RATE = 2         -- the eased approach's rate a second at Fade Speed 100% (the original's)
local KEYS = { "Brightness", "Contrast", "Gamma" }
local RANGE = { { 0, 100 }, { 0, 100 }, { 0.3, 2 } }
local SETTLED = { 0.05, 0.05, 0.001 } -- close enough to the target to stop easing
local NIGHT_ELF = 4          -- the race ID with night vision
local ZONE, DUNGEON = 3, 4   -- Enum.UIMapType: a zone (cities too), a dungeon
local CONTINENTS = { 1414, 1415 } -- Kalimdor, the Eastern Kingdoms
-- The capitals' maps: Stormwind, Orgrimmar, Ironforge, Thunder Bluff, Darnassus, and the Exodar and
-- Silvermoon where a client has them. Undercity (UNDERCITY) is its own place.
local CAPITALS = { [1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true, [1947] = true, [1954] = true }
local UNDERCITY = 1458

-- Its values, each a level { brightness, contrast, gamma } or a number (Visuals' `light` data
-- keeps only what was changed).
DL.Defaults = {
    day = { 50, 50, 1 },
    cityFade = 30,
    sunrise = 6, sunset = 20, twilight = 1.5, moon = true, moonrise = 22,
    dusk = { 32, 35, 0.92 }, midnight = { 18, 20, 0.84 }, moonlit = { 24, 25, 0.88 },
    indoorDay = { 50, 50, 1 }, indoorNight = { 34, 45, 0.94 }, cave = { 16, 20, 0.82 }, dungeonCaves = false,
    undercity = { 30, 25, 0.9 }, capitalLift = 30,
    lights = "", lightBoost = 5, lightMax = 10, nightVision = 5,
    multBrightness = 100, multContrast = 100, multGamma = 100, gamma = true, speed = 100,
}

local mod = assert(ns.Visuals, "DynamicLight.lua loads after Visuals.lua").module

local LIGHT_KEYS = {
    "day", "cityFade", "sunrise", "sunset", "twilight", "moon", "moonrise", "dusk", "midnight", "moonlit",
    "indoorDay", "indoorNight", "cave", "dungeonCaves", "undercity", "capitalLift", "lights", "lightBoost",
    "lightMax", "nightVision", "multBrightness", "multContrast", "multGamma", "gamma", "speed",
}

local REFERENCE = "reference"
local PROFILE_CUSTOM = ""

local function copyLevel(level)
    return { level[1], level[2], level[3] }
end

local function copyValue(value)
    if type(value) == "table" then return copyLevel(value) end
    return value
end

local function withDefaults(own)
    local values = {}
    own = type(own) == "table" and own or {}
    for _, key in ipairs(LIGHT_KEYS) do
        local value = own[key]
        if value == nil then value = DL.Defaults[key] end
        values[key] = copyValue(value)
    end
    return values
end

local function copyZones(values)
    local copied = {}
    for mapID, value in pairs(type(values) == "table" and values or {}) do copied[mapID] = value end
    return copied
end

local function copyZoneDay(values)
    local copied = {}
    for mapID, level in pairs(type(values) == "table" and values or {}) do
        if type(level) == "table" then copied[mapID] = copyLevel(level) end
    end
    return copied
end

local function sameLevel(a, b)
    return type(a) == "table" and type(b) == "table" and a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

local function sameValues(a, b)
    for _, key in ipairs(LIGHT_KEYS) do
        local av, bv = a[key], b[key]
        if type(av) == "table" or type(bv) == "table" then
            if not sameLevel(av, bv) then return false end
        elseif av ~= bv then
            return false
        end
    end
    return true
end

local function sameZones(a, b)
    for mapID, value in pairs(a) do if b[mapID] ~= value then return false end end
    for mapID, value in pairs(b) do if a[mapID] ~= value then return false end end
    return true
end

local function sameZoneDay(a, b)
    for mapID, level in pairs(a) do if not sameLevel(level, b[mapID]) then return false end end
    for mapID, level in pairs(b) do if not sameLevel(level, a[mapID]) then return false end end
    return true
end

DL["PROFILES"] = {
    {
        id = REFERENCE,
        title = function() return L.DLIGHT_PROFILE_REFERENCE end,
        tip = function() return L.DLIGHT_PROFILE_REFERENCE_TIP end,
        values = function() return withDefaults() end,
    },
    {
        id = "va-odyssey-g5-sdr",
        title = function() return L.DLIGHT_PROFILE_VA_G5 end,
        tip = function() return L.DLIGHT_PROFILE_VA_G5_TIP end,
        values = function() return withDefaults({
            dusk = { 34, 37, 0.93 }, midnight = { 22, 24, 0.88 }, moonlit = { 27, 28, 0.9 },
            indoorNight = { 37, 47, 0.95 }, cave = { 20, 24, 0.86 }, undercity = { 33, 28, 0.91 },
            capitalLift = 32, lightBoost = 4, lightMax = 8, nightVision = 4,
            multBrightness = 110, multContrast = 95,
        }) end,
    },
    {
        id = "icc-neutral",
        title = function() return L.DLIGHT_PROFILE_ICC_NEUTRAL end,
        tip = function() return L.DLIGHT_PROFILE_ICC_NEUTRAL_TIP end,
        values = function() return withDefaults({
            dusk = { 32, 35, 1 }, midnight = { 18, 20, 1 }, moonlit = { 24, 25, 1 }, indoorDay = { 50, 50, 1 },
            indoorNight = { 34, 45, 1 }, cave = { 16, 20, 1 }, undercity = { 30, 25, 1 }, gamma = true,
        }) end,
    },
}

local function builtInByID(id)
    for _, profile in ipairs(DL["PROFILES"]) do
        if profile.id == id then
            return {
                id = profile.id,
                title = profile.title(),
                tip = profile.tip(),
                values = profile.values(),
                builtin = true,
            }
        end
    end
end

local function ownProfileByID(id)
    local own = mod.db and mod.db.lightProfiles and mod.db.lightProfiles[id]
    if type(own) ~= "table" then return end
    local profile = {
        id = id,
        title = type(own.title) == "string" and own.title or L.DLIGHT_PROFILE_CUSTOM,
        values = withDefaults(own.values),
        builtin = false,
    }
    if type(own.zones) == "table" then profile.zones = copyZones(own.zones) end
    if type(own.zoneDay) == "table" then profile.zoneDay = copyZoneDay(own.zoneDay) end
    return profile
end

local function allProfiles()
    local list = {}
    for _, built in ipairs(DL["PROFILES"]) do list[#list + 1] = builtInByID(built.id) end
    local own = mod.db and mod.db.lightProfiles or {}
    local ownList = {}
    for id in pairs(own) do
        if not builtInByID(id) then ownList[#ownList + 1] = ownProfileByID(id) end
    end
    table.sort(ownList, function(a, b) return a.title < b.title end)
    for _, profile in ipairs(ownList) do list[#list + 1] = profile end
    return list
end

function DL.Profile(id)
    return builtInByID(id) or ownProfileByID(id)
end

function DL.ProfileTitle(id)
    local profile = DL.Profile(id)
    return profile and profile.title or nil
end

function DL.ProfileList()
    return allProfiles()
end

local suspendChanged

local ticker
local current, last = {}, {} -- what's eased to so far; what was last set (rounded)
local target                 -- where the light is going, from the last look
local place                  -- the place at the last look ("capital", "outdoors", ...)
local blend                  -- a slow walk between a city and the open world: { ends, rates }
local steps = 0              -- steps since the ticker started (a look every LOOK_EVERY)

-- One of its values: yours, else the default.
function DL.Value(key)
    local own = mod.db and mod.db.light[key]
    if own ~= nil then return own end
    return DL.Defaults[key]
end

function DL.SetValue(key, value)
    local default = DL.Defaults[key]
    local same = value == default
    if type(value) == "table" then
        same = true
        for i = 1, 3 do same = same and value[i] == default[i] end
    end
    -- Kept only when it isn't the default (false too: an `and/or` would drop it).
    if same then mod.db.light[key] = nil else mod.db.light[key] = value end
    if not suspendChanged then DL.Changed() end
end

local function currentValues()
    local values = {}
    for _, key in ipairs(LIGHT_KEYS) do values[key] = copyValue(DL.Value(key)) end
    return values
end

local function matchesProfile(profile)
    if not profile then return false end
    if not sameValues(currentValues(), profile.values) then return false end
    if profile.zones and not sameZones(copyZones(mod.db.zones), profile.zones) then return false end
    if profile.zoneDay and not sameZoneDay(copyZoneDay(mod.db.zoneDay), profile.zoneDay) then return false end
    return true
end

local function selectedID()
    return mod.db.lightProfile or PROFILE_CUSTOM
end

function DL.SelectedProfile()
    local id = selectedID()
    local selected = id ~= PROFILE_CUSTOM and DL.Profile(id) or nil
    if selected and matchesProfile(selected) then return id end
    for _, profile in ipairs(allProfiles()) do
        if matchesProfile(profile) then return profile.id end
    end
    return PROFILE_CUSTOM
end

function DL.MarkCustom()
    mod.db.lightProfile = PROFILE_CUSTOM
end

local function nextProfileID()
    local own = mod.db.lightProfiles
    local n = 1
    while own["custom" .. n] do n = n + 1 end
    return "custom" .. n
end

local function saveOwnProfile(id, title, values)
    local own = mod.db.lightProfiles
    own[id] = own[id] or {}
    own[id].title = title
    own[id].values = withDefaults(values)
    if next(mod.db.zones) then own[id].zones = copyZones(mod.db.zones) else own[id].zones = nil end
    if next(mod.db.zoneDay) then own[id].zoneDay = copyZoneDay(mod.db.zoneDay) else own[id].zoneDay = nil end
end

function DL.SaveCurrent(title)
    title = (type(title) == "string" and title:gsub("^%s*(.-)%s*$", "%1") or "")
    if title == "" then return nil end
    local id = nextProfileID()
    saveOwnProfile(id, title, currentValues())
    mod.db.lightProfile = id
    return id
end

function DL.Duplicate(id, title)
    local source = DL.Profile(id)
    title = (type(title) == "string" and title:gsub("^%s*(.-)%s*$", "%1") or "")
    if not source or title == "" then return nil end
    local newID = nextProfileID()
    mod.db.lightProfiles[newID] = {
        title = title,
        values = withDefaults(source.values),
        zones = source.zones and copyZones(source.zones) or nil,
        zoneDay = source.zoneDay and copyZoneDay(source.zoneDay) or nil,
    }
    mod.db.lightProfile = newID
    return newID
end

function DL.Rename(id, title)
    local own = mod.db.lightProfiles[id]
    title = (type(title) == "string" and title:gsub("^%s*(.-)%s*$", "%1") or "")
    if type(own) ~= "table" or title == "" then return false end
    own.title = title
    return true
end

local function applyProfile(profile)
    suspendChanged = true
    for key in pairs(mod.db.light) do mod.db.light[key] = nil end
    for _, key in ipairs(LIGHT_KEYS) do
        DL.SetValue(key, copyValue(profile.values[key]))
    end
    suspendChanged = nil
    if profile.zones then mod.db.zones = copyZones(profile.zones) end
    if profile.zoneDay then mod.db.zoneDay = copyZoneDay(profile.zoneDay) end
    mod.db.lightProfile = profile.id
    DL.Changed()
end

function DL.ApplyProfile(id)
    local profile = DL.Profile(id)
    if not profile then
        profile = assert(DL.Profile(REFERENCE))
        applyProfile(profile)
        mod:Reply(L.DLIGHT_PROFILE_FALLBACK)
        return profile.id
    end
    applyProfile(profile)
    return profile.id
end

function DL.ResetToSelected()
    local id = selectedID()
    if id == PROFILE_CUSTOM then
        DL.ApplyProfile(REFERENCE)
        mod:Reply(L.DLIGHT_PROFILE_RESET_FALLBACK)
        return REFERENCE
    end
    return DL.ApplyProfile(id)
end

function DL.Delete(id)
    if builtInByID(id) then return false end
    if not mod.db.lightProfiles[id] then
        if selectedID() == id then
            DL.ApplyProfile(REFERENCE)
            mod:Reply(L.DLIGHT_PROFILE_FALLBACK)
        end
        return false
    end
    mod.db.lightProfiles[id] = nil
    if selectedID() == id then
        DL.ApplyProfile(REFERENCE)
        mod:Reply(L.DLIGHT_PROFILE_DELETE_FALLBACK)
    end
    return true
end

---------------------------------------------------------------------------
-- Time and place
---------------------------------------------------------------------------

local function hour()
    local h, m = GetGameTime()
    return (Plain(h) or 12) + (Plain(m) or 0) / 60
end

local function smooth(x)
    x = math.max(0, math.min(1, x))
    return x * x * (3 - 2 * x)
end

local function lerp(a, b, t) return a + (b - a) * t end

local function lerpLevel(a, b, t) return { lerp(a[1], b[1], t), lerp(a[2], b[2], t), lerp(a[3], b[3], t) } end

-- 0 by day, 1 at full dark, eased through dusk and dawn.
function DL.Darkness(h)
    local rise, set, half = DL.Value("sunrise"), DL.Value("sunset"), DL.Value("twilight") / 2
    if h >= rise + half and h <= set - half then return 0 end
    if h > set - half and h < set + half then return smooth((h - (set - half)) / (half * 2)) end
    if h > rise - half and h < rise + half then return 1 - smooth((h - (rise - half)) / (half * 2)) end
    return 1
end

-- 0 before Moonrise (or with Moon off), easing to 1 over the hour after it, and 1 until dawn.
function DL.Moon(h)
    if not DL.Value("moon") then return 0 end
    local rise = DL.Value("moonrise")
    if h >= rise then return smooth(h - rise) end
    if h < DL.Value("sunrise") then return 1 end
    return 0
end

local function lower(text) return (Plain(text) or ""):lower() end

local function namedLike(list, place)
    for word in list:gmatch("[^,]+") do
        word = word:match("^%s*(.-)%s*$"):lower()
        if word ~= "" and place:find(word, 1, true) then return true end
    end
    return false
end

-- The zone (or dungeon) map you're in: a city district or cave counts for its zone. Nil on a
-- continent or the world map.
local function zone()
    local info = C_Map.GetMapInfo(Plain(C_Map.GetBestMapForUnit("player")) or 0)
    while info and (info.mapType or ZONE) > DUNGEON and info.parentMapID and info.parentMapID > 0 do
        info = C_Map.GetMapInfo(info.parentMapID)
    end
    if info and (info.mapType or ZONE) >= ZONE then return info.mapID end
end
DL.Zone = zone

-- "cave", "undercity", "indoors", "capital" or "outdoors".
function DL.Place()
    local sub, zoneName, map = lower(GetSubZoneText()), lower(GetZoneText()), zone()
    local inside = IsIndoors() == true
    if map == UNDERCITY or zoneName == L.DLIGHT_UNDERCITY:lower() then return "undercity" end
    if inside then
        local inInstance, kind = IsInInstance()
        local dungeon = inInstance and (kind == "party" or kind == "raid")
        if dungeon and DL.Value("dungeonCaves") then return "cave" end
        if namedLike(L.DLIGHT_CAVE_WORDS, sub .. " " .. zoneName) then return "cave" end
        return "indoors"
    end
    if CAPITALS[map] or namedLike(L.DLIGHT_CAPITALS, zoneName) then return "capital" end
    return "outdoors"
end

-- Every zone and city of Kalimdor and the Eastern Kingdoms, from the game's map, for the page's
-- zone picker: { { mapID, name, zones = { { mapID, name } } } }, each sorted by name.
function DL.ZoneList()
    local list = {}
    for _, continent in ipairs(CONTINENTS) do
        local info = C_Map.GetMapInfo(continent)
        if info then
            local zones = {}
            for _, child in ipairs(C_Map.GetMapChildrenInfo(continent, ZONE) or {}) do
                zones[#zones + 1] = { mapID = child.mapID, name = child.name }
            end
            table.sort(zones, function(a, b) return a.name < b.name end)
            list[#list + 1] = { mapID = continent, name = info.name, zones = zones }
        end
    end
    return list
end

-- Each zone's own strength, percent (100 when it has none).
function DL.ZoneStrength(mapID)
    mapID = mapID or zone()
    return mapID and mod.db and mod.db.zones[mapID] or 100
end

function DL.SetZoneStrength(value, mapID)
    mapID = mapID or zone()
    if not mapID then return end
    mod.db.zones[mapID] = value ~= 100 and value or nil
    DL.Changed()
end

---------------------------------------------------------------------------
-- The light
---------------------------------------------------------------------------

-- Your own light, for while Dynamic Light is off: the page's Brightness, Contrast and Gamma
-- (else the game's from before the module first ran).
local function yours()
    local values, original = mod.db.values, mod.db.original
    return { values.Brightness or tonumber(original.Brightness) or 50, values.Contrast or tonumber(original.Contrast) or 50,
        values.Gamma or tonumber(original.Gamma) or 1 }
end

-- A zone's own Day light, or nil when it follows Day.
function DL.ZoneDay(mapID)
    mapID = mapID or zone()
    return mapID and mod.db and mod.db.zoneDay[mapID] or nil
end

-- Gives zone `mapID` its own Day light (a level), or nil: it follows Day again.
function DL.SetZoneDay(level, mapID)
    mapID = mapID or zone()
    if not mapID then return end
    mod.db.zoneDay[mapID] = level
    DL.Changed()
end

-- The day's light here: the zone's own, else Day.
local function day() return DL.ZoneDay() or DL.Value("day") end

-- Your own Brightness and Contrast (and gamma from before) as Day: a start to fine-tune from.
function DL.DayFromYours()
    local own = yours()
    DL.SetValue("day", { own[1], own[2], own[3] })
end

-- Points from light sources on now: the first Light Boost, each further half the one before.
local function lightBonus()
    local list = DL.Value("lights")
    if list == "" then return 0 end
    local bonus, step = 0, DL.Value("lightBoost")
    for i = 1, 40 do
        local aura = C_UnitAuras.GetBuffDataByIndex("player", i)
        if not aura then break end
        local name = lower(aura.name)
        if name ~= "" and namedLike(list, name) then
            bonus = bonus + step
            step = step / 2
        end
    end
    return math.min(bonus, DL.Value("lightMax"))
end

-- Where the light should be for the place and hour, before strength.
local function levelFor(place, h, base)
    local dark = DL.Darkness(h)
    if place == "undercity" then return DL.Value("undercity") end
    if place == "cave" then return DL.Value("cave") end
    if place == "indoors" then return lerpLevel(DL.Value("indoorDay"), DL.Value("indoorNight"), dark) end
    local night = lerpLevel(DL.Value("midnight"), DL.Value("moonlit"), DL.Moon(h))
    local level = dark <= 0.5 and lerpLevel(base, DL.Value("dusk"), dark * 2)
        or lerpLevel(DL.Value("dusk"), night, (dark - 0.5) * 2)
    if place == "capital" then level = lerpLevel(level, base, DL.Value("capitalLift") / 100) end
    return level
end

-- Where the light should be now, and the place.
function DL.Target()
    local base, h, place = day(), hour(), DL.Place()
    local level = levelFor(place, h, base)
    local k = mod.db.dynamicStrength / 100 * DL.ZoneStrength() / 100
    local mult = { DL.Value("multBrightness") / 100, DL.Value("multContrast") / 100, DL.Value("multGamma") / 100 }
    -- Light sources and night vision lift the brightness (and a little gamma), never past the day.
    local lift = lightBonus()
    local _, _, race = UnitRace("player")
    if race == NIGHT_ELF then lift = lift + DL.Value("nightVision") * DL.Darkness(h) end
    local wanted = {}
    for i = 1, 3 do
        local value = base[i] + (level[i] - base[i]) * k * mult[i]
        if i == 1 then value = math.min(base[1], value + lift) end
        if i == 3 then value = math.min(base[3], value + lift / 100) end
        wanted[i] = math.max(RANGE[i][1], math.min(RANGE[i][2], value))
    end
    if not DL.Value("gamma") then wanted[3] = base[3] end
    return wanted, place
end

local function rounded(i, value)
    if i == 3 then return math.floor(value * 100 + 0.5) / 100 end
    return math.floor(value + 0.5)
end

-- Sets the rounded values that moved; `check`: also each one something else (the game's Options,
-- another addon) changed since, read only then (on a look).
local function set(values, check)
    local changed = false
    for i, key in ipairs(KEYS) do
        local value = rounded(i, values[i])
        local now = check and ns.Visuals.Get(key)
        if (value ~= last[i] or (now and math.abs(now - value) > 0.001)) and ns.Visuals.Has(key) then
            ns.Visuals.SetCVar(key, value, true)
            last[i] = value
            changed = true
        end
    end
    -- The page's "Now" line follows (only drawn while the page is shown).
    if changed then ns.DynamicLightPage.ShowNow() end
end

-- A city is a capital or Undercity: walking in or out of one blends over City Fade.
local CITIES = { capital = true, undercity = true }

-- A look: where the light should be now. Walking between a city and the open world starts a
-- blend of City Fade seconds, at an even pace (the original DynamicLight's capital fade).
local function look()
    local wanted, now = DL.Target()
    local fade = DL.Value("cityFade")
    if place and now ~= place and (CITIES[place] or CITIES[now]) and fade > 0 and current[1] then
        local rates = {}
        for i = 1, 3 do rates[i] = math.abs(wanted[i] - current[i]) / fade end
        blend = { ends = GetTime() + fade, rates = rates }
    elseif now ~= place then
        blend = nil
    end
    target, place = wanted, now
end

-- One step of the fade: an even pace while a city blend lasts, else an eased approach (fast at
-- first, slowing as it arrives, as eyes adjust), at Fade Speed.
local function ease(dt)
    local blending = blend and GetTime() < blend.ends
    if not blending then blend = nil end
    local factor = 1 - math.exp(-RATE * DL.Value("speed") / 100 * dt)
    for i = 1, 3 do
        local now, goal = current[i] or target[i], target[i]
        local moved
        if blending then
            local move = blend.rates[i] * dt
            moved = now + math.max(-move, math.min(move, goal - now))
        else
            moved = now + (goal - now) * factor
        end
        if math.abs(goal - moved) < SETTLED[i] then moved = goal end
        current[i] = moved
    end
end

local function step()
    steps = steps + 1
    local looking = steps % LOOK_EVERY == 1 or not target
    if looking then look() end
    ease(FRAME)
    set(current, looking)
end

function DL.Start()
    if not (mod.active and mod.db.dynamic) or mod:IsPending(ticker) then return end
    current, last, blend, steps = {}, {}, nil, 0
    -- There at once, as the original does: only what changes after is eased.
    look()
    for i = 1, 3 do current[i] = target[i] end
    set(current, true)
    ticker = mod:NewTicker(FRAME, step)
end

function DL.Stop()
    mod:CancelTimer(ticker)
    ticker, target, place, blend = nil, nil, nil, nil
    if next(last) then
        last = {}
        set(yours())
    end
    current = {}
end

-- Something it reads changed (the day's values, a strength, one of its values): there at once,
-- so the control moved shows what it does.
function DL.Changed()
    if not mod:IsPending(ticker) then return end
    look()
    blend = nil
    for i = 1, 3 do current[i] = target[i] end
    set(current)
end

function DL.IsRunning() return mod:IsPending(ticker) end

-- The time of day in words: day, dusk, dawn, night or moonlit night.
local function phase(h)
    local dark = DL.Darkness(h)
    if dark <= 0 then return L.DLIGHT_NOW_DAY end
    if dark < 1 then return h < 12 and L.DLIGHT_NOW_DAWN or L.DLIGHT_NOW_DUSK end
    return DL.Moon(h) >= 0.5 and L.DLIGHT_NOW_MOONLIT or L.DLIGHT_NOW_NIGHT
end

local PLACES = { outdoors = "DLIGHT_PLACE_OUTDOORS", indoors = "DLIGHT_PLACE_INDOORS", cave = "DLIGHT_PLACE_CAVE",
    capital = "DLIGHT_PLACE_CAPITAL", undercity = "DLIGHT_PLACE_UNDERCITY" }

-- What it sets now and why, for the page: the time of day, the place and zone, and the values.
function DL.Status()
    if not DL.IsRunning() then return L.DLIGHT_NOW_OFF end
    local map = zone()
    local info = map and C_Map.GetMapInfo(map)
    local where = L[PLACES[DL.Place()]]
    if info and info.name then where = where .. ", " .. info.name end
    local values = { ns.Visuals.Get("Brightness"), ns.Visuals.Get("Contrast"), ns.Visuals.Get("Gamma") }
    return L.DLIGHT_NOW:format(phase(hour()), where, values[1] or 0, values[2] or 0, values[3] or 0)
end

-- Its values back to the defaults.
function DL.Reset()
    for key in pairs(mod.db.light) do mod.db.light[key] = nil end
    DL.Changed()
end
