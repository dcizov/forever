--[[
    Forever Compendium - Modules/Journal/CreatureQuestTab.lua
    A creature's Quests tab (CreatureTabs.lua makes it): the quests it has to do with, each after
    its state's icon (in your log, ready to turn in, not taken, done) and with icons for what it
    does for it (gives, takes in, drops the item that starts it, is killed, looted or spoken to
    for it), its objectives on mouse over; a click shows the quest (ns.ShowQuest). A legend under
    the list says what each icon means.
]]

local _, ns = ...
local L = ns.L

local ipairs, table = ipairs, table
local CreateFrame = CreateFrame
local Book, Text, J = ns.Book, ns.JournalText, ns.JournalKit

local QuestTab = {}
QuestTab.__index = QuestTab
ns.CreatureQuestTab = QuestTab

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

-- The legend under the list, two rows (the quest's state, then what the creature does for it).
local function buildLegend(content)
    local legend = CreateFrame("Frame", nil, content)
    legend:SetHeight(40)
    legend:SetPoint("BOTTOMLEFT", 0, 0)
    legend:SetPoint("BOTTOMRIGHT", 0, 0)
    local line = legend:CreateTexture(nil, "ARTWORK")
    line:SetAtlas("Options_HorizontalDivider", true)
    line:SetPoint("TOPLEFT", 0, 2)
    line:SetPoint("TOPRIGHT", 0, 2)
    local previous = {}
    local function addKey(row, icon, label)
        local mark = legend:CreateTexture(nil, "ARTWORK")
        mark:SetSize(14, 14)
        mark:SetTexture(icon)
        local text = legend:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", mark, "RIGHT", 3, 0)
        text:SetText(label)
        if previous[row] then
            mark:SetPoint("LEFT", previous[row], "RIGHT", 12, 0)
        else
            mark:SetPoint("TOPLEFT", 2, -6 - (row - 1) * 18)
        end
        previous[row] = text
    end
    for _, state in ipairs(Text.STATE_ORDER) do addKey(1, Text.STATE_ICONS[state], Text.QuestStateLabel(state)) end
    for _, role in ipairs(Text.ROLE_ORDER) do
        if role ~= true then addKey(2, Text.ROLES[role].icon, Text.ROLES[role].short) end
    end
    return legend
end

-- The tab's list and legend in `content`.
function QuestTab.Build(content)
    local tab = setmetatable({ lines = J.NewLines(content, 560) }, QuestTab)
    local legend = buildLegend(content)
    tab.lines.scroll:SetPoint("TOPLEFT", 0, -4)
    tab.lines.scroll:SetPoint("BOTTOMRIGHT", legend, "TOPRIGHT", -20, 6)
    return tab
end

-- Lists creature `rec`'s quests.
function QuestTab:Show(rec)
    local lines = self.lines
    lines:Begin()
    local list = Text.CreatureQuests(rec)
    for _, entry in ipairs(list) do
        lines:Line(Text.RoleIcons(entry.roles, 14) .. "  " .. Text.QuestLine(entry.questID), {
            data = entry, onEnter = questTip, onClick = function(line) ns.ShowQuest(line.data.questID) end })
    end
    if #list == 0 then lines:Line(Text.GRAY .. L.JOURNAL_NO_QUESTS .. "|r") end
    lines:End()
end
