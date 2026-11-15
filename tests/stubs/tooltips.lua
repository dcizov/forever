--[[
    Forever suite - tests/stubs/tooltips.lua
    The stand-in game's tooltip data processing (pre, post and line calls), colors and the item,
    profession and auction house calls Forever Tweaks' Tooltips category uses, loaded by
    tests/wow.lua after the other stubs.
      W.knownSpells[spellID] = true: a spell the player knows (Pick Lock)
      W.compare, W.cannotUse, W.compared, W.itemStats: see below
]]

QuestDifficultyColors = {
    impossible = { r = 1, g = 0.1, b = 0.1 }, verydifficult = { r = 1, g = 0.5, b = 0.25 },
    difficult = { r = 1, g = 1, b = 0 }, standard = { r = 0.25, g = 0.75, b = 0.25 }, trivial = { r = 0.5, g = 0.5, b = 0.5 },
}
function GetCreatureDifficultyColor(level) return GetQuestDifficultyColor(level) end
PLAYER_FACTION_COLORS = { [0] = { r = 0.9, g = 0.05, b = 0.07 }, [1] = { r = 0.29, g = 0.33, b = 0.91 } }
local function color(r, g, b)
    return { r = r, g = g, b = b, GetRGB = function(self) return self.r, self.g, self.b end,
        WrapTextInColorCode = function(self, text) return "|cff000000" .. text .. "|r" end }
end
TOOLTIP_DEFAULT_COLOR = color(1, 1, 1)
GRAY_FONT_COLOR, HIGHLIGHT_FONT_COLOR = color(0.5, 0.5, 0.5), color(1, 1, 1)
NORMAL_FONT_COLOR.WrapTextInColorCode = TOOLTIP_DEFAULT_COLOR.WrapTextInColorCode
C_ClassColor = { GetClassColor = function(token) return color(0.5, 0.5, 1) end }
LOCALIZED_CLASS_NAMES_MALE, LOCALIZED_CLASS_NAMES_FEMALE = { MAGE = "Mage" }, { MAGE = "Mage" }
function GetMoneyString(copper) return copper .. "c" end
SELL_PRICE, ITEM_MIN_SKILL, ITEM_SPELL_TRIGGER_ONEQUIP = "Sell Price:", "Requires %s (%d)", "Equip:"
ITEM_MOD_SPIRIT_SHORT, ITEM_MOD_SPIRIT = "Spirit", "%c%s Spirit"
ITEM_MOD_HIT_RATING_SHORT = "Hit Rating" -- no long string: Forever words the Equip: line as a spell's
FRIENDS_LEVEL_TEMPLATE, FACTION_HORDE, FACTION_ALLIANCE, WOW_PROJECT_ID = "Level %d %s", "Horde", "Alliance", 1

-- Tooltip data processing: the calls a module adds, and W.ItemTooltip/W.UnitTooltip run them.
TooltipDataProcessor.AllTypes = "all"
W.tooltipCalls = { pre = {}, linePre = {}, linePost = {} }
function TooltipDataProcessor.AddTooltipPreCall(kind, fn) table.insert(W.tooltipCalls.pre, { kind = kind, fn = fn }) end
function TooltipDataProcessor.AddLinePreCall(kind, fn) table.insert(W.tooltipCalls.linePre, { kind = kind, fn = fn }) end
function TooltipDataProcessor.AddLinePostCall(kind, fn) table.insert(W.tooltipCalls.linePost, { kind = kind, fn = fn }) end
Enum.TooltipDataType.Object, Enum.TooltipDataType.MinimapMouseover = 4, 23
Enum.TooltipDataLineType.SellPrice = 11
Enum.BagIndex.Bank, Enum.BagIndex.BankBag_1 = -1, 6

-- Lockpicking: W.knownSpells[spellID] = true for a spell the player knows.
W.knownSpells = {}
C_SpellBook.IsSpellKnown = function(id) return W.knownSpells[id] == true end
function InRepairMode() return false end
function UnitFactionGroup() return "Horde" end
-- Units for unit tooltips: W.unitInfo (tests/stubs/units.lua) says who they are.
function UnitSelectionColor() return 1, 0.1, 0.1 end
function UnitIsUnit(a, b) return a == b end
function UnitPVPName(unit) return UnitName(unit) end
function UnitIsInMyGuild() return false end
function GetGuildInfo() return nil end
function UnitClass(unit)
    local u = W.unitInfo[unit]
    if u and u.class then return u.class, u.class end
end
-- W.compare: Shift held for Compare Items; W.cannotUse[itemID]: gear the player can't use;
-- W.compared: the links C_TooltipComparison.CompareItem was asked to compare.
W.cannotUse, W.compared = {}, {}
function IsModifiedClick(action) return action == "COMPAREITEMS" and W.compare == true end
C_CVar.GetCVarBool = function() return false end
C_PlayerInfo = { CanUseItem = function(id) return not W.cannotUse[id] end }
C_TooltipComparison = { CompareItem = function(item) W.compared[#W.compared + 1] = item.hyperlink end }
function GameTooltip_ShowCompareItem() end
function GameTooltip_SetDefaultAnchor() end
FriendsListSocialCardMixin = { BuildTooltip = function() end }
GameTooltip.StatusBar = W.NewFrame("StatusBar", nil, GameTooltip)
GameTooltip.NineSlice = W.NewFrame("Frame", nil, GameTooltip)
GameTooltip.IsEmbedded = false -- a field on the game's tooltips (true on ones inside another)
GameTooltip:CreateFontString("GameTooltipTextLeft1")
function GameTooltip.NineSlice:SetBorderColor(r, g, b) self._border = { r, g, b } end
function GameTooltip:GetPrimaryTooltipData() return self._data end
function GameTooltip:RefreshData() end

-- Items, bags and the bank (item info, counts and qualities are the loot and merchant stubs').
C_Item.RequestLoadItemDataByID = function() end
W.itemStats = {} -- link -> C_Item.GetItemStats' table
C_Item.GetItemStats = function(link) return W.itemStats[link] end
BankFrame = W.NewFrame("Frame", "BankFrame", UIParent)
BankFrame:Hide()

-- The auction house (Blizzard_AuctionHouseUI loads on demand: no AuctionHouseFrame here).
-- W.ah: what the server is asked (queries: browse searches sent, more: further pages asked for),
-- whether its query throttle is ready, and whether the browse results are all in.
W.ah = { queries = 0, more = 0, ready = true, full = true }
C_AuctionHouse = {
    SendBrowseQuery = function() W.ah.queries = W.ah.queries + 1 end,
    SearchForFavorites = function() end, SearchForItemKeys = function() end,
    HasFullBrowseResults = function() return W.ah.full end,
    RequestMoreBrowseResults = function() W.ah.more = W.ah.more + 1 end,
    IsThrottledMessageSystemReady = function() return W.ah.ready end, GetBrowseResults = function() return {} end,
}
