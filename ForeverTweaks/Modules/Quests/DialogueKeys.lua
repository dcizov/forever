--[[
    Forever Tweaks - Dialogue Keys
    Talk to quest givers from the keyboard or a gamepad, in Blizzard's own windows:
      * 1 to 9 pick a quest or an option in a gossip list or a quest giver's greeting (each row
        gets its number beside it), or a reward when a quest lets you choose one;
      * Space (or your Interact key) accepts a quest, hands in its items, completes it, or picks
        the only choice there is; Tab and Shift+Tab step through reward choices;
      * a gamepad: the d-pad moves through the list, A confirms (picks the highlighted row),
        B closes the window.
    Escape still closes the window as it always does.

    Keys are heard on a frame of ours that's shown only while a gossip or quest window is open; a
    key it doesn't use goes on to the game (SetPropagateKeyboardInput), so movement and action
    bars keep working. Propagation is never changed in combat: the frame stops listening when
    combat starts and listens again after. The rows are what Blizzard's lists show, in its order
    (Shared/GossipFrameShared.lua: available quests, active quests, then options by order index;
    a greeting's active quests first); a choice is made with the same calls its button makes,
    and the quest window's buttons are clicked. Steps aside while DialogueUI is loaded.
    The way of listening is DialogueUI's (Peterodox and Raenore); none of its code.
]]

local _, ns = ...
local L = ns.L

local _G, ipairs, tonumber, sort, format = _G, ipairs, tonumber, table.sort, string.format
local OtherAddons = ns.OtherAddons

local MAX_KEYS = 9
local NUMBER_KEY = {} -- key name -> its number
for i = 1, MAX_KEYS do
    NUMBER_KEY[tostring(i)] = i
    NUMBER_KEY["NUMPAD" .. i] = i
end
local DIALOG_EVENTS = { "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE" }
local CLOSE_EVENTS = { "GOSSIP_CLOSED", "QUEST_FINISHED" }

local M = ns:NewModule("DialogueKeys", {
    title = L.DKEYS_TITLE,
    category = "quests",
    group = L.GROUP_QUEST_WINDOWS,
    description = L.DKEYS_DESC,
    added = "2.7.0",
    defaults = { confirm = "space", numbers = true, labels = true, gamepad = true },
    options = {
        { key = "confirm", type = "dropdown", label = L.DKEYS_CONFIRM, tooltip = L.DKEYS_CONFIRM_TIP,
          choices = { { "space", L.DKEYS_CONFIRM_SPACE }, { "interact", L.DKEYS_CONFIRM_INTERACT },
              { "both", L.DKEYS_CONFIRM_BOTH }, { "off", L.DKEYS_CONFIRM_OFF } } },
        { key = "numbers", type = "checkbox", label = L.DKEYS_NUMBERS, tooltip = L.DKEYS_NUMBERS_TIP },
        { key = "labels", type = "checkbox", label = L.DKEYS_LABELS, tooltip = L.DKEYS_LABELS_TIP, requires = "numbers" },
        { key = "gamepad", type = "checkbox", label = L.DKEYS_GAMEPAD, tooltip = L.DKEYS_GAMEPAD_TIP },
    },
})
M.notice = { { text = L.DKEYS_DIALOGUEUI, shown = function() return OtherAddons.Loaded("DialogueUI") end } }

local listener -- our frame that hears keys, made on first enable
local dialog   -- the window open now: "gossip", "greeting", "detail", "progress", "complete", or nil
local focus = 0 -- the row the gamepad's d-pad has highlighted (0: none)
local labels = {} -- row number -> its label font string

local function inCharge() return M.active and not OtherAddons.Loaded("DialogueUI") end

-- The rows ------------------------------------------------------------------------------------

-- What a gossip list shows, in its order: { select = fn } each.
local function gossipRows()
    local rows = {}
    for _, quest in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
        rows[#rows + 1] = { select = function() C_GossipInfo.SelectAvailableQuest(quest.questID) end,
            kind = "available", id = quest.questID }
    end
    for _, quest in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
        rows[#rows + 1] = { select = function() C_GossipInfo.SelectActiveQuest(quest.questID) end,
            kind = "active", id = quest.questID }
    end
    local options = C_GossipInfo.GetOptions() or {}
    sort(options, function(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end)
    for _, option in ipairs(options) do
        rows[#rows + 1] = { select = function() C_GossipInfo.SelectOptionByIndex(option.orderIndex) end,
            kind = "option", id = option.orderIndex }
    end
    return rows
end

-- A quest giver's older greeting: active quests first, each picked by its place in its list.
local function greetingRows()
    local rows = {}
    for i = 1, GetNumActiveQuests() do
        rows[#rows + 1] = { select = function() SelectActiveQuest(i) end, kind = "greetActive", id = i }
    end
    for i = 1, GetNumAvailableQuests() do
        rows[#rows + 1] = { select = function() SelectAvailableQuest(i) end, kind = "greetAvailable", id = i }
    end
    return rows
end

-- A quest's reward choices: Blizzard's choice buttons, picked as a click picks them.
local function rewardRows()
    local rows = {}
    local frame = _G.QuestInfoFrame and _G.QuestInfoFrame.rewardsFrame
    local buttons = frame and frame.RewardButtons or {}
    for i = 1, GetNumQuestChoices() do
        local button = buttons[i]
        if button and button.type == "choice" then
            rows[#rows + 1] = { select = function() _G.QuestInfoItem_OnClick(button) end, kind = "reward", id = i,
                button = button }
        end
    end
    return rows
end

local function rowsNow()
    if dialog == "gossip" then return gossipRows() end
    if dialog == "greeting" then return greetingRows() end
    if dialog == "complete" then return rewardRows() end
    return {}
end
M.Rows = rowsNow -- (the tests' way in)

-- Number labels -------------------------------------------------------------------------------

-- The Blizzard button that shows a row: a gossip row by its data, a greeting's by its ID.
local function buttonsByRow(rows)
    local found = {}
    local function match(kind, id, button)
        for i, row in ipairs(rows) do
            if row.kind == kind and row.id == id then found[i] = button end
        end
    end
    local panel = _G.GossipFrame and _G.GossipFrame.GreetingPanel
    if dialog == "gossip" and panel and panel.ScrollBox and panel.ScrollBox.ForEachFrame then
        panel.ScrollBox:ForEachFrame(function(button)
            local data = button.GetElementData and button:GetElementData()
            local kind = data and data.buttonType
            local info = data and data.info
            if not info then return end
            if kind == _G.GOSSIP_BUTTON_TYPE_AVAILABLE_QUEST then match("available", info.questID, button)
            elseif kind == _G.GOSSIP_BUTTON_TYPE_ACTIVE_QUEST then match("active", info.questID, button)
            elseif kind == _G.GOSSIP_BUTTON_TYPE_OPTION then match("option", info.orderIndex, button) end
        end)
    elseif dialog == "greeting" and _G.QuestFrameGreetingPanel and _G.QuestFrameGreetingPanel.titleButtonPool then
        for button in _G.QuestFrameGreetingPanel.titleButtonPool:EnumerateActive() do
            match(button.isActive == 1 and "greetActive" or "greetAvailable", button:GetID(), button)
        end
    elseif dialog == "complete" then
        for i, row in ipairs(rows) do found[i] = row.button end
    end
    return found
end

local function hideLabels()
    for _, label in ipairs(labels) do label:Hide() end
end

-- Puts each row's number beside its button (the gamepad's highlighted one in white).
local function showLabels()
    hideLabels()
    if not (inCharge() and M.db.numbers and M.db.labels) then return end
    local buttons = buttonsByRow(rowsNow())
    for i = 1, MAX_KEYS do
        local button = buttons[i]
        if button then
            local label = labels[i]
            if not label then
                label = listener:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                labels[i] = label
            end
            label:SetParent(button)
            label:ClearAllPoints()
            label:SetPoint("RIGHT", button, "LEFT", -1, 0)
            label:SetText(format(L.DKEYS_LABEL, i))
            if i == focus then label:SetTextColor(1, 1, 1) else label:SetTextColor(1, 0.82, 0) end
            label:Show()
        end
    end
end

-- Choosing --------------------------------------------------------------------------------------

local function pick(n)
    local row = rowsNow()[n]
    if not row then return false end
    row.select()
    if dialog == "complete" then showLabels() end -- a reward picked: the window stays
    return true
end

-- The quest window's main button for the panel showing, if it can be pressed now.
local function mainButton()
    local name = dialog == "detail" and "QuestFrameAcceptButton" or dialog == "progress" and "QuestFrameCompleteButton"
        or dialog == "complete" and "QuestFrameCompleteQuestButton"
    local button = name and _G[name]
    return button and button:IsShown() and button:IsEnabled() and button or nil
end

-- Space, Interact or the gamepad's A: the quest window's button, or the only row there is.
local function confirm()
    local button = mainButton()
    if button then
        button:Click()
        return true
    end
    local rows = rowsNow()
    if #rows == 1 then return pick(1) end
    return false
end

-- Tab through reward choices (Shift+Tab back).
local function cycleReward(back)
    if dialog ~= "complete" then return false end
    local rows = rowsNow()
    if #rows < 2 then return false end
    local current = _G.QuestInfoFrame and tonumber(_G.QuestInfoFrame.itemChoice) or 0
    local at = 0
    for i, row in ipairs(rows) do if row.id == current then at = i end end
    at = back and (at <= 1 and #rows or at - 1) or (at % #rows + 1)
    return pick(at)
end

local function isConfirmKey(key)
    local how = M.db.confirm
    if (how == "space" or how == "both") and key == "SPACE" then return true end
    if how == "interact" or how == "both" then
        local bound = GetBindingKey("INTERACTTARGET")
        return bound ~= nil and key == bound
    end
    return false
end

-- What a key does here: true when it's ours (then the game doesn't get it).
local function onKey(key)
    if NUMBER_KEY[key] and M.db.numbers and not (IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()) then
        return pick(NUMBER_KEY[key])
    end
    if isConfirmKey(key) then return confirm() end
    if key == "TAB" then return cycleReward(IsShiftKeyDown()) end
    return false
end
M.OnKey = onKey

local function moveFocus(step)
    local count = #rowsNow()
    if count == 0 then return false end
    focus = focus + step
    if focus < 1 then focus = count elseif focus > count then focus = 1 end
    showLabels()
    return true
end

local function onPad(button)
    if not M.db.gamepad then return false end
    if button == "PADDDOWN" or button == "PADDRIGHT" then return moveFocus(1) end
    if button == "PADDUP" or button == "PADDLEFT" then return moveFocus(-1) end
    if button == "PAD1" then
        if focus > 0 then return pick(focus) end
        return confirm()
    end
    if button == "PAD2" then
        if dialog == "gossip" then C_GossipInfo.CloseGossip() else CloseQuest() end
        return true
    end
    return false
end
M.OnPad = onPad

-- The listener ----------------------------------------------------------------------------------

local function handled(frame, ours)
    -- Never in combat (the frame isn't listening then anyway).
    if not InCombatLockdown() then frame:SetPropagateKeyboardInput(not ours) end
end

local function listen(on)
    on = on and inCharge() and dialog ~= nil and not InCombatLockdown()
    if on then
        listener:Show()
        listener:EnableKeyboard(true)
        listener:EnableGamePadButton(M.db.gamepad)
        showLabels()
    else
        listener:Hide() -- a hidden frame hears nothing, in combat too
        hideLabels()
    end
end

local function build()
    listener = CreateFrame("Frame", "ForeverTweaksDialogueKeys", UIParent)
    listener:Hide()
    listener:SetPropagateKeyboardInput(true)
    listener:SetScript("OnKeyDown", function(self, key)
        handled(self, ns.ChargedCall(M, "dialogue key", onKey, key) == true)
    end)
    listener:SetScript("OnGamePadButtonDown", function(self, button)
        handled(self, ns.ChargedCall(M, "dialogue pad", onPad, button) == true)
    end)
end

local OPENS = { GOSSIP_SHOW = "gossip", QUEST_GREETING = "greeting", QUEST_DETAIL = "detail",
    QUEST_PROGRESS = "progress", QUEST_COMPLETE = "complete" }

local function onOpen(_, event)
    dialog, focus = OPENS[event], 0
    -- After Blizzard has filled its window this frame.
    M:Soon(function() listen(true) end)
end

local function onClose()
    dialog, focus = nil, 0
    listen(false)
end

function M:OnEnable()
    if not listener then build() end
    for _, event in ipairs(DIALOG_EVENTS) do self:RegisterEvent(event, onOpen) end
    for _, event in ipairs(CLOSE_EVENTS) do self:RegisterEvent(event, onClose) end
    -- Combat: stop listening before the lockdown, listen again after.
    self:RegisterEvent("PLAYER_REGEN_DISABLED", function()
        if not InCombatLockdown() then listener:SetPropagateKeyboardInput(true) end
        listen(false)
    end)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function() listen(true) end)
end

function M:OnDisable()
    if not listener then return end
    if not InCombatLockdown() then listener:SetPropagateKeyboardInput(true) end
    listen(false)
end

function M:OnSettingChanged() listen(dialog ~= nil) end
