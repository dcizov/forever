--[[
    Forever Gearbox - Advanced Graphics (module key Visuals)
    How the game looks, on top of its own graphics menu, in one page (VisualsPage.lua): the image
    (brightness, contrast, gamma, sharpening), Forever's new lighting and atmosphere (indirect
    lighting, fog, god rays, bloom, water, weather), Dynamic Light (DynamicLight.lua: brightness,
    contrast and gamma following the time of day and where you are), world detail (grass, distant
    objects) and the camera and the nearest object's name (SETTINGS, in SECTIONS); with presets
    (PRESETS: from Performance to Maximum, the classic or modern look, Blizzard's defaults, and the
    values before the module first ran). Each is a console variable (a few set others with it, as
    the game's menu does: `linked`); one this client doesn't have isn't shown.

      * The page: its own entry under Forever++ in Settings while the module is on, as Forever++'s
        Console Variables has; without Forever++, a window of its own.
      * Protect Values: what you set here is put back when the game's graphics menu (one of its
        "graphics..." variables) or a login overwrites it.
      * Dynamic Light and the image: while it's on it sets Brightness, Contrast and Gamma (`light`);
        the page's are yours, for while it's off. Blizzard Default and Before turn it off too.
    A change in combat waits for it to end. A setting another addon makes its own (`conflict`: an
    addon loaded) is left to it. Loot sparkles are Forever++'s Quest Item Sparkles (3.3.0 took
    them out of here).
    The idea and the settings of ForeverVisuals by greynor (no license: its choices and console
    variables, none of its code).
]]

local _, ns = ...
local L = ns.L

local ipairs, pairs, tonumber, tostring, type, math, format, next = ipairs, pairs, tonumber, tostring, type, math, string.format, next

local REAPPLY_WAIT = 0.5  -- seconds after the graphics menu changes before ours go back
local LOGIN_AGAIN = 5     -- seconds after login to put them back again (account settings come late)

local Visuals = {}
ns.Visuals = Visuals

-- The page's sections, in order; Dynamic Light's come after Lighting (`light`: VisualsPage.lua).
Visuals.SECTIONS = {
    { key = "image", title = L.VISUALS_IMAGE },
    { key = "new", title = L.VISUALS_NEW, light = true },
    { key = "world", title = L.VISUALS_WORLD }, { key = "view", title = L.VISUALS_VIEW },
}

local function cvarDefault(cvar) return tonumber(C_CVar.GetCVarDefault(cvar)) or 0 end

-- The nearest object's icon and name all around you, about 15 yards out; off: the game's own.
local function softTarget(value)
    local on = value == 1
    return {
        SoftTargetIconGameObject = on and 1 or cvarDefault("SoftTargetIconGameObject"),
        SoftTargetLowPriorityIcons = on and 1 or cvarDefault("SoftTargetLowPriorityIcons"),
        SoftTargetInteractArc = on and 2 or cvarDefault("SoftTargetInteractArc"),
        SoftTargetInteractRange = on and 15 or cvarDefault("SoftTargetInteractRange"),
    }
end

-- kind "slider" (min, max, step, format) or "checkbox"; `linked(value)` the variables set with it.
Visuals.SETTINGS = {
    -- The image (Brightness, Contrast and Gamma: Dynamic Light's while it's on).
    { cvar = "Brightness", section = "image", kind = "slider", label = L.VISUALS_BRIGHTNESS, tip = L.VISUALS_BRIGHTNESS_TIP,
      min = 0, max = 100, light = true },
    { cvar = "Contrast", section = "image", kind = "slider", label = L.VISUALS_CONTRAST, tip = L.VISUALS_CONTRAST_TIP,
      min = 0, max = 100, light = true },
    { cvar = "Gamma", section = "image", kind = "slider", label = L.VISUALS_GAMMA, tip = L.VISUALS_GAMMA_TIP,
      min = 0.5, max = 1.5, step = 0.01, format = "%.2f", light = true },
    { cvar = "ResampleAlwaysSharpen", section = "image", kind = "checkbox", label = L.VISUALS_SHARPEN,
      tip = L.VISUALS_SHARPEN_TIP },
    { cvar = "ResampleSharpness", section = "image", kind = "slider", label = L.VISUALS_SHARPNESS,
      tip = L.VISUALS_SHARPNESS_TIP, min = 0, max = 1, step = 0.05, format = "%.2f" },
    -- Forever's new lighting and atmosphere.
    { cvar = "giQuality", section = "new", kind = "slider", label = L.VISUALS_GI, tip = L.VISUALS_GI_TIP, min = 1, max = 4,
      linked = function(value) return { RenderFormat = value >= 2 and 2 or 1 } end },
    { cvar = "volumeFog", section = "new", kind = "checkbox", label = L.VISUALS_FOG, tip = L.VISUALS_FOG_TIP },
    { cvar = "volumeFogLevel", section = "new", kind = "slider", label = L.VISUALS_FOG_LEVEL, tip = L.VISUALS_FOG_LEVEL_TIP,
      min = 0, max = 4 },
    { cvar = "sunShafts", section = "new", kind = "slider", label = L.VISUALS_SUN, tip = L.VISUALS_SUN_TIP, min = 0, max = 2 },
    { cvar = "bloomUserMult", section = "new", kind = "slider", label = L.VISUALS_BLOOM, tip = L.VISUALS_BLOOM_TIP,
      min = 0, max = 1, step = 0.1, format = "%.1f" },
    { cvar = "pbrLiquidDetail", section = "new", kind = "slider", label = L.VISUALS_WATER, tip = L.VISUALS_WATER_TIP,
      min = 0, max = 2 },
    { cvar = "weatherDensity", section = "new", kind = "slider", label = L.VISUALS_WEATHER, tip = L.VISUALS_WEATHER_TIP,
      min = 0, max = 3 },
    -- World detail: grass and distant objects.
    { cvar = "groundEffectDensity", section = "world", kind = "slider", label = L.VISUALS_GRASS, tip = L.VISUALS_GRASS_TIP,
      min = 16, max = 256, step = 16 },
    { cvar = "groundEffectDist", section = "world", kind = "slider", label = L.VISUALS_GRASS_DIST,
      tip = L.VISUALS_GRASS_DIST_TIP, min = 40, max = 500, step = 10 },
    { cvar = "groundEffectFade", section = "world", kind = "slider", label = L.VISUALS_GRASS_FADE,
      tip = L.VISUALS_GRASS_FADE_TIP, min = 0, max = 500, step = 10 },
    { cvar = "lodObjectCullSize", section = "world", kind = "slider", label = L.VISUALS_CULL, tip = L.VISUALS_CULL_TIP,
      min = 0, max = 30 },
    { cvar = "lodObjectFadeScale", section = "world", kind = "slider", label = L.VISUALS_OBJECT_FADE,
      tip = L.VISUALS_OBJECT_FADE_TIP, min = 50, max = 300, step = 10 },
    -- The camera, and what's shown around you.
    { cvar = "cameraDistanceMaxZoomFactor", section = "view", kind = "slider", label = L.VISUALS_ZOOM,
      tip = L.VISUALS_ZOOM_TIP, min = 1, max = 4, step = 0.1, format = "%.1f" },
    { cvar = "SoftTargetNameplateInteract", section = "view", kind = "checkbox", label = L.VISUALS_NEAREST,
      tip = L.VISUALS_NEAREST_TIP, linked = softTarget, conflict = "ForeverLootSparkles" },
}

-- Presets: what each sets (the rest stays). "default" and "original" set every one.
Visuals.PRESETS = {
    { key = "performance", label = L.VISUALS_PRESET_PERFORMANCE, tip = L.VISUALS_PRESET_PERFORMANCE_TIP, values = {
        giQuality = 1, volumeFog = 1, volumeFogLevel = 1, sunShafts = 0, pbrLiquidDetail = 0, groundEffectDensity = 32,
        groundEffectDist = 80, groundEffectFade = 60, weatherDensity = 1, lodObjectCullSize = 19, lodObjectFadeScale = 90,
        ResampleAlwaysSharpen = 0 } },
    { key = "balanced", label = L.VISUALS_PRESET_BALANCED, tip = L.VISUALS_PRESET_BALANCED_TIP, values = {
        giQuality = 2, volumeFog = 1, volumeFogLevel = 3, sunShafts = 1, pbrLiquidDetail = 1, groundEffectDensity = 128,
        groundEffectDist = 200, groundEffectFade = 180, weatherDensity = 2, lodObjectCullSize = 14, lodObjectFadeScale = 150,
        cameraDistanceMaxZoomFactor = 2.6, ResampleAlwaysSharpen = 1 } },
    { key = "max", label = L.VISUALS_PRESET_MAX, tip = L.VISUALS_PRESET_MAX_TIP, values = {
        giQuality = 4, volumeFog = 1, volumeFogLevel = 4, sunShafts = 2, pbrLiquidDetail = 2, bloomUserMult = 1,
        groundEffectDensity = 256, groundEffectDist = 500, groundEffectFade = 380, weatherDensity = 3, lodObjectCullSize = 8,
        lodObjectFadeScale = 200, cameraDistanceMaxZoomFactor = 4, ResampleAlwaysSharpen = 1 } },
    { key = "classic", label = L.VISUALS_PRESET_CLASSIC, tip = L.VISUALS_PRESET_CLASSIC_TIP, values = {
        giQuality = 1, volumeFog = 0, sunShafts = 0, pbrLiquidDetail = 0, bloomUserMult = 0 } },
    { key = "modern", label = L.VISUALS_PRESET_MODERN, tip = L.VISUALS_PRESET_MODERN_TIP, values = {
        giQuality = 4, volumeFog = 1, volumeFogLevel = 4, sunShafts = 2, pbrLiquidDetail = 2, bloomUserMult = 1 } },
    { key = "default", label = L.VISUALS_PRESET_DEFAULT, tip = L.VISUALS_PRESET_DEFAULT_TIP },
    { key = "original", label = L.VISUALS_PRESET_ORIGINAL, tip = L.VISUALS_PRESET_ORIGINAL_TIP },
}

local M = ns:NewModule("Visuals", {
    title = L.VISUALS_TITLE,
    category = "interface",
    description = L.VISUALS_DESC,
    added = "3.2.0",
    defaults = {
        enabled = false, protect = true, dynamic = false, dynamicStrength = 100,
        skyEnabled = true, skyDynamicTime = true, skyNightOnly = true, skyHideFlyingOrIndoors = true,
        skyGradientHeight = 250, skyDayAlpha = 0.25, skyNightAlpha = 0.5,
        skyGradientIntensity = 0.65, skySunriseHour = 6, skySunsetHour = 20, skyTwilightHours = 1,
        values = {},   -- data: cvar -> the value you set here (Protect Values puts it back)
        original = {}, -- data: cvar -> its value when the module first ran (the Before preset)
        preset = "",   -- data: the preset last applied ("" once a value is changed by hand)
        zones = {},    -- data: mapID -> Dynamic Light's strength there, percent
        zoneDay = {},  -- data: mapID -> Dynamic Light's Day light there (a level), when it has its own
        light = {},    -- data: Dynamic Light's values you changed (DynamicLight.Defaults has the rest)
    },
    options = {
        { key = "protect", type = "checkbox", label = L.VISUALS_PROTECT, tooltip = L.VISUALS_PROTECT_TIP },
        { key = "dynamic", type = "checkbox", label = L.VISUALS_DYNAMIC, tooltip = L.VISUALS_DYNAMIC_TIP,
          slider = "dynamicStrength" },
        { key = "dynamicStrength", type = "slider", label = L.VISUALS_DYNAMIC_STRENGTH, tooltip = L.VISUALS_DYNAMIC_STRENGTH_TIP,
          min = 0, max = 150, step = 10, format = "%d%%", requires = "dynamic" },
        { key = "skyEnabled", type = "checkbox", label = L.VISUALS_SKY_ENABLE, tooltip = L.VISUALS_SKY_ENABLE_TIP },
        { key = "skyDynamicTime", type = "checkbox", label = L.VISUALS_SKY_DYNAMIC, tooltip = L.VISUALS_SKY_DYNAMIC_TIP },
        { key = "skyNightOnly", type = "checkbox", label = L.VISUALS_SKY_NIGHT_ONLY, tooltip = L.VISUALS_SKY_NIGHT_ONLY_TIP },
        { key = "skyHideFlyingOrIndoors", type = "checkbox", label = L.VISUALS_SKY_HIDE, tooltip = L.VISUALS_SKY_HIDE_TIP },
        { key = "skyGradientHeight", type = "slider", label = L.VISUALS_SKY_HEIGHT, tooltip = L.VISUALS_SKY_HEIGHT_TIP,
          min = 120, max = 500, step = 10, format = "%d px" },
        { key = "skyDayAlpha", type = "slider", label = L.VISUALS_SKY_DAY, tooltip = L.VISUALS_SKY_DAY_TIP,
          min = 0, max = 1, step = 0.05, format = "%.2f" },
        { key = "skyNightAlpha", type = "slider", label = L.VISUALS_SKY_NIGHT, tooltip = L.VISUALS_SKY_NIGHT_TIP,
          min = 0, max = 1, step = 0.05, format = "%.2f" },
        { key = "skyGradientIntensity", type = "slider", label = L.VISUALS_SKY_GRADIENT, tooltip = L.VISUALS_SKY_GRADIENT_TIP,
          min = 0, max = 1, step = 0.05, format = "%.2f" },
        { key = "skySunriseHour", type = "slider", label = L.VISUALS_SKY_SUNRISE, tooltip = L.VISUALS_SKY_SUNRISE_TIP,
          min = 0, max = 24, step = 0.5, format = "%.1f h" },
        { key = "skySunsetHour", type = "slider", label = L.VISUALS_SKY_SUNSET, tooltip = L.VISUALS_SKY_SUNSET_TIP,
          min = 0, max = 24, step = 0.5, format = "%.1f h" },
        { key = "skyTwilightHours", type = "slider", label = L.VISUALS_SKY_TWILIGHT, tooltip = L.VISUALS_SKY_TWILIGHT_TIP,
          min = 0, max = 6, step = 0.25, format = "%.2f h" },
    },
})
Visuals.module = M

---------------------------------------------------------------------------
-- Setting values
---------------------------------------------------------------------------

local pending = {}  -- cvar -> text, set as combat ends
local ours = false  -- true while we set one (CVAR_UPDATE fires inside SetCVar)

-- A value as the game keeps it: "4", "0.3" (not "0.30000000000000004").
local function text(value)
    if value == math.floor(value) then return tostring(math.floor(value)) end
    return (format("%.3f", value):gsub("0+$", ""):gsub("%.$", ""))
end

function Visuals.Has(cvar) return C_CVar.GetCVar(cvar) ~= nil end

local skyFrame
local skyTexture
local skyFade = 0
local skyFadeTarget = 0
local SKY_FADE_SPEED = 4

local function skyTimeAlpha()
    local db = M.db
    local light = ns.DynamicLight
    -- Hybrid: Dynamic Light sets the time curve (sunrise, sunset, twilight), while the sky's
    -- Day Alpha and Night Alpha remain independent ramp endpoints that can be tuned separately.
    local sunrise = light and light.Value and light.Value("sunrise") or (db.skySunriseHour or 6)
    local sunset = light and light.Value and light.Value("sunset") or (db.skySunsetHour or 20)
    local twilight = light and light.Value and light.Value("twilight") or (db.skyTwilightHours or 1)
    local dayAlpha = db.skyDayAlpha or 0.25
    local nightAlpha = db.skyNightAlpha or 0.5

    local hour, minute = GetGameTime()
    local now = (hour or 12) + ((minute or 0) / 60)

    local dawnStart = sunrise - twilight
    local dawnEnd = sunrise + twilight
    local duskStart = sunset - twilight
    local duskEnd = sunset + twilight

    if now >= dawnEnd and now <= duskStart then
        return dayAlpha
    elseif now > dawnStart and now < dawnEnd then
        local t = (now - dawnStart) / (dawnEnd - dawnStart)
        return nightAlpha + (dayAlpha - nightAlpha) * t
    elseif now > duskStart and now < duskEnd then
        local t = (now - duskStart) / (duskEnd - duskStart)
        return dayAlpha + (nightAlpha - dayAlpha) * t
    end
    return nightAlpha
end

local function skyNightGate()
    local db = M.db
    if not db.skyNightOnly then return 1 end
    local light = ns.DynamicLight
    local sunrise = light and light.Value and light.Value("sunrise") or (db.skySunriseHour or 6)
    local sunset = light and light.Value and light.Value("sunset") or (db.skySunsetHour or 20)
    local twilight = light and light.Value and light.Value("twilight") or (db.skyTwilightHours or 1)
    local dayAlpha = db.skyDayAlpha or 0.25
    local nightAlpha = db.skyNightAlpha or 0.5
    local hour, minute = GetGameTime()
    local now = (hour or 12) + ((minute or 0) / 60)
    local dawnStart = sunrise - twilight
    local dawnEnd = sunrise + twilight
    local duskStart = sunset - twilight
    local duskEnd = sunset + twilight

    if now >= dawnEnd and now <= duskStart then
        return 0
    elseif now > dawnStart and now < dawnEnd then
        local t = (now - dawnStart) / (dawnEnd - dawnStart)
        return math.max(0, math.min(1, 1 - t))
    elseif now > duskStart and now < duskEnd then
        local t = (now - duskStart) / (duskEnd - duskStart)
        return math.max(0, math.min(1, t))
    elseif now < dawnStart or now > duskEnd then
        return 1
    end

    local base = skyTimeAlpha()
    local span = math.max(0.05, nightAlpha - dayAlpha)
    return math.max(0, math.min(1, (base - dayAlpha) / span))
end

function Visuals.SkyAlpha()
    local db = M.db
    if not db.skyEnabled then return 0 end
    local fly = rawget(_G, "IsFlying") and _G.IsFlying() or false
    local inside = rawget(_G, "IsIndoors") and _G.IsIndoors() or false
    if db.skyHideFlyingOrIndoors and (fly or inside) then return 0 end

    local intensity = db.skyGradientIntensity or 0.65
    local alpha = db.skyDynamicTime and skyTimeAlpha() or 1
    return alpha * (db.skyNightOnly and skyNightGate() or 1) * intensity
end

local function skySetGradient(alpha)
    if not skyTexture then return end
    local topR, topG, topB = 0.35, 0.48, 0.72
    local bottomR, bottomG, bottomB = 0.02, 0.06, 0.16
    if rawget(skyTexture, "SetGradient") and rawget(_G, "CreateColor") then
        local top = _G.CreateColor(topR, topG, topB, alpha * 0.9)
        local bottom = _G.CreateColor(bottomR, bottomG, bottomB, alpha)
        skyTexture:SetGradient("VERTICAL", top, bottom)
        return
    end
    if rawget(skyTexture, "SetGradientAlpha") then
        skyTexture:SetGradientAlpha("VERTICAL", topR, topG, topB, alpha * 0.9, bottomR, bottomG, bottomB, alpha)
        return
    end
    skyTexture:SetColorTexture(bottomR, bottomG, bottomB, alpha)
end

function Visuals.UpdateSky()
    if not skyFrame or not skyTexture or not M.db then return end
    skyFrame:SetHeight(M.db.skyGradientHeight or 250)

    local fadeTarget = 1
    if not M.db.skyEnabled then
        fadeTarget = 0
    else
        local fly = rawget(_G, "IsFlying") and _G.IsFlying() or false
        local inside = rawget(_G, "IsIndoors") and _G.IsIndoors() or false
        if M.db.skyHideFlyingOrIndoors and (fly or inside) then fadeTarget = 0 end
    end
    skyFadeTarget = fadeTarget
    if fadeTarget > 0 then
        skyFrame:Show()
    end

    local alpha = Visuals.SkyAlpha()
    if fadeTarget <= 0 or alpha <= 0 then
        skySetGradient(0)
        return
    end
    skySetGradient(alpha)
end

function Visuals.StartSky()
    if not skyFrame then
        skyFrame = CreateFrame("Frame", "ForeverGearboxVisualsSky", UIParent)
        skyFrame:SetFrameStrata("BACKGROUND")
        skyFrame:SetFrameLevel(0)
        skyFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        skyFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
        skyFrame:SetHeight(M.db.skyGradientHeight or 250)
        skyFrame:EnableMouse(false)
        skyTexture = skyFrame:CreateTexture(nil, "BACKGROUND")
        skyTexture:SetAllPoints(true)
        skyTexture:SetColorTexture(1, 1, 1, 1)
        skyFrame:SetScript("OnUpdate", function(self, elapsed)
            if math.abs(skyFade - skyFadeTarget) > 0.005 then
                if skyFade < skyFadeTarget then
                    skyFade = math.min(skyFadeTarget, skyFade + elapsed * SKY_FADE_SPEED)
                else
                    skyFade = math.max(skyFadeTarget, skyFade - elapsed * SKY_FADE_SPEED)
                end
                self:SetAlpha(skyFade)
            elseif skyFade ~= skyFadeTarget then
                skyFade = skyFadeTarget
                self:SetAlpha(skyFade)
            end
            if skyFadeTarget <= 0.01 and skyFade <= 0.01 then self:Hide() end
            if skyFadeTarget > 0 and not self:IsShown() then self:Show() end
        end)
        skyFade, skyFadeTarget = 0, 0
        skyFrame:SetAlpha(0)
        skyFrame:Hide()
    end
    Visuals.UpdateSky()
end

function Visuals.StopSky()
    if skyFrame then
        skyFadeTarget = 0
        skyFrame:Hide()
        skyFrame:SetAlpha(0)
    end
end

-- A variable's value now (or the one waiting for combat to end), as a number.
function Visuals.Get(cvar) return tonumber(pending[cvar] or C_CVar.GetCVar(cvar)) end

-- Sets one variable (after combat, in combat). `anyTime`: at once even in combat (Dynamic Light's
-- brightness, contrast and gamma: not protected, and a fight shouldn't hold the light back).
function Visuals.SetCVar(cvar, value, anyTime)
    local wanted = text(value)
    if InCombatLockdown() and not anyTime then
        pending[cvar] = wanted
        return
    end
    ours = true
    C_CVar.SetCVar(cvar, wanted)
    ours = false
end

-- The other addon that makes a setting its own, if it's loaded.
function Visuals.Conflict(def)
    return def.conflict and C_AddOns.IsAddOnLoaded(def.conflict) and def.conflict or nil
end

-- Whether Dynamic Light runs a setting now (Brightness, Contrast, Gamma; Gamma only with its
-- Gamma Too).
function Visuals.Dynamic(def)
    if not (def.light and M.active and M.db.dynamic) then return false end
    return def.cvar ~= "Gamma" or ns.DynamicLight.Value("gamma") == true
end

local function round(def, value)
    local step = def.step or 1
    return math.floor(value / step + 0.5) * step
end

-- Sets a setting (and what goes with it) and keeps it for Protect Values. `byHand`: from its
-- control, not a preset.
function Visuals.Apply(def, value, byHand)
    if Visuals.Conflict(def) or not Visuals.Has(def.cvar) then return end
    -- A control's value on its steps; a preset's or the game's default as it is (40 isn't one).
    if byHand then value = round(def, value) end
    M.db.values[def.cvar] = value
    if byHand then M.db.preset = "" end
    if Visuals.Dynamic(def) then return ns.DynamicLight.Changed() end -- its daytime value
    Visuals.SetCVar(def.cvar, value)
    for cvar, linked in pairs(def.linked and def.linked(value) or {}) do
        Visuals.SetCVar(cvar, linked)
        M.db.values[cvar] = linked
    end
end

local byCVar = {}
for _, def in ipairs(Visuals.SETTINGS) do byCVar[def.cvar] = def end
local presetByKey = {}
for _, preset in ipairs(Visuals.PRESETS) do presetByKey[preset.key] = preset end

function Visuals.ApplyPreset(key)
    local preset = presetByKey[key]
    if not preset then return end
    for _, def in ipairs(Visuals.SETTINGS) do
        local value = preset.values and preset.values[def.cvar]
        if key == "default" then value = tonumber(C_CVar.GetCVarDefault(def.cvar)) end
        if key == "original" then value = tonumber(M.db.original[def.cvar]) end
        if value ~= nil then Visuals.Apply(def, value) end
    end
    -- Blizzard's or yours from before: from now on the game's menu decides again, and the picture is
    -- the game's own (Dynamic Light off).
    if key == "default" or key == "original" then
        M.db.values = {}
        if M.db.dynamic then ns:SetOption(M.name, "dynamic", false) end
    end
    M.db.preset = key
    M:Reply(format(L.VISUALS_PRESET_APPLIED, preset.label))
    if Visuals.Redraw then Visuals.Redraw() end
end

-- Puts back each value you set that something else changed since. Returns how many.
function Visuals.Reapply()
    local count = 0
    for cvar, value in pairs(M.db.values) do
        local def = byCVar[cvar]
        local now = Visuals.Get(cvar)
        if not (def and (Visuals.Conflict(def) or Visuals.Dynamic(def))) and now and math.abs(now - value) > 0.001 then
            Visuals.SetCVar(cvar, value)
            count = count + 1
        end
    end
    return count
end

---------------------------------------------------------------------------
-- Turning on and off
---------------------------------------------------------------------------

local function reapplyNow()
    if not M.db.protect then return end
    local count = Visuals.Reapply()
    if count > 0 then M:Reply(format(L.VISUALS_REAPPLIED, count)) end
    if Visuals.Redraw then Visuals.Redraw() end
end

local function onCVar(_, _, name)
    if ours or not M.db.protect or type(name) ~= "string" then return end
    name = name:lower()
    if name:find("^graphics") or name:find("^raidgraphics") then M:After(REAPPLY_WAIT, reapplyNow) end
end

function M:OnEnable()
    -- The values before the module first ran (the Before preset), each the first time it's seen.
    for _, def in ipairs(Visuals.SETTINGS) do
        if self.db.original[def.cvar] == nil and Visuals.Has(def.cvar) then self.db.original[def.cvar] = C_CVar.GetCVar(def.cvar) end
    end
    self:RegisterEvent("CVAR_UPDATE", onCVar)
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        reapplyNow()
        self:After(LOGIN_AGAIN, reapplyNow)
        Visuals.UpdateSky()
    end)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        for cvar, wanted in pairs(pending) do
            pending[cvar] = nil
            Visuals.SetCVar(cvar, tonumber(wanted))
        end
    end)
    reapplyNow()
    ns.VisualsPage.Show(true)
    ns.DynamicLight.Start()
    Visuals.StartSky()
end

function M:OnDisable()
    ns.VisualsPage.Show(false)
    ns.DynamicLight.Stop()
    Visuals.StopSky()
end

function M:OnSettingChanged(key)
    if key == "dynamic" then
        if self.db.dynamic then ns.DynamicLight.Start() else ns.DynamicLight.Stop() end
    elseif key == "dynamicStrength" then
        ns.DynamicLight.Changed()
    elseif key == "protect" then
        reapplyNow()
    elseif key:match("^sky") then
        Visuals.UpdateSky()
    end
    if Visuals.Redraw then Visuals.Redraw() end
end

-- The page, from Forever++'s Modules page and /fg visuals.
M.actions = { { name = L.VISUALS_OPEN, button = L.VISUALS_OPEN_BUTTON, description = L.VISUALS_OPEN_TIP,
    fn = function() ns.VisualsPage.Open() end } }

ns.Slash.Add("SKYTWEAK", { "/skytweak", "/st" }, function(msg)
    local command = (msg or ""):lower():match("^%s*(.-)%s*$")
    if command == "toggle" then
        ns:SetOption("Visuals", "skyEnabled", not M.db.skyEnabled)
        return
    end
    ns.VisualsPage.Open()
end)

function M:DebugLine()
    local set = 0
    for _ in pairs(self.db.values) do set = set + 1 end
    return format(L.VISUALS_DEBUG, set, next(pending) and L.VISUALS_DEBUG_WAITING or "")
end
