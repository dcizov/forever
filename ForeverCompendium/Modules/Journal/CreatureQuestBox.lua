--[[
    Forever Compendium - Modules/Journal/CreatureQuestBox.lua
    The list in a creature's Quests box (CreatureBoxes.lua makes the box): the quests it has to
    do with, each after its state's icon (in your log, ready to turn in, not taken, done) and with
    icons for what it does for it (gives, takes in, drops the item that starts it, is killed,
    looted or spoken to for it), its objectives on mouse over; a click shows the quest
    (ns.ShowQuest). QuestBox.LegendTip says what each icon means (the box header's "?").
]]

local _, ns = ...
local L = ns.L

local ipairs, table = ipairs, table
local Book = ns.Book
local Text = assert(ns.JournalText, "CreatureQuestBox.lua loads after JournalText.lua")
local J = assert(ns.JournalKit, "CreatureQuestBox.lua loads after JournalKit.lua")

local QuestBox = {}
QuestBox.__index = QuestBox
ns.CreatureQuestBox = QuestBox

local function questTip(line)
    local entry = line.data
    local roles = {}
    for _, role in ipairs(entry.roles) do roles[#roles + 1] = Text.ROLES[role].label end
    local q = Book.Quest(entry.questID) or {}
    J.Tip(line, Book.QuestName(entry.questID), Text.GRAY .. Text.QuestStateLabel(Text.QuestState(entry.questID)) .. "|r",
        table.concat(roles, "\n"), q.objectives and " " or nil)
    for _, objective in ipairs(q.objectives or {}) do GameTooltip:AddLine("- " .. objective.text, 1, 1, 1, true) end
    GameTooltip:AddLine(L.CTABS_QUEST_HINT, 0.1, 1, 0.1)
    GameTooltip:Show()
end

-- The legend, as a tooltip on `owner`: the quest's states, then what the creature does for it.
function QuestBox.LegendTip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.CBOX_LEGEND, 1, 0.82, 0)
    for _, state in ipairs(Text.STATE_ORDER) do
        GameTooltip:AddLine(Text.Icon(Text.STATE_ICONS[state], 14) .. "  " .. Text.QuestStateLabel(state), 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    for _, role in ipairs(Text.ROLE_ORDER) do
        if role ~= true then GameTooltip:AddLine(Text.Icon(Text.ROLES[role].icon, 14) .. "  " .. Text.ROLES[role].label, 1, 1, 1) end
    end
    GameTooltip:Show()
end

-- The list in `content` (the caller places it: list.lines.scroll).
function QuestBox.Build(content)
    return setmetatable({ lines = J.NewLines(content, 280) }, QuestBox)
end

-- Lists creature `rec`'s quests.
function QuestBox:Show(rec)
    local lines = self.lines
    lines:Begin()
    local list = Text.CreatureQuests(rec)
    for _, entry in ipairs(list) do
        lines:Line(Text.RoleIcons(entry.roles, 14) .. "  " .. Text.QuestLine(entry.questID), {
            data = entry, onEnter = questTip, onClick = function(line) ns.ShowQuest(line.data.questID) end })
    end
    if #list == 0 then lines:Line(Text.GRAY .. L.JOURNAL_NO_QUESTS .. "|r") end
    lines:End()
    lines.scroll:SetVerticalScroll(0)
end
