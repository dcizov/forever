--[[
    Forever Tweaks - Fishing's outfit
    Forever has Classic's equipment slots, with no profession gear slots: fishing gear is ordinary
    gear (a fishing pole, the Lucky Fishing Hat, Nat Pagle's boots). This keeps a fishing outfit
    and swaps it on and off, as Fishing Buddy, CFC and FishFry do (no code from them). Mining,
    Herbalism and Skinning need nothing worn, and gear for them is rare, so only Fishing has one
    (1.8.1 folded the Profession Outfits module, which had one per gathering profession, in here).

    The outfit is the game's own equipment set "FT Fishing", kept by the server and shown in the
    Character window's Equipment Manager. Saving it keeps only the slots holding fishing gear (a
    fishing pole, or an item whose tooltip gives "+N Fishing"), plus the off hand when the main
    hand is in it, so a later armor upgrade is never swapped back off. Wearing it first saves the
    same slots of what you have on into "FT Usual", which swaps back.

    Whether the outfit is on is saved per character, and checked against what you wear before a
    swap: taken off by hand, it isn't on any more, so the next swap puts it on (saving what you
    wear now as Usual) rather than putting an old Usual back.

    Swaps are refused in combat. Combat Weapons: when combat starts with a pole in hand, your
    usual weapons go on (weapon slots can change in combat) and the pole comes back afterwards.

    A part of the Fishing module (module:AddPart): its events follow the module on and off.
]]

local _, ns = ...
local L = ns.L
local M = assert(ns.modules.Fishing, "FishingOutfit.lua loads after Fishing.lua")
local State = assert(ns.FishingState, "FishingOutfit.lua loads after FishingState.lua")

local format, ipairs, pairs, type, select = string.format, ipairs, pairs, type, select
local C_EquipmentSet, C_Item, C_TooltipInfo = C_EquipmentSet, C_Item, C_TooltipInfo

local FIRST_SLOT, LAST_SLOT = 1, 19 -- head to tabard (INVSLOT_HEAD .. INVSLOT_TABARD)
local MAINHAND, OFFHAND = State.MAINHAND, 17
local FISHING = 356 -- the skill line, saved as which outfit is on

local Outfit = {}
local refreshPage -- redraws the module's page while it's built
local tookPole    -- the pole Combat Weapons took off, to put back after combat

-- The game's name for Fishing (the set is named after it), or ours before it's learned.
local function fishingName() return select(4, State.Skill()) or L.FISHING_TITLE end
local function outfitName() return format(L.OUTFITS_SET, fishingName()) end
local setID = C_EquipmentSet.GetEquipmentSetID

-- Whether what's in `slot` is fishing gear: a fishing pole, or a tooltip line with Fishing's name
-- and a "+N" ("Equip: Increased Fishing +20.", an enchant's "Fishing +2").
local function isFishingGear(slot, name)
    local itemID = GetInventoryItemID("player", slot)
    if not itemID then return false end
    if slot == MAINHAND and State.IsPole(itemID) then return true end
    local data = C_TooltipInfo.GetInventoryItem("player", slot)
    for _, line in ipairs(data and data.lines or {}) do
        local text = line.leftText
        if type(ns.Plain(text)) == "string" and text:find(name, 1, true) and text:find("%+%d") then
            return true
        end
    end
    return false
end

-- Saves what you wear in `slots` (slot -> true) as the set `name`, ignoring the other slots.
local function saveSet(name, slots, icon)
    C_EquipmentSet.ClearIgnoredSlotsForSave()
    for slot = FIRST_SLOT, LAST_SLOT do
        if not slots[slot] then C_EquipmentSet.IgnoreSlotForSave(slot) end
    end
    local id = setID(name)
    if id then
        C_EquipmentSet.SaveEquipmentSet(id, icon)
    else
        C_EquipmentSet.CreateEquipmentSet(name, icon)
    end
    C_EquipmentSet.ClearIgnoredSlotsForSave()
end

-- A set's items: slot -> itemID, real items only (an empty slot reads as 0 or -1). Read from
-- its items, not GetIgnoredSlots: in game that reported no slot ignored for a set saved this way.
local function setItems(id)
    local items = {}
    for slot, itemID in pairs(id and C_EquipmentSet.GetItemIDs(id) or {}) do
        if type(slot) == "number" and itemID and itemID > 0 then items[slot] = itemID end
    end
    return items
end

-- An outfit takes the off hand with the main hand: a two-handed pole leaves it empty, and Usual
-- must give the shield back.
local function withOffHand(slots)
    if slots[MAINHAND] then slots[OFFHAND] = true end
    return slots
end

-- The slots an outfit holds (slot -> true).
local function slotsOf(id)
    local slots = {}
    for slot in pairs(setItems(id)) do slots[slot] = true end
    return withOffHand(slots)
end

-- Whether every item of the outfit is on.
local function outfitOn()
    local id = setID(outfitName())
    if not id then return false end
    for slot, itemID in pairs(setItems(id)) do
        if GetInventoryItemID("player", slot) ~= itemID then return false end
    end
    return true
end

-- Whether the outfit is on: as saved, checked against what you wear (out of combat: Combat
-- Weapons has the pole off then). Forgets the saved state when you took it off by hand.
local function checkWearing()
    if M.db.state.wearing and not InCombatLockdown() and not outfitOn() then M.db.state.wearing = nil end
    return M.db.state.wearing ~= nil
end

-- True, after saying why, when outfits can't be swapped now (in combat, or no equipment manager).
local function cannotSwap()
    if InCombatLockdown() then
        ns:Print(L.OUTFITS_IN_COMBAT)
        return true
    end
    if not C_EquipmentSet.CanUseEquipmentSets() then
        ns:Print(L.OUTFITS_NO_MANAGER)
        return true
    end
end

local function saveOutfit()
    if cannotSwap() then return end
    local name, slots, any = fishingName(), {}, false
    for slot = FIRST_SLOT, LAST_SLOT do
        if isFishingGear(slot, name) then slots[slot], any = true, true end
    end
    if not any then return ns:Print(L.OUTFITS_NOTHING) end
    withOffHand(slots)
    local index = select(4, GetProfessions())
    saveSet(outfitName(), slots, index and select(2, GetProfessionInfo(index)))
    ns:Print(L.OUTFITS_SAVED)
end

local function wearUsual()
    if cannotSwap() then return end
    local id = setID(L.OUTFITS_USUAL_SET)
    if not id then return ns:Print(L.OUTFITS_NO_USUAL) end
    C_EquipmentSet.UseEquipmentSet(id)
    M.db.state.wearing = nil
end

local function wear()
    if cannotSwap() then return end
    local id = setID(outfitName())
    if not id then return ns:Print(L.OUTFITS_NOT_SAVED) end
    if not checkWearing() then saveSet(L.OUTFITS_USUAL_SET, slotsOf(id)) end
    C_EquipmentSet.UseEquipmentSet(id)
    M.db.state.wearing = FISHING
end

-- Your fishing outfit on, or your usual gear back (/ft outfit, the Fishing line's menu).
local function toggleOutfit()
    if checkWearing() then return wearUsual() end
    wear()
end

-- The Fishing line's menu: the swap, named for what it does now.
function Outfit:AddMenuEntries(add)
    add(checkWearing() and L.OUTFITS_WEAR_USUAL or L.OUTFITS_WEAR_FISHING, toggleOutfit)
end

-- Combat Weapons ------------------------------------------------------------------------------

local function onCombatStart()
    if not M.db.combatWeapons or not State.PoleEquipped() then return end
    local id = setID(L.OUTFITS_USUAL_SET)
    local items = id and C_EquipmentSet.GetItemIDs(id)
    local weapon = items and items[MAINHAND]
    if not weapon or State.IsPole(weapon) then return end
    tookPole = GetInventoryItemID("player", MAINHAND)
    C_Item.EquipItemByName(weapon, MAINHAND)
    if items[OFFHAND] then C_Item.EquipItemByName(items[OFFHAND], OFFHAND) end
    M:Debug("combat: weapons on, pole", tookPole)
end

local function onCombatEnd()
    if not tookPole then return end
    local pole = tookPole
    tookPole = nil
    C_Item.EquipItemByName(pole, MAINHAND)
end

-- The command and the page ---------------------------------------------------------------------

M:AddCommand("outfit", L.OUTFITS_CMD_USAGE, L.OUTFITS_CMD_DESC, function(args)
    local verb = (args or ""):match("^%s*(%S*)"):lower()
    if verb == "" then return toggleOutfit() end
    if verb == L.OUTFITS_CMD_USUAL then return wearUsual() end
    if verb == L.OUTFITS_CMD_SAVE then return saveOutfit() end
    if verb == L.OUTFITS_CMD_WEAR then return wear() end
    ns:Print(L.OUTFITS_CMD_HELP)
end)

local function itemsText(name)
    local id = setID(name)
    if not id then return L.OUTFITS_EMPTY end
    local names = {}
    for _, itemID in pairs(setItems(id)) do names[#names + 1] = C_Item.GetItemInfo(itemID) or ("#" .. itemID) end
    table.sort(names)
    return #names > 0 and table.concat(names, ", ") or L.OUTFITS_EMPTY
end

-- Under the options: the outfit with Save and Wear beside it and what it holds, then Usual.
function M:BuildPage(stack)
    local Kit = ns.Kit
    if not C_EquipmentSet.CanUseEquipmentSets() then
        Kit.AddTextRow(stack, L.OUTFITS_NO_MANAGER, "GameFontDisableSmall", 10)
        return
    end
    Kit.AddButtonsRow(stack, L.OUTFITS_FISHING, {
        { L.OUTFITS_SAVE, saveOutfit },
        { L.OUTFITS_WEAR, wear },
    }, L.OUTFITS_SAVE_TIP)
    local outfitRow = Kit.AddTextRow(stack, "", "GameFontDisableSmall", 10)
    Kit.AddButtonsRow(stack, L.OUTFITS_USUAL, { { L.OUTFITS_WEAR, wearUsual } }, L.OUTFITS_USUAL_TIP)
    local usualRow = Kit.AddTextRow(stack, "", "GameFontDisableSmall", 10)
    refreshPage = function()
        outfitRow.text:SetText(itemsText(outfitName()))
        usualRow.text:SetText(itemsText(L.OUTFITS_USUAL_SET))
    end
    refreshPage()
    return refreshPage
end

function Outfit:Enable()
    M:RegisterEvent("PLAYER_REGEN_DISABLED", onCombatStart)
    M:RegisterEvent("PLAYER_REGEN_ENABLED", onCombatEnd)
    M:RegisterEvent("EQUIPMENT_SETS_CHANGED", function()
        if refreshPage then refreshPage() end
    end)
end

function Outfit:Disable()
    tookPole = nil
end

M:AddPart(Outfit)
