--[[
    Forever Tweaks - Combat Error Filter
    Hides the red error spam you get while fighting ("Not enough rage", "Ability is not ready yet",
    "Out of range", "You have no target") during combat, kind by kind, and lets it show again
    after. Mainline's error frame hides most of these anyway; Forever's (its Camelot override)
    hides only "Another action is in progress". It uses the error frame's own switch
    (UIErrorsFrame:SetMessageTypeEnabled, the table BLACK_LISTED_MESSAGE_TYPES), and never turns
    back on a kind the game hides itself. Hidden errors are silent too: their voice line doesn't
    play.
    Left to WilduTools' Hide Combat Error Spam while that's on.
]]

local _, ns = ...
local L = ns.L

local ipairs, pairs, rawget, format = ipairs, pairs, rawget, string.format
local OtherAddons = ns.OtherAddons

local COVERS = { { "!WilduTools", "blizzUI_filterCombatErrors" } }

-- Each kind's message types, by their constants' names (not in the API dumps: read with rawget
-- and skipped when missing).
local KINDS = {
    cooldown = { "LE_GAME_ERR_ABILITY_COOLDOWN", "LE_GAME_ERR_SPELL_COOLDOWN", "LE_GAME_ERR_ITEM_COOLDOWN" },
    power = { "LE_GAME_ERR_OUT_OF_RAGE", "LE_GAME_ERR_OUT_OF_ENERGY", "LE_GAME_ERR_OUT_OF_MANA",
        "LE_GAME_ERR_OUT_OF_FOCUS", "LE_GAME_ERR_OUT_OF_COMBO_POINTS", "LE_GAME_ERR_OUT_OF_POWER_DISPLAY" },
    range = { "LE_GAME_ERR_OUT_OF_RANGE", "LE_GAME_ERR_SPELL_OUT_OF_RANGE" },
    target = { "LE_GAME_ERR_GENERIC_NO_VALID_TARGETS", "LE_GAME_ERR_NO_ATTACK_TARGET",
        "LE_GAME_ERR_INVALID_ATTACK_TARGET", "LE_GAME_ERR_BADATTACKFACING", "LE_GAME_ERR_BADATTACKPOS" },
}
local ORDER = { "cooldown", "power", "range", "target" }

local GROUP = { label = L.CERR_KINDS, format = L.CERR_KINDS_COUNT, tooltip = L.CERR_KINDS_TIP }

local M = ns:NewModule("CombatErrors", {
    title = L.CERR_TITLE,
    category = "interface",
    description = L.CERR_DESC,
    added = "1.9.3",
    defaults = { enabled = false, cooldown = true, power = true, range = true, target = true, always = false },
    options = {
        { key = "cooldown", type = "checkbox", label = L.CERR_COOLDOWN, group = GROUP },
        { key = "power", type = "checkbox", label = L.CERR_POWER, group = GROUP },
        { key = "range", type = "checkbox", label = L.CERR_RANGE, group = GROUP },
        { key = "target", type = "checkbox", label = L.CERR_TARGET, group = GROUP },
        { key = "always", type = "checkbox", label = L.CERR_ALWAYS, tooltip = L.CERR_ALWAYS_TIP },
    },
})

M.notice = OtherAddons.CoveredNotices(M, COVERS, L.CERR_WHAT)

local hidden = {} -- message type -> true while we hide it

local function hide(messageType)
    if BLACK_LISTED_MESSAGE_TYPES[messageType] then return end -- the game hides it itself
    UIErrorsFrame:SetMessageTypeEnabled(messageType, false)
    hidden[messageType] = true
end

local function showAll()
    for messageType in pairs(hidden) do UIErrorsFrame:SetMessageTypeEnabled(messageType, true) end
    hidden = {}
end

-- Hides every ticked kind (unless WilduTools does it).
local function hideTicked()
    if OtherAddons.CoveredBy(M, COVERS) then return end
    for _, kind in ipairs(ORDER) do
        if M.db[kind] then
            for _, name in ipairs(KINDS[kind]) do
                local messageType = rawget(_G, name)
                if messageType then hide(messageType) end
            end
        end
    end
end

-- What's ticked hidden now (in combat, or always), the rest shown again.
local function apply()
    showAll()
    if M.db.always or InCombatLockdown() then hideTicked() end
end

function M:OnEnable()
    -- PLAYER_REGEN_DISABLED comes just before combat lockdown (InCombatLockdown still says no).
    self:RegisterEvent("PLAYER_REGEN_DISABLED", function()
        showAll()
        hideTicked()
    end)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function() if not M.db.always then showAll() end end)
    apply()
end

function M:OnDisable() showAll() end
function M:OnSettingChanged() apply() end

function M:DebugLine()
    local n = 0
    for _ in pairs(hidden) do n = n + 1 end
    return format(L.CERR_DEBUG, n)
end
