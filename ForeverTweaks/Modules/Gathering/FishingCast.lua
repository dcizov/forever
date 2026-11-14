--[[
    Forever Tweaks - Fishing Cast
    With a fishing pole in hand, right-click twice quickly on the open world (not on a creature or
    a window, standing still) to cast Fishing; a right-click on the bobber still loots it.
      * Casting is protected, so the second click doesn't cast from our code: releasing the first
        puts a temporary override binding on the right mouse button, which the game then runs
        itself; it comes off when the cast starts or the moment passes. Never armed in combat.
      * Apply Lure: when the pole has no lure and one is in your bags, that double-click puts the
        lure on the pole instead (a secure button using the item on the main hand, Blizzard's
        `target-slot`); the next one casts.
      * Louder Bobber: while Fishing channels, sound effects go to full and music down, so the
        splash is easy to hear; your own volumes come back a moment after (and at the next login
        if a reload cut a cast short).
      * Combat Warning: a red line when combat starts with the pole still in hand.
    Each is left to Forever++ while its own is on (Fishing Cast, Auto Weapon Buff).
    Adapted from Forever++'s Fishing Cast by xIGBClutchIx (MIT License).
]]

local _, ns = ...
local L = ns.L

local GetTime, next, tonumber, tostring = GetTime, next, tonumber, tostring
local Plain = ns.Plain
local OtherAddons = ns.OtherAddons
local State = assert(ns.FishingState, "FishingCast.lua loads after FishingState.lua")

local FISHING = 7620 -- Classic's Fishing (Mainline's isn't in Forever's data)
local MAINHAND = State.MAINHAND
local LURE_BUTTON = "ForeverTweaksLureButton"
local COVERS = {
    cast = { { "ForeverPlusPlus", "FishingCast" } },
    applyLure = { { "ForeverPlusPlus", "AutoWeaponBuff" } },
}

local M = ns:NewModule("FishingCast", {
    title = L.FCAST_TITLE,
    category = "gathering",
    description = L.FCAST_DESC,
    added = "1.9.2",
    defaults = { speed = 400, applyLure = true, louderBobber = false, combatWarning = true,
        saved = {} }, -- data: console variable -> your own value while Louder Bobber has changed it
    options = {
        { key = "speed", type = "slider", label = L.FCAST_SPEED, tooltip = L.FCAST_SPEED_TIP, min = 200, max = 600,
          step = 50, format = "%d ms" },
        { key = "applyLure", type = "checkbox", label = L.FCAST_LURE, tooltip = L.FCAST_LURE_TIP },
        { key = "louderBobber", type = "checkbox", label = L.FCAST_LOUDER, tooltip = L.FCAST_LOUDER_TIP },
        { key = "combatWarning", type = "checkbox", label = L.FCAST_COMBAT, tooltip = L.FCAST_COMBAT_TIP },
    },
})

M.notice = OtherAddons.CoveredNotices(M, COVERS.cast, L.FCAST_WHAT_CAST)
OtherAddons.CoveredNotices(M, COVERS.applyLure, L.FCAST_WHAT_LURE, M.notice)

local castCovered = function() return OtherAddons.CoveredBy(M, COVERS.cast) ~= nil end

---------------------------------------------------------------------------
-- Double right-click
---------------------------------------------------------------------------

local owner, lureButton -- secure buttons, made once (a frame can't be removed)
local lastClick, armed, disarmTimer = 0, false, nil

local function disarm()
    if armed and not InCombatLockdown() then
        ClearOverrideBindings(owner)
        armed = false
    end
end

-- Over the bare world: Forever answers an empty list there, not WorldFrame.
local function overWorld()
    local foci = GetMouseFoci()
    return not foci or foci[1] == nil or foci[1] == WorldFrame
end

local function canStart()
    local speed = Plain(GetUnitSpeed("player"))
    return overWorld() and not UnitExists("mouseover") and speed == 0 and not Plain(UnitChannelInfo("player"))
        and State.PoleEquipped()
end

-- The lure to put on first: with Apply Lure on (and not Forever++'s), the pole bare, one in the bags.
local function lureToApply()
    if not M.db.applyLure or OtherAddons.CoveredBy(M, COVERS.applyLure) or State.LureLeft() then return nil end
    return State.LureInBags()
end

-- What the second click does: put a lure on, or cast.
local function arm()
    local lure = lureToApply()
    if lure then
        lureButton:SetAttribute("type", "item")
        lureButton:SetAttribute("item", "item:" .. lure)
        lureButton:SetAttribute("target-slot", MAINHAND)
        SetOverrideBindingClick(owner, true, "BUTTON2", LURE_BUTTON, "LeftButton")
    else
        local name = C_Spell.GetSpellName(FISHING)
        if not name then return end
        SetOverrideBindingSpell(owner, true, "BUTTON2", name)
    end
    armed = true
end

-- The first right-click is only noted; the binding goes on when it's released, so it's in place
-- when the second press comes (arming during the press was too late for the game to see it).
local function onMouseDown(_, _, button)
    if InCombatLockdown() then return end
    if armed then -- the second click: leave the binding for it, the cast takes it off
        lastClick = 0
        return
    end
    lastClick = (button == "RightButton" and not castCovered() and canStart()) and GetTime() or 0
end

local function onMouseUp(_, _, button)
    if InCombatLockdown() or armed or button ~= "RightButton" or lastClick == 0 then return end
    local window = M.db.speed / 1000
    if GetTime() - lastClick >= window then
        lastClick = 0
        return
    end
    arm()
    M:CancelTimer(disarmTimer)
    disarmTimer = M:After(window, function()
        lastClick = 0
        disarm()
    end)
end

---------------------------------------------------------------------------
-- Louder Bobber
---------------------------------------------------------------------------

local SFX_ON, SFX_VOLUME, MUSIC_VOLUME = "Sound_EnableSFX", "Sound_SFXVolume", "Sound_MusicVolume"
local QUIET_MUSIC, RESTORE_DELAY = 0.1, 5
local restoreTimer

local function setSaved(cvar, value)
    local saved = M.db.saved
    if saved[cvar] == nil then saved[cvar] = C_CVar.GetCVar(cvar) end
    C_CVar.SetCVar(cvar, value)
end

local function restoreSound()
    M:CancelTimer(restoreTimer)
    local saved = M.db.saved
    for cvar, value in pairs(saved) do
        C_CVar.SetCVar(cvar, value)
        saved[cvar] = nil
    end
end

local function louder()
    M:CancelTimer(restoreTimer)
    setSaved(SFX_ON, "1")
    setSaved(SFX_VOLUME, "1")
    -- Only ever lower the music: a player who keeps it quieter keeps their value.
    local music = tonumber(C_CVar.GetCVar(MUSIC_VOLUME) or "")
    if music and music > QUIET_MUSIC then setSaved(MUSIC_VOLUME, tostring(QUIET_MUSIC)) end
end

local function isFishing(spellID)
    spellID = Plain(spellID)
    return spellID ~= nil and C_Spell.GetSpellName(spellID) == C_Spell.GetSpellName(FISHING)
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

local function onCastStart(_, _, unit)
    if unit == "player" then disarm() end
end

local function onChannelStart(_, _, unit, _, spellID)
    if unit ~= "player" then return end
    disarm()
    if M.db.louderBobber and not castCovered() and isFishing(spellID) then louder() end
end

local function onChannelStop(_, _, unit)
    if unit == "player" and next(M.db.saved) ~= nil then
        M:CancelTimer(restoreTimer)
        restoreTimer = M:After(RESTORE_DELAY, restoreSound)
    end
end

-- Combat starts (just before the lockdown): never leave a right-click casting Fishing.
local function onCombat()
    lastClick = 0
    if armed then ns:AfterCombat(M, disarm) end
    if M.db.combatWarning and not castCovered() and State.PoleEquipped() then
        UIErrorsFrame:AddMessage(L.FCAST_COMBAT_TEXT, 1, 0.1, 0.1)
    end
end

function M:OnEnable()
    restoreSound() -- not fishing now: anything saved is left from a reload mid-cast
    if not owner then
        owner = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
        lureButton = CreateFrame("Button", LURE_BUTTON, UIParent, "SecureActionButtonTemplate")
        lureButton:RegisterForClicks("AnyUp", "AnyDown")
    end
    lastClick = 0
    self:RegisterEvent("GLOBAL_MOUSE_DOWN", onMouseDown)
    self:RegisterEvent("GLOBAL_MOUSE_UP", onMouseUp)
    self:RegisterEvent("UNIT_SPELLCAST_START", onCastStart)
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", onChannelStart)
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", onChannelStop)
    self:RegisterEvent("PLAYER_REGEN_DISABLED", onCombat)
end

function M:OnDisable()
    if armed then ns:AfterCombat(M, disarm) end
    restoreSound()
end

function M:OnSettingChanged(key)
    if key == "louderBobber" and not self.db.louderBobber then restoreSound() end
end

function M:DebugLine()
    return armed and L.FCAST_ARMED or L.FCAST_IDLE
end
