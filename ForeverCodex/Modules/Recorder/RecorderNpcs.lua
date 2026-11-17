--[[
    Forever Codex - Modules/Recorder/RecorderNpcs.lua
    The Recorder's NPC part (Modules/Recorder/Recorder.lua calls these): what a creature is beyond
    its name.

      * Title: the line under its name in its tooltip ("Innkeeper", "<Cenarion Circle>"), read
        when it's first met and again while it has none.
      * Looks: each model a creature was seen with (its display ID), read through an invisible
        model frame off screen from a unit you target, mouse over or deal with (an NPC's window
        open: unit "npc", as friendly NPCs are met only so). The game can take a moment
        to load it, so it's asked again a few times while the unit is still the same one.
      * Wares: what a vendor sells, each time its window opens (MERCHANT_SHOW): the price, how
        many come at once, and whether its stock runs out.
]]

local _, ns = ...

local type, ipairs, CreateFrame = type, ipairs, CreateFrame
local Book, Plain = ns.Book, ns.Plain

local Npcs = {}
ns.RecorderNpcs = Npcs

local PROBE_TRIES, PROBE_WAIT = 4, 0.25

-- Whether a player owns the unit: its tooltip has an owner line ("Name's Pet", "Name's
-- Guardian", a totem's or minion's), so pets and guardians the game doesn't call
-- player-controlled are still left out.
function Npcs.IsOwned(unit)
    local data = C_TooltipInfo.GetUnit(unit)
    for _, line in ipairs(data and data.lines or {}) do
        if line.type == Enum.TooltipDataLineType.UnitOwner then return true end
    end
    return false
end

-- The creature's title from its tooltip's second line, unless that line is its level.
function Npcs.RecordTitle(unit, rec)
    if rec.title then return end
    local data = C_TooltipInfo.GetUnit(unit)
    local line = data and data.lines and data.lines[2]
    local text = line and Plain(line.leftText)
    if type(text) ~= "string" or text == "" or text:find(LEVEL, 1, true) then return end
    rec.title = text
end

---------------------------------------------------------------------------
-- Looks
---------------------------------------------------------------------------

local seenGUIDs = {} -- GUID -> true once its look was read this session
-- Invisible model frames, one for each look being read: one frame shared by two reads could
-- answer with the other creature's display as its model finished loading (every creature then
-- had the look of whichever was read before it).
local freeProbes = {}

local function takeProbe()
    local probe = table.remove(freeProbes)
    if not probe then
        probe = CreateFrame("PlayerModel", nil, UIParent)
        probe:SetSize(64, 64)
        probe:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", -100, -100)
        probe:SetAlpha(0)
    end
    probe:ClearModel()
    return probe
end

local function giveBack(probe)
    probe:ClearModel()
    freeProbes[#freeProbes + 1] = probe
end

-- Reads `unit`'s look into its own probe (kept for each try), while it's still `guid`.
local function readModel(mod, probe, unit, guid, npc, rec, tries)
    if Plain(UnitGUID(unit)) ~= guid then return giveBack(probe) end
    probe:SetUnit(unit)
    local id = Plain(probe:GetDisplayInfo())
    if id and id > 0 then
        giveBack(probe)
        rec.display = rec.display or id
        if not (rec.displays and rec.displays[id]) then
            Book.Mark(rec, "displays", id)
            if Book.Count(rec.displays) > 1 then ns:Announce("CREATURE_LEARNED", npc, "looks") end
        end
    elseif tries < PROBE_TRIES then
        mod:After(PROBE_WAIT, function() readModel(mod, probe, unit, guid, npc, rec, tries + 1) end)
    else
        giveBack(probe)
    end
end

-- Reads the look of the creature `unit` is, once per creature you meet (each one can look different).
function Npcs.RecordLook(mod, unit, npc, rec)
    if unit ~= "target" and unit ~= "mouseover" and unit ~= "npc" then return end
    local guid = Plain(UnitGUID(unit))
    if not guid or seenGUIDs[guid] then return end
    seenGUIDs[guid] = true
    readModel(mod, takeProbe(), unit, guid, npc, rec, 1)
end

---------------------------------------------------------------------------
-- Wares
---------------------------------------------------------------------------

function Npcs.RecordWares()
    local npc = Book.NpcOf(UnitGUID("npc"))
    local rec = npc and Book.Creature(npc)
    if not rec then return end
    local wares = {}
    for i = 1, GetMerchantNumItems() do
        local itemID = Plain(GetMerchantItemID(i))
        local info = C_MerchantFrame.GetItemInfo(i)
        if itemID and info then
            local available = Plain(info.numAvailable)
            wares[itemID] = { price = Plain(info.price) or 0, stack = Plain(info.stackCount) or 1,
                limited = type(available) == "number" and available >= 0 or nil }
            Book.SetItem(itemID, info.name, C_Item.GetItemQualityByID(itemID), info.texture)
        end
    end
    if next(wares) then
        local isNew = rec.wares == nil
        rec.wares = wares
        if isNew then ns:Announce("CREATURE_LEARNED", npc, "wares") end
    end
end
