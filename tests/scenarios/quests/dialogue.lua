--[[
    Forever Tweaks - tests/scenarios/quests/dialogue.lua
    Dialogue Keys: number keys pick a gossip list's rows in Blizzard's order (available quests,
    active quests, options by order index) and a greeting's (active first); Space presses the
    quest window's button; Tab steps through reward choices; a key it doesn't use goes on to the
    game; nothing heard in combat, and propagation never changed then; the gamepad's d-pad and
    A; nothing while DialogueUI is loaded.
    Run by tests/run.lua (lua5.1 tests/run.lua dialogue), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
-- The quest window's buttons, and a reward choice as Blizzard picks it.
local pressed = {}
for _, name in ipairs({ "QuestFrameAcceptButton", "QuestFrameCompleteButton", "QuestFrameCompleteQuestButton" }) do
    local button = W.NewFrame("Button", name)
    button:SetScript("OnClick", function() pressed[#pressed + 1] = name end)
end
QuestInfoFrame = { itemChoice = 0, rewardsFrame = { RewardButtons = {} } }
function QuestInfoItem_OnClick(button) QuestInfoFrame.itemChoice = button:GetID() end
local ns = W.LoadAddon(root, "ForeverTweaks")
login()
local M = ns.modules.DialogueKeys
local keys = ForeverTweaksDialogueKeys
local function press(key)
    keys:Fire("OnKeyDown", key)
    return keys._propagate
end
local function last() return W.chosen[#W.chosen] end

-- A gossip list: one available quest, one active, two options (given out of order).
W.gossip = { available = { { questID = 11, title = "New" } }, active = { { questID = 12, title = "Done" } },
    options = { { orderIndex = 2, name = "Bye" }, { orderIndex = 1, name = "Train me" } } }
W.Fire("GOSSIP_SHOW")
W.RunTimers()
check(keys:IsShown(), "listening while the gossip window is open")
eq(press("1"), false, "1: ours, not the game's")
eq(last()[1] .. last()[2], "SelectAvailableQuest11", "the available quest first")
press("2")
eq(last()[1] .. last()[2], "SelectActiveQuest12", "then the active quest")
press("3")
eq(last()[1] .. last()[2], "SelectOptionByIndex1", "then options by their order")
eq(press("W"), true, "a key it doesn't use goes on to the game")
local before = #W.chosen
eq(press("7"), true, "a number with no row: the game's")
eq(#W.chosen, before, "and nothing chosen")

-- The gamepad: the d-pad moves, A picks the highlighted row.
keys:Fire("OnGamePadButtonDown", "PADDDOWN")
keys:Fire("OnGamePadButtonDown", "PADDDOWN")
keys:Fire("OnGamePadButtonDown", "PAD1")
eq(last()[1] .. last()[2], "SelectActiveQuest12", "d-pad down twice and A: the second row")
W.Fire("GOSSIP_CLOSED")
check(not keys:IsShown(), "closed: not listening")

-- A quest's details: Space accepts.
W.Fire("QUEST_DETAIL")
W.RunTimers()
eq(press("SPACE"), false, "Space: ours")
eq(pressed[#pressed], "QuestFrameAcceptButton", "accepts the quest")

-- Rewards to choose from: numbers and Tab pick, Space completes.
W.questChoices = { 100, 101, 102 }
for i = 1, 3 do
    local b = W.NewFrame("Button")
    b.type = "choice"
    b.GetID = function() return i end
    QuestInfoFrame.rewardsFrame.RewardButtons[i] = b
end
W.Fire("QUEST_COMPLETE")
W.RunTimers()
press("2")
eq(QuestInfoFrame.itemChoice, 2, "2: the second reward")
press("TAB")
eq(QuestInfoFrame.itemChoice, 3, "Tab: the next")
press("TAB")
eq(QuestInfoFrame.itemChoice, 1, "and round again")
W.shift = true
press("TAB")
W.shift = false
eq(QuestInfoFrame.itemChoice, 3, "Shift+Tab: back")
press("SPACE")
eq(pressed[#pressed], "QuestFrameCompleteQuestButton", "Space completes it")

-- The Interact key, when chosen.
W.bindingKeys.INTERACTTARGET = "F"
ns:SetOption("DialogueKeys", "confirm", "interact")
eq(press("SPACE"), true, "Interact Key: Space is the game's again")
eq(press("F"), false, "and F is ours")

-- Combat: not listening, propagation left alone.
W.combat = true
W.Fire("PLAYER_REGEN_DISABLED")
check(not keys:IsShown(), "combat: not listening")
W.combat = false
W.Fire("PLAYER_REGEN_ENABLED")
check(keys:IsShown(), "after combat: listening again")
W.Fire("QUEST_FINISHED")

-- A greeting: active quests first.
W.greeting = { available = { { questID = 30, title = "A" } }, active = { { questID = 31, title = "B" } } }
W.Fire("QUEST_GREETING")
W.RunTimers()
press("1")
eq(last()[1] .. last()[2], "greetActive1", "a greeting's active quest first")
press("2")
eq(last()[1] .. last()[2], "greetAvailable1", "then its available one")
W.Fire("QUEST_FINISHED")

-- DialogueUI loaded: ours steps aside.
W.loaded.DialogueUI = true
W.Fire("GOSSIP_SHOW")
W.RunTimers()
check(not keys:IsShown(), "DialogueUI does it: not listening")
W.loaded.DialogueUI = nil
eq(#W.errors, 0, "no errors")
finish()
