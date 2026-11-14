--[[
    Forever Tweaks - Tooltips
    Colors unit and item tooltips so they say more at a glance: the border and name follow the
    unit's class (players) or how it feels about you, item borders follow quality, a unit's guild,
    level, class and faction lines get colors, a player's title shows in their name, a line says
    who the unit targets, and a friend's tooltip in the friends list is colored the same way. Also:
    tooltips at the mouse, unit tooltips hidden in combat (faded, so Blizzard's own OnHide never runs
    from our code), the health bar under them hidden, and the quest lines left out of unit (and
    object) tooltips as they're built (line pre calls; the tooltip data keeps them, so Quest
    Nameplates still reads them).
    The friends list's tooltip is TooltipsFriends.lua's; the tooltips at the mouse, the health bar
    and the quest lines are TooltipsBehavior.lua's.
    Every change is made on Blizzard's own lines after it builds the tooltip (TooltipDataProcessor
    post calls). Unit data can be secret, mostly in combat and in instances: text that would have
    to be read is left alone then, and colors that come back secret go straight to the setters.
    Left to Forever++'s Tooltips while that's on. Adapted from Forever++ by xIGBClutchIx (MIT
    License), whose ideas came from ManiaTip.
]]

local _, ns = ...
local L = ns.L

local type, setmetatable = type, setmetatable
local find = string.find
local GameTooltip = GameTooltip
local Kit, OtherAddons, Plain = ns.TooltipKit, ns.OtherAddons, ns.Plain

local COVERS = { { "ForeverPlusPlus", "Tooltips" } }
local UNIT_COLORS = {
    { "class", L.TOOLTIPS_COLOR_CLASS },
    { "reaction", L.TOOLTIPS_COLOR_REACTION },
    { "off", L.TOOLTIPS_COLOR_OFF },
}

local M = ns:NewModule("Tooltips", {
    title = L.TOOLTIPS_TITLE,
    category = "tooltips",
    description = L.TOOLTIPS_DESC,
    added = "2.2.0",
    defaults = {
        border = "class", itemBorder = true, nameColor = "class", guildColor = "all",
        levelColor = true, classColor = true, factionColor = true, friends = true, title = true, target = true,
        hideInCombat = false, anchorCursor = false, hideHealthBar = false, questLines = "show",
    },
    options = {
        { key = "border", type = "dropdown", label = L.TOOLTIPS_BORDER, tooltip = L.TOOLTIPS_BORDER_TIP,
          choices = UNIT_COLORS, section = L.TOOLTIPS_SECTION_BORDERS },
        { key = "itemBorder", type = "checkbox", label = L.TOOLTIPS_ITEM_BORDER, tooltip = L.TOOLTIPS_ITEM_BORDER_TIP },
        { key = "nameColor", type = "dropdown", label = L.TOOLTIPS_NAME_COLOR, tooltip = L.TOOLTIPS_NAME_COLOR_TIP,
          choices = UNIT_COLORS, section = L.TOOLTIPS_SECTION_TEXT },
        { key = "guildColor", type = "dropdown", label = L.TOOLTIPS_GUILD_COLOR, tooltip = L.TOOLTIPS_GUILD_COLOR_TIP,
          choices = { { "mine", L.TOOLTIPS_GUILD_COLOR_MINE }, { "all", L.TOOLTIPS_GUILD_COLOR_ALL },
              { "off", L.TOOLTIPS_COLOR_OFF } } },
        { key = "levelColor", type = "checkbox", label = L.TOOLTIPS_LEVEL_COLOR, tooltip = L.TOOLTIPS_LEVEL_COLOR_TIP },
        { key = "classColor", type = "checkbox", label = L.TOOLTIPS_CLASS_COLOR, tooltip = L.TOOLTIPS_CLASS_COLOR_TIP },
        { key = "factionColor", type = "checkbox", label = L.TOOLTIPS_FACTION_COLOR, tooltip = L.TOOLTIPS_FACTION_COLOR_TIP },
        { key = "friends", type = "checkbox", label = L.TOOLTIPS_FRIENDS, tooltip = L.TOOLTIPS_FRIENDS_TIP },
        { key = "title", type = "checkbox", label = L.TOOLTIPS_PLAYER_TITLE, tooltip = L.TOOLTIPS_PLAYER_TITLE_TIP,
          section = L.TOOLTIPS_SECTION_LINES },
        { key = "target", type = "checkbox", label = L.TOOLTIPS_TARGET, tooltip = L.TOOLTIPS_TARGET_TIP },
        { key = "anchorCursor", type = "checkbox", label = L.TOOLTIPS_ANCHOR_CURSOR, tooltip = L.TOOLTIPS_ANCHOR_CURSOR_TIP,
          section = L.TOOLTIPS_SECTION_BEHAVIOR },
        { key = "hideInCombat", type = "checkbox", label = L.TOOLTIPS_HIDE_IN_COMBAT, tooltip = L.TOOLTIPS_HIDE_IN_COMBAT_TIP },
        { key = "hideHealthBar", type = "checkbox", label = L.TOOLTIPS_HIDE_HEALTH_BAR, tooltip = L.TOOLTIPS_HIDE_HEALTH_BAR_TIP },
        { key = "questLines", type = "dropdown", label = L.TOOLTIPS_QUEST_LINES, tooltip = L.TOOLTIPS_QUEST_LINES_TIP,
          choices = { { "show", L.TOOLTIPS_QUEST_LINES_SHOW }, { "units", L.TOOLTIPS_QUEST_LINES_UNITS },
              { "all", L.TOOLTIPS_QUEST_LINES_ALL } } },
    },
})

M.notice = OtherAddons.CoveredNotices(M, COVERS, L.TOOLTIPS_WHAT)

local GUILDMATE_COLOR, GUILD_COLOR, YOU_COLOR = Kit.GUILD_GREEN, Kit.GRAY, Kit.RED

local function isPlain(value) return value == nil or Plain(value) ~= nil end

local lineText, dataLine, colorMatch = Kit.LineText, Kit.DataLine, Kit.ColorMatch
local unitColor, levelColor, classColor, leftLine = Kit.UnitColor, Kit.LevelColor, Kit.PlayerClass, Kit.LeftLine

-- Border -------------------------------------------------------------------------------------

local colored = setmetatable({}, { __mode = "k" }) -- tooltip -> true while we colored its border
local onCleared -- below: what a tooltip being cleared undoes (one hook per tooltip does it all)

local function resetBorder(tooltip)
    if colored[tooltip] then
        colored[tooltip] = nil
        tooltip.NineSlice:SetBorderColor(TOOLTIP_DEFAULT_COLOR:GetRGB())
    end
end

local function setBorder(tooltip, r, g, b)
    local slice = tooltip.NineSlice
    if not (slice and slice.SetBorderColor) or tooltip.IsEmbedded then
        return -- tooltips inside other tooltips use their parent's border
    end
    M:HookScript(tooltip, "OnTooltipCleared", onCleared)
    colored[tooltip] = true
    slice:SetBorderColor(r, g, b)
end

-- Unit tooltips ------------------------------------------------------------------------------

-- The unit the tooltip shows, or nil when it can't tell.
local function tooltipUnit(tooltip)
    local _, unit = tooltip:GetUnit()
    unit = Plain(unit)
    if type(unit) == "string" and Plain(UnitExists(unit)) then
        return unit
    end
end

-- Puts the title in the name when Blizzard's line is only the name.
local function addTitle(tooltip, data, unit)
    local shown, name = lineText(data, 1), UnitName(unit)
    local full = UnitPVPName(unit)
    if shown and isPlain(name) and isPlain(full) and full and shown == name and full ~= name then
        local line = leftLine(tooltip, 1)
        if line then
            line:SetText(full)
        end
    end
end

-- Colors the <Guild> line and returns its number, so the level search skips it.
local function colorGuild(tooltip, data, unit)
    local guild = GetGuildInfo(unit)
    if not (isPlain(guild) and guild) then
        return nil
    end
    for i = 2, 4 do
        local text = lineText(data, i)
        if text and find(text, guild, 1, true) then
            local mode, color = M.db.guildColor, nil
            if mode ~= "off" and Plain(UnitIsInMyGuild(unit)) then
                color = GUILDMATE_COLOR
            elseif mode == "all" then
                color = GUILD_COLOR
            end
            local line = color and dataLine(tooltip, data, i)
            if line then
                line:SetTextColor(color[1], color[2], color[3])
            end
            return i
        end
    end
end

-- Colors the level by difficulty and the class name by class, on the level line (and the line
-- after it, where Mainline puts a player's specialization and class).
local function colorLevelLine(tooltip, data, unit, guildLine)
    local db = M.db
    local level = Plain(UnitLevel(unit))
    if type(level) ~= "number" then
        return
    end
    local levelPattern = level > 0 and "%f[%d]" .. level .. "%f[%D]" or "%?%?"
    local className = db.classColor and UnitClass(unit)
    local class = classColor(unit)
    local classWord = isPlain(className) and className ~= "" and class and className
    for i = 2, #data.lines do
        local text = i ~= guildLine and lineText(data, i)
        if text and find(text, levelPattern) then
            local changed, found = false
            if db.levelColor then
                local color = levelColor(level)
                if color then
                    text, changed = colorMatch(text, levelPattern, color.r, color.g, color.b)
                end
            end
            if classWord then
                local r, g, b = class:GetRGB()
                text, found = colorMatch(text, nil, r, g, b, classWord)
                changed = changed or found
                local nextText = not found and lineText(data, i + 1)
                if nextText then
                    local nextLine = dataLine(tooltip, data, i + 1)
                    nextText, found = colorMatch(nextText, nil, r, g, b, classWord)
                    if found and nextLine then
                        nextLine:SetText(nextText)
                    end
                end
            end
            local line = changed and dataLine(tooltip, data, i)
            if line then
                line:SetText(text)
            end
            return
        end
    end
end

-- Colors the "Horde" or "Alliance" line Blizzard adds to a unit, in the side's color, as on maps.
local function colorFaction(tooltip, data)
    for i = 2, #data.lines do
        local text = lineText(data, i)
        local side = text and (text == FACTION_HORDE and "H" or text == FACTION_ALLIANCE and "A")
        local line = side and dataLine(tooltip, data, i)
        if line then
            local color = Kit.Faction(side)
            line:SetTextColor(color.r, color.g, color.b)
            return
        end
    end
end

-- Adds "Target: <name>", or "Target: You", colored like names.
local function addTarget(tooltip, unit)
    local target = unit .. "target"
    local exists = UnitExists(target)
    if not (isPlain(exists) and exists) then
        return
    end
    local lr, lg, lb = NORMAL_FONT_COLOR:GetRGB()
    local isPlayer = UnitIsUnit(target, "player")
    if isPlain(isPlayer) and isPlayer then
        tooltip:AddDoubleLine(L.TOOLTIPS_TARGET_LINE, L.TOOLTIPS_TARGET_YOU, lr, lg, lb,
            YOU_COLOR[1], YOU_COLOR[2], YOU_COLOR[3])
        return
    end
    local ok, r, g, b = unitColor(target, "class")
    if not ok then
        r, g, b = 1, 1, 1
    end
    -- A secret name is left out: other addons reading the tooltip's lines would trip on it.
    local name = Plain(UnitName(target))
    if name then tooltip:AddDoubleLine(L.TOOLTIPS_TARGET_LINE, name, lr, lg, lb, r, g, b) end
end

-- Hide in Combat fades GameTooltip rather than hiding it: Hide would run Blizzard's OnHide from
-- our code, mid-processing and in combat, and taint the next tooltip. The next tooltip or its
-- hiding brings it back.
local faded = false

local function unfade()
    if faded then
        faded = false
        GameTooltip:SetAlpha(1)
    end
end

-- A tooltip cleared: its border back to the default, and GameTooltip shown again. One handler,
-- because Module:HookScript hooks a frame's script once (a second hook would never be added).
function onCleared(_, tooltip)
    resetBorder(tooltip)
    if tooltip == GameTooltip then unfade() end
end

local function onUnit(_, tooltip, data)
    -- Hide in Combat: the mouseover tooltip only; tooltips the player opens stay.
    if M.db.hideInCombat and tooltip == GameTooltip and InCombatLockdown() then
        faded = true
        tooltip:SetAlpha(0)
        return
    end
    local unit = data and tooltipUnit(tooltip)
    if not unit then
        return
    end
    local db = M.db
    local lines = isPlain(data.lines) and type(data.lines) == "table"
    if lines and db.title then
        addTitle(tooltip, data, unit)
    end
    if db.nameColor ~= "off" then
        local ok, r, g, b = unitColor(unit, db.nameColor)
        local line = ok and leftLine(tooltip, 1)
        if line then
            line:SetTextColor(r, g, b)
        end
    end
    if db.border ~= "off" then
        local ok, r, g, b = unitColor(unit, db.border)
        if ok then
            setBorder(tooltip, r, g, b)
        end
    end
    if lines then
        colorLevelLine(tooltip, data, unit, colorGuild(tooltip, data, unit))
        if db.factionColor then
            colorFaction(tooltip, data)
        end
    end
    if db.target then
        addTarget(tooltip, unit)
    end
end

-- Item tooltips ------------------------------------------------------------------------------

local function onItem(_, tooltip, data)
    if not (M.db.itemBorder and data) then
        return
    end
    local item = Plain(data.id) or Plain(data.hyperlink)
    local quality = item and Plain(C_Item.GetItemQualityByID(item))
    if quality then
        local r, g, b = C_Item.GetItemQualityColor(quality)
        if r then
            setBorder(tooltip, r, g, b)
        end
    end
end

local function inCharge() return not OtherAddons.CoveredBy(M, COVERS) end

-- Each hook runs only while this is on (Module:HookCallback), and does nothing while Forever++'s
-- Tooltips is.
local function guarded(fn)
    return function(...)
        if inCharge() then return fn(...) end
    end
end

function M:OnEnable()
    self:HookCallback(TooltipDataProcessor, "unit", function(hook)
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, hook)
    end, guarded(onUnit))
    self:HookCallback(TooltipDataProcessor, "item", function(hook)
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, hook)
    end, guarded(onItem))
    self:HookScript(GameTooltip, "OnTooltipCleared", onCleared)
    self:HookScript(GameTooltip, "OnHide", unfade)
    -- Out of combat a tooltip faded in it comes back, even before it changes.
    self:RegisterEvent("PLAYER_REGEN_ENABLED", unfade)
end

function M:OnDisable() unfade() end

function M:OnSettingChanged(key)
    if key == "hideInCombat" and not self.db.hideInCombat then unfade() end
end

-- What TooltipsFriends.lua and TooltipsBehavior.lua share with this file.
ns.TooltipsParts = { module = M, Guarded = guarded, InCharge = inCharge, ColorMatch = colorMatch, LevelColor = levelColor }
