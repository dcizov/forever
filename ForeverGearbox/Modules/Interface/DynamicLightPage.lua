--[[
    Forever Gearbox - Modules/Interface/DynamicLightPage.lua
    Dynamic Light's section of the Advanced Graphics page (VisualsPage.lua; DynamicLight.lua's
    values), a part of the page of its own under a divider and a big heading: on and off and
    Strength, a boxed line saying what it sets now and why (DynamicLight.Status, kept up as it
    changes), Reset; then, only while it's on, each of its sections (SECTIONS): Time,
    Day (with a button taking your own Brightness, Contrast and Gamma as its start), Zones (a zone
    picked from every zone and city of Kalimdor and the Eastern Kingdoms, yours by default: its
    strength and, if you like, its own Day light), Night, Indoors and Caves, Cities, Light Sources,
    Strength. A level (dusk, midnight, a cave...) is three rows: its brightness, contrast and gamma.
    Each control sets the value at once (DynamicLight.SetValue), so the screen shows what it does.
]]

local _, ns = ...
local L, Kit = ns.L, ns.Kit

local ipairs, format, unpack = ipairs, string.format, unpack
local picked -- the zone the Zones rows set (its map), nil for the one you're in

local LightPage = {}
ns.DynamicLightPage = LightPage

local Page = assert(ns.VisualsPage, "DynamicLightPage.lua loads after VisualsPage.lua")

local HOURS = "%.1f h"
local RESET_WIDTH = 120 -- the Defaults button, as wide as Blizzard's
local PERCENT = "%d%%"
-- A level's three parts: their label, range, step and format.
local PARTS = {
    { L.VISUALS_BRIGHTNESS, 0, 100, 1 }, { L.VISUALS_CONTRAST, 0, 100, 1 }, { L.DLIGHT_GAMMA, 0.3, 1.5, 0.01, "%.2f" },
}

-- Each row: key (DynamicLight.Defaults'), kind ("level", "slider", "checkbox", "text"), label,
-- tip, and a slider's min, max, step, format.
local SECTIONS = {
    { title = L.DLIGHT_TIME, rows = {
        { key = "sunrise", kind = "slider", label = L.DLIGHT_SUNRISE, tip = L.DLIGHT_SUNRISE_TIP, min = 3, max = 9, step = 0.5, format = HOURS },
        { key = "sunset", kind = "slider", label = L.DLIGHT_SUNSET, tip = L.DLIGHT_SUNSET_TIP, min = 17, max = 23, step = 0.5, format = HOURS },
        { key = "twilight", kind = "slider", label = L.DLIGHT_TWILIGHT, tip = L.DLIGHT_TWILIGHT_TIP, min = 0.5, max = 4, step = 0.25,
          format = "%.2f h" },
        { key = "moon", kind = "checkbox", label = L.DLIGHT_MOON, tip = L.DLIGHT_MOON_TIP },
        { key = "moonrise", kind = "slider", label = L.DLIGHT_MOONRISE, tip = L.DLIGHT_MOONRISE_TIP, min = 18, max = 24, step = 0.5,
          format = HOURS },
    } },
    { title = L.DLIGHT_DAY_SECTION, zones = true, rows = {
        { key = "day", kind = "level", label = L.DLIGHT_DAY, tip = L.DLIGHT_DAY_TIP },
    } },
    { title = L.DLIGHT_NIGHT, rows = {
        { key = "dusk", kind = "level", label = L.DLIGHT_DUSK, tip = L.DLIGHT_DUSK_TIP },
        { key = "midnight", kind = "level", label = L.DLIGHT_MIDNIGHT, tip = L.DLIGHT_MIDNIGHT_TIP },
        { key = "moonlit", kind = "level", label = L.DLIGHT_MOONLIT, tip = L.DLIGHT_MOONLIT_TIP },
    } },
    { title = L.DLIGHT_INDOORS, rows = {
        { key = "indoorDay", kind = "level", label = L.DLIGHT_INDOOR_DAY, tip = L.DLIGHT_INDOOR_DAY_TIP },
        { key = "indoorNight", kind = "level", label = L.DLIGHT_INDOOR_NIGHT, tip = L.DLIGHT_INDOOR_NIGHT_TIP },
        { key = "cave", kind = "level", label = L.DLIGHT_CAVE, tip = L.DLIGHT_CAVE_TIP },
        { key = "dungeonCaves", kind = "checkbox", label = L.DLIGHT_DUNGEON_CAVES, tip = L.DLIGHT_DUNGEON_CAVES_TIP },
    } },
    { title = L.DLIGHT_CITIES, rows = {
        { key = "capitalLift", kind = "slider", label = L.DLIGHT_CAPITAL, tip = L.DLIGHT_CAPITAL_TIP, min = 0, max = 100, step = 5,
          format = PERCENT },
        { key = "undercity", kind = "level", label = L.DLIGHT_UNDERCITY_LEVEL, tip = L.DLIGHT_UNDERCITY_TIP },
        { key = "cityFade", kind = "slider", label = L.DLIGHT_CITY_FADE, tip = L.DLIGHT_CITY_FADE_TIP, min = 0, max = 60, step = 5,
          format = "%d s" },
    } },
    { title = L.DLIGHT_LIGHT, rows = {
        { key = "lights", kind = "text", label = L.DLIGHT_LIGHTS, tip = L.DLIGHT_LIGHTS_TIP },
        { key = "lightBoost", kind = "slider", label = L.DLIGHT_BOOST, tip = L.DLIGHT_BOOST_TIP, min = 0, max = 15, step = 1 },
        { key = "lightMax", kind = "slider", label = L.DLIGHT_MAX, tip = L.DLIGHT_MAX_TIP, min = 0, max = 30, step = 1 },
        { key = "nightVision", kind = "slider", label = L.DLIGHT_NIGHT_VISION, tip = L.DLIGHT_NIGHT_VISION_TIP, min = 0, max = 15,
          step = 1 },
    } },
    { title = L.DLIGHT_STRENGTH, rows = {
        { key = "multBrightness", kind = "slider", label = L.VISUALS_BRIGHTNESS, tip = L.DLIGHT_MULT_TIP, min = 0, max = 200, step = 10,
          format = PERCENT },
        { key = "multContrast", kind = "slider", label = L.VISUALS_CONTRAST, tip = L.DLIGHT_MULT_TIP, min = 0, max = 200, step = 10,
          format = PERCENT },
        { key = "multGamma", kind = "slider", label = L.DLIGHT_GAMMA, tip = L.DLIGHT_MULT_TIP, min = 0, max = 200, step = 10,
          format = PERCENT },
        { key = "gamma", kind = "checkbox", label = L.DLIGHT_GAMMA_TOO, tip = L.DLIGHT_GAMMA_TOO_TIP },
        { key = "speed", kind = "slider", label = L.DLIGHT_SPEED, tip = L.DLIGHT_SPEED_TIP, min = 25, max = 400, step = 25,
          format = PERCENT },
    } },
}
LightPage.SECTIONS = SECTIONS

local DL = function() return ns.DynamicLight end
LightPage.ShowNow = function() end -- its "Now" line drawn again (set once the page is built)

local function on() return Page.Enabled() end

-- A level's three rows (brightness, contrast, gamma): get() gives the level, set(level) keeps it.
local function addLevel(stack, label, tip, get, set)
    for i, part in ipairs(PARTS) do
        local def = { min = part[2], max = part[3], step = part[4], format = part[5] }
        local row = Kit.AddSliderRow(stack, format(L.DLIGHT_LEVEL_PART, label, part[1]), def,
            function() return get()[i] end,
            function(value)
                local level = { unpack(get()) }
                level[i] = value
                set(level)
            end, tip)
        Page.AddRefresh(function() row.Refresh(on()) end)
    end
end

-- One spec's rows (a level: three) on `stack`.
local function addRows(stack, spec)
    local light = DL()
    if spec.kind == "level" then
        addLevel(stack, spec.label, spec.tip, function() return light.Value(spec.key) end,
            function(level) light.SetValue(spec.key, level) end)
        if spec.key == "day" then
            local row = Kit.AddButtonRow(stack, L.DLIGHT_DAY_YOURS, L.DLIGHT_DAY_YOURS_BUTTON, function()
                light.DayFromYours()
                Page.Redraw()
            end, L.DLIGHT_DAY_YOURS_TIP)
            Page.AddRefresh(function() row:SetAlpha(on() and 1 or 0.5) end)
        end
    elseif spec.kind == "slider" then
        local row = Kit.AddSliderRow(stack, spec.label, spec, function() return light.Value(spec.key) end,
            function(value) light.SetValue(spec.key, value) end, spec.tip)
        Page.AddRefresh(function() row.Refresh(on()) end)
    elseif spec.kind == "checkbox" then
        local row = Kit.AddCheckRow(stack, spec.label, function() return light.Value(spec.key) end,
            function(checked) light.SetValue(spec.key, checked) end, spec.tip)
        Page.AddRefresh(row.Refresh)
    else
        local row = Kit.AddEditRow(stack, spec.label, function() return light.Value(spec.key) end,
            function(text) light.SetValue(spec.key, text) end, spec.tip)
        Page.AddRefresh(row.Refresh)
    end
end

local function addSkyRows(stack)
    local mod = ns.Visuals.module
    local start = #stack.entries + 1
    local function check(key, label, tip)
        local row = Kit.AddCheckRow(stack, label, function() return mod.db[key] end,
            function(checked) ns:SetOption(mod.name, key, checked) end, tip)
        Page.AddRefresh(function() row.Refresh(mod.db.skyEnabled) end)
    end
    local function slider(key, label, tip, min, max, step, format)
        local row = Kit.AddSliderRow(stack, label, { min = min, max = max, step = step, format = format },
            function() return mod.db[key] end,
            function(value) ns:SetOption(mod.name, key, value) end, tip)
        Page.AddRefresh(function() row.Refresh(mod.db.skyEnabled) end)
    end
    check("skyEnabled", L.VISUALS_SKY_ENABLE, L.VISUALS_SKY_ENABLE_TIP)
    check("skyDynamicTime", L.VISUALS_SKY_DYNAMIC, L.VISUALS_SKY_DYNAMIC_TIP)
    check("skyNightOnly", L.VISUALS_SKY_NIGHT_ONLY, L.VISUALS_SKY_NIGHT_ONLY_TIP)
    check("skyHideFlyingOrIndoors", L.VISUALS_SKY_HIDE, L.VISUALS_SKY_HIDE_TIP)
    slider("skyGradientHeight", L.VISUALS_SKY_HEIGHT, L.VISUALS_SKY_HEIGHT_TIP, 120, 500, 10, "%d px")
    slider("skyDayAlpha", L.VISUALS_SKY_DAY, L.VISUALS_SKY_DAY_TIP, 0, 1, 0.05, "%.2f")
    slider("skyNightAlpha", L.VISUALS_SKY_NIGHT, L.VISUALS_SKY_NIGHT_TIP, 0, 1, 0.05, "%.2f")
    slider("skyGradientIntensity", L.VISUALS_SKY_GRADIENT, L.VISUALS_SKY_GRADIENT_TIP, 0, 1, 0.05, "%.2f")
    for i = start + 1, #stack.entries do
        stack.entries[i].shown = function() return mod.db.skyEnabled end
    end
end

-- The picked zone's map (yours while none is picked) and its name.
local function pickedZone()
    local mapID = picked or DL().Zone()
    local info = mapID and C_Map.GetMapInfo(mapID)
    return mapID, info and info.name or L.DLIGHT_ZONE_NONE
end

-- The Zones section: the picker, then the picked zone's strength and its own Day light.
local function addZones(stack)
    local light = DL()
    Kit.AddHeaderRow(stack, L.DLIGHT_ZONES)
    Kit.AddTextRow(stack, L.DLIGHT_ZONES_INTRO, "GameFontHighlightSmall", 4)
    local picker = Kit.AddDropdownRow(stack, L.DLIGHT_ZONE, function(root)
        root:CreateRadio(L.DLIGHT_ZONE_YOURS, function() return picked == nil end, function()
            picked = nil
            Page.Redraw()
        end)
        for _, continent in ipairs(light.ZoneList()) do
            local sub = root:CreateButton(continent.name)
            for _, zone in ipairs(continent.zones) do
                local mark = (light.ZoneDay(zone.mapID) or light.ZoneStrength(zone.mapID) ~= 100) and " *" or ""
                sub:CreateRadio(zone.name .. mark, function() return picked == zone.mapID end, function()
                    picked = zone.mapID
                    Page.Redraw()
                end)
            end
        end
    end, function()
        local _, name = pickedZone()
        return picked and name or format(L.DLIGHT_ZONE_YOURS_NAMED, name)
    end, L.DLIGHT_ZONE_TIP)
    Page.AddRefresh(picker.Refresh)
    local strength = Kit.AddSliderRow(stack, L.VISUALS_ZONE, { min = 0, max = 200, step = 10, format = "%d%%" },
        function() return light.ZoneStrength((pickedZone())) end,
        function(value) light.SetZoneStrength(value, (pickedZone())) end, L.VISUALS_ZONE_TIP)
    Page.AddRefresh(function() strength.Refresh(on()) end)
    local own = Kit.AddCheckRow(stack, L.DLIGHT_ZONE_DAY, function() return light.ZoneDay((pickedZone())) ~= nil end,
        function(checked)
            local level = checked and { unpack(light.ZoneDay((pickedZone())) or light.Value("day")) } or nil
            light.SetZoneDay(level, (pickedZone()))
            Page.Redraw()
        end, L.DLIGHT_ZONE_DAY_TIP)
    Page.AddRefresh(own.Refresh)
    addLevel(stack, L.DLIGHT_DAY, L.DLIGHT_ZONE_DAY_TIP,
        function() return light.ZoneDay((pickedZone())) or light.Value("day") end,
        function(level) light.SetZoneDay(level, (pickedZone())) end)
    Kit.ShowWhen(stack, function() return light.ZoneDay((pickedZone())) ~= nil end, #PARTS)
end

-- Shows the rows added since entry `from` only while Dynamic Light is on (each keeping its own test).
local function whileOn(stack, from)
    for i = from, #stack.entries do
        local entry = stack.entries[i]
        local own = entry.shown
        entry.shown = function() return Page.Enabled() and (not own or own()) end
    end
end

-- Its section of the Advanced Graphics page (VisualsPage.lua), on `stack`: on and off, its
-- strength, what it sets now, Reset, then (while it's on) each of its sections.
function LightPage.AddTo(stack)
    Kit.AddPartRow(stack, L.DLIGHT_TITLE, 40)
    Kit.AddTextRow(stack, L.DLIGHT_PAGE_INTRO, "GameFontHighlightSmall", 6)
    Page.AddOptionRow(stack, "dynamic")
    Page.AddOptionRow(stack, "dynamicStrength", Page.Enabled)
    Kit.AddHeaderRow(stack, L.VISUALS_SKY)
    addSkyRows(stack)
    -- The sky rows are always there (the rest of Dynamic Light's hide while it's off); their time
    -- curve is Dynamic Light's while that's on, else their own three hours (Visuals.lua).
    local from = #stack.entries + 1
    -- What it sets now and why, in a box of its own between the rows (not a row's label).
    local now = Kit.AddInfoRow(stack, "", 8)
    local function showNow() now:SetText(DL().Status()) end
    Page.AddRefresh(showNow)
    LightPage.ShowNow = showNow
    local reset = Kit.AddButtonRow(stack, L.DLIGHT_RESET, SETTINGS_DEFAULTS, function()
        DL().Reset()
        Page.Redraw()
    end, L.DLIGHT_RESET_TIP, RESET_WIDTH)
    stack.entries[#stack.entries].gap = 8
    Page.AddRefresh(function() reset:SetAlpha(on() and 1 or 0.5) end)
    for _, section in ipairs(SECTIONS) do
        Kit.AddHeaderRow(stack, section.title)
        for _, spec in ipairs(section.rows) do addRows(stack, spec) end
        if section.zones then addZones(stack) end
    end
    whileOn(stack, from)
end
