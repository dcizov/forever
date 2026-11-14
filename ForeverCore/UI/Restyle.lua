--[[
    Forever Core - UI/Restyle.lua
    Giving another addon's frames Blizzard's look, for the skins on the Tweaks for Addons page
    (Dungeon Journal Skin). Pieces the other addon keeps setting are set
    once and set again, through the module's hooks, every time it changes them, with a guard so
    our own call doesn't run the hook again. `mod` is the module whose hooks they are:

      * Restyle.KeepText(mod, text, font, color): keeps a Blizzard font object, the colour, and no
        shadow (Blizzard's quest text has none).
      * Restyle.PlainText(mod, text): the |c colour codes in its text taken out, as no SetTextColor
        overrides them.
      * Restyle.PanelButton(mod, button, state): a backdrop button drawn as Blizzard's red panel
        button: UIPanelButtonNoTooltipTemplate's Left, Middle and Right from
        Interface\Buttons\UI-Panel-Button-<look> (Blizzard_SharedXML/SecureUIPanelTemplates.xml),
        its highlight, and Down while pressed. state(button) says "Up" or "Disabled";
        Restyle.PaintPanelButton(button, look) redraws it.

    And, set once (a backdrop the other addon sets again is the module's to clear again):
      * Restyle.Window(frame, layout, lift): its backdrop cleared, Blizzard's rock background, and
        a NineSlice border (ButtonFrameTemplateNoPortrait, GenericMetal) as a frame of its own
        drawn above the content, `lift` px above the frame's top. Returns the border frame.
      * Restyle.Inset(panel, atlas): its backdrop cleared, InsetFrameTemplate's inner edge, and the
        inset's marble (or `atlas`) behind it.
]]

local _, ns = ...

local ipairs, pairs = ipairs, pairs
local CreateFrame, NineSliceUtil = CreateFrame, NineSliceUtil

local Restyle = {}
ns.Restyle = Restyle

---------------------------------------------------------------------------
-- Font strings
---------------------------------------------------------------------------

local kept = setmetatable({}, { __mode = "k" }) -- font string -> { color, font, plain, noShadow }
local busy = false -- our own call is running: the hooks it sets off do nothing

-- Applies everything kept for `text` again, after the frame's owner changed it.
local function reapply(_, text)
    local want = kept[text]
    if busy or not want then return end
    busy = true
    if want.font then text:SetFontObject(want.font) end
    if want.color then text:SetTextColor(want.color[1], want.color[2], want.color[3]) end
    if want.noShadow then text:SetShadowOffset(0, 0) end
    if want.plain then
        local shown = text:GetText()
        if ns.Plain(shown) then
            local plain = shown:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            if plain ~= shown then text:SetText(plain) end
        end
    end
    busy = false
end

-- What the other addon may call to change each kept piece.
local SETTERS = {
    color = { "SetTextColor" },
    font = { "SetFont", "SetFontObject" },
    noShadow = { "SetShadowOffset", "SetShadowColor" },
    plain = { "SetText" },
}

local function keep(mod, text, what)
    if not text then return end
    local want = kept[text] or {}
    kept[text] = want
    for key, value in pairs(what) do
        want[key] = value
        for _, setter in ipairs(SETTERS[key]) do mod:Hook(text, setter, reapply) end
    end
    reapply(nil, text)
end

function Restyle.KeepText(mod, text, font, color) keep(mod, text, { font = font, color = color, noShadow = true }) end

function Restyle.PlainText(mod, text) keep(mod, text, { plain = true }) end

---------------------------------------------------------------------------
-- Blizzard's red panel button
---------------------------------------------------------------------------

local PANEL_BUTTON = "Interface\\Buttons\\UI-Panel-Button-"
local PIECES = { { 0, 0.09375 }, { 0.09375, 0.53125 }, { 0.53125, 0.625 } } -- Left, Middle, Right
local panelArt = setmetatable({}, { __mode = "k" }) -- button -> its three pieces

function Restyle.PaintPanelButton(button, look)
    for _, piece in ipairs(panelArt[button] or {}) do piece:SetTexture(PANEL_BUTTON .. look) end
end

function Restyle.PanelButton(mod, button, state)
    if not button or panelArt[button] then return end
    button:ClearBackdrop()
    local made = {}
    for i, coords in ipairs(PIECES) do
        local piece = button:CreateTexture(nil, "BACKGROUND")
        piece:SetTexCoord(coords[1], coords[2], 0, 0.6875)
        made[i] = piece
    end
    made[1]:SetWidth(12)
    made[1]:SetPoint("TOPLEFT")
    made[1]:SetPoint("BOTTOMLEFT")
    made[3]:SetWidth(12)
    made[3]:SetPoint("TOPRIGHT")
    made[3]:SetPoint("BOTTOMRIGHT")
    made[2]:SetPoint("TOPLEFT", made[1], "TOPRIGHT")
    made[2]:SetPoint("BOTTOMRIGHT", made[3], "BOTTOMLEFT")
    panelArt[button] = made
    button:SetHighlightTexture(PANEL_BUTTON .. "Highlight", "ADD")
    button:GetHighlightTexture():SetTexCoord(0, 0.625, 0, 0.6875)
    Restyle.PaintPanelButton(button, state(button))
    mod:HookScript(button, "OnMouseDown", function()
        if state(button) == "Up" then Restyle.PaintPanelButton(button, "Down") end
    end)
    mod:HookScript(button, "OnMouseUp", function() Restyle.PaintPanelButton(button, state(button)) end)
end

---------------------------------------------------------------------------
-- Window chrome: Blizzard's metal frame on rock, and its marble insets
---------------------------------------------------------------------------

local function tiled(texture, file)
    texture:SetTexture(file, "REPEAT", "REPEAT")
    texture:SetHorizTile(true)
    texture:SetVertTile(true)
end

function Restyle.Window(frame, layout, lift)
    frame:ClearBackdrop()
    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
    tiled(bg, "Interface\\FrameGeneral\\UI-Background-Rock")
    bg:SetPoint("TOPLEFT", 2, -2)
    bg:SetPoint("BOTTOMRIGHT", -2, 2)
    -- Like Blizzard's windows, the NineSlice is its own frame drawn above the content.
    local border = CreateFrame("Frame", nil, frame)
    border:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, lift or 0)
    border:SetPoint("BOTTOMRIGHT")
    border:SetFrameLevel(frame:GetFrameLevel() + 50)
    border:EnableMouse(false)
    NineSliceUtil.ApplyLayoutByName(border, layout)
    border.bg = bg
    return border
end

function Restyle.Inset(panel, atlas)
    panel:ClearBackdrop()
    NineSliceUtil.ApplyLayoutByName(panel, "InsetFrameTemplate")
    local bg = panel:CreateTexture(nil, "BACKGROUND", nil, -6)
    if atlas then
        bg:SetAtlas(atlas)
    else
        tiled(bg, "Interface\\FrameGeneral\\UI-Background-Marble")
    end
    bg:SetAllPoints(panel)
    return bg
end
