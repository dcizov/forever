--[[
    Forever Gearbox - Nameplate Distance
    Keeps nameplates at a shorter range while you're resting and a wider one while you aren't,
    using the game's own IsResting() signal so inns work the same as a macro. The CVar is written
    only while safe, and a pending change waits until combat ends instead of being pushed mid-fight.
]]

local _, ns = ...
local L = ns.L
local format = string.format

local NAMEPLATE_CVAR = "nameplateMaxDistance"
local DEFAULT_RESTING = 25
local DEFAULT_NORMAL = 45
local REST_MIN, REST_MAX = 5, 90

local pendingValue

local M = ns:NewModule("NameplateDistance", {
    title = L.NPDIST_TITLE,
    category = "interface",
    description = L.NPDIST_DESC,
    added = "3.3.0",
    defaults = {
        enabled = false,
        restingDistance = DEFAULT_RESTING,
        normalDistance = DEFAULT_NORMAL,
        restoreOnDisable = true,
        original = nil,
    },
    options = {
        { key = "restingDistance", type = "slider", label = L.NPDIST_RESTING,
            tooltip = L.NPDIST_RESTING_TIP, min = REST_MIN, max = REST_MAX, step = 1,
            format = "%d yd" },
        { key = "normalDistance", type = "slider", label = L.NPDIST_NORMAL,
            tooltip = L.NPDIST_NORMAL_TIP, min = REST_MIN, max = REST_MAX, step = 1,
            format = "%d yd" },
        { key = "restoreOnDisable", type = "checkbox", label = L.NPDIST_RESTORE,
            tooltip = L.NPDIST_RESTORE_TIP },
    },
})

local function distanceNow()
    local value = tonumber(C_CVar.GetCVar(NAMEPLATE_CVAR))
    if value == nil then return 0 end
    return math.floor(value + 0.5)
end

local function recordOriginal()
    if M.db.original == nil then M.db.original = C_CVar.GetCVar(NAMEPLATE_CVAR) end
end

local function chooseDistance()
    return IsResting() and M.db.restingDistance or M.db.normalDistance
end

local function writeDistance(value)
    local yards = tonumber(value)
    if not yards then return end
    recordOriginal()
    if InCombatLockdown() then
        pendingValue = yards
        return
    end
    pendingValue = nil
    if C_CVar.SetCVar(NAMEPLATE_CVAR, yards) == false then
        M:Debug("failed to set", NAMEPLATE_CVAR, yards)
        return false
    end
    return true
end

local function applyNow()
    if not M.active then return end
    writeDistance(chooseDistance())
end

function M:OnEnable()
    pendingValue = nil
    self:RegisterEvent("PLAYER_ENTERING_WORLD", applyNow)
    self:RegisterEvent("PLAYER_UPDATE_RESTING", applyNow)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if pendingValue == nil then return end
        local value = pendingValue
        pendingValue = nil
        writeDistance(value)
    end)
    applyNow()
end

function M:OnDisable()
    pendingValue = nil
    if self.db.restoreOnDisable and self.db.original ~= nil then
        C_CVar.SetCVar(NAMEPLATE_CVAR, self.db.original)
    end
end

function M:OnSettingChanged(key)
    if key == "restingDistance" or key == "normalDistance" then applyNow() end
end

function M:DebugLine()
    return format(L.NPDIST_DEBUG, distanceNow(), IsResting() and L.NPDIST_RESTING_STATE or L.NPDIST_NORMAL_STATE)
end
