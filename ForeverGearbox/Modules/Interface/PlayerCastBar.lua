--[[
    Forever Gearbox - Cast Bar
    Small changes to Blizzard's player cast bar (PlayerCastingBarFrame), each its own checkbox:
      * Timer Inside: the cast time (Edit Mode's Show Cast Time) inside the bar's right end, with
        an outline, instead of beside the bar.
      * Simple Look: the spell name in the bar instead of in the box under it.
      * Channel Ticks: a line on the bar where each tick of a channelled spell lands (Arcane
        Missiles, Drain Life, Mind Flay, ...), so you can stop right after one. The ticks per
        spell are what the spells do in Classic; a rank with fewer ticks shows the top rank's.
    The bar's size and place are Edit Mode's (Cast Bar: Bar Size). Each piece goes back as
    Blizzard's XML has it when its checkbox goes off.
    Left to WilduTools' cast bar options while those are on.
]]

local _, ns = ...
local L = ns.L

local pairs, ipairs = pairs, ipairs
local Plain = ns.Plain
local OtherAddons = ns.OtherAddons

local COVERS = {
    timerInside = { { "!WilduTools", "blizzUI_attachCastTimeTextInside" } },
    simple = { { "!WilduTools", "castBar_simplifyPlayerCastBar" } },
    ticks = { { "!WilduTools", "castBar_showTicks" } },
}

-- Channelled spells by their base spell ID, with how many times they tick.
local TICKS = { [5143] = 5, [689] = 5, [1120] = 5, [5138] = 5, [15407] = 3, [10] = 8, [16914] = 10, [740] = 5,
    [755] = 10, [5740] = 4, [12051] = 4, [1510] = 6 }

local M = ns:NewModule("PlayerCastBar", {
    title = L.CASTBAR_TITLE,
    category = "interface",
    group = L.GROUP_COMBAT,
    description = L.CASTBAR_DESC,
    added = "1.9.3",
    defaults = { timerInside = false, simple = false, ticks = false },
    options = {
        { key = "timerInside", type = "checkbox", label = L.CASTBAR_TIMER, tooltip = L.CASTBAR_TIMER_TIP },
        { key = "simple", type = "checkbox", label = L.CASTBAR_SIMPLE, tooltip = L.CASTBAR_SIMPLE_TIP },
        { key = "ticks", type = "checkbox", label = L.CASTBAR_TICKS, tooltip = L.CASTBAR_TICKS_TIP },
    },
    features = { "timerInside", "simple", "ticks" },
})

M.notice = OtherAddons.CoveredNotices(M, COVERS.timerInside, L.CASTBAR_WHAT_TIMER)
OtherAddons.CoveredNotices(M, COVERS.simple, L.CASTBAR_WHAT_SIMPLE, M.notice)
OtherAddons.CoveredNotices(M, COVERS.ticks, L.CASTBAR_WHAT_TICKS, M.notice)

local function on(key) return M.active and M.db[key] and not OtherAddons.CoveredBy(M, COVERS[key]) end

local bar = PlayerCastingBarFrame
local tickLines = {}
local tickNames -- spell name -> ticks, made once (spell names come with the client's language)

---------------------------------------------------------------------------
-- Timer and look
---------------------------------------------------------------------------

local function placeTimer()
    local timer = bar.CastTimeText
    timer:ClearAllPoints()
    if on("timerInside") then
        timer:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
        timer:SetFontObject("GameFontHighlightSmall")
        local font, size = timer:GetFont()
        timer:SetFont(font, size, "OUTLINE")
    else -- as Mainline/CastingBarFrame.xml has it
        timer:SetPoint("LEFT", bar, "RIGHT", 10, 0)
        timer:SetFontObject("GameFontHighlightLarge")
    end
end

local busy = false
local function placeText()
    if busy then return end
    busy = true
    local simple = on("simple")
    bar.TextBorder:SetShown(not simple)
    if simple then
        bar.Text:ClearAllPoints()
        bar.Text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    else
        bar:SetLook(bar.look) -- Blizzard lays its text out again
    end
    busy = false
end

---------------------------------------------------------------------------
-- Channel ticks
---------------------------------------------------------------------------

local function hideTicks()
    for _, line in ipairs(tickLines) do line:Hide() end
end

local function ticksFor(spellID)
    if not tickNames then
        tickNames = {}
        for id, count in pairs(TICKS) do
            local name = C_Spell.GetSpellName(id)
            if name then tickNames[name] = count end
        end
    end
    local name = C_Spell.GetSpellName(spellID)
    return name and tickNames[name]
end

local function showTicks(count)
    hideTicks()
    local width = bar:GetWidth()
    for i = 1, count - 1 do
        local line = tickLines[i]
        if not line then
            line = bar:CreateTexture(nil, "OVERLAY", nil, 3)
            line:SetColorTexture(1, 1, 1, 0.6)
            line:SetWidth(1)
            tickLines[i] = line
        end
        line:ClearAllPoints()
        line:SetPoint("TOP", bar, "TOPLEFT", width * i / count, 0)
        line:SetPoint("BOTTOM", bar, "BOTTOMLEFT", width * i / count, 0)
        line:Show()
    end
end

local function onChannelStart(_, _, unit, _, spellID)
    spellID = Plain(spellID)
    if unit ~= "player" or not spellID or not on("ticks") then return end
    local count = ticksFor(spellID)
    if count then showTicks(count) else hideTicks() end
end

local function onChannelStop(_, _, unit)
    if unit == "player" then hideTicks() end
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

local function applyAll()
    placeTimer()
    placeText()
    if not on("ticks") then hideTicks() end
end

function M:OnEnable()
    -- Blizzard lays the text out again when the bar's look changes (Edit Mode, attaching it).
    self:Hook(bar, "SetLook", function() if on("simple") then placeText() end end)
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", onChannelStart)
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", onChannelStop)
    applyAll()
end

function M:OnDisable() applyAll() end
function M:OnSettingChanged() applyAll() end
