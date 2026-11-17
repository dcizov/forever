--[[
    Forever Gearbox - Fishing
    What a fishing helper shows (casting and lures are Fishing Cast's, Modules/Gathering/
    FishingCast.lua). While a fishing pole is in your main hand:

        Fishing 152 +25 (177)   Zone 130   Lure 7:32

    a line with your skill, the bonus the game counts from your gear, lure and food
    (GetProfessionInfo's modifier, so no gear list is kept here; what the game says is read by
    Modules/Gathering/FishingState.lua), the skill the zone's water needs
    (ns.FishingZones, Modules/Gathering/FishingZones.lua: red while fish get away, yellow when only
    the coast is beyond you, green once both are within it), and the lure's time left (the pole's
    temporary enchant). It warns when you cast without a lure while one is in your bags, once per
    zone when you cast where your skill is too low, and once when a lure is about to run out.
    Ideas from Fishing Buddy, CFC and FishFry; no code from them.
]]

local _, ns = ...
local L = ns.L

local format, floor = string.format, math.floor
local C_Item, C_Spell = C_Item, C_Spell
local State = assert(ns.FishingState, "Fishing.lua loads after FishingState.lua")
local poleEquipped, fishingSkill, lureLeft, lureInBags, zoneSkill =
    State.PoleEquipped, State.Skill, State.LureLeft, State.LureInBags, State.ZoneSkill
local LURE_TIME_UNKNOWN = State.LURE_TIME_UNKNOWN

local FISHING_SPELL = 7620         -- Classic's Fishing (Forever++ FishingCast: Mainline's isn't in Forever)
local TOP_SKILL = 300              -- Forever's highest rank; below it a full rank wants the next one
local NO_LURE_EVERY = 60           -- seconds between two no-lure warnings
local LURE_LOW = 60                -- the lure's time turns yellow under this

local function clockText(seconds)
    seconds = floor(seconds)
    return format("%d:%02d", seconds / 60, seconds % 60)
end

---------------------------------------------------------------------------
-- The module
---------------------------------------------------------------------------

local ANCHOR = { "TOP", "BOTTOM", 0, -60 } -- under the minimap

local M = ns:NewModule("Fishing", {
    attach = "FishingCast", -- a section on Forever++'s FishingCast page (Core/Attach.lua)
    title = L.FISHING_TITLE,
    category = "gathering",
    group = L.GROUP_FISHING,
    description = L.FISHING_DESC,
    added = "1.8.0",
    defaults = ns.Widgets.DisplayDefaults({
        info = true,
        zone = true,
        warnNoLure = true,
        warnZone = true,
        warnLureEnding = true,
        lureWarnAt = 30,
        sound = false,
    }, ANCHOR),
    options = ns.Widgets.DisplayOptions({
        { key = "info", type = "checkbox", label = L.FISHING_INFO, tooltip = L.FISHING_INFO_TIP },
        { key = "zone", type = "checkbox", label = L.FISHING_ZONE, tooltip = L.FISHING_ZONE_TIP, added = "1.8.1" },
        { key = "warnNoLure", type = "checkbox", label = L.FISHING_WARN_NO_LURE, tooltip = L.FISHING_WARN_NO_LURE_TIP,
          section = L.FISHING_WARNINGS },
        { key = "warnZone", type = "checkbox", label = L.FISHING_WARN_ZONE, tooltip = L.FISHING_WARN_ZONE_TIP,
          added = "1.8.1" },
        { key = "warnLureEnding", type = "checkbox", label = L.FISHING_WARN_ENDING, tooltip = L.FISHING_WARN_ENDING_TIP,
          slider = "lureWarnAt" },
        { key = "lureWarnAt", type = "slider", label = L.FISHING_WARN_AT, min = 15, max = 120, step = 15,
          format = function(v) return format(L.FISHING_SECONDS, v) end, tooltip = L.FISHING_WARN_AT_TIP },
        { key = "sound", type = "checkbox", label = L.FISHING_SOUND, tooltip = L.FISHING_SOUND_TIP },
    }),
    features = { "info", "warnNoLure", "warnZone", "warnLureEnding" },
})

local display -- added below
local ticker
local warnedEnding = false -- the lure in use has had its running-out warning
local lastNoLure = -NO_LURE_EVERY
local zoneLow, zoneHigh  -- what the zone you're in needs (zoneSkill), read on zone changes
local warnedZone = false -- the zone you're in has had its skill-too-low warning

local function warn(text)
    UIErrorsFrame:AddMessage(text, 1, 0.1, 0.1, 1)
    if M.db.sound then PlaySound(SOUNDKIT.RAID_WARNING, "Master") end
end

-- "Zone 130" (or "Zone 130/205" with a coast that needs more), colored against `total`.
local function zoneText(total)
    if not zoneLow then return "" end
    local color = total < zoneLow and "|cffff2020" or total < zoneHigh and "|cffffd100" or "|cff20ff20"
    local need = zoneHigh > zoneLow and format("%d/%d", zoneLow, zoneHigh) or tostring(zoneLow)
    return "   " .. color .. format(L.FISHING_ZONE_NEEDS, need) .. "|r"
end

-- The line's text, or nil without Fishing.
local function infoText()
    local rank, maxRank, modifier, name = fishingSkill()
    if not rank then return nil end
    local text = modifier > 0 and format(L.FISHING_SKILL_BONUS, name, rank, modifier, rank + modifier)
        or format(L.FISHING_SKILL, name, rank)
    if rank >= maxRank and maxRank < TOP_SKILL then text = text .. "  |cffff8000" .. L.FISHING_RANK_CAP .. "|r" end
    if M.db.zone then text = text .. zoneText(rank + modifier) end
    local left = lureLeft()
    if not left then
        -- Red when there's one in your bags to put on, gray when there isn't.
        local color = lureInBags() and "|cffff2020" or "|cff808080"
        return text .. "   " .. color .. L.FISHING_NO_LURE .. "|r"
    end
    if left == LURE_TIME_UNKNOWN then return text .. "   " .. L.FISHING_LURE_ON end
    local color = left < LURE_LOW and "|cffffd100" or "|cffffffff"
    return text .. "   " .. color .. format(L.FISHING_LURE, clockText(left)) .. "|r"
end

local function checkLureEnding(pole)
    local left = pole and lureLeft()
    if not (left and left <= M.db.lureWarnAt) then
        warnedEnding = false -- no lure, or plenty left: the next one gets its warning
    elseif M.db.warnLureEnding and not warnedEnding then
        warnedEnding = true
        warn(format(L.FISHING_LURE_ENDING, clockText(left)))
    end
end

local update

-- Once a second, only while a pole is in hand.
local function syncTicker(pole)
    if pole and not M:IsPending(ticker) then
        ticker = M:NewTicker(1, function() update() end)
    elseif not pole then
        M:CancelTimer(ticker)
    end
end

update = function()
    local pole = poleEquipped()
    syncTicker(pole)
    checkLureEnding(pole)
    local text = pole and M.db.info and infoText()
    if text then display:SetLine(text) end
    display:SetShown(text)
end

local function requestUpdate() M:Soon(update) end

local function isFishing(spellID)
    if not ns.Plain(spellID) then return false end
    return spellID == FISHING_SPELL or C_Spell.GetSpellName(spellID) == C_Spell.GetSpellName(FISHING_SPELL)
end

-- No lure on, and one in your bags to put on: at most once a minute.
local function checkNoLure()
    if not M.db.warnNoLure or lureLeft() then return end
    local lure = lureInBags()
    local now = GetTime()
    if not lure or now - lastNoLure < NO_LURE_EVERY then return end
    lastNoLure = now
    warn(format(L.FISHING_NO_LURE_WARNING, C_Item.GetItemNameByID(lure) or L.FISHING_A_LURE))
end

-- Your skill below what the zone's water needs: once per zone.
local function checkZone()
    if not (M.db.warnZone and zoneLow) or warnedZone then return end
    local rank, _, modifier = fishingSkill()
    if not rank or rank + modifier >= zoneLow then return end
    warnedZone = true
    warn(format(L.FISHING_ZONE_WARNING, zoneLow, rank + modifier))
end

local function onChannelStart(_, _, unit, _, spellID)
    if unit ~= "player" or not isFishing(spellID) then return end
    checkNoLure()
    checkZone()
end

local function readZone()
    local low, high = zoneSkill()
    if low ~= zoneLow or high ~= zoneHigh then warnedZone = false end
    zoneLow, zoneHigh = low, high
end

local function onZoneChanged()
    readZone()
    requestUpdate()
end

local function fillTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(L.FISHING_TITLE, 1, 0.82, 0)
    GameTooltip:AddLine(L.FISHING_TOOLTIP, 1, 1, 1, true)
end

display = ns.Widgets.AddDisplay(M, { name = "ForeverGearboxFishing", relativeTo = Minimap,
    onEnter = fillTooltip,
    sample = format(L.FISHING_SKILL_BONUS, L.FISHING_TITLE, 152, 25, 177) .. "   " .. format(L.FISHING_ZONE_NEEDS, 130)
        .. "   " .. format(L.FISHING_LURE, "7:32") })

M:AddCommand("fishing", nil, L.FISHING_CMD_DESC, function()
    local text = infoText()
    M:Reply(text or L.FISHING_UNTRAINED)
end)

function M:OnEnable()
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", requestUpdate)
    self:RegisterEvent("UNIT_INVENTORY_CHANGED", function(_, _, unit)
        if unit == "player" then requestUpdate() end
    end)
    self:RegisterEvent("SKILL_LINES_CHANGED", requestUpdate)
    self:RegisterEvent("CHAT_MSG_SKILL", requestUpdate)
    self:RegisterEvent("BAG_UPDATE_DELAYED", requestUpdate)
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", onZoneChanged)
    self:RegisterEvent("ZONE_CHANGED", onZoneChanged)
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", onChannelStart)
    readZone()
    update()
end

function M:OnSettingChanged()
    update()
end

function M:DebugLine()
    local rank, maxRank, modifier = fishingSkill()
    return format(L.FISHING_DEBUG, tostring(rank), tostring(maxRank), tostring(modifier),
        tostring(poleEquipped()), tostring(lureLeft()), tostring(zoneLow), tostring(zoneHigh))
end
