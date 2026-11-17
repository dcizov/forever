--[[
    Forever Gearbox - tests/scenarios/interface/visuals.lua
    Visuals: its page under Forever++ in Settings only while it's on (before Forever++'s
    Changelog and About), a setting with what goes with it, presets, Protect Values putting back
    what the graphics menu changed, combat holding changes back, and Dynamic Light easing
    brightness down at night, darker in a cave, by each zone's strength, and back when it's off.
    Run by tests/run.lua (lua5.1 tests/run.lua visuals), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

for name, value in pairs({ giQuality = "1", RenderFormat = "1", volumeFog = "1", volumeFogLevel = "2", sunShafts = "0",
    pbrLiquidDetail = "0", bloomUserMult = "1", Brightness = "50", Contrast = "50", Gamma = "1",
    groundEffectDensity = "64", groundEffectDist = "100", groundEffectFade = "80", weatherDensity = "2",
    lodObjectCullSize = "14", lodObjectFadeScale = "120", cameraDistanceMaxZoomFactor = "1.9", ResampleAlwaysSharpen = "0",
    ResampleSharpness = "0", graphicsGroundClutter = "3" }) do
    W.cvars[name] = value
end
W.cvarDefaults.groundEffectDensity = "40"

-- Saved before 3.3.0: Loot Sparkles kept with the Outline Mode it set.
ForeverGearboxDB = { version = 15, settings = {}, data = { Visuals = { values = {
    outlineModeShowLootEffectWhenDisabled = 1, graphicsOutlineMode = 0, giQuality = 2 },
    light = { midnight = { 21, 23, 0.89 } } } } }
W.Strict()
local ns = W.LoadAddon(root, "ForeverGearbox")
-- Forever++ gives Settings its entry at its login: its pages, then the entry itself.
W.addonMeta.ForeverPlusPlus = { Title = "Forever++" }
local fpp = Settings.RegisterCanvasLayoutCategory(W.NewFrame("Frame"), "Forever++")
Settings.RegisterCanvasLayoutSubcategory(fpp, W.NewFrame("Frame"), "Profiles")
Settings.RegisterCanvasLayoutSubcategory(fpp, W.NewFrame("Frame"), "Changelog")
Settings.RegisterCanvasLayoutSubcategory(fpp, W.NewFrame("Frame"), "About")
Settings.RegisterAddOnCategory(fpp)
login()
-- Forever++ Integration on: what this checks works with Forever++ (Core/Plugin.lua).
ns:SetEnabled("ForeverPlusPlus", true)
W.RunTimers()
local V = ns.Visuals
local DL = ns.DynamicLight
local L = ns.L

eq(V.module.db.lightProfile, "my-settings", "migration keeps pre-profile Dynamic Light values as My Settings")
check(type(V.module.db.lightProfiles["my-settings"]) == "table", "migration creates My Settings once")
eq(V.module.db.lightProfiles["my-settings"].values.midnight[1], 21, "My Settings keeps the tuned value")

DL.ApplyProfile("va-odyssey-g5-sdr")
eq(V.module.db.lightProfile, "va-odyssey-g5-sdr", "a built-in profile can be selected")
eq(V.module.db.light.midnight[1], 22, "built-in apply writes expected Dynamic Light keys")
eq(V.module.db.light.multContrast, 95, "built-in apply writes expected scalar values")

V.module.db.lightProfiles.sparse = { title = "Sparse", values = { midnight = { 26, 27, 0.92 } } }
DL.ApplyProfile("sparse")
eq(DL.Value("midnight")[1], 26, "a profile can override one key")
eq(V.module.db.light.dusk, nil, "a key absent from the profile does not leak from the previous profile")
DL.ApplyProfile("reference")
eq(V.module.db.light.midnight, nil, "switching back to Reference clears previous profile overrides")

ns.DynamicLightPage.SetValue("midnight", { 19, 21, 0.85 })
eq(V.module.db.lightProfile, "", "a manual page change marks the profile selection Custom")
DL.ApplyProfile("reference")

local ownProfile = DL.SaveCurrent("Temp Profile")
DL.ApplyProfile(ownProfile)
DL.Delete(ownProfile)
eq(V.module.db.lightProfile, "reference", "deleting the selected profile falls back to Reference")
eq(DL.Value("day")[1], 50, "fallback keeps valid Dynamic Light values")

eq(L.VISUALS_SKY, "Sky", "the sky section is named Sky")
eq(L.VISUALS_SKY_ENABLE, "Sky Gradient", "the sky toggle has its own name")
eq(L.VISUALS_SKY_HIDE, "Fade Indoors or While Flying", "the sky hide row names indoors first")
check(L.VISUALS_SKY_HIDE_TIP:find("client reports flying", 1, true) ~= nil,
    "the sky hide tip explains flying depends on client reporting")
eq(L.VISUALS_SKY_DYNAMIC_TIP:match("Dynamic Light"), "Dynamic Light", "the hybrid mapping explains the time curve source")
eq(type(V.module.defaults.skyGradientIntensity), "number", "there is a dedicated sky gradient intensity value")
eq(type(V.module.defaults.skyColorDarkness), "number", "there is a dedicated sky color darkness value")
eq(V.module.defaults.skyNightOnly, true, "the night-only gate defaults on")

local function pageNames()
    local names = {}
    for i, c in ipairs(fpp:GetSubcategories()) do names[i] = c:GetName() end
    return table.concat(names, ",")
end
eq(pageNames(), "Profiles,Changelog,About", "off: no Visuals page")
ns:SetEnabled("Visuals", true)
eq(pageNames(), "Profiles," .. L.VISUALS_TITLE .. ",Changelog,About",
    "on: one Advanced Graphics page, before Forever++'s last two")
eq(V.module.db.values.outlineModeShowLootEffectWhenDisabled, nil, "3.3.0: the old loot sparkle isn't kept any more")
eq(V.module.db.values.graphicsOutlineMode, nil, "nor the Outline Mode it set")

-- A setting, and what goes with it (Indirect Lighting turns the 16-bit render format on).
local gi
for _, def in ipairs(V.SETTINGS) do if def.cvar == "giQuality" then gi = def end end
V.Apply(gi, 3, true)
eq(W.cvars.giQuality, "3", "the setting")
eq(W.cvars.RenderFormat, "2", "and what goes with it")
eq(V.module.db.preset, "", "set by hand: Custom")

-- A preset: what it names, the rest left.
V.ApplyPreset("performance")
eq(W.cvars.groundEffectDensity, "32", "a preset's value")
eq(W.cvars.Gamma, "1", "what it doesn't name, left")
eq(V.module.db.preset, "performance", "the preset kept")

-- Protect Values: the graphics menu changes one, ours goes back a moment later.
W.cvars.groundEffectDensity = "48"
W.Fire("CVAR_UPDATE", "graphicsGroundClutter")
W.Advance(0.6)
eq(W.cvars.groundEffectDensity, "32", "put back after the graphics menu")
ns:SetOption("Visuals", "protect", false)
W.cvars.groundEffectDensity = "48"
W.Fire("CVAR_UPDATE", "graphicsGroundClutter")
W.Advance(0.6)
eq(W.cvars.groundEffectDensity, "48", "Protect Values off: left as the menu set it")
ns:SetOption("Visuals", "protect", true)

-- In combat a change waits for it to end.
W.combat = true
V.Apply(gi, 4, true)
eq(W.cvars.giQuality, "1", "held back in combat (the preset's 1 still)")
W.combat = false
W.Fire("PLAYER_REGEN_ENABLED")
eq(W.cvars.giQuality, "4", "set as combat ends")

-- Blizzard's defaults: every one, and nothing kept to put back.
V.ApplyPreset("default")
eq(W.cvars.groundEffectDensity, "40", "the game's default")
check(next(V.module.db.values) == nil, "nothing kept to put back")

-- Dynamic Light: by day its own Day level at once (as the original: a change you see as you
-- turn it on), whatever your own Brightness and Contrast.
W.gameTime = { 12, 0 }
local bright, contrast
for _, def in ipairs(V.SETTINGS) do
    if def.cvar == "Brightness" then bright = def elseif def.cvar == "Contrast" then contrast = def end
end
V.Apply(bright, 47, true)
V.Apply(contrast, 61, true)
ns:SetOption("Visuals", "dynamic", true)
eq(tonumber(W.cvars.Contrast), 50, "noon: its Day level at once, not your 61")
eq(tonumber(W.cvars.Brightness), 50, "and its brightness")
ns:SetOption("Visuals", "dynamic", false)
eq(tonumber(W.cvars.Contrast), 61, "off: your contrast back at once")
V.Apply(bright, 50, true)
V.Apply(contrast, 50, true)
-- Midnight: there at once when turned on; later changes are eased.
W.gameTime = { 0, 0 }
ns:SetOption("Visuals", "dynamic", true)
eq(tonumber(W.cvars.Brightness), 24, "midnight with the moon up: Moonlit")
eq(tonumber(W.cvars.Gamma), 0.88, "gamma too")
-- No moon: Midnight all night.
DL.SetValue("moon", false)
eq(tonumber(W.cvars.Brightness), 18, "Moon off: Midnight")
DL.SetValue("moon", true)
-- Dusk: half way into the dark, the Dusk level.
W.gameTime = { 20, 0 }
DL.Changed()
eq(tonumber(W.cvars.Brightness), 32, "sunset, half the twilight gone: Dusk")
W.gameTime = { 0, 0 }
-- A zone at half strength: half the change.
W.place = { map = 1429, x = 0.5, y = 0.5 }
DL.SetZoneStrength(50)
eq(tonumber(W.cvars.Brightness), 37, "half the night in a zone at half strength")
DL.SetZoneStrength(100)
-- Brightness's own share: none, it stays at the day's.
DL.SetValue("multBrightness", 0)
eq(tonumber(W.cvars.Brightness), 50, "Brightness at 0%: the day's")
DL.SetValue("multBrightness", 100)
-- Indoors at night: Indoors at Night.
W.indoors = true
DL.Changed()
eq(tonumber(W.cvars.Brightness), 34, "a house at night")
-- A cave: dark whatever the hour.
W.gameTime = { 12, 0 }
W.subzone = "Fargodeep Mine"
W.Advance(10)
eq(tonumber(W.cvars.Brightness), 16, "a cave at noon: Cave")
W.indoors, W.subzone = false, nil
-- A capital at night: lifted back toward the day.
W.gameTime, W.zoneText = { 0, 0 }, "Orgrimmar"
DL.Changed()
eq(tonumber(W.cvars.Brightness), 32, "Orgrimmar at night: 30% of the way back to the day")
W.zoneText = "Undercity"
DL.Changed()
eq(tonumber(W.cvars.Brightness), 30, "Undercity: its own")
W.zoneText = nil
-- A light buff on: brighter by Light Boost.
W.buffs = { { name = "Torch" } }
DL.SetValue("lights", "torch, lantern")
eq(tonumber(W.cvars.Brightness), 29, "a torch lit: 5 brighter")
W.buffs = {}
DL.SetValue("lights", "")
W.Advance(10)
eq(tonumber(W.cvars.Brightness), 24, "the torch out: the night again")
-- Your Brightness is kept for when it's off; the night is its own level.
V.Apply(bright, 60, true)
eq(V.module.db.values.Brightness, 60, "your brightness kept")
eq(tonumber(W.cvars.Brightness), 24, "the night its own")
-- Defaults: every value back.
DL.SetValue("cave", { 10, 10, 0.8 })
DL.Reset()
eq(next(V.module.db.light), nil, "Defaults: nothing of yours left")
-- A Day level of your own: the day starts there.
W.gameTime = { 12, 0 }
DL.SetValue("day", { 55, 45, 1 })
eq(tonumber(W.cvars.Brightness), 55, "your Day level at noon")
DL.SetValue("day", { 50, 50, 1 })
-- Capitals by their map, whatever the zone's name (any language): Stormwind's streets lifted.
W.gameTime, W.place, W.zoneText = { 0, 0 }, { map = 1453, x = 0.5, y = 0.5 }, "Sturmwind"
DL.Changed()
eq(DL.Place(), "capital", "Stormwind by its map")
eq(tonumber(W.cvars.Brightness), 32, "lifted 30% back to the day at night")
W.place = { map = 1458, x = 0.5, y = 0.5 }
eq(DL.Place(), "undercity", "Undercity by its map")
W.zoneText = nil
-- A zone's own Day light: the day starts there in that zone only; a district counts for its zone.
W.gameTime, W.place = { 12, 0 }, { map = 1411, x = 0.5, y = 0.5 }
W.maps[9001], W.mapTypes[9001] = 1411, 5
DL.SetZoneDay({ 62, 55, 1 }, 1411)
DL.Changed()
eq(tonumber(W.cvars.Brightness), 62, "Durotar's own Day light at noon")
W.place = { map = 9001, x = 0.5, y = 0.5 }
DL.Changed()
eq(tonumber(W.cvars.Brightness), 62, "and in a district of it")
W.place = { map = 1429, x = 0.5, y = 0.5 }
DL.Changed()
eq(tonumber(W.cvars.Brightness), 50, "elsewhere: Day")
DL.SetZoneDay(nil, 1411)
eq(DL.ZoneDay(1411), nil, "back to following Day")
-- Every zone of Kalimdor and the Eastern Kingdoms, for the page's picker.
W.maps[1411], W.maps[1429], W.maps[1453] = 1414, 1415, 1415
W.mapNames[1414], W.mapNames[1415], W.mapNames[1411], W.mapNames[1429], W.mapNames[1453] =
    "Kalimdor", "Eastern Kingdoms", "Durotar", "Elwynn Forest", "Stormwind City"
local zones = DL.ZoneList()
eq(#zones, 2, "both continents")
eq(zones[2].name .. ":" .. zones[2].zones[1].name .. "," .. zones[2].zones[2].name, "Eastern Kingdoms:Elwynn Forest,Stormwind City",
    "each with its zones and cities, by name")
-- Day from your own Brightness and Contrast, to fine-tune from.
DL.DayFromYours()
eq(DL.Value("day")[1], 60, "Use My Brightness and Contrast: Day starts from yours")
DL.SetValue("day", { 50, 50, 1 })
-- Something else changes the brightness: put back on the next look; in combat too.
W.gameTime = { 0, 0 }
DL.Changed()
local want = W.cvars.Brightness
W.cvars.Brightness = "70"
W.combat = true
W.Advance(1)
eq(W.cvars.Brightness, want, "the game's Options changed it: Dynamic Light puts its own back, even in combat")
W.combat = false
W.gameTime = { 12, 0 }
-- Leaving Undercity: an even blend over City Fade, never a jump of more than a point or so a step.
W.gameTime, W.zoneText, W.place = { 12, 0 }, "Undercity", { map = 1458, x = 0.5, y = 0.5 }
DL.Changed()
eq(tonumber(W.cvars.Brightness), 30, "in Undercity")
W.zoneText, W.place = "Tirisfal Glades", { map = 1420, x = 0.5, y = 0.5 }
local biggest, previous = 0, 30
for _ = 1, 300 do -- 15 seconds, a step at a time
    W.Advance(0.05)
    local b = tonumber(W.cvars.Brightness)
    biggest = math.max(biggest, math.abs(b - previous))
    previous = b
end
check(previous > 35 and previous < 45, "half way out after half of City Fade: " .. previous)
check(biggest <= 1, "never more than a point a step: " .. biggest)
W.Advance(16)
eq(tonumber(W.cvars.Brightness), 50, "the day's light once City Fade is over")
-- Elsewhere eased as eyes adjust: most of the way in the first second, there in a few.
W.indoors, W.subzone = true, "Fargodeep Mine"
for _ = 1, 20 do W.Advance(0.05) end
local after = tonumber(W.cvars.Brightness)
check(after > 16 and after < 30, "into a cave: most of the way after a second: " .. after)
W.Advance(5)
eq(tonumber(W.cvars.Brightness), 16, "there in a few")
W.indoors, W.subzone = false, nil
-- Off: your light back.
ns:SetOption("Visuals", "dynamic", false)
eq(tonumber(W.cvars.Brightness), 60, "Dynamic Light off: your brightness")

-- Gamma is yours too: kept for while Dynamic Light is off.
local gamma
for _, def in ipairs(V.SETTINGS) do if def.cvar == "Gamma" then gamma = def end end
V.Apply(gamma, 1.1, true)
eq(W.cvars.Gamma, "1.1", "your gamma, Dynamic Light off")
ns:SetOption("Visuals", "dynamic", true)
eq(tonumber(W.cvars.Gamma), 1, "Dynamic Light on: its Day gamma")
check(V.Dynamic(gamma), "the Gamma row says Dynamic Light sets it")
ns:SetOption("Visuals", "dynamic", false)
eq(W.cvars.Gamma, "1.1", "off: your gamma back")

-- The page: one scrolling column; Dynamic Light's sections only while it's on.
C_SettingsUtil.OpenSettingsPanel(L.VISUALS_TITLE)
check(#W.categories[L.VISUALS_TITLE].frame._children > 0, "the page filled")
local function stackOf(name)
    for _, child in ipairs(W.categories[name].frame._children) do
        local inner = child._kind == "ScrollFrame" and child:GetScrollChild()
        if inner and inner.entries then return inner end
    end
end
local stack = stackOf(L.VISUALS_TITLE)
local function shownRows()
    local n = 0
    for _, entry in ipairs(stack.entries) do if entry.frame:IsShown() then n = n + 1 end end
    return n
end
-- The graphics settings in two columns, Dynamic Light under them across the page.
local columns = stack.entries[1].frame._children
local function rowsIn(column) return #column.entries end
check(#columns == 2 and rowsIn(columns[1]) >= 10 and rowsIn(columns[2]) >= 8,
    "Look, Image and World Detail left; Lighting and Camera right")
check(#stack.entries >= 40, "then Dynamic Light across the page")
local offRows = shownRows()
-- The Sky toggle stays visible while the rest of the sky rows are hidden.
local skyShown = shownRows()
V.module.db.skyNightOnly = false
V.UpdateSky()
local sky = _G.ForeverGearboxVisualsSky
local skyTexture = sky and sky._children and sky._children[1]
check(sky and skyTexture, "the sky frame and texture exist")
check(skyTexture._gradient and skyTexture._gradient[1] == "VERTICAL", "the sky uses a vertical gradient")
local topAlpha = skyTexture._gradient[2].a or skyTexture._gradient[2][4]
local bottomAlpha = skyTexture._gradient[3].a or skyTexture._gradient[3][4]
check(topAlpha and bottomAlpha and topAlpha ~= bottomAlpha, "the top and bottom gradient alphas differ")

local function gradientTopAlpha()
    local g = skyTexture and skyTexture._gradient
    local top = g and g[2]
    return top and (top.a or top[4]) or 0
end

local function gradientTopColor()
    local g = skyTexture and skyTexture._gradient
    local top = g and g[2]
    if not top then return 0, 0, 0 end
    return top.r or top[1] or 0, top.g or top[2] or 0, top.b or top[3] or 0
end

-- Hidden by day, visible by night again without needing an explicit toggle.
ns:SetOption("Visuals", "skyNightOnly", true)
ns:SetOption("Visuals", "skyHideFlyingOrIndoors", false)
W.gameTime = { 12, 0 }
W.Advance(2)
check(not sky:IsShown(), "day with Night Only: sky fades out and hides")
W.gameTime = { 0, 0 }
W.Advance(2)
check(sky:IsShown(), "night after day: sky fades in again")
check(gradientTopAlpha() > 0, "night: gradient alpha is above zero")

-- Indoors event hides it promptly, then outdoors shows it again.
ns:SetOption("Visuals", "skyHideFlyingOrIndoors", true)
W.indoors = true
W.Fire("ZONE_CHANGED_INDOORS")
W.Advance(1)
check(not sky:IsShown(), "indoors: sky fades out")
W.indoors = false
W.Fire("ZONE_CHANGED_INDOORS")
W.Advance(1)
check(sky:IsShown(), "outdoors: sky fades back in")

-- Color darkness darkens the tint independently from alpha.
ns:SetOption("Visuals", "skyNightOnly", false)
ns:SetOption("Visuals", "skyDynamicTime", false)
ns:SetOption("Visuals", "skyGradientIntensity", 1)
ns:SetOption("Visuals", "skyColorDarkness", 0)
W.Advance(1)
local r0, g0, b0 = gradientTopColor()
ns:SetOption("Visuals", "skyColorDarkness", 1)
W.Advance(1)
local r1, g1, b1 = gradientTopColor()
check(r1 < r0 and g1 < g0 and b1 < b0, "Color Darkness darkens the gradient tint")

ns:SetOption("Visuals", "skyEnabled", false)
check(shownRows() < skyShown, "sky off: the detail rows hide")
check(shownRows() >= 1, "sky off: the toggle stays visible")
ns:SetOption("Visuals", "skyEnabled", true)
check(shownRows() == skyShown, "sky on: the detail rows come back")
ns:SetOption("Visuals", "skyDynamicTime", true)
W.gameTime = { 6, 30 }
local before = V.SkyAlpha()
V.module.db.skySunriseHour = 10
check(V.SkyAlpha() ~= before, "the sky reads its own sunrise time")
ns:SetOption("Visuals", "dynamic", true)
local afterDynamic = V.SkyAlpha()
V.module.db.skySunriseHour = 6
check(V.SkyAlpha() ~= afterDynamic, "the sky keeps its own clock even while Dynamic Light is on")
ns:SetOption("Visuals", "dynamic", false)
ns:SetOption("Visuals", "dynamic", true)
check(shownRows() > offRows + 30, "Dynamic Light on: its sections show")
local now
for _, entry in ipairs(stack.entries) do
    local text = rawget(entry.frame, "text") and entry.frame.text:GetText()
    if text and text:find("Now:", 1, true) then now = text end
end
check(now and now:find("Brightness", 1, true) ~= nil, "a line says what it sets now: " .. tostring(now))
-- Blizzard Default: the game's own look, Dynamic Light off too.
V.ApplyPreset("default")
eq(V.module.db.dynamic, false, "Blizzard Default turns Dynamic Light off")
eq(shownRows(), offRows, "and its sections hide")

-- Off: the page leaves Forever++'s list.
ns:SetEnabled("Visuals", false)
eq(pageNames(), "Profiles,Changelog,About", "off again: no pages")
finish()
