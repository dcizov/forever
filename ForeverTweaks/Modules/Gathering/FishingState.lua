--[[
    Forever Tweaks - Modules/Gathering/FishingState.lua
    Fishing's state (Modules/Gathering/Fishing.lua and Fishing Cast use it):
    what the game says about your fishing, read when asked and never kept. Whether a fishing pole
    is in your main hand, your Fishing skill, the lure on it and in your bags, and the skill the
    zone you're in needs (from ns.FishingZones, Modules/Gathering/FishingZones.lua).
]]

local _, ns = ...

local select, pairs, ipairs = select, pairs, ipairs
local C_Item, C_Map = C_Item, C_Map

local State = {}
ns.FishingState = State

State.MAINHAND = 16
local MAINHAND = State.MAINHAND
-- Shiny Bauble, Nightcrawlers, Bright Baubles, Aquadynamic Fish Attractor, Flesh Eating Worm,
-- Aquadynamic Fish Lens (Forever++'s Auto Weapon Buff's list).
local LURES = { 6529, 6530, 6532, 6533, 7307, 6811 }
local MAX_MAP_PARENTS = 4          -- a subzone or city map up to its zone
local WEAPON, FISHING_POLE = Enum.ItemClass.Weapon, Enum.ItemWeaponSubclass.Fishingpole

function State.IsPole(itemID)
    if not itemID then return false end
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    return classID == WEAPON and subclassID == FISHING_POLE
end

function State.PoleEquipped() return State.IsPole(GetInventoryItemID("player", MAINHAND)) end

-- rank, rank cap, bonus, name; nil without Fishing.
function State.Skill()
    local index = select(4, GetProfessions())
    if not index then return nil end
    local name, _, rank, maxRank, _, _, _, modifier = GetProfessionInfo(index)
    return rank, maxRank, modifier or 0, name
end

-- A lure is on but the game keeps its time secret (LureLeft's answer then).
State.LURE_TIME_UNKNOWN = math.huge

-- Seconds left on the main hand's temporary enchant (with a pole in hand, its lure), or nil.
-- Forever's C_Item.GetWeaponEnchantInfo(weaponSlot) gives a list of { hasEnchant, timeLeft (ms),
-- ... } per slot, as its buff frame and Forever++'s Auto Weapon Buff read it; either value may
-- be secret.
function State.LureLeft()
    local left
    for _, enchant in pairs(C_Item.GetWeaponEnchantInfo(Enum.WeaponSlot.MainHand)) do
        local has, time = enchant.hasEnchant, enchant.timeLeft
        -- A secret answer means "a lure, time unknown", not "no lure", so it is told apart from nil.
        if issecretvalue(has) or (has and issecretvalue(time)) then return State.LURE_TIME_UNKNOWN end -- secret apart from nil
        if has and (not left or time < left) then left = time end
    end
    return left and left / 1000
end

-- The first lure in your bags (its item ID), or nil.
function State.LureInBags()
    for _, id in ipairs(LURES) do
        if C_Item.GetItemCount(id) > 0 then return id end
    end
end

-- What the zone you're in needs: inland, coast (the same when it has one), or nil for a zone
-- with no fishing data. A dungeon's or subzone's map is looked up through its parents.
function State.ZoneSkill()
    local mapID = C_Map.GetBestMapForUnit("player")
    for _ = 1, MAX_MAP_PARENTS do
        if not ns.Plain(mapID) then return nil end
        local zone = ns.FishingZones[mapID]
        if zone then return zone[1], zone[2] or zone[1] end
        local info = C_Map.GetMapInfo(mapID)
        mapID = info and info.parentMapID
    end
end
