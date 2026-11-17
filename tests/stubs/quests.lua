--[[
    Forever Gearbox - tests/stubs/quests.lua
    The stand-in game's quest log and item tooltips, loaded by tests/wow.lua. A scenario puts
    quests in W.quests ({ title, questID, objectives = { { type = "item", text = "Murloc Eye: 2/3",
    numFulfilled, numRequired } } }), Use: spells in W.itemSpells (link or item ID -> spell) and
    quests turned in in W.questsDone (questID -> true).
]]

W.quests, W.itemSpells, W.questsDone = {}, {}, {}

C_QuestLog = {
    GetInfo = function(i)
        local q = W.quests[i]
        return q and { title = q.title, questID = q.questID, isHeader = q.isHeader or false } or nil
    end,
    GetQuestObjectives = function(questID)
        for _, q in ipairs(W.quests) do
            if q.questID == questID then return q.objectives end
        end
        return {}
    end,
    IsQuestFlaggedCompleted = function(questID) return W.questsDone[questID] == true end,
    ReadyForTurnIn = function(questID) return W.questsReady[questID] == true end,
}
W.questsReady = {} -- questID -> true: ready to turn in
C_Item.GetItemSpell = function(item) return W.itemSpells[item] end

ITEM_STARTS_QUEST = "This Item Begins a Quest"
Enum.TooltipDataType = { Item = 0, Unit = 2 }
W.tooltipPostCalls = {}
TooltipDataProcessor = {
    AddTooltipPostCall = function(kind, fn)
        W.tooltipPostCalls[#W.tooltipPostCalls + 1] = { kind = kind, fn = fn }
    end,
}
-- Shows an item's tooltip as the game builds it: `getter` = { "GetBagItem", bag, slot } for a bag
-- item, else just the item ID and its own lines. Returns the lines added after the game's.
function W.ItemTooltip(itemID, getter, lines)
    local tooltip = { added = {} }
    function tooltip:AddLine(text, r, g, b) self.added[#self.added + 1] = { text = text, r = r, g = g, b = b } end
    function tooltip:AddDoubleLine(left, right) self.added[#self.added + 1] = { text = left, right = right } end
    function tooltip:GetOwner() return nil end
    function tooltip:GetPrimaryTooltipData() return nil end
    function tooltip:GetName() return nil end
    function tooltip:GetPrimaryTooltipInfo()
        if getter then return { getterName = getter[1], getterArgs = { getter[2], getter[3] } } end
        return { getterName = "GetItemByID", getterArgs = { itemID } }
    end
    local data = { id = itemID, lines = lines or {} }
    for _, call in ipairs(W.tooltipPostCalls) do
        if call.kind == Enum.TooltipDataType.Item then call.fn(tooltip, data) end
    end
    return tooltip.added
end

-- Shows a unit's tooltip as the game builds it, for the unit with `guid`. Returns the lines added.
-- `unit` (optional) is the unit it shows, its name on a font string W.UnitTipTextLeft1.
local nameLine = W.NewFrame("FontString", "W.UnitTipTextLeft1", UIParent)
function nameLine:SetTextColor(r, g, b) self._color = { r, g, b } end
_G["W.UnitTipTextLeft1"] = nameLine
function W.UnitTooltip(guid, unit)
    local tooltip = { added = {}, NineSlice = { SetBorderColor = function(self, r, g, b) self._border = { r, g, b } end } }
    function tooltip:AddLine(text, r, g, b) self.added[#self.added + 1] = { text = text, r = r, g = g, b = b } end
    function tooltip:AddDoubleLine(left, right) self.added[#self.added + 1] = { text = left, right = right } end
    function tooltip:GetUnit() return nil, unit end
    function tooltip:GetName() return "W.UnitTip" end
    function tooltip:HookScript() end
    for _, call in ipairs(W.tooltipPostCalls) do
        if call.kind == Enum.TooltipDataType.Unit then call.fn(tooltip, { guid = guid, lines = {} }) end
    end
    return tooltip.added
end

-- Nameplates and unit tooltips (Quest Markers).
--   W.plates[unit]      = { player = bool }: a nameplate on screen for `unit` ("nameplate1", ...)
--   W.unitTips[unit]    = the unit tooltip's lines: { { type, text } }
--   W.cursorTip         = the world cursor's tooltip lines (an object under the soft target)
--   W.softObject        = { name, unable }: the soft-interact game object, or nil
Enum.TooltipDataLineType = { QuestObjective = 8, UnitOwner = 16, QuestTitle = 17, QuestPlayer = 18, None = 0 }
W.plates, W.unitTips, W.plateFrames = {}, {}, {}
local function plateFor(unit)
    local p = W.plates[unit]
    if not p then return nil end
    local frame = W.plateFrames[unit]
    if not frame then
        local base = W.NewFrame("Frame", nil, UIParent)
        base.namePlateUnitToken = unit
        base.UnitFrame = W.NewFrame("Frame", nil, base)
        base.UnitFrame.HealthBarsContainer = W.NewFrame("Frame", nil, base.UnitFrame)
        base.UnitFrame.SoftTargetFrame = W.NewFrame("Frame", nil, base.UnitFrame)
        base.UnitFrame.SoftTargetFrame.Icon = base.UnitFrame.SoftTargetFrame:CreateTexture()
        frame = base
        W.plateFrames[unit] = frame
    end
    return frame
end
C_NamePlate = {
    GetNamePlateForUnit = function(unit) return plateFor(unit) end,
    GetNamePlates = function()
        local list = {}
        for unit in pairs(W.plates) do list[#list + 1] = plateFor(unit) end
        return list
    end,
}
local function lines(list)
    local out = {}
    for i, l in ipairs(list or {}) do out[i] = { type = l[1], leftText = l[2] } end
    return { lines = out }
end
C_TooltipInfo.GetUnit = function(unit) return lines(W.unitTips[unit]) end
C_TooltipInfo.GetWorldCursor = function() return lines(W.cursorTip) end
local unitIsPlayer = UnitIsPlayer
function UnitIsPlayer(unit)
    if W.plates[unit] then return W.plates[unit].player or false end
    return unitIsPlayer(unit)
end
function UnitIsGameObject(unit) return unit == "softinteract" and W.softObject ~= nil end
local unitName = UnitName
function UnitName(unit)
    if unit == "softinteract" then return W.softObject and W.softObject.name end
    return unitName(unit)
end
-- The game's cursor art for the soft target, as SetUnitCursorTexture puts it on a texture.
function SetUnitCursorTexture(texture, unit)
    if unit ~= "softinteract" or not W.softObject then return false end
    texture:SetAtlas(W.softObject.unable and "Crosshair_unablelootall_32" or "Crosshair_lootall_32")
    return true
end
C_QuestLog.GetNumQuestLogEntries = function() return #W.quests, #W.quests end
