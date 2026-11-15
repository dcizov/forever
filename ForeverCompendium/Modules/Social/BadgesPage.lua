--[[
    Forever Compendium - Modules/Social/BadgesPage.lua
    The journal's Badges page (its tab shows while Badges is on): a card for every badge, with its
    icon in the colour of its tier, its name and tier, what the next tier asks and how far along
    you are, and when it was earned. Click an earned badge to show it on your tooltip (a star marks
    the shown ones, up to three).
]]

local _, ns = ...
local L = ns.L

local ipairs, format, math = ipairs, string.format, math
local CreateFrame = CreateFrame
local Text = assert(ns.JournalText, "BadgesPage.lua loads after JournalText.lua")
local J = assert(ns.JournalKit, "BadgesPage.lua loads after JournalKit.lua")
local Journal = assert(ns.Journal, "BadgesPage.lua loads after Journal.lua")
local Badges = assert(ns.Badges, "BadgesPage.lua loads after Badges.lua")

local COLUMNS, CARD_HEIGHT, GAP = 3, 74, 8
local STAR = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"

local page = { key = "badges", label = L.JOURNAL_TAB_BADGES, icon = "Interface\\Icons\\Achievement_GuildPerk_HonorableMention", order = 40 }
local cards, summary, scroll, content = {}, nil, nil, nil

function page.Shown() return Badges.module.active end

local function cardTip(card)
    local key = card.key
    local earned = Badges.module.db.earned[key]
    local stats = card.stats
    J.Tip(card, Badges.TierName(key, earned and earned.tier), Badges.Describe(key, card.need or stats[key] or 0),
        earned and { format(L.BADGES_EARNED_ON, Text.Date(earned.at)), 0.7, 0.7, 0.7 } or nil,
        earned and { Badges.IsShown(key) and L.BADGES_HIDE_HINT or L.BADGES_SHOW_HINT, 0.1, 1, 0.1 } or nil)
end

local function newCard(parent, width)
    local card = CreateFrame("Button", nil, parent)
    card:SetSize(width, CARD_HEIGHT)
    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(42, 42)
    card.icon:SetPoint("LEFT", 8, 0)
    -- The Toy Box's slot border: gold once earned, grey before; the tier's colour on a ring.
    card.slot = J.CollectionSlot(card, 42)
    card.slot:SetAllPoints(card.icon)
    card.ring = card:CreateTexture(nil, "OVERLAY", nil, 2)
    card.ring:SetTexture("Interface\\Common\\WhiteIconFrame")
    card.ring:SetAllPoints(card.icon)
    card.star = card:CreateTexture(nil, "OVERLAY", nil, 2)
    card.star:SetTexture(STAR)
    card.star:SetSize(16, 16)
    card.star:SetPoint("TOPRIGHT", -6, -6)
    card.name = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.name:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 10, -2)
    card.name:SetPoint("RIGHT", -24, 0)
    card.name:SetJustifyH("LEFT")
    card.bar = CreateFrame("StatusBar", nil, card)
    card.bar:SetStatusBarTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar")
    card.bar:SetHeight(11)
    card.barFrame = card.bar:CreateTexture(nil, "OVERLAY")
    card.barFrame:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder")
    card.barFrame:SetPoint("TOPLEFT", -5, 8)
    card.barFrame:SetPoint("BOTTOMRIGHT", 5, -8)
    card.bar:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -8)
    card.bar:SetPoint("RIGHT", -14, 0)
    card.barBg = card.bar:CreateTexture(nil, "BACKGROUND")
    card.barBg:SetAllPoints()
    card.barBg:SetColorTexture(0, 0, 0, 0.5)
    card.progress = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.progress:SetPoint("TOPLEFT", card.bar, "BOTTOMLEFT", 0, -4)
    card:SetHighlightAtlas("PetList-ButtonHighlight", "ADD")
    card:SetScript("OnClick", function(self)
        Badges.ToggleShown(self.key)
        page.Refresh()
        cardTip(self)
    end)
    card:SetScript("OnEnter", cardTip)
    card:SetScript("OnLeave", GameTooltip_Hide)
    return card
end

local function fillCard(card, badge, stats)
    local key = badge.key
    local count = stats[key] or 0
    local tier, need = Badges.TierOf(key, count)
    card.key, card.stats, card.need = key, stats, need
    card.icon:SetTexture(badge.icon)
    card.icon:SetDesaturated(tier == 0)
    card.slot:SetCollected(tier > 0)
    card.ring:SetVertexColor(Badges.TierColor(tier))
    card.ring:SetShown(tier > 0)
    card.name:SetText(tier > 0 and Badges.TierName(key, tier) or (Text.GRAY .. Badges.Name(key) .. "|r"))
    card.star:SetShown(Badges.IsShown(key))
    local floor = badge.tiers[tier] or 0
    card.bar:SetMinMaxValues(0, 1)
    card.bar:SetValue(need and math.min(1, (count - floor) / math.max(need - floor, 1)) or 1)
    card.bar:SetStatusBarColor(Badges.TierColor(math.max(tier, 1)))
    card.progress:SetText(need and format(L.BADGES_PROGRESS, Badges.CountText(key, count), Badges.CountText(key, need))
        or L.BADGES_COMPLETE)
end

-- Places the cards in COLUMNS columns across the scroll's width.
local function placeCards()
    local width = math.max(scroll:GetWidth() or 0, 300)
    local cardWidth = math.floor((width - GAP * (COLUMNS - 1)) / COLUMNS)
    content:SetWidth(width)
    for i, card in ipairs(cards) do
        card:SetWidth(cardWidth)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", ((i - 1) % COLUMNS) * (cardWidth + GAP), -math.floor((i - 1) / COLUMNS) * (CARD_HEIGHT + GAP))
    end
    content:SetHeight(math.ceil(#cards / COLUMNS) * (CARD_HEIGHT + GAP))
end

function page.Refresh()
    placeCards()
    local stats = Badges.Stats()
    local earned, total = 0, 0
    for i, badge in ipairs(Badges.LIST) do
        fillCard(cards[i], badge, stats)
        local entry = Badges.module.db.earned[badge.key]
        earned, total = earned + (entry and entry.tier or 0), total + #badge.tiers
    end
    summary.Count:SetText(format(L.JOURNAL_COUNT, earned, total))
end

function page.Build(frame)
    summary = J.CountBox(frame, L.BADGES_TIERS)
    summary:SetPoint("LEFT", frame, "TOPLEFT", J.PORTRAIT, -J.STRIP / 2 + 2)
    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("RIGHT", frame, "TOPRIGHT", -8, -J.STRIP / 2)
    hint:SetText(L.BADGES_PAGE_HINT)
    local inset = J.Inset(frame)
    inset:SetPoint("TOPLEFT", 0, -J.STRIP)
    inset:SetPoint("BOTTOMRIGHT")
    J.CollectionsBackground(inset)
    scroll = ns.Kit.NewScroll(inset)
    scroll:SetPoint("TOPLEFT", 40, -40)
    scroll:SetPoint("BOTTOMRIGHT", -40, 24)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    for i = 1, #Badges.LIST do cards[i] = newCard(content, 280) end
end

Journal.AddPage(page)
