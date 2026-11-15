--[[
    Forever Tweaks - tests/scenarios/tweaks/tooltiptext.lua
    The tooltip features that work by reading Blizzard's text:
      * Stat Colors: a "+6 Spirit" line drawn again in its stat's color; an Equip: line worded as
        a spell's told by its number among the item's stats (a rating by its percent), "Equip:"
        kept in the line's own color; a line with right text, an Equip: line two stats fit, and
        everything with the option off left to Blizzard.
      * Compare Crafted Gear: a bag recipe making gear compared by the crafted item's link, only
        with Shift, only gear you can use, under Professions only for a profession you have, and
        never when off or for a recipe that makes no gear.
      * The friends list: a Social window card's tooltip found by the text Blizzard built from
        the card's friend info, its name, level, class and side colored; any other tooltip, a
        friend in another game's level, and the option off left alone.
    Run by tests/run.lua (lua5.1 tests/run.lua tooltiptext), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverTweaks")
login()
local Kit, COLORS = ns.TooltipKit, ns.ItemStats.COLORS
-- Item Stats reads each stat's strings by name, probing for the ones this client has.
for key in pairs(ns.ItemStats.KEYS) do W.OPTIONAL[key], W.OPTIONAL[(key:gsub("_SHORT$", ""))] = true, true end

---------------------------------------------------------------------------
-- Stat Colors
---------------------------------------------------------------------------

-- Shows an item's tooltip as the game builds it: the item pre call, then each line's pre calls
-- (a call answering true draws the line itself, so Blizzard's is skipped) and post calls, then
-- the item post calls. Returns the lines our code added and the lines Blizzard drew.
local function show(data)
    local tooltip, blizzard = { added = {} }, {}
    function tooltip:AddLine(text, r, g, b) self.added[#self.added + 1] = { text = text, r = r, g = g, b = b } end
    function tooltip:AddDoubleLine(left, right) self.added[#self.added + 1] = { text = left, right = right } end
    function tooltip:GetPrimaryTooltipData() return data end
    function tooltip:GetName() return nil end
    function tooltip:GetOwner() return nil end
    function tooltip:GetPrimaryTooltipInfo() return { getterName = "GetItemByID", getterArgs = { data.id } } end
    local function each(calls, kind, ...)
        local drawn
        for _, call in ipairs(calls) do
            if call.kind == kind or call.kind == TooltipDataProcessor.AllTypes then
                drawn = call.fn(tooltip, ...) or drawn
            end
        end
        return drawn
    end
    each(W.tooltipCalls.pre, Enum.TooltipDataType.Item, data)
    for _, line in ipairs(data.lines) do
        if not each(W.tooltipCalls.linePre, line.type, line) then blizzard[#blizzard + 1] = line.leftText end
        each(W.tooltipCalls.linePost, line.type, line)
    end
    each(W.tooltipPostCalls, Enum.TooltipDataType.Item, data)
    return tooltip.added, blizzard
end

local NONE = Enum.TooltipDataLineType.None
local function item(id, ...)
    local lines = {}
    for i, line in ipairs({ ... }) do
        lines[i] = { type = NONE, leftText = line[1], rightText = line[2], leftColor = { r = 0, g = 1, b = 0 } }
    end
    return { type = Enum.TooltipDataType.Item, id = id, lines = lines }
end
local function lineWith(lines, text)
    for _, line in ipairs(lines) do
        if line.text and line.text:find(text, 1, true) then return line end
    end
end

W.items["[Robe of Spirit]"] = { id = 9100, class = 4, quality = 2, sell = 10 }
local SPIRIT, HAND = { "+6 Spirit" }, { "One-Hand", "Sword" }
local HIT = { "Equip: Improves your chance to hit by 1%." }
W.itemStats["item:9100"] = { ITEM_MOD_SPIRIT_SHORT = 6, ITEM_MOD_HIT_RATING_SHORT = 10 }
local added, blizzard = show(item(9100, HAND, SPIRIT, HIT))
local spirit = lineWith(added, "+6 Spirit")
check(spirit ~= nil, "a stat line is drawn again")
eq(spirit and spirit.r, COLORS.SPI[1], "in its stat's color")
local hit = lineWith(added, "Improves your chance to hit")
check(hit ~= nil, "an Equip: line worded as a spell's, told by its percent among the item's stats")
check(hit and hit.text:find(Kit.Code(COLORS.HIT[1], COLORS.HIT[2], COLORS.HIT[3]) .. "Improves", 1, true) ~= nil,
    "its effect in the stat's color")
check(hit and hit.text:find(Kit.Text({ r = 0, g = 1, b = 0 }, "Equip: "), 1, true) == 1, "\"Equip:\" in the line's own color")
eq(table.concat(blizzard, "|"), "One-Hand", "the line with right text is Blizzard's; the stat lines aren't")

-- Two stats the number fits: the line is left alone.
W.itemStats["item:9100"] = { ITEM_MOD_HIT_RATING_SHORT = 10, ITEM_MOD_CRIT_RATING_SHORT = 14 }
added, blizzard = show(item(9100, HIT))
eq(#blizzard, 1, "an Equip: line two stats fit stays Blizzard's")

ns:SetOption("ItemTooltips", "statColors", false)
added, blizzard = show(item(9100, SPIRIT))
eq(#blizzard, 1, "Stat Colors off: Blizzard's line")
ns:SetOption("ItemTooltips", "statColors", true)

---------------------------------------------------------------------------
-- Compare Crafted Gear
---------------------------------------------------------------------------

-- A Tailoring pattern in the bags (its data: the recipe's ID, a bag GUID, the robe's link).
W.items["[Pattern: Robe of Spirit]"] = { id = 9101, class = Enum.ItemClass.Recipe, subclass = 2 }
W.items["[Robe of Spirit]"].equipLoc = "INVTYPE_CHEST"
W.items["[Pattern: Spirit Potion]"] = { id = 9102, class = Enum.ItemClass.Recipe, subclass = 6 }
W.items["[Spirit Potion]"] = { id = 9103, equipLoc = "" }
local function compare(recipe, link)
    W.compared = {}
    GameTooltip._data = { type = Enum.TooltipDataType.Item, id = recipe, guid = "Item-1-0001", hyperlink = link }
    GameTooltip_ShowCompareItem(GameTooltip)
    return W.compared[1]
end
eq(compare(9101, "[Robe of Spirit]"), nil, "no comparison without Shift")
W.compare = true
eq(compare(9101, "[Robe of Spirit]"), "[Robe of Spirit]", "with Shift: the robe compared with what you wear")
eq(compare(9102, "[Spirit Potion]"), nil, "a recipe making no gear isn't")
W.cannotUse[9100] = true
eq(compare(9101, "[Robe of Spirit]"), nil, "nor gear you can't use")
W.cannotUse[9100] = nil
ns:SetOption("ItemTooltips", "craftedCompare", "professions")
eq(compare(9101, "[Robe of Spirit]"), nil, "Professions: not without Tailoring")
W.profs[1] = { name = "Tailoring", rank = 75, maxRank = 150, line = 197 }
W.Fire("SKILL_LINES_CHANGED")
eq(compare(9101, "[Robe of Spirit]"), "[Robe of Spirit]", "Professions: with Tailoring")
ns:SetOption("ItemTooltips", "craftedCompare", "off")
eq(compare(9101, "[Robe of Spirit]"), nil, "off: never")
W.compare = false

---------------------------------------------------------------------------
-- The friends list
---------------------------------------------------------------------------

local LINES = { "Thrall#1234", "Thrall", "Level 17 Mage", "Orc", "Durotar", "Horde" }
for i = 2, #LINES do GameTooltip:CreateFontString("GameTooltipTextLeft" .. i) end
local card = W.NewFrame("Frame", nil, UIParent)
card.BuildTooltip = FriendsListSocialCardMixin.BuildTooltip
local friend = { isOnline = true, characterName = "Thrall", className = "Mage", classFilename = "MAGE",
    characterLevel = 17, wowProjectID = WOW_PROJECT_ID }
card.elementData = { accountInfo = { gameAccountInfo = friend } }
local owner = card
function GameTooltip:GetOwner() return owner end
function GameTooltip:NumLines() return #LINES end
local function line(i) return _G["GameTooltipTextLeft" .. i] end
local function showFriend()
    for i, text in ipairs(LINES) do
        line(i):SetText(text)
        line(i)._textColor = nil
    end
    GameTooltip:Show()
    GameTooltip:Hide()
end

local class = { C_ClassColor.GetClassColor("MAGE"):GetRGB() }
showFriend()
eq(table.concat(line(2)._textColor or {}, ","), table.concat(class, ","), "the name in the class color")
local level = GetCreatureDifficultyColor(17)
check(line(3):GetText():find(Kit.Code(level.r, level.g, level.b) .. "17", 1, true) ~= nil, "the level against yours")
check(line(3):GetText():find(Kit.Code(class[1], class[2], class[3]) .. "Mage", 1, true) ~= nil, "the class in its color")
local horde = PLAYER_FACTION_COLORS[0]
eq(table.concat(line(6)._textColor or {}, ","), table.concat({ horde.r, horde.g, horde.b }, ","), "the side in its color")

friend.wowProjectID = WOW_PROJECT_ID + 1
showFriend()
eq(line(3):GetText():find("|c", 1, true) < line(3):GetText():find("Mage", 1, true), true, "another game's friend: the class colored")
check(line(3):GetText():find(Kit.Code(level.r, level.g, level.b), 1, true) == nil, "but not the level, which means nothing here")
friend.wowProjectID = WOW_PROJECT_ID

owner = W.NewFrame("Frame", nil, UIParent)
showFriend()
eq(line(3):GetText(), "Level 17 Mage", "any other tooltip is left alone")
owner = card
ns:SetOption("Tooltips", "friends", false)
showFriend()
eq(line(3):GetText(), "Level 17 Mage", "Friends List off: left alone")
eq(line(2)._textColor, nil, "the name too")
finish()
