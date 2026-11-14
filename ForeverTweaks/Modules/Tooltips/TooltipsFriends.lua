--[[
    Forever Tweaks - Tooltips: the friends list
    A friend's tooltip in the friends list colored the way unit tooltips are: their name by class,
    the level against yours, the class name and the side. Forever's friends list is the Social
    window's, whose cards build a plain GameTooltip with no tooltip data (the account name, then a
    character's name, "Level 17 Shaman", race, zone and side: FriendsListSocialCardMixin:
    BuildTooltip), so it's recolored after it shows, finding Blizzard's lines by the text it built
    from the card's own friend info. Adapted from Forever++'s Tooltips by xIGBClutchIx (MIT License).
]]

local _, ns = ...

local type, format, find = type, string.format, string.find
local GameTooltip = GameTooltip
local Kit, Plain = ns.TooltipKit, ns.Plain
local Shared = ns.TooltipsParts
local M, colorMatch, levelColor = Shared.module, Shared.ColorMatch, Shared.LevelColor
local leftLine = Kit.LeftLine

-- Friends list tooltips ----------------------------------------------------------------------

-- Forever's friends list is the Social window's (docs/forever-api.md), whose cards build a plain
-- GameTooltip with no tooltip data: the account name, then for a WoW character its name, "Level 17
-- Shaman", race, zone, and side (FriendsListSocialCardMixin:BuildTooltip, Gethe `forever` branch,
-- checked 2026-11-05). So it's recolored after it shows, finding Blizzard's lines by the text it
-- built from the card's own friend info. Battle.net friend info isn't secret.

-- The friend info of the Social window card that owns the tooltip, or nil for any other owner.
local function friendCardInfo(tooltip)
    local mixin = FriendsListSocialCardMixin -- loads with the Social window
    local owner = tooltip:GetOwner()
    if not (mixin and ns.Usable(owner) and owner.BuildTooltip == mixin.BuildTooltip) then
        return nil
    end
    local data = owner.elementData
    local info = data and data.accountInfo
    local game = info and info.gameAccountInfo
    if game and game.isOnline and type(game.characterName) == "string" and type(game.className) == "string"
        and type(game.characterLevel) == "number" then
        return game
    end
end

-- The tooltip's line `i` and its text, when it's readable.
local function shownLine(tooltip, i)
    local line = leftLine(tooltip, i)
    local text = line and Plain(line:GetText())
    if type(text) == "string" then
        return line, text
    end
end

local function onFriendTooltip(_, tooltip)
    local db = M.db
    local game = db.friends and friendCardInfo(tooltip)
    if not game then
        return
    end
    local levelText = format(FRIENDS_LEVEL_TEMPLATE, game.characterLevel, game.className)
    for i = 2, tooltip:NumLines() do
        local line, text = shownLine(tooltip, i)
        if text == levelText then
            local class = Kit.ClassToken(game.classFilename) or Kit.ClassToken(Kit.ClassTokenOf(game.className))
            local nameLine, nameText = shownLine(tooltip, i - 1)
            if class and db.nameColor ~= "off" and nameText and find(nameText, game.characterName, 1, true) then
                nameLine:SetTextColor(class:GetRGB())
            end
            -- A level against the player's means something only in this game.
            local color = db.levelColor and game.wowProjectID == WOW_PROJECT_ID and levelColor(game.characterLevel)
            local levelPattern = "%f[%d]" .. game.characterLevel .. "%f[%D]"
            if color then
                text = colorMatch(text, levelPattern, color.r, color.g, color.b)
            end
            if class and db.classColor then
                local r, g, b = class:GetRGB()
                text = colorMatch(text, nil, r, g, b, game.className)
            end
            line:SetText(text)
            -- Race and zone, then the side.
            local sideLine, side = shownLine(tooltip, i + 3)
            side = side and (side == FACTION_HORDE and "H" or side == FACTION_ALLIANCE and "A")
            if side and db.factionColor then
                local faction = Kit.Faction(side)
                sideLine:SetTextColor(faction.r, faction.g, faction.b)
            end
            return
        end
    end
end

M:AddPart({
    Enable = function() M:Hook(GameTooltip, "Show", Shared.Guarded(onFriendTooltip)) end,
})
