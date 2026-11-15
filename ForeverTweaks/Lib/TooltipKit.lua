--[[
    Forever Tweaks - Lib/TooltipKit.lua
    What the tooltip modules share: a tooltip's font strings, color codes, class and faction
    colors, and the money text. Adapted from Forever++'s Lib/Colors.lua and Lib/Text.lua by
    xIGBClutchIx (MIT License).
]]

local _, ns = ...

local _G, type, pairs, format, floor = _G, type, pairs, string.format, math.floor
local find, sub, byte = string.find, string.sub, string.byte
local Plain = ns.Plain

local TooltipKit = {}
ns.TooltipKit = TooltipKit

TooltipKit.GRAY = { 0.65, 0.65, 0.65 }      -- a guild name that isn't highlighted
TooltipKit.RED = { 1, 0.25, 0.25 }          -- "You" as a target
TooltipKit.GUILD_GREEN = { 0.25, 1, 0.25 }  -- guild chat's green, for your own guild

-- Blizzard's faction colors (PLAYER_FACTION_COLORS: Horde 0, Alliance 1), and neutral yellow.
function TooltipKit.Faction(side)
    if side == "H" then return PLAYER_FACTION_COLORS[0] end
    if side == "A" then return PLAYER_FACTION_COLORS[1] end
    return { r = 0.9, g = 0.7, b = 0 }
end

-- A color code for r, g, b (0 to 1).
function TooltipKit.Code(r, g, b)
    return format("|cff%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

-- A tooltip's left (or right) font string on line `i`, or nil for one without named lines.
function TooltipKit.LeftLine(tooltip, i)
    local name = tooltip:GetName()
    return type(name) == "string" and _G[name .. "TextLeft" .. i] or nil
end
function TooltipKit.RightLine(tooltip, i)
    local name = tooltip:GetName()
    return type(name) == "string" and _G[name .. "TextRight" .. i] or nil
end

-- A class token's color (a ColorMixin), or nil.
function TooltipKit.ClassToken(token)
    if type(token) == "string" then return C_ClassColor.GetClassColor(token) end
end

-- A player unit's class color, or nil (an NPC, or a class that's secret).
function TooltipKit.PlayerClass(unit)
    if not Plain(UnitIsPlayer(unit)) then return nil end
    local _, class = UnitClass(unit)
    return TooltipKit.ClassToken(Plain(class))
end

local classTokens -- localized class name -> token, made when first asked

-- The class token for a localized class name (the friends list gives names).
function TooltipKit.ClassTokenOf(name)
    if not classTokens then
        classTokens = {}
        for _, names in pairs({ LOCALIZED_CLASS_NAMES_MALE, LOCALIZED_CLASS_NAMES_FEMALE }) do
            for token, localized in pairs(names) do classTokens[localized] = token end
        end
    end
    return classTokens[name]
end

-- Text as it shows, without its escape codes: colors, links (their text stays), textures and
-- atlases; an escaped "||" is one "|". Never given a secret value.
function TooltipKit.StripCodes(text)
    if not text:find("|", 1, true) then return text end
    text = text:gsub("||", "\1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:|]*:", ""):gsub("|r", "")
    text = text:gsub("|H[^|]*|h(.-)|h", "%1"):gsub("|T[^|]*|t", ""):gsub("|A[^|]*|a", "")
    return (text:gsub("\1", "|"))
end

-- A pattern for one of the client's format strings ("Requires %s (%d)"), so it matches in any
-- language: each %s and %d captured (or only matched without `capture`); "%1$s" counts as "%s".
function TooltipKit.FormatPattern(formatString, capture)
    local pattern = formatString:gsub("%%%d+%$", "%%"):gsub("[%^%$%(%)%.%[%]%*%+%-%?]", "%%%0")
    return (pattern:gsub("%%([sd])", capture and { s = "(.+)", d = "(%d+)" } or { s = ".-", d = "%d+" }))
end

-- Text in a color table's color ({ r, g, b } fields, or a list).
function TooltipKit.Text(color, text)
    local r, g, b = color.r or color[1], color.g or color[2], color.b or color[3]
    return TooltipKit.Code(r, g, b) .. text .. "|r"
end


---------------------------------------------------------------------------
-- A tooltip's lines and colors (Tooltips)
---------------------------------------------------------------------------

-- The text Blizzard put on line `i`, from the tooltip's data rather than the font string, or
-- nil when it's missing or secret.
function TooltipKit.LineText(data, i)
    local lineData = data.lines[i]
    local text = lineData and Plain(lineData.leftText)
    if type(text) == "string" then
        return text
    end
end

-- The tooltip's left font string for data line `i`. Blizzard numbers each line it adds
-- (lineData.lineIndex); after a line left out (Quest Lines, or another addon's line pre call),
-- the tooltip's lines no longer match their place in the data. When the first line has a number
-- and this one hasn't, it was left out: nil.
function TooltipKit.DataLine(tooltip, data, i)
    local lineData, first = data.lines[i], data.lines[1]
    local index = lineData and lineData.lineIndex
    if type(Plain(index)) == "number" then
        return TooltipKit.LeftLine(tooltip, index)
    end
    if lineData and not (first and type(Plain(first.lineIndex)) == "number") then
        return TooltipKit.LeftLine(tooltip, i)
    end
end

-- Whether the byte at `i` is an ASCII letter or digit, so a match there runs into a longer word.
local function wordByte(text, i)
    local c = byte(text, i)
    return c and ((c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122))
end

-- Where `word` first stands alone in `text`. A plain search with the edges checked by hand, since
-- %w and %f only know ASCII and would never match a Russian or Korean class name.
local function findWord(text, word)
    local start = 1
    while true do
        local first, last = find(text, word, start, true)
        if not first then
            return
        end
        if not wordByte(text, first - 1) and not wordByte(text, last + 1) then
            return first, last
        end
        start = first + 1
    end
end

-- `text` with the first match of `pattern` (or of `word`, standing alone) wrapped in a color, and
-- whether it matched. The |r goes back to the line's own color.
function TooltipKit.ColorMatch(text, pattern, r, g, b, word)
    local first, last
    if word then
        first, last = findWord(text, word)
    else
        first, last = find(text, pattern)
    end
    if not first then
        return text, false
    end
    return sub(text, 1, first - 1) .. TooltipKit.Code(r, g, b) .. sub(text, first, last) .. "|r" .. sub(text, last + 1), true
end

-- r, g, b for the unit in `mode`: "class" gives a player's class color, and every other unit
-- (and mode "reaction") the color Blizzard gives its name and selection circle
-- (UnitSelectionColor). Always a color; it may be secret, so it goes straight to the setters,
-- never compared.
function TooltipKit.UnitColor(unit, mode)
    if mode == "class" then
        local color = TooltipKit.PlayerClass(unit)
        if color then
            return color:GetRGB()
        end
    end
    return UnitSelectionColor(unit, true)
end

-- The color for a unit of `level` against the player's, as quest levels are colored.
function TooltipKit.LevelColor(level)
    if level <= 0 then
        local own = Plain(UnitLevel("player"))
        if type(own) ~= "number" then
            return nil
        end
        level = own + 10 -- "??": far above the player
    end
    return GetCreatureDifficultyColor(level)
end
