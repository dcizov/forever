--[[
    Forever Tweaks - Modules/Tooltips/ItemStatColors.lua
    Item Tooltips: Stat Colors and Compare Crafted Gear
      * Stat Colors: each stat line in an item's tooltip ("+6 Spirit", "Equip: Increases your hit
        by 1%.") drawn again in its stat's color (Lib/ItemStats.lua), so the stats an item has read
        at a glance; an Equip: line keeps "Equip:" in Blizzard's green. A line with right text is
        the damage line, never a stat.
      * Compare Crafted Gear: a recipe in your bags that makes gear shows Blizzard's comparison
        with what you wear, as the gear itself would: Usable (gear the client says you can use,
        which counts your level too) or only for your Professions. A recipe's tooltip data has the crafted
        item's link; Blizzard compares a bag item by its GUID on every refresh (each clearing the
        comparison), so right after GameTooltip_ShowCompareItem the comparison is asked again by
        that link, in the same frame (Forever++ found asking from the tooltip's own post call came
        first and was emptied).
    Adapted from Forever++'s Item Tooltips by xIGBClutchIx (MIT License).
]]

local _, ns = ...

local type, setmetatable = type, setmetatable
local ItemTooltip, Kit, Plain, ItemStats = ns.ItemTooltip, ns.TooltipKit, ns.Plain, ns.ItemStats
local Professions = ns.Professions
local Shared = assert(ns.ItemTooltipsShared, "ItemStatColors.lua loads after ItemTooltips.lua")
local M = assert(ns.modules.ItemTooltips, "ItemStatColors.lua loads after ItemTooltips.lua")

---------------------------------------------------------------------------
-- Stat Colors
---------------------------------------------------------------------------

local PLAIN = Enum.TooltipDataLineType.None -- plain stat and Equip: lines
local NONE = {} -- an item whose stats can't be read
local itemStats = setmetatable({}, { __mode = "k" }) -- tooltip data -> the item's stat table

-- The item's stat table, read once per tooltip, for Equip: lines worded as a spell's.
local function statsOf(data)
    local raw = itemStats[data]
    if raw then return raw ~= NONE and raw or nil end
    local link = Plain(data.hyperlink)
    if type(link) ~= "string" then
        local id = ItemTooltip.ItemID(data)
        link = id and ("item:" .. id)
    end
    raw = link and Plain(C_Item.GetItemStats(link))
    raw = type(raw) == "table" and raw or nil
    itemStats[data] = raw or NONE
    return raw
end

local function isEquip(plain)
    local equip = ITEM_SPELL_TRIGGER_ONEQUIP
    return equip ~= "" and plain:sub(1, #equip) == equip
end

-- Draws a stat line again in its stat's color, and says so, so Blizzard's is skipped.
local function colorLine(tooltip, data, lineData)
    if not Shared.IsShown("statColors") or lineData.type ~= PLAIN then return end
    local text = Plain(lineData.leftText)
    if type(text) ~= "string" or text == "" or type(Plain(lineData.rightText)) == "string" then return end
    local plain = Kit.StripCodes(text)
    local key, effect = ItemStats.LineStat(plain, isEquip(plain) and statsOf(data) or nil)
    local color = key and ItemStats.COLORS[key]
    if not color then return end
    local line = plain
    if effect then
        -- "Equip:" stays in the line's own color; the effect takes the stat's.
        local lead = plain:sub(1, #plain - #effect)
        local own = Plain(lineData.leftColor)
        if type(own) == "table" and own.r then lead = Kit.Text(own, lead) end
        line = lead .. Kit.Code(color[1], color[2], color[3]) .. effect .. "|r"
    end
    tooltip:AddLine(line, color[1], color[2], color[3], Plain(lineData.wrapText) == true)
    return true
end

---------------------------------------------------------------------------
-- Compare Crafted Gear
---------------------------------------------------------------------------

local RECIPE = Enum.ItemClass.Recipe
-- The profession that makes a recipe's gear, by the recipe's subclass (Enum.ItemRecipeSubclass:
-- 1 Leatherworking, 2 Tailoring, 3 Engineering, 4 Blacksmithing), as its skill line.
local CRAFTS_GEAR = { [1] = 165, [2] = 197, [3] = 202, [4] = Professions.BLACKSMITHING }

-- The crafted item's link when the tooltip is a bag recipe making gear the setting compares.
local function craftedGear(data)
    local guid, link, recipe = Plain(data.guid), Plain(data.hyperlink), Plain(data.id)
    if type(guid) ~= "string" or type(link) ~= "string" or type(recipe) ~= "number" then return nil end
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(recipe)
    local line = classID == RECIPE and CRAFTS_GEAR[subclassID]
    if not line then return nil end
    local itemID, _, _, equipLoc = C_Item.GetItemInfoInstant(link)
    if not itemID or itemID == recipe or type(equipLoc) ~= "string" or equipLoc == "" then return nil end
    if Plain(C_PlayerInfo.CanUseItem(itemID)) == false then return nil end
    if M.db.craftedCompare == "professions" and not Professions.Rank(line) then return nil end
    return link
end

local function onShowCompare(_, tooltip, anchorFrame)
    if not Shared.IsShown("craftedCompare") then return end
    -- Only when the client compares at all: Shift (the Compare Items modifier) or Always Compare.
    if not (IsModifiedClick("COMPAREITEMS") or C_CVar.GetCVarBool("alwaysCompareItems")) then return end
    tooltip = tooltip or GameTooltip
    local data = tooltip:GetPrimaryTooltipData()
    local link = data and craftedGear(data)
    if link then C_TooltipComparison.CompareItem({ hyperlink = link }, tooltip, anchorFrame) end
end

M:AddPart({
    Enable = function()
        ItemTooltip.ReplaceLine(M, colorLine)
        M:Hook("GameTooltip_ShowCompareItem", onShowCompare)
        M:RegisterEvent("SKILL_LINES_CHANGED", Professions.Forget)
    end,
})
