--[[
    Forever Tweaks - Class Colors
    Players' health bars and names in their class colour on the player, target, focus, party and
    target-of-target frames, and NPCs' health bars by how they stand toward you: red when hostile,
    yellow when neutral, grey when someone else tapped them. Friendly NPCs, disconnected players
    and units the game keeps secret keep Blizzard's colours. The bar behind a target's or focus's
    name takes the class colour too. Nameplates are Blizzard's to colour: the game's own console
    variables for class-coloured plates are asked for as notices, each with its button.

    Blizzard's health bars are a green texture it never tints (lockColor), so a bar is
    desaturated and tinted to show a colour. Every colour and desaturation Blizzard sets on a bar
    is remembered and painted over again, so turning the module (or a frame) off puts back exactly
    what Blizzard last set. Blizzard calls UnitFrame_Update whenever a frame's unit changes, so
    the colours follow it.
    Left to Forever++'s Class Colors while that's on.
    Adapted from Forever++'s Class Colors by xIGBClutchIx (MIT License); its friends and Who list
    colouring is left out (Forever's friends list is the Social window's cards).
]]

local _, ns = ...
local L = ns.L

local _G, setmetatable = _G, setmetatable
local Plain, Kit, OtherAddons = ns.Plain, ns.TooltipKit, ns.OtherAddons

local COVERS = { { "ForeverPlusPlus", "ClassColors" } }

local FRAMES = L.CLASSCOLORS_SECTION_FRAMES
local M = ns:NewModule("ClassColors", {
    title = L.CLASSCOLORS_TITLE,
    category = "interface",
    description = L.CLASSCOLORS_DESC,
    added = "2.7.0",
    defaults = { healthBars = true, npcBars = true, nameColor = "class", nameBackgrounds = true,
        player = true, target = true, focus = true, party = true, targetOfTarget = true },
    options = {
        { key = "healthBars", type = "checkbox", label = L.CLASSCOLORS_BARS, tooltip = L.CLASSCOLORS_BARS_TIP },
        { key = "npcBars", type = "checkbox", label = L.CLASSCOLORS_NPC_BARS, tooltip = L.CLASSCOLORS_NPC_BARS_TIP },
        { key = "nameColor", type = "dropdown", label = L.CLASSCOLORS_NAMES, tooltip = L.CLASSCOLORS_NAMES_TIP,
          choices = { { "default", L.CLASSCOLORS_NAMES_DEFAULT }, { "white", L.CLASSCOLORS_NAMES_WHITE },
              { "class", L.CLASSCOLORS_NAMES_CLASS } } },
        { key = "nameBackgrounds", type = "checkbox", label = L.CLASSCOLORS_NAME_BG, tooltip = L.CLASSCOLORS_NAME_BG_TIP },
        { key = "player", type = "checkbox", label = L.CLASSCOLORS_PLAYER, section = FRAMES },
        { key = "target", type = "checkbox", label = L.CLASSCOLORS_TARGET },
        { key = "focus", type = "checkbox", label = L.CLASSCOLORS_FOCUS },
        { key = "party", type = "checkbox", label = L.CLASSCOLORS_PARTY },
        { key = "targetOfTarget", type = "checkbox", label = L.CLASSCOLORS_TOT },
    },
})

-- Players' bars on Blizzard's nameplates are a flat blue or red, and friendly players' names
-- white, unless these are on (NamePlateDriverMixin:UpdateNamePlateOptions reads them).
M.notice = OtherAddons.CoveredNotices(M, COVERS, L.CLASSCOLORS_WHAT, {
    { requires = { { cvar = "nameplateShowFriendlyClassColor", value = "1" } }, tooltip = L.CLASSCOLORS_PLATES_FRIENDLY },
    { requires = { { cvar = "nameplateShowClassColor", value = "1" } }, tooltip = L.CLASSCOLORS_PLATES_ENEMY },
    { requires = { { cvar = "nameplateUseClassColorForFriendlyPlayerUnitNames", value = "1" } },
      tooltip = L.CLASSCOLORS_PLATES_NAMES },
})

local MAX_PARTY = 4
local NEUTRAL_REACTION = 4 -- UnitReaction: 1-3 hostile, 4 neutral, 5-8 friendly
-- Blizzard's hostile, neutral and tapped colours (UnitSelectionColor, Classic's tapped bar).
local HOSTILE, NEUTRAL, TAPPED = CreateColor(1, 0, 0), CreateColor(1, 1, 0), CreateColor(0.5, 0.5, 0.5)
local WHITE = CreateColor(1, 1, 1)
local weak = { __mode = "k" }
local applying = setmetatable({}, weak)            -- bar or texture -> true while we colour it
local painted = setmetatable({}, weak)             -- bar, name or texture -> true while in our colour
local blizzardColor = setmetatable({}, weak)       -- bar -> { r, g, b, a } Blizzard last set
local blizzardDesaturated = setmetatable({}, weak) -- bar -> what Blizzard last set
local oldNameColor = setmetatable({}, weak)        -- name -> { r, g, b, a } before we coloured it
local backgroundFrame = setmetatable({}, weak)     -- texture -> the unit frame it's the background of
local blizzardBackground = setmetatable({}, weak)  -- texture -> { r, g, b, a } Blizzard last set

local function inCharge() return M.active and not OtherAddons.CoveredBy(M, COVERS) end

-- Which frame setting a Blizzard unit frame falls under, or nil.
local function partOf(frame)
    if not frame then return nil end
    local target, focus = _G.TargetFrame, _G.FocusFrame
    if frame == _G.PlayerFrame then return "player" end
    if frame == target then return "target" end
    if frame == focus then return "focus" end
    if (target and frame == target.totFrame) or (focus and frame == focus.totFrame) then return "targetOfTarget" end
    if _G.PartyFrame and frame:GetParent() == _G.PartyFrame then return "party" end
end

local function frameOn(frame, unit)
    local part = partOf(frame)
    return inCharge() and part and M.db[part] and unit and true or false
end

-- An NPC's colour by how it stands toward you, or nil for friendly ones and ones the game won't say.
local function reactionColor(unit)
    if Plain(UnitPlayerControlled(unit)) == false and Plain(UnitIsTapDenied(unit)) then return TAPPED end
    -- The unit's reaction to the player, as Blizzard's tooltip reads it.
    local reaction = Plain(UnitReaction(unit, "player"))
    if not reaction then return nil end
    if reaction < NEUTRAL_REACTION then return HOSTILE end
    if reaction == NEUTRAL_REACTION then return NEUTRAL end
end

-- The colour for `unit`'s health bar, name or name background (`setting`: healthBars, names or
-- nameBackgrounds) on `frame`, or nil for Blizzard's.
local function wanted(frame, unit, setting)
    if not frameOn(frame, unit) then return nil end
    local player = Plain(UnitIsPlayer(unit))
    if player == nil then return nil end
    if not player then
        return setting == "healthBars" and M.db.npcBars and reactionColor(unit) or nil
    end
    if setting ~= "names" and not M.db[setting] then return nil end
    if Plain(UnitIsConnected(unit)) == false then return nil end
    return Kit.PlayerClass(unit)
end

-- Health bars ---------------------------------------------------------------------------------

local function restoreBar(bar)
    local color = blizzardColor[bar]
    applying[bar] = true
    bar:SetStatusBarDesaturated(blizzardDesaturated[bar] or false)
    if color then
        bar:SetStatusBarColor(color[1], color[2], color[3], color[4])
    else
        bar:SetStatusBarColor(1, 1, 1) -- a lockColor bar: Blizzard never tints it
    end
    applying[bar] = nil
    painted[bar] = nil
end

-- What the bar shows before we first paint it is Blizzard's: kept to put back (the hooks don't
-- hear Blizzard while the module is off).
local function keepBlizzardBar(bar)
    local r, g, b, a = bar:GetStatusBarColor()
    if Plain(r) then blizzardColor[bar] = { r, g, b, a } end
    if bar.IsStatusBarDesaturated then
        local desaturated = Plain(bar:IsStatusBarDesaturated())
        if desaturated ~= nil then blizzardDesaturated[bar] = desaturated end
    end
end

local function paintBar(bar)
    local color = wanted(bar.unitFrame, bar.unit, "healthBars")
    if not color then
        if painted[bar] then restoreBar(bar) end
        return
    end
    if not painted[bar] then keepBlizzardBar(bar) end
    applying[bar] = true
    bar:SetStatusBarDesaturated(true)
    bar:SetStatusBarColor(color:GetRGB())
    applying[bar] = nil
    painted[bar] = true
end

-- What Blizzard sets is remembered, then painted over again (a hook gets the module first).
local function onBarColor(_, bar, r, g, b, a)
    if applying[bar] then return end
    blizzardColor[bar] = { r, g, b, a }
    paintBar(bar)
end

local function onBarDesaturated(_, bar, desaturated)
    if applying[bar] then return end
    blizzardDesaturated[bar] = desaturated
    paintBar(bar)
end

-- Names and their backgrounds -------------------------------------------------------------------

-- A font string in `color`, or back in the colour it had before we first coloured it.
local function colorText(text, color)
    if color then
        if not oldNameColor[text] then oldNameColor[text] = { text:GetTextColor() } end
        text:SetTextColor(color:GetRGB())
        painted[text] = true
    elseif painted[text] then
        local old = oldNameColor[text]
        text:SetTextColor(old[1], old[2], old[3], old[4])
        painted[text] = nil
    end
end

local function paintName(frame)
    local text = frame.name
    if not text then return end
    local color
    if M.db.nameColor == "white" then
        color = frameOn(frame, frame.unit) and WHITE or nil
    elseif M.db.nameColor == "class" then
        color = wanted(frame, frame.unit, "names")
    end
    colorText(text, color)
end

-- The bar behind a target's or focus's name that Blizzard tints by faction (its field differs
-- between builds); frames without one (player, party) give nil.
local function backgroundOf(frame)
    if frame.nameBackground then return frame.nameBackground end
    local content = frame.TargetFrameContent
    local main = content and content.TargetFrameContentMain
    return main and main.ReputationColor
end

local function paintBackground(texture, frame)
    local color = wanted(frame, frame.unit, "nameBackgrounds")
    if not color then
        if painted[texture] then
            local old = blizzardBackground[texture]
            applying[texture] = true
            if old then texture:SetVertexColor(old[1], old[2], old[3], old[4]) end
            applying[texture] = nil
            painted[texture] = nil
        end
        return
    end
    if not painted[texture] then
        local r, g, b, a = texture:GetVertexColor()
        if Plain(r) then blizzardBackground[texture] = { r, g, b, a } end
    end
    applying[texture] = true
    texture:SetVertexColor(color:GetRGB())
    applying[texture] = nil
    painted[texture] = true
end

local function onBackgroundColor(_, texture, r, g, b, a)
    if applying[texture] then return end
    blizzardBackground[texture] = { r, g, b, a }
    paintBackground(texture, backgroundFrame[texture])
end

-- Every frame ---------------------------------------------------------------------------------

local function paintFrame(frame)
    if not partOf(frame) then return end
    local bar = frame.healthbar
    if bar then
        M:Hook(bar, "SetStatusBarColor", onBarColor)
        M:Hook(bar, "SetStatusBarDesaturated", onBarDesaturated)
        paintBar(bar)
    end
    paintName(frame)
    local texture = backgroundOf(frame)
    if texture then
        backgroundFrame[texture] = frame
        M:Hook(texture, "SetVertexColor", onBackgroundColor)
        paintBackground(texture, frame)
    end
end

local function updateAll()
    local target, focus, party = _G.TargetFrame, _G.FocusFrame, _G.PartyFrame
    paintFrame(_G.PlayerFrame)
    paintFrame(target)
    paintFrame(focus)
    paintFrame(target and target.totFrame)
    paintFrame(focus and focus.totFrame)
    for i = 1, MAX_PARTY do paintFrame(party and party["MemberFrame" .. i]) end
end

M.Paint = updateAll -- (the tests' way in)

function M:OnEnable()
    self:Hook("UnitFrame_Update", function(_, frame) paintFrame(frame) end)
    -- A reaction or tap can change with no new unit (a mob turns hostile, someone tags it); the
    -- event comes for every unit at once, so one pass a frame later covers a burst.
    self:RegisterEvent("UNIT_FACTION", function() self:Soon(updateAll) end)
    updateAll()
end

-- M.active is already false here: every painted bar and name goes back to Blizzard's.
function M:OnDisable() updateAll() end

function M:OnSettingChanged() updateAll() end
