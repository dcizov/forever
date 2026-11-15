--[[
    Forever Tweaks - tests/stubs/professions.lua
    The stand-in game's professions, worn gear, weapon enchants, item tooltips, spells and error
    text, loaded by tests/wow.lua after loot.lua (it adds to its C_Item).
      W.profs[i]    = { name, rank, maxRank, modifier, line, icon }: 1 and 2 the primary
                      professions, 4 Fishing (GetProfessions' order)
      W.equipped    = slot -> item ID worn there
      W.lure        = the main hand's temporary enchant's time left in ms, or nil
      W.tooltips    = item ID -> its tooltip lines (text)
      W.uiErrors    = the red messages shown, in order
      W.mapID       = the map you're on (C_Map.GetBestMapForUnit), W.maps = map ID -> its parent
]]

W.profs, W.equipped, W.tooltips, W.uiErrors, W.maps = {}, {}, {}, {}, {}
W.mapTypes = {} -- map ID -> Enum.UIMapType (3, a zone, unless set)

C_Map = {
    GetBestMapForUnit = function() return W.mapID end,
    GetMapInfo = function(id) return { mapID = id, parentMapID = W.maps[id], mapType = W.mapTypes[id] or 3 } end,
}

function GetProfessions()
    return W.profs[1] and 1, W.profs[2] and 2, nil, W.profs[4] and 4, nil
end

function GetProfessionInfo(index)
    local p = W.profs[index]
    return p.name, p.icon or 0, p.rank, p.maxRank, 0, 0, p.line, p.modifier or 0
end

function GetInventoryItemID(_, slot) return W.equipped[slot] end

-- Forever's form: one weapon slot (Enum.WeaponSlot), a list of its enchants.
C_Item.GetWeaponEnchantInfo = function(weaponSlot)
    assert(weaponSlot == Enum.WeaponSlot.MainHand, "GetWeaponEnchantInfo: needs a weapon slot")
    if W.lure == nil then return {} end
    return { { hasEnchant = true, timeLeft = W.lure, charges = 0, enchantID = 263, enchantIconID = 0 } }
end

C_TooltipInfo = {
    GetInventoryItem = function(_, slot)
        local lines = {}
        for i, text in ipairs(W.tooltips[W.equipped[slot]] or {}) do lines[i] = { leftText = text } end
        return { lines = lines }
    end,
}

W.spells = { [7620] = "Fishing" }
C_Spell = { GetSpellName = function(id) return W.spells[id] end }

UIErrorsFrame = W.NewFrame("MessageFrame", "UIErrorsFrame")
function UIErrorsFrame:AddMessage(text) W.uiErrors[#W.uiErrors + 1] = text end

-- Override bindings and the mouse (Fishing Cast). W.bindings[key] = { spell = name } or
-- { click = button name }, per what's set now; W.mouseFoci is what GetMouseFoci answers
-- (nil: the bare world).
W.bindings = {}
function SetOverrideBindingSpell(_, _, key, spell)
    if InCombatLockdown() then W.errors[#W.errors + 1] = "SetOverrideBindingSpell in combat" end
    W.bindings[key] = { spell = spell }
end
function SetOverrideBindingClick(_, _, key, button)
    if InCombatLockdown() then W.errors[#W.errors + 1] = "SetOverrideBindingClick in combat" end
    W.bindings[key] = { click = button }
end
function ClearOverrideBindings()
    if InCombatLockdown() then W.errors[#W.errors + 1] = "ClearOverrideBindings in combat" end
    W.bindings = {}
end
function GetMouseFoci() return W.mouseFoci or {} end
WorldFrame = W.NewFrame("Frame", "WorldFrame")
-- A right-click on the world: press and release, `gap` seconds after the last one.
function W.RightClick(gap)
    W.Advance(gap or 0)
    W.Fire("GLOBAL_MOUSE_DOWN", "RightButton")
    W.Fire("GLOBAL_MOUSE_UP", "RightButton")
end

-- The player's cast bar, mana bar, spellbook, range checks and error types (Cast Bar, Five-Second
-- Rule, Melee Range, Combat Error Filter).
--   W.spellbook = { { spellID, harmful, maxRange } }: the spellbook's one line of spells
--   W.inRange[spellID] = true/false: C_Spell.IsSpellInRange on the target
--   W.powerCost[spellID] = mana cost; W.powerType = the power shown (0 mana)
PlayerCastingBarFrame = W.NewFrame("StatusBar", "PlayerCastingBarFrame", UIParent)
PlayerCastingBarFrame.look = "CLASSIC"
PlayerCastingBarFrame.Text = PlayerCastingBarFrame:CreateFontString()
PlayerCastingBarFrame.CastTimeText = PlayerCastingBarFrame:CreateFontString()
PlayerCastingBarFrame.TextBorder = PlayerCastingBarFrame:CreateTexture()
W.looksSet = 0
function PlayerCastingBarFrame:SetLook(look)
    self.look = look
    W.looksSet = W.looksSet + 1
    self.Text:ClearAllPoints()
    self.Text:SetPoint("TOP", self, "BOTTOM", 0, -10)
end
local manaBar = W.NewFrame("StatusBar", nil, UIParent)
function PlayerFrame_GetManaBar() return manaBar end
W.powerType = 0
function UnitPowerType() return W.powerType end
W.spellbook, W.inRange, W.powerCost, W.rangeChecks = {}, {}, {}, {}
Enum.SpellBookSpellBank = { Player = 0 }
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = #W.spellbook } end,
    GetSpellBookItemInfo = function(slot) local s = W.spellbook[slot]; return s and { spellID = s.spellID, isPassive = false } end,
    IsSpellBookItemHarmful = function(slot) return W.spellbook[slot] and W.spellbook[slot].harmful or false end,
}
C_Spell.GetSpellInfo = function(id)
    for _, s in ipairs(W.spellbook) do if s.spellID == id then return { spellID = id, minRange = 0, maxRange = s.maxRange } end end
end
C_Spell.IsSpellInRange = function(id) return W.inRange[id] end
C_Spell.EnableSpellRangeCheck = function(id, on) W.rangeChecks[id] = on or nil end
C_Spell.GetSpellPowerCost = function(id)
    return W.powerCost[id] and { { type = 0, cost = W.powerCost[id], costPerSec = 0 } } or {}
end
W.targetDead, W.targetEnemy = false, false
function UnitIsDead() return W.targetDead end
function UnitCanAttack() return W.targetEnemy end
LE_GAME_ERR_SPELL_FAILED_ANOTHER_IN_PROGRESS, LE_GAME_ERR_ABILITY_COOLDOWN, LE_GAME_ERR_OUT_OF_RAGE, LE_GAME_ERR_OUT_OF_RANGE = 1, 2, 3, 4
BLACK_LISTED_MESSAGE_TYPES = { [LE_GAME_ERR_SPELL_FAILED_ANOTHER_IN_PROGRESS] = true }
function UIErrorsFrame:SetMessageTypeEnabled(messageType, enabled) BLACK_LISTED_MESSAGE_TYPES[messageType] = not enabled end

-- The world map and the minimap's reach (Gathering Map). W.mapSizes[mapID] = { width, height } in
-- yards; WorldMapFrame shows W.worldMapID; W.indoors, W.facing.
WorldMapFrame = W.NewFrame("Frame", "WorldMapFrame", UIParent)
WorldMapFrame._shown = false
WorldMapFrame.ScrollContainer = W.NewFrame("ScrollFrame", nil, WorldMapFrame)
WorldMapFrame.ScrollContainer.Child = W.NewFrame("Frame", nil, WorldMapFrame.ScrollContainer)
function WorldMapFrame.ScrollContainer.Child:GetWidth() return 1000 end
function WorldMapFrame.ScrollContainer.Child:GetHeight() return 700 end
W.canvasScale = 1
function WorldMapFrame:GetMapID() return W.worldMapID end
function WorldMapFrame:GetCanvasScale() return W.canvasScale end
function WorldMapFrame:OnMapChanged() end
function WorldMapFrame:OnCanvasScaleChanged() end
W.mapSizes = {}
C_Map.GetMapWorldSize = function(mapID) local s = W.mapSizes[mapID]; if s then return s[1], s[2] end return 0, 0 end
W.indoors, W.facing = false, 0
function IsIndoors() return W.indoors end
function GetPlayerFacing() return W.facing end
function Minimap:GetZoom() return 0 end
-- The player's place: W.place = { map, x, y } (nil off any map).
C_Map.GetPlayerMapPosition = function(mapID)
    local p = W.place
    if not p or p.map ~= mapID then return nil end
    return { GetXY = function() return p.x, p.y end }
end
