--[[
    Forever Codex - Modules/Journal/JournalPage.lua
    More of JournalKit (ns.JournalKit): the parchment and what's written on it.

      * Ink: J.Ink (colour codes as the parchment writes them), J.InkFont (a font string in an
        ink of J.COLOR), J.InkTree (every word of a frame in ink, kept so: the settings window's
        pages; the game's controls left as they are).
      * The page: J.Paper (the spellbook's right page cut to its paper), J.Parchment, J.Page (an
        inset with the parchment in it), J.Divider (the spellbook's), J.Panel and J.HeaderInset
        (sections), J.Header (a heading in dark gold with its count, over the divider).
]]

local _, ns = ...

local ipairs, math, type, format, tonumber = ipairs, math, type, string.format, tonumber
local CreateFrame = CreateFrame
local J = assert(ns.JournalKit, "JournalPage.lua loads after JournalKit.lua")
local C = J.COLOR

---------------------------------------------------------------------------
-- Ink: text on the parchment
---------------------------------------------------------------------------

-- A colour code's colour as written on the parchment: white and grey become the ink (grey the
-- soft ink), the game's gold the headings' dark gold, any other colour darker so it reads on the paper.
local inked = {}
local function inkCode(hex)
    local done = inked[hex]
    if done then return done end
    local r, g, b = tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
    local high, low = math.max(r, g, b), math.min(r, g, b)
    local key
    if high - low < 0.12 then
        key = high > 0.8 and "ink" or "inkSoft"
    elseif r > 0.9 and g > 0.7 and b < 0.2 then
        key = "heading"
    end
    if key then
        done = J.Hex(key)
    else
        -- Its brightest part as deep as the ink's headings: a pale blue reads as well as a red.
        local f = math.min(0.55, 0.45 / high) * 255
        done = format("|cff%02x%02x%02x", r * f, g * f, b * f)
    end
    inked[hex] = done
    return done
end

-- `text` with its colour codes as the parchment writes them (see inkCode).
function J.Ink(text)
    if type(text) ~= "string" then return text end
    return (text:gsub("|c[fF][fF](%x%x%x%x%x%x)", function(hex) return inkCode(hex:lower()) end))
end

-- Writes font string `fs` in ink (`key`: J.COLOR's, the ink by default), with no shadow.
function J.InkFont(fs, key)
    local c = C[key or "ink"]
    fs:SetTextColor(c[1], c[2], c[3])
    fs:SetShadowColor(0, 0, 0, 0)
end

-- The game's fonts and the ink each is written in on the parchment (J.InkTree): gold headings
-- and labels in the headings' dark gold, white in the ink, grey in the softer ink.
local FONT_INK = {
    GameFontNormal = "heading", GameFontNormalSmall = "heading", GameFontNormalLarge = "heading",
    GameFontNormalHuge = "heading", GameFontHighlight = "ink", GameFontHighlightSmall = "ink",
    GameFontHighlightLarge = "ink", GameFontHighlightHuge = "ink", GameFontDisable = "inkSoft",
    GameFontDisableSmall = "inkSoft", GameFontDisableLarge = "inkSoft",
    QuestTitleFont = "ink", QuestFont = "ink", -- as the quest log writes them on its parchment
}

-- Writes font string `fs` in the ink its font calls for, and keeps it so: what sets its font,
-- colour or text later goes through the ink too.
local function inkString(fs)
    if fs.inked then return end
    fs.inked = true
    local setFont, setColor, setText = fs.SetFontObject, fs.SetTextColor, fs.SetText
    local function paint(self)
        local font = self:GetFontObject()
        local c = C[FONT_INK[font and font:GetName() or ""] or "ink"]
        setColor(self, c[1], c[2], c[3])
        self:SetShadowColor(0, 0, 0, 0)
    end
    function fs.SetFontObject(self, font)
        setFont(self, font)
        paint(self)
    end
    function fs.SetTextColor(self, r, g, b)
        -- A shade of grey set by the page (a part turned off): the softer ink, else as the font.
        if r and r == g and g == b and r < 0.8 then
            local c = C.inkSoft
            return setColor(self, c[1], c[2], c[3])
        end
        paint(self)
    end
    function fs.SetText(self, text) setText(self, J.Ink(text)) end
    paint(fs)
    fs:SetText(fs:GetText())
end

-- The kinds of frame whose words are the game's own control's (a button's face, a dropdown, a
-- box to type in): left as they are on the parchment.
local CONTROLS = { EditBox = true, DropdownButton = true, Slider = true, CheckButton = true, ScrollBar = true }

-- Writes every word in `frame` and what it holds in the parchment's ink (J.InkFont's), but the
-- game's controls' (CONTROLS, and buttons of a template, whose face is a font string of theirs).
-- Again on what was added since: each one is inked once.
function J.InkTree(frame)
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:GetObjectType() == "FontString" then inkString(region) end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        local kind = child:GetObjectType()
        -- A dropdown (WowStyle1DropdownTemplate) can answer as a plain Button: known by its menu
        -- (a mixin method, copied onto the frame itself).
        local control = CONTROLS[kind] or rawget(child, "SetupMenu") ~= nil or (kind == "Button" and child:GetFontString() ~= nil)
        if not control then J.InkTree(child) end
    end
end

---------------------------------------------------------------------------
-- The page and what's on it
---------------------------------------------------------------------------

-- The paper of the spellbook's right page (spellbook-Page-Right-C60, 810 x 682): the atlas less
-- its dark header band across the top, its frame's edge down the right and its foot.
local PAGE_ATLAS, PAGE_W, PAGE_H = "spellbook-Page-Right-C60", 810, 682
local PAPER = { left = 4, right = 784, top = 60, bottom = 672 }

-- Draws the paper on texture `paper` (cut from the atlas: J.Parchment's and the banner's).
function J.Paper(paper)
    local info = C_Texture.GetAtlasInfo(PAGE_ATLAS)
    local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
    paper:SetTexture(info.file)
    paper:SetTexCoord(l + (r - l) * PAPER.left / PAGE_W, l + (r - l) * PAPER.right / PAGE_W,
        t + (b - t) * PAPER.top / PAGE_H, t + (b - t) * PAPER.bottom / PAGE_H)
    return paper
end

-- The parchment inside `inset`, under the inset's own border.
function J.Parchment(inset)
    local paper = inset:CreateTexture(nil, "BACKGROUND", nil, 2)
    paper:SetPoint("TOPLEFT", 3, -3)
    paper:SetPoint("BOTTOMRIGHT", -3, 3)
    return J.Paper(paper)
end

-- A page: Blizzard's inset with the parchment in it. Returns the inset and the frame inside it
-- (3 in from its border) to lay the page out in.
function J.Page(parent)
    local inset = J.Inset(parent)
    local background = inset:CreateTexture(nil, "BACKGROUND")
    background:SetColorTexture(0.18, 0.10, 0.06, 1)
    background:SetAllPoints()
    J.Parchment(inset)
    local holder = CreateFrame("Frame", nil, inset)
    holder:SetPoint("TOPLEFT", 3, -3)
    holder:SetPoint("BOTTOMRIGHT", -3, 3)
    if inset.NineSlice then inset.NineSlice:SetFrameLevel(holder:GetFrameLevel() + 5) end
    return inset, holder
end

-- The spellbook's divider under a heading: across `parent`'s width at `y` from its top (or
-- anchored by the caller when `y` is nil).
function J.Divider(parent, y)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetAtlas("spellbook-divider")
    line:SetHeight(8)
    if y then
        line:SetPoint("TOPLEFT", 0, y)
        line:SetPoint("TOPRIGHT", 0, y)
    end
    return line
end

-- A section of a page: a plain frame (what it holds is on the parchment itself).
function J.Panel(parent)
    return CreateFrame("Frame", nil, parent)
end

-- A section with a heading strip HEADER_INSET high (the caller fills it) over the spellbook's
-- divider, and box.content for what it holds below.
J.HEADER_INSET = 34
function J.HeaderInset(parent)
    local box = J.Panel(parent)
    local line = J.Divider(box)
    line:SetPoint("TOPLEFT", 6, -J.HEADER_INSET + 4)
    line:SetPoint("TOPRIGHT", -6, -J.HEADER_INSET + 4)
    box.content = CreateFrame("Frame", nil, box)
    box.content:SetPoint("TOPLEFT", 12, -J.HEADER_INSET - 8)
    box.content:SetPoint("BOTTOMRIGHT", -8, 8)
    return box
end

-- A heading on the parchment, as the spellbook heads its groups: in dark gold, a count in the
-- softer ink beside it (f.count), over the spellbook's divider.
function J.Header(parent, text, font)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(26)
    f.text = f:CreateFontString(nil, "OVERLAY", font or "GameFontNormalLarge")
    f.text:SetPoint("BOTTOMLEFT", 2, 8)
    f.text:SetText(text)
    J.InkFont(f.text, "heading")
    f.count = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.count:SetPoint("BOTTOMLEFT", f.text, "BOTTOMRIGHT", 6, 1)
    J.InkFont(f.count, "inkSoft")
    local line = J.Divider(f)
    line:SetPoint("BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", 0, 0)
    return f
end

