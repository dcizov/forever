--[[
    Forever Tweaks - Five-Second Rule
    Mana comes back fully only five seconds after your last spell that cost mana (the "five-second
    rule"). This runs a spark along your mana bar for those five seconds after each such cast, so
    you see when regeneration picks up again. Only while mana is the power you see (not as a
    bear or cat). The spark is an animation, so nothing runs each frame.
    Left to WilduTools' Five Second Rule Spark while that's on.
]]

local _, ns = ...
local L = ns.L

local ipairs = ipairs
local Plain = ns.Plain
local OtherAddons = ns.OtherAddons

local COVERS = { { "!WilduTools", "unitFrames_fiveSecondRuleSpark" } }
local RULE = 5 -- seconds
local MANA = 0 -- Enum.PowerType.Mana

local M = ns:NewModule("FiveSecond", {
    title = L.FIVESEC_TITLE,
    category = "interface",
    group = L.GROUP_COMBAT,
    description = L.FIVESEC_DESC,
    added = "1.9.3",
    defaults = { enabled = false },
})

M.notice = OtherAddons.CoveredNotices(M, COVERS, L.FIVESEC_WHAT)

local spark, sweep

local function build(bar)
    spark = bar:CreateTexture(nil, "OVERLAY")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetBlendMode("ADD")
    spark:SetSize(16, bar:GetHeight() * 2)
    spark:SetPoint("CENTER", bar, "LEFT", 0, 0)
    spark:Hide()
    sweep = spark:CreateAnimationGroup()
    local move = sweep:CreateAnimation("Translation")
    move:SetOffset(bar:GetWidth(), 0)
    move:SetDuration(RULE)
    sweep:SetScript("OnFinished", function() spark:Hide() end)
    sweep:SetScript("OnStop", function() spark:Hide() end)
end

local function costsMana(spellID)
    for _, cost in ipairs(C_Spell.GetSpellPowerCost(spellID) or {}) do
        if cost.type == MANA and ((cost.cost or 0) > 0 or (cost.costPerSec or 0) > 0) then return true end
    end
    return false
end

local function onCast(_, _, unit, _, spellID)
    spellID = Plain(spellID)
    if unit ~= "player" or not spellID or UnitPowerType("player") ~= MANA or not costsMana(spellID)
        or OtherAddons.CoveredBy(M, COVERS) then
        return
    end
    if not spark then build(PlayerFrame_GetManaBar()) end
    sweep:Stop()
    spark:Show()
    sweep:Play()
end

local function onPowerType(_, _, unit)
    if unit == "player" and sweep and UnitPowerType("player") ~= MANA then sweep:Stop() end
end

function M:OnEnable()
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", onCast)
    self:RegisterEvent("UNIT_DISPLAYPOWER", onPowerType)
end

function M:OnDisable()
    if sweep then sweep:Stop() end
end

function M:DebugLine()
    return sweep and sweep:IsPlaying() and L.FIVESEC_RUNNING or L.FIVESEC_IDLE
end
