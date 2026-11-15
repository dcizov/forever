--[[
    Forever Tweaks - Melee Range
    "Too far" in red in the middle of the screen while your target is a living enemy out of your
    melee reach, so you step in instead of wondering why nothing swings. Reach is the game's own
    range check (C_Spell.EnableSpellRangeCheck, SPELL_RANGE_CHECK_UPDATE) on a melee spell you
    know: the first harmful one in your spellbook with melee range, else Auto Attack. Moves and
    sizes in Edit Mode like the other displays; it takes no clicks, so it never gets in the way.
    Left to WilduTools' Melee Range Display while that's on.
]]

local _, ns = ...
local L = ns.L

local format, tostring = string.format, tostring
local Plain = ns.Plain
local OtherAddons = ns.OtherAddons

local COVERS = { { "!WilduTools", "wilduUI_rangeMeleeIndicator" } }
local AUTO_ATTACK = 6603
local MELEE_REACH = 5 -- yards: a melee ability's range

local M = ns:NewModule("MeleeRange", {
    title = L.MELEE_TITLE,
    category = "interface",
    group = L.GROUP_COMBAT,
    description = L.MELEE_DESC,
    added = "1.9.3",
    defaults = ns.Widgets.DisplayDefaults({ enabled = false, combatOnly = false, size = 18 },
        { "CENTER", "CENTER", 0, -140 }),
    options = ns.Widgets.DisplayOptions({
        { key = "combatOnly", type = "checkbox", label = L.MELEE_COMBAT, tooltip = L.MELEE_COMBAT_TIP },
    }),
})

M.notice = OtherAddons.CoveredNotices(M, COVERS, L.MELEE_WHAT)

local display = ns.Widgets.AddDisplay(M, { name = "ForeverTweaksMeleeRange", relativeTo = UIParent,
    sample = "|cffff2020" .. L.MELEE_TOO_FAR .. "|r", clickThrough = true })

local melee        -- the melee spell to check with, found again when your spells change
local spell        -- the spell whose range is checked now (melee, while the target is an enemy)
local inRange      -- its last answer: true, false, or nil (can't say)
local targetDead   -- whether the target was dead at the last look
local inCombat     -- in combat, from the combat events: PLAYER_REGEN_DISABLED comes before
                   -- InCombatLockdown() turns true, and PLAYER_REGEN_ENABLED before it turns false

-- The first harmful spell in your spellbook with melee reach, else Auto Attack.
local function meleeSpell()
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
        if info and not info.offSpecID then
            for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local item = C_SpellBook.GetSpellBookItemInfo(slot, Enum.SpellBookSpellBank.Player)
                if item and item.spellID and not item.isPassive
                    and C_SpellBook.IsSpellBookItemHarmful(slot, Enum.SpellBookSpellBank.Player) then
                    local spellInfo = C_Spell.GetSpellInfo(item.spellID)
                    if spellInfo and spellInfo.maxRange > 0 and spellInfo.maxRange <= MELEE_REACH then
                        return item.spellID
                    end
                end
            end
        end
    end
    return AUTO_ATTACK
end

local function enemyTarget()
    return Plain(UnitExists("target")) and not Plain(UnitIsDead("target")) and Plain(UnitCanAttack("player", "target"))
end

local function redraw()
    local far = inRange == false and enemyTarget() and (not M.db.combatOnly or inCombat)
        and not OtherAddons.CoveredBy(M, COVERS)
    display:SetLine("|cffff2020" .. L.MELEE_TOO_FAR .. "|r")
    display:SetShown(far and true or false)
end

local function useSpell(id)
    if spell == id then return end
    if spell then C_Spell.EnableSpellRangeCheck(spell, false) end
    spell = id
    if spell then C_Spell.EnableSpellRangeCheck(spell, true) end
end

local function evaluate()
    targetDead = Plain(UnitIsDead("target"))
    useSpell(enemyTarget() and melee or nil)
    inRange = nil
    if spell then inRange = Plain(C_Spell.IsSpellInRange(spell, "target")) end -- false (out of reach) kept
    redraw()
end

local function onRangeUpdate(_, _, spellID, range, checks)
    if Plain(spellID) ~= spell then return end
    inRange = nil
    if Plain(checks) then inRange = Plain(range) end
    redraw()
end

function M:OnEnable()
    self:RegisterEvent("PLAYER_TARGET_CHANGED", evaluate)
    self:RegisterEvent("SPELLS_CHANGED", function()
        melee = meleeSpell()
        useSpell(nil)
        evaluate()
    end)
    self:RegisterEvent("SPELL_RANGE_CHECK_UPDATE", onRangeUpdate)
    local function onCombat(_, event)
        inCombat = event == "PLAYER_REGEN_DISABLED"
        redraw()
    end
    self:RegisterEvent("PLAYER_REGEN_DISABLED", onCombat)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", onCombat)
    inCombat = InCombatLockdown()
    -- The target dying: the only health change that matters here.
    self:RegisterEvent("UNIT_HEALTH", function(_, _, unit)
        if unit == "target" and Plain(UnitIsDead("target")) ~= targetDead then evaluate() end
    end)
    melee = meleeSpell()
    evaluate()
end

function M:OnDisable() useSpell(nil) end
function M:OnSettingChanged() redraw() end

function M:DebugLine()
    return format(L.MELEE_DEBUG, tostring(spell), tostring(inRange))
end
