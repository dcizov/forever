--[[
    Forever Compendium - Modules/Journal/CreatureBoxes.lua
    The bottom of the Creatures page's right side (CreaturesPage.lua makes it and calls Show):
    two boxes side by side, the Quests one only for a creature with quests (else Loot takes the
    whole width).

      * Loot: its loot, wares or quest rewards (CreatureLootBox.lua).
      * Quests: the quests it has to do with (CreatureQuestBox.lua); its "?" says what the
        icons mean.
    Your note on it is on the model's stage (CreatureNotes.lua).
]]

local _, ns = ...
local L = ns.L

local format = string.format
local CreateFrame = CreateFrame
local Book = ns.Book
local Text = assert(ns.JournalText, "CreatureBoxes.lua loads after JournalText.lua")
local J = assert(ns.JournalKit, "CreatureBoxes.lua loads after JournalKit.lua")
local LootBox = assert(ns.CreatureLootBox, "CreatureBoxes.lua loads after CreatureLootBox.lua")
local QuestBox = assert(ns.CreatureQuestBox, "CreatureBoxes.lua loads after CreatureQuestBox.lua")
local Notes = assert(ns.CreatureNotes, "CreatureBoxes.lua loads after CreatureNotes.lua")

local Boxes = {}
ns.CreatureBoxes = Boxes

local pane = {}

local function buildQuestBox(holder)
    local box = J.HeaderInset(holder)
    pane.questBox = box
    box.title = box:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    box.title:SetPoint("TOPLEFT", 12, -12)
    local legend = J.IconButton(box, 20, "Interface\\Common\\help-i", L.CBOX_LEGEND, nil, nil)
    legend:SetPoint("TOPRIGHT", -10, -8)
    legend:SetScript("OnEnter", QuestBox.LegendTip)
    pane.quests = QuestBox.Build(box.content)
    pane.quests.lines.scroll:SetPoint("TOPLEFT", 0, 0)
    pane.quests.lines.scroll:SetPoint("BOTTOMRIGHT", -20, 0)
end

-- The two boxes side by side, or Loot alone across.
local function placeBoxes(withQuests)
    local loot = pane.lootBox
    loot:ClearAllPoints()
    loot:SetPoint("TOPLEFT")
    if withQuests then
        loot:SetPoint("BOTTOMRIGHT", pane.holder, "BOTTOM", -3, 0)
    else
        loot:SetPoint("BOTTOMRIGHT")
    end
    pane.questBox:SetShown(withQuests)
end

-- Below the display (`top` high).
function Boxes.Build(parent, top)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetPoint("TOPLEFT", 0, -top - 6)
    holder:SetPoint("BOTTOMRIGHT")
    pane.holder = holder
    pane.lootBox = J.HeaderInset(holder)
    LootBox.Build(pane.lootBox, function() Boxes:Show(pane.npcID) end)
    buildQuestBox(holder)
    pane.questBox:SetPoint("TOPLEFT", holder, "TOP", 3, 0)
    pane.questBox:SetPoint("BOTTOMRIGHT")
    placeBoxes(false)
    return setmetatable(pane, { __index = Boxes })
end

-- Shows creature `npcID`'s boxes (nil: none).
function Boxes:Show(npcID)
    local rec = npcID and Book.Creature(npcID)
    pane.holder:SetShown(rec ~= nil)
    if not rec then return end
    pane.npcID = npcID
    local quests = #Text.CreatureQuests(rec)
    placeBoxes(quests > 0)
    LootBox.Show(rec, npcID)
    if quests > 0 then
        pane.questBox.title:SetText(format("%s (%d)", L.CTABS_QUESTS, quests))
        pane.quests:Show(rec)
    end
end

-- Shows `key` of the creature shown: a view of the loot box ("loot", "wares", "rewards"),
-- "quests" (the Quests box, always shown when it has any) or "notes" (its note opened).
function Boxes:Open(key)
    if key == "notes" then return Notes.Open() end
    if LootBox.SetView(key) then Boxes:Show(pane.npcID) end
end
