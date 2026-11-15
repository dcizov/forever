--[[
    Forever Tweaks - tests/scenarios/quests/marks.lua
    New in Forever: a quest above Classic's last ID gets the medallion after its title, an old one
    none, and it comes off when the module turns off; an item above Classic's last ID gets a "New
    in WoW Forever" line, an old one none.
    Run by tests/run.lua (lua5.1 tests/run.lua marks), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
-- A quest's details: Blizzard's title header, filled by QuestInfo_Display.
QuestInfoTitleHeader = W.NewFrame("Frame", "QuestInfoTitleHeader"):CreateFontString()
function QuestInfo_Display() QuestInfoTitleHeader:SetText(W.questWindow.title) end
local ns = W.LoadAddon(root, "ForeverTweaks")
login()
local M = ns.modules.ForeverMarks
local ICON = "Glues-WoW-ForeverLogo-Infinity"

W.questWindow = { questID = 26001, title = "A Forever Quest" }
QuestInfo_Display()
local text = QuestInfoTitleHeader:GetText()
check(text:find("A Forever Quest", 1, true) == 1 and text:find(ICON, 1, true) ~= nil, "a new quest: the medallion after its title")
W.questWindow = { questID = 783, title = "A Threat Within" }
QuestInfo_Display()
eq(QuestInfoTitleHeader:GetText(), "A Threat Within", "a Classic quest: nothing")
W.questWindow = { questID = 26001, title = "A Forever Quest" }
QuestInfo_Display()
ns:SetEnabled("ForeverMarks", false)
eq(QuestInfoTitleHeader:GetText(), "A Forever Quest", "off: the title as Blizzard wrote it")
ns:SetEnabled("ForeverMarks", true)

local function has(lines, part)
    for _, line in ipairs(lines) do if tostring(line.text):find(part, 1, true) then return true end end
    return false
end
check(has(W.ItemTooltip(30000), ns.L.FMARKS_ITEM_LINE), "an item new to Forever: says so")
check(not has(W.ItemTooltip(2589), ns.L.FMARKS_ITEM_LINE), "a Classic item: nothing")
ns:SetOption("ForeverMarks", "items", false)
check(not has(W.ItemTooltip(30000), ns.L.FMARKS_ITEM_LINE), "Item Tooltips off: nothing")
check(M.IsNewQuest(9666) and not M.IsNewQuest(9665), "quests: new above 9665")
eq(#W.errors, 0, "no errors")
finish()
