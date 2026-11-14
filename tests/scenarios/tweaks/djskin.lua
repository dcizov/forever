--[[
    Forever Tweaks - tests/scenarios/tweaks/djskin.lua
    Dungeon Journal Skin on a stand-in DungeonJournal: its palette swapped and put back, the
    window's backdrops cleared and Blizzard's layouts drawn, icon borders on pooled loot rows, and
    turning a part off asking to reload. (Every other scenario runs without DungeonJournal, where
    the module must do nothing.)
    Run by tests/run.lua (lua5.1 tests/run.lua djskin), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()

-- DungeonJournal as it is at PLAYER_LOGIN: its namespace and themes, and its window.
W.loaded.ForeverDungeonJournal = true
local hall = { title = { 0.9, 0.7, 0.3 }, text = { 0.9, 0.8, 0.6 }, border = { 0.5, 0.3, 0.1, 1 }, row = { 0.2, 0.1, 0.05, 0.9 } }
local wailing = { title = { 0.9, 0.9, 0.4 }, text = { 0.8, 0.9, 0.7 } }
ForeverDungeonJournal_NS = { RPG_BAR_Y = 51, THEMES = {
    ["Hall of Thanes"] = hall,
    ["Wailing Caverns"] = wailing,
    ["Scarlet Monastery: Library"] = hall, -- shared, as the Graveyard's is
} }

-- Blizzard's Backdrop mixin: colour calls do nothing once the backdrop is cleared.
local function backdrop(f)
    f.backdropInfo = {}
    function f:ClearBackdrop() self.backdropInfo = nil end
    function f:SetBackdropColor(...) if self.backdropInfo then self.bgColor = { ... } end end
    return f
end

-- DungeonJournal makes its window in its own PLAYER_LOGIN handler (below), which may run after ours.
ForeverDungeonJournalFrame = false
local frame = backdrop(CreateFrame("Frame", nil, UIParent, "BackdropTemplate"))
frame.topStrip = frame:CreateTexture()
frame.mainTitle = frame:CreateFontString()
frame.closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
for _, key in ipairs({ "contentPanel", "leftPanel", "homePanel" }) do
    frame[key] = backdrop(CreateFrame("Frame", nil, frame, "BackdropTemplate"))
end
frame.contentParchment = frame.contentPanel:CreateTexture()
frame.lootContent = CreateFrame("Frame", nil, frame)
-- The boss list: 315 px rows in a scroll frame 300 wide.
local bossScroll = CreateFrame("ScrollFrame", nil, frame)
function bossScroll:GetWidth() return 300 end
frame.bossContent = CreateFrame("Frame", nil, bossScroll)
function frame.bossContent:GetWidth() return 315 end
local bossRow = backdrop(CreateFrame("Button", nil, frame.bossContent, "BackdropTemplate"))
frame.searchEditBox = backdrop(CreateFrame("EditBox", nil, frame, "BackdropTemplate"))
frame.bossesTab = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
frame.bossesTab.fdjIcon = frame.bossesTab:CreateTexture()
frame.bossesTab.text = frame.bossesTab:CreateFontString()

-- The quest page, and RPG Mode's Journey bar (made when the home page's cards are drawn).
frame.questTextInset = backdrop(CreateFrame("Frame", nil, frame, "BackdropTemplate"))
frame.questParchment = frame.questTextInset:CreateTexture()
frame.questInsetEdges = { frame.questTextInset:CreateTexture() }
frame.selectedQuestName = frame.questTextInset:CreateFontString()
frame.questDetailText = frame.questTextInset:CreateFontString()
frame.questRewardHeader = frame.questTextInset:CreateFontString()
frame.homeCardsContent = CreateFrame("Frame", nil, frame.homePanel)
frame.questShareButton = backdrop(CreateFrame("Button", nil, frame.questTextInset, "BackdropTemplate"))
frame.questXPReward = backdrop(CreateFrame("Frame", nil, frame.questTextInset, "BackdropTemplate"))
frame.questXPReward.badge = frame.questXPReward:CreateTexture()
frame.questXPReward.badgeLabel = frame.questXPReward:CreateFontString()
frame.questXPReward.text = frame.questXPReward:CreateFontString()
frame.questMoneyReward = backdrop(CreateFrame("Frame", nil, frame.questTextInset, "BackdropTemplate"))
frame.questMoneyReward.text = frame.questMoneyReward:CreateFontString()
-- Reputation pills, pooled; DungeonJournal lays them out by their text's width.
local function repPill()
    local pill = backdrop(CreateFrame("Frame", nil, frame.questTextInset, "BackdropTemplate"))
    pill.badge, pill.amount, pill.name = pill:CreateTexture(), pill:CreateFontString(), pill:CreateFontString()
    return pill
end
frame.questDetailContent = frame.questTextInset
frame.questRepPills = { repPill(), repPill() }
ForeverDungeonJournal_NS.LayoutRepPills = function(reps, y)
    for i, pill in ipairs(frame.questRepPills) do pill:SetPoint("TOPLEFT", frame.questDetailContent, "TOPLEFT", (i - 1) * 90, -y) end
    return 30
end
ForeverDungeonJournal_NS.SetQuestShareButtonVisual = function(button, shareable) button._fdjShareableQuest = shareable end

W.items["[Thane's Blade]"] = { id = 101, quality = 3 }
local function lootRow(item)
    local row = backdrop(CreateFrame("Button", nil, frame.lootContent, "BackdropTemplate"))
    row.icon = row:CreateTexture()
    row.slot = row:CreateFontString()
    row.item = item
    return row
end
-- What the skin adds to a row after its icon and name: the row art (an atlas) and the border.
local function added(row, wantAtlas)
    for i = 3, #(row._children or {}) do
        local child = row._children[i]
        if child._kind == "Texture" and (child._atlas ~= nil) == wantAtlas then return child end
    end
end
local function borderOf(row)
    for _, child in ipairs(row._children or {}) do
        if child._texture == "Interface\\Common\\WhiteIconFrame" then return child end
    end
end
local function artOf(row) return added(row, true) end
local first = lootRow({ 101 })
-- The hover each row is given (the stand-in keeps no highlight of its own).
for _, row in ipairs({ first, bossRow }) do
    local set = row.SetHighlightAtlas
    function row:SetHighlightAtlas(atlas, ...) self._highlight = atlas; return set(self, atlas, ...) end
end

local ns = W.LoadAddon(root, "ForeverTweaks")
local maker = CreateFrame("Frame") -- made after ours, so it hears PLAYER_LOGIN after ours
maker:RegisterEvent("PLAYER_LOGIN")
maker:SetScript("OnEvent", function() ForeverDungeonJournalFrame = frame end)
login()
W.RunTimers() -- the frame after: the window skinned on the one before paints its lists now
local mod = ns.modules.DungeonJournalSkin
check(mod.active, "on by default")

-- Colours
eq(hall.title[2], 0.82, "titles are Blizzard's gold")
eq(wailing.text[1], 1, "text is white in every dungeon")
eq(hall.row[4], 0, "rows' own fill goes clear over their art")
eq(hall.rowSelected[2], 0.82, "a picked row is a gold wash")

-- Window frame and panels
eq(frame.backdropInfo, nil, "the window's backdrop is cleared")
eq(frame.topStrip:IsShown(), false, "its title strip is hidden")
eq(frame.contentPanel.backdropInfo, nil, "a panel's backdrop is cleared")
frame.contentPanel:SetBackdropColor(1, 0, 0, 1)
eq(frame.contentPanel.bgColor, nil, "and DungeonJournal's colours no longer reach it")
eq(frame.contentPanel._layout, "InsetFrameTemplate", "a panel is a Blizzard inset")
eq(frame.homePanel._layout, "InsetFrameTemplate", "the home page too")
eq(frame.contentParchment:IsShown(), false, "its parchment wash is hidden")
local border
for _, child in ipairs(frame._children) do
    if child._layout then border = child end
end
eq(border and border._layout, "ButtonFrameTemplateNoPortrait", "the metal frame is drawn")
eq(frame.mainTitle:GetParent(), border, "the title sits in the title bar")

-- Row art and the search box
eq(artOf(first) and artOf(first)._atlas, "PetList-ButtonBackground", "a row gets the pet list's row art")
eq(frame.searchEditBox.backdropInfo, nil, "the search box loses its backdrop")

-- Picked and hovered look different: a picked boss has the Select frame over a gold tint, a
-- hovered row (loot too) only the soft hover; never DungeonJournal's yellow fill.
local function textureWith(row, test)
    for _, child in ipairs(row._children or {}) do
        if child._kind == "Texture" and test(child) then return child end
    end
end
eq(first._highlight, "Options_List_Hover", "a loot row lights softly under the mouse")
eq(bossRow._highlight, "Options_List_Hover", "and a boss row too")
first.Center = first:CreateTexture() -- the Backdrop mixin's fill
first:SetBackdropColor(1, 0.82, 0, 1) -- DungeonJournal's hover, at full alpha
eq(textureWith(first, function(t) return t._atlas == "PetList-ButtonSelect" end), nil,
    "a hovered loot row never gets the picked look")
eq(first.Center:IsShown(), false, "nor DungeonJournal's yellow fill")
local pickFrame = textureWith(bossRow, function(t) return t._atlas == "PetList-ButtonSelect" end)
local pickTint = textureWith(bossRow, function(t) return t._color ~= nil and t._color[1] == 1 end)
bossRow:SetBackdropColor(1, 0.82, 0, 0.22) -- the palette's picked row
check(pickFrame and pickFrame:IsShown(), "a picked boss shows the Select frame")
check(pickTint and pickTint:IsShown(), "over a gold tint")
bossRow:SetBackdropColor(0, 0, 0, 0) -- another boss picked: the palette's clear row
eq(pickFrame:IsShown() or pickTint:IsShown(), false, "and nothing once another is picked")

-- A boss row's art stops where its scroll frame cuts the row off.
local bossArt = bossRow._children and bossRow._children[1]
eq(bossArt and bossArt._atlas, "PetList-ButtonBackground", "a boss row gets the pet list's row art")
eq(select(4, bossArt:GetPoint()), -15, "ending where the list's frame cuts the row off, not past it")

-- The quest page: Blizzard's parchment, its text colours kept through DungeonJournal's redraws.
eq(frame.questParchment._atlas, "QuestBG-Parchment", "the quest page is Blizzard's quest parchment")
eq(frame.questInsetEdges[1]:IsShown(), false, "without DungeonJournal's brown edge lines")
frame.selectedQuestName:SetTextColor(1, 0.78, 0.16) -- DungeonJournal's gold, on a redraw
eq(frame.selectedQuestName._textColor[1], 0.2, "the quest title keeps the parchment's title colour")

-- The Share button: Blizzard's red panel button, grayed while the quest can't be shared.
local share = frame.questShareButton
eq(share.backdropInfo, nil, "the Share button loses its green box")
local left = share._children[1]
eq(left._texture, "Interface\\Buttons\\UI-Panel-Button-Disabled", "not shareable: the gray panel button")
ForeverDungeonJournal_NS.SetQuestShareButtonVisual(share, true)
eq(left._texture, "Interface\\Buttons\\UI-Panel-Button-Up", "shareable: the red panel button")
share:Fire("OnMouseDown")
eq(left._texture, "Interface\\Buttons\\UI-Panel-Button-Down", "pressed")
share:Fire("OnMouseUp")
eq(left._texture, "Interface\\Buttons\\UI-Panel-Button-Up", "and up again")

-- Rewards: Blizzard's compact reward buttons (SmallItemButtonTemplate), never stretched.
local function childWith(f, test)
    for _, child in ipairs(f._children or {}) do if test(child) then return child end end
end
local xp = frame.questXPReward
eq(xp.backdropInfo, nil, "the XP reward loses its purple box")
eq(xp._width, 134, "Blizzard's 134 px wide button")
eq(xp._height, 30, "30 high")
eq(xp.badge._alpha, 0, "DungeonJournal's badge is hidden")
local xpIcon = childWith(xp, function(c) return c._texture == "Interface\\Icons\\XP_Icon" end)
check(xpIcon ~= nil, "with Blizzard's XP icon")
local border = childWith(xp, function(c) return c._atlas == "QuestItemBorder" end)
check(border ~= nil and border._useAtlasSize == true, "and the QuestItemBorder name frame at its own size")
eq(xp.text._fontObject, "NumberFontNormal", "its number in NumberFontNormal")
xp.text:SetTextColor(0.2, 0.2, 0.2)
eq(xp.text._textColor[1], 1, "and white")
local money = frame.questMoneyReward
check(childWith(money, function(c) return c._texture == "Interface\\Icons\\inv_misc_coin_01" end) ~= nil,
    "money has Blizzard's coin icon")
money:SetWidth(60) -- DungeonJournal sizes it to its text
eq(money._width, 134, "and keeps Blizzard's width")
ForeverDungeonJournal_NS.LayoutRepPills({ { "Thunder Bluff", "100" }, { "Orgrimmar", "50" } }, 200, 200)
local rep1, rep2 = frame.questRepPills[1], frame.questRepPills[2]
check(childWith(rep1, function(c) return c._texture == "Interface\\Icons\\Achievement_Reputation_01" end) ~= nil,
    "a reputation reward has a reputation icon")
eq(select(1, rep1.amount:GetPoint()), "BOTTOMRIGHT", "its amount on the icon's corner")
eq(rep1._width, 134, "at Blizzard's width")
eq(select(4, rep2:GetPoint()), 0, "two that don't fit side by side: the second starts a new row")
eq(select(5, rep2:GetPoint()), -232, "one button and 2 px lower")
frame.questDetailText:SetFont("Fonts\\FRIZQT__.TTF", 14)
eq(frame.questDetailText._fontObject, "QuestFont", "the quest text keeps the quest window's font")
eq(frame.selectedQuestName._fontObject, "QuestTitleFont", "and the title its title font")
frame.selectedQuestName:SetShadowOffset(1, -1) -- DungeonJournal's black shadow, on a redraw
eq(frame.selectedQuestName._shadowOffset[1], 0, "the title has no shadow, as Blizzard's quest text")
frame.questRewardHeader:SetText("|cffffd36bRewards|r")
eq(frame.questRewardHeader:GetText(), "Rewards", "the Rewards header loses its gold colour code")

-- RPG Mode's Journey bar: DungeonJournal's own, a quarter smaller and lower.
check(math.abs(ForeverDungeonJournal_NS.RPG_BAR_Y - (51 * 0.86 + 6) / 0.75) < 0.01, "placed lower, for room above it")
local theirs = CreateFrame("Frame", nil, frame.homePanel)
frame.rpgBar = theirs
frame.homeCardsContent:SetHeight(400)
W.RunTimers()
eq(theirs._scale, 0.75, "drawn a quarter smaller")

-- Icon borders
check(borderOf(first) and borderOf(first):IsShown(), "a loot icon gets a quality border")
local pooled = lootRow({ 101 })
local empty = lootRow(nil)
frame.lootContent:SetHeight(200) -- a loot refresh ends so
W.RunTimers()
check(borderOf(pooled) and borderOf(pooled):IsShown(), "a row made later gets one after the refresh")
check(artOf(pooled) ~= nil, "and its row art")
eq(borderOf(empty), nil, "a row with no item gets none")

-- The mode buttons: no oversized icon, the label centred even when DungeonJournal moves it.
eq(frame.bossesTab.fdjIcon._alpha, 0, "the skull icon is hidden")
frame.bossesTab.text:SetPoint("CENTER", frame.bossesTab, "CENTER", 7, 0)
eq(select(4, frame.bossesTab.text:GetPoint()), 0, "the label stays centred")

-- Turning parts off
ns:SetOption("DungeonJournalSkin", "colors", false)
eq(hall.title[2], 0.7, "Colours off puts each dungeon's own back")
eq(wailing.text[1], 0.8, "in every dungeon")
ns:SetOption("DungeonJournalSkin", "colors", true)
eq(hall.title[2], 0.82, "and on again swaps them back")
ns:SetOption("DungeonJournalSkin", "icons", false)
eq(borderOf(first):IsShown(), false, "Icon Borders off hides them")
check(not mod:DebugLine():find("icons", 1, true), "and the debug line stops listing them")
ns:SetOption("DungeonJournalSkin", "icons", true)
check(mod:DebugLine():find("icons", 1, true) ~= nil, "on again: listed again")
ns:SetOption("DungeonJournalSkin", "icons", false)
eq(#W.popups, 0, "neither asks to reload")
ns:SetOption("DungeonJournalSkin", "panels", false)
eq(#W.popups, 1, "Panels off asks to reload")
W.Accept()
eq(W.reloaded, true, "and reloads when told to")

finish()
