--[[
    Forever Tweaks - Dungeon Journal Skin's page pieces (Modules/Addons/DungeonJournalSkin.lua uses
    them): two parts of DungeonJournal's window that need more than a cleared backdrop.

      * The quest page, made like Blizzard's quest window (Blizzard_UIPanels_Game/Mainline/
        QuestInfo.xml, QuestFrameTemplates.xml): its parchment (atlas QuestBG-Parchment) in place
        of DungeonJournal's tan box and brown edge lines; the title and section headers in
        QuestTitleFont, the text in QuestFont, in the parchment's colours
        (GetMaterialTextColors "Parchment"); the Share button Blizzard's red panel button
        (UIPanelButtonNoTooltipTemplate's three UI-Panel-Button pieces, Disabled while the quest
        can't be shared); and the rewards, DungeonJournal's coloured pills, Blizzard's compact
        reward buttons (below, at rewardButton). DungeonJournal sets the fonts and colours again on every
        redraw, so each line keeps them (UI/Restyle.lua).
      * The Journey bar (RPG Mode): DungeonJournal's own bar (Blizzard's profession skill bar
        art), drawn a quarter smaller and lower under the header's buttons for room around it.
]]

local _, ns = ...
local Restyle = assert(ns.Restyle, "DungeonJournalPages.lua loads after UI/Restyle.lua")

local ipairs = ipairs

local Pages = {}
ns.DungeonJournalPages = Pages

---------------------------------------------------------------------------
-- The quest page
---------------------------------------------------------------------------

local TITLES = { "selectedQuestName", "questObjectiveHeader", "questDescHeader", "questRequiredItemsHeader",
    "questProvidedItemHeader", "questStartsHeader", "questTurninHeader", "questNotesHeader", "questRewardHeader" }
local TEXTS = { "selectedQuestMeta", "questDetailText", "questTurninText", "questRewardSummary" }

local function shareState(button) return button._fdjShareableQuest and "Up" or "Disabled" end

-- The rewards as Blizzard's compact reward buttons (SmallItemButtonTemplate, which the world
-- map's quest log uses for its rewards, MapQuestInfoRewardsFrame; Blizzard_ItemButton/Mainline/
-- ItemButtonTemplate.xml): 134 x 30, a 30 px icon, then the QuestItemBorder name frame at its
-- own size (102 x 30, never stretched) 2 px right of it, the name 4 px into it and 92 wide.
-- XP has XP_Icon and its number in NumberFontNormal, money inv_misc_coin_01, as
-- MapQuestInfoRewardsFrame's OnLoad sets them; reputation has the amount on its icon's corner,
-- as SmallQuestInfoRewardReputationTemplate's RewardAmount. DungeonJournal's pills are made
-- into these: their backdrop and badge go, their size is Blizzard's (kept when DungeonJournal
-- sizes the money pill to its text), and reputation pills are laid out again at that size.
local BUTTON_WIDTH, BUTTON_HEIGHT, ICON_SIZE = 134, 30, 30
local NAME_FRAME_GAP, NAME_INSET, NAME_WIDTH = 2, 4, 92
local ROW_GAP, COLUMN_GAP = 2, 8
local WHITE = { 1, 1, 1 }
local XP_ICON = "Interface\\Icons\\XP_Icon"
local MONEY_ICON = "Interface\\Icons\\inv_misc_coin_01"
local REPUTATION_ICON = "Interface\\Icons\\Achievement_Reputation_01"
local made = setmetatable({}, { __mode = "k" }) -- pill -> true once it's a reward button

local function keepWidth(_, pill, width)
    if width ~= BUTTON_WIDTH then pill:SetWidth(BUTTON_WIDTH) end
end

-- `name` goes in the name frame in `font`; `badge` and `badgeText`, DungeonJournal's, are hidden.
local function rewardButton(mod, pill, icon, name, font, badge, badgeText)
    if not pill or made[pill] then return end
    made[pill] = true
    pill:ClearBackdrop()
    pill:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    mod:Hook(pill, "SetWidth", keepWidth)
    if badge then badge:SetAlpha(0) end
    if badgeText then badgeText:SetAlpha(0) end
    local iconTexture = pill:CreateTexture(nil, "BACKGROUND")
    iconTexture:SetTexture(icon)
    iconTexture:SetSize(ICON_SIZE, ICON_SIZE)
    iconTexture:SetPoint("TOPLEFT")
    local nameFrame = pill:CreateTexture(nil, "BACKGROUND")
    nameFrame:SetAtlas("QuestItemBorder", true)
    nameFrame:SetPoint("LEFT", iconTexture, "RIGHT", NAME_FRAME_GAP, 0)
    name:ClearAllPoints()
    name:SetPoint("LEFT", nameFrame, "LEFT", NAME_INSET, 0)
    name:SetWidth(NAME_WIDTH)
    name:SetJustifyH("LEFT")
    Restyle.KeepText(mod, name, font, WHITE)
    pill.rewardIcon = iconTexture
end

-- Reputation: the amount on the icon's bottom right corner.
local function reputationButton(mod, pill)
    if made[pill] then return end
    rewardButton(mod, pill, REPUTATION_ICON, pill.name, "GameFontHighlightSmall", pill.badge)
    pill.amount:ClearAllPoints()
    pill.amount:SetPoint("BOTTOMRIGHT", pill.rewardIcon, "BOTTOMRIGHT", 0, 1)
    Restyle.KeepText(mod, pill.amount, "NumberFontNormalSmall", WHITE)
end

-- DungeonJournal lays reputation pills out by their text's width (FDJ.LayoutRepPills(reps, y,
-- maxWidth)); at Blizzard's width they're laid out again the same way, a row 2 px under the last.
local function layOutReputation(frame, y, maxWidth)
    local x, row = 0, 0
    for _, pill in ipairs(frame.questRepPills or {}) do
        if pill:IsShown() then
            if row == 0 then row = 1 end
            if x > 0 and x + BUTTON_WIDTH > maxWidth then
                x, row = 0, row + 1
            end
            pill:ClearAllPoints()
            pill:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", x, -(y + (row - 1) * (BUTTON_HEIGHT + ROW_GAP)))
            x = x + BUTTON_WIDTH + COLUMN_GAP
        end
    end
end

function Pages.SkinQuestPage(mod, frame, fdj)
    local inset = frame.questTextInset
    if not inset then return end
    inset:ClearBackdrop()
    if frame.questParchment then frame.questParchment:SetAtlas("QuestBG-Parchment") end
    for _, edge in ipairs(frame.questInsetEdges or {}) do edge:Hide() end
    local textColor, titleColor = GetMaterialTextColors("Parchment")
    for _, key in ipairs(TITLES) do Restyle.KeepText(mod, frame[key], "QuestTitleFont", titleColor) end
    for _, key in ipairs(TEXTS) do Restyle.KeepText(mod, frame[key], "QuestFont", textColor) end
    -- Its gold is a colour code in the text.
    Restyle.PlainText(mod, frame.questRewardHeader)

    local share = frame.questShareButton
    Restyle.PanelButton(mod, share, shareState)
    if fdj.SetQuestShareButtonVisual then
        mod:Hook(fdj, "SetQuestShareButtonVisual", function(_, button)
            if button == share then Restyle.PaintPanelButton(share, shareState(share)) end
        end)
    end

    local xp = frame.questXPReward
    if xp then rewardButton(mod, xp, XP_ICON, xp.text, "NumberFontNormal", xp.badge, xp.badgeLabel) end
    local money = frame.questMoneyReward
    if money then rewardButton(mod, money, MONEY_ICON, money.text, "GameFontHighlight") end
    -- Reputation rewards are pooled, made as they're laid out.
    local function reputation(_, _, y, maxWidth)
        for _, pill in ipairs(frame.questRepPills or {}) do reputationButton(mod, pill) end
        if y and maxWidth then layOutReputation(frame, y, maxWidth) end
    end
    if fdj.LayoutRepPills then mod:Hook(fdj, "LayoutRepPills", reputation) end
    reputation()
end

---------------------------------------------------------------------------
-- The Journey bar
---------------------------------------------------------------------------

-- DungeonJournal draws its bar at scale 0.86, FDJ.RPG_BAR_Y (51) of its own units down from the
-- home page's top; its emblems and the line under it follow the bar's place and scale. Smaller,
-- and lower by PADDING px, with that much more room above it and the same 5 px under it.
local SCALE = 0.75
local PADDING = 6
local ORIGINAL_SCALE = 0.86

local moved = false

-- Before DungeonJournal places its bar (FDJ.RPG_BAR_Y is read each time it does).
function Pages.MoveJourneyBar(fdj)
    if moved or type(fdj.RPG_BAR_Y) ~= "number" then return end
    fdj.RPG_BAR_Y = (fdj.RPG_BAR_Y * ORIGINAL_SCALE + PADDING) / SCALE
    moved = true
end

function Pages.SkinJourneyBar(_, frame)
    local bar = frame.rpgBar
    if bar and bar:GetScale() ~= SCALE then bar:SetScale(SCALE) end
end

