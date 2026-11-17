--[[
    Forever Gearbox - Layer Info
    Shows which layer you're on, in a small line on screen.

    How: every NPC's GUID carries the zone UID of the world copy (layer) it lives in, the fifth
    part of "Creature-0-server-instance-zoneUID-npcID-spawnUID". Forever obfuscates the server
    and spawn parts (build 70425), not the zone UID, so the same NPC reads the same layer for
    everyone. Forever gives addons no combat log, so the NPCs you target, mouse over, or see a
    nameplate of are read. A GUID can be a secret value (in instances): those are skipped.

    The number: with Nova World Buffs installed, its layer number (the one most layer addons
    and players use); otherwise the raw zone UID, which is stable but not a small number.
]]

local _, ns = ...
local L = ns.L

local UnitGUID, UnitIsPlayer, UnitName, strsplit, tonumber, GetTime = UnitGUID, UnitIsPlayer, UnitName, strsplit, tonumber, GetTime
local format = string.format

-- Just above the quest tracker, under the minimap: right of center, growing right.
local ANCHOR = { "BOTTOMLEFT", "TOP", 8, 6 }
local NAMEPLATE_CVAR = "nameplateShowFriendlyNpcs"

local M = ns:NewModule("LayerInfo", {
    title = L.LAYER_TITLE,
    category = "interface",
    description = L.LAYER_DESC,
    added = "0.7.0",
    defaults = ns.Widgets.DisplayDefaults({
        enabled = true,
        chat = false,
    }, ANCHOR),
    options = ns.Widgets.DisplayOptions({
        ns.ChatOption(L.LAYER_CHAT_TIP),
    }),
    -- Reading is quickest with friendly NPC nameplates on.
    notice = { requires = { { cvar = NAMEPLATE_CVAR, value = "1" } }, tooltip = L.LAYER_NOTICE_TIP },
})

local display -- added below, once the functions it uses are
local layer, source, seenAt -- the zone UID read last, the NPC it came from, and when
local stale = true          -- after a zone or group change, until an NPC is read again

local function layerNumber()
    local nwb = _G.NWB_CurrentLayer
    if type(nwb) == "number" and nwb > 0 then return nwb end
end

local function update()
    local _, instanceType = IsInInstance()
    if instanceType and instanceType ~= "none" then
        display:SetLine("|cff999999" .. L.LAYER_INSTANCE .. "|r")
    elseif not layer then
        display:SetLine("|cff999999" .. L.LAYER_UNKNOWN .. "|r")
    else
        local text = format(L.LAYER_N, layerNumber() or layer)
        display:SetLine(stale and ("|cff999999" .. text .. "?|r") or text)
    end
end

-- Zone UID from a unit's GUID, or nil (players, pets, secret or odd GUIDs).
local function readUnit(unit)
    if ns.Plain(UnitIsPlayer(unit)) ~= false then return end -- a player, or can't tell
    local guid = UnitGUID(unit)
    guid = ns.Plain(guid)
    if not guid then return end
    local kind, _, _, _, zoneUID = strsplit("-", guid)
    if kind ~= "Creature" and kind ~= "Vehicle" then return end
    zoneUID = tonumber(zoneUID)
    if zoneUID and zoneUID > 0 then return zoneUID end
end

-- Nameplates are read only while the layer may have changed.
local onPlate -- below, after learn

local function setListeningPlates(on)
    if on then M:RegisterEvent("NAME_PLATE_UNIT_ADDED", onPlate) else M:UnregisterEvent("NAME_PLATE_UNIT_ADDED") end
end

local function learn(unit)
    local zoneUID = readUnit(unit)
    if not zoneUID then return end
    local changed = layer ~= nil and zoneUID ~= layer
    layer, source, seenAt = zoneUID, ns.Plain(UnitName(unit)), GetTime()
    stale = false
    -- Known: nameplates (the busiest source) can rest until something may have changed.
    setListeningPlates(false)
    if changed then
        M:Debug("layer changed to", zoneUID)
        M:Print(format(L.LAYER_N, layerNumber() or zoneUID))
        ns:Announce("LAYER_CHANGED", zoneUID, layerNumber())
    end
    update()
end

local function onTarget() learn("target") end
local function onMouseover() learn("mouseover") end
function onPlate(_, _, unit) learn(unit) end

local function markStale()
    stale = true
    setListeningPlates(true)
    update()
end


local function fillTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(L.LAYER_TITLE, 1, 0.82, 0)
    if layer then
        local number = layerNumber()
        if number then GameTooltip:AddDoubleLine(L.LAYER_NWB, number, 1, 1, 1, 1, 1, 1) end
        GameTooltip:AddDoubleLine(L.LAYER_ZONE_UID, layer, 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine(L.LAYER_FROM, source or "?", 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine(L.LAYER_WHEN, format(L.SECONDS_AGO, GetTime() - seenAt), 1, 1, 1, 1, 1, 1)
        if stale then GameTooltip:AddLine(L.LAYER_STALE, 1, 0.5, 0.5, true) end
    else
        GameTooltip:AddLine(L.LAYER_NOT_READ, 1, 1, 1)
    end
    GameTooltip:AddLine(L.LAYER_HOW, 0.7, 0.7, 0.7, true)
end

display = ns.Widgets.AddDisplay(M, {
    name = "ForeverGearboxLayer",
    onEnter = fillTooltip,
    menu = function(add)
        if layer then
            add(L.LAYER_COPY, function() ns:ShowCopyText("LAYER", L.LAYER_COPY_TEXT, tostring(layer)) end)
        end
    end,
})

function M:OnEnable()
    self:RegisterEvent("PLAYER_TARGET_CHANGED", onTarget)
    self:RegisterEvent("UPDATE_MOUSEOVER_UNIT", onMouseover)
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", markStale)
    self:RegisterEvent("PLAYER_ENTERING_WORLD", markStale)
    self:RegisterEvent("GROUP_ROSTER_UPDATE", markStale)
    markStale()
end

function M:OnSettingChanged()
    update()
end

-- For the public API: zone UID, Nova World Buffs' number, and whether it may be out of date;
-- nothing while the module is off.
function M:GetLayer()
    if not self.active then return end
    return layer, layerNumber(), stale
end
