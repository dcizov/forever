--[[
    Forever Compendium - Notification Banner
    A banner at the top of the screen when the Recorder learns something worth knowing (its
    ns:Announce news): a rare creature met (on by default), any new creature, a new drop, a
    quest's giver, turn-in or start item found, a badge earned or a rare or boss defeated for the
    first time (a trophy; these on by default; each its own checkbox). Blizzard's toast look (the scenario
    toast's gold frame, Toast-Frame: an icon slot and two bands of text, docs/forever-api.md),
    shown for a few seconds, one after the other when several come at once. A click on it opens
    the journal on what it's about. No sound, nothing in chat.
    It moves in Edit Mode (Forever Core's UI/EditMode.lua, which shows it there as a sample):
    its place is kept as its top centre's offset from the screen's.
]]

local _, ns = ...
local L = ns.L

local math, format, tremove = math, string.format, table.remove
local CreateFrame, UIParent = CreateFrame, UIParent
local Book = ns.Book

local PLATE, PLATE_W, PLATE_H = "Toast-Frame", 311, 78
local SLOT_X, SLOT_Y, SLOT = 22, -22, 34
local TEXT_LEFT, TEXT_RIGHT, TITLE_Y, SUB_Y = 78, -29, -25, -47
local QUEUE_MAX = 5 -- banners waiting their turn, at most (the oldest go first)
local BOOK_ICON = "Interface\\Icons\\INV_Misc_Book_11"
local RARE = { rare = true, rareelite = true }

local M = ns:NewModule("Banner", {
    title = L.BANNER_TITLE,
    category = "notifications",
    description = L.BANNER_DESC,
    added = "2.1.0",
    defaults = {
        rares = true, creatures = false, drops = false, quests = false, badges = true, trophies = true,
        duration = 5, scale = 100,
        x = 0, y = -160, -- the banner's top centre, from the screen's top centre (Edit Mode moves it)
    },
    options = {
        { key = "rares", type = "checkbox", label = L.BANNER_RARES, tooltip = L.BANNER_RARES_TIP },
        { key = "creatures", type = "checkbox", label = L.BANNER_CREATURES, tooltip = L.BANNER_CREATURES_TIP },
        { key = "drops", type = "checkbox", label = L.BANNER_DROPS, tooltip = L.BANNER_DROPS_TIP },
        { key = "quests", type = "checkbox", label = L.BANNER_QUESTS, tooltip = L.BANNER_QUESTS_TIP },
        { key = "badges", type = "checkbox", label = L.BANNER_BADGES, tooltip = L.BANNER_BADGES_TIP, added = "2.3.0" },
        { key = "trophies", type = "checkbox", label = L.BANNER_TROPHIES, tooltip = L.BANNER_TROPHIES_TIP, added = "2.4.0" },
        { key = "duration", type = "slider", label = L.BANNER_DURATION, min = 2, max = 15, step = 1, format = "%d s",
          tooltip = L.BANNER_DURATION_TIP },
        { key = "scale", type = "slider", label = L.BANNER_SCALE, min = 60, max = 150, step = 5, format = "%d%%",
          tooltip = L.BANNER_SCALE_TIP },
    },
})

local banner, editInfo, hideTimer
local queue = {} -- { icon, atlas, title, sub, open } waiting (open: what a click opens)

---------------------------------------------------------------------------
-- The frame
---------------------------------------------------------------------------

local function band(text, y)
    text:SetPoint("LEFT", banner, "TOPLEFT", TEXT_LEFT, y)
    text:SetPoint("RIGHT", banner, "TOPRIGHT", TEXT_RIGHT, y)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
end

local function place()
    local s = M.db.scale / 100
    banner:SetScale(s)
    banner:ClearAllPoints()
    banner:SetPoint("TOP", UIParent, "TOP", M.db.x / s, M.db.y / s)
end

-- Edit Mode puts the banner's centre at (cx, cy), in UIParent units.
local function moveTo(cx, cy)
    local top = cy + PLATE_H * banner:GetScale() / 2
    ns:StoreOption(M.name, "x", math.floor(cx - UIParent:GetWidth() / 2 + 0.5))
    ns:StoreOption(M.name, "y", math.floor(top - UIParent:GetHeight() + 0.5))
    place()
end

local function draw(note)
    banner.note = note
    if note.atlas then banner.icon:SetAtlas(note.atlas) else banner.icon:SetTexture(note.icon or BOOK_ICON) end
    banner.title:SetText(note.title)
    banner.sub:SetText(note.sub or "")
end

local showNext -- below

local function build()
    banner = CreateFrame("Button", "ForeverCompendiumBanner", UIParent)
    banner:SetSize(PLATE_W, PLATE_H)
    banner:SetFrameStrata("DIALOG")
    banner:Hide()
    local plate = banner:CreateTexture(nil, "BACKGROUND")
    plate:SetAtlas(PLATE)
    plate:SetAllPoints()
    banner.icon = banner:CreateTexture(nil, "ARTWORK")
    banner.icon:SetSize(SLOT, SLOT)
    banner.icon:SetPoint("TOPLEFT", banner, "TOPLEFT", SLOT_X, SLOT_Y)
    banner.title = banner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    band(banner.title, TITLE_Y)
    banner.sub = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    band(banner.sub, SUB_Y)
    banner:SetScript("OnClick", function(self)
        local open = self.note and self.note.open
        if open then ns.RunCall(M, "banner click", open) end
        M:CancelTimer(hideTimer)
        ns.RunCall(M, "banner click", showNext)
    end)
    editInfo = {
        label = L.BANNER_TITLE,
        owner = M,
        moveTo = moveTo,
        size = { min = 60, max = 150, step = 5, format = "%d%%",
            get = function() return M.db.scale end,
            set = function(value) ns:SetOption(M.name, "scale", value) end },
        reset = function()
            ns:ResetOption(M.name, "x")
            ns:ResetOption(M.name, "y")
            place()
        end,
        settings = function() ns:OpenSettings(M.name) end,
        -- In Edit Mode it shows a sample to move.
        onActive = function(active)
            if active then
                draw({ atlas = "VignetteKill", title = L.BANNER_RARE, sub = L.BANNER_SAMPLE })
                banner:Show()
            elseif not M:IsPending(hideTimer) then
                banner:Hide()
            end
        end,
    }
    place()
end

-- The next banner waiting, or none.
function showNext()
    local note = tremove(queue, 1)
    if not note then
        hideTimer = nil
        if not ns.EditMode.IsActive() then banner:Hide() end
        return
    end
    draw(note)
    banner:Show()
    hideTimer = M:After(M.db.duration, showNext)
end

local function notify(note)
    if not banner then build() end
    queue[#queue + 1] = note
    while #queue > QUEUE_MAX do tremove(queue, 1) end
    if not M:IsPending(hideTimer) then showNext() end
end

---------------------------------------------------------------------------
-- What's worth a banner
---------------------------------------------------------------------------

local function creatureNote(npc)
    local rec = Book.Creature(npc)
    if not rec then return end
    local rare = RARE[rec.classification]
    local open = function() ns.ShowCreature(npc) end
    if rare and M.db.rares then
        return { atlas = "VignetteKill", title = L.BANNER_RARE, sub = rec.name, open = open }
    elseif M.db.creatures then
        local level = rec.maxLevel and format(L.BANNER_LEVEL, rec.maxLevel) or ""
        return { icon = BOOK_ICON, title = L.BANNER_CREATURE, sub = rec.name .. level, open = open }
    end
end

local function dropNote(npc, itemID)
    local rec, item = Book.Creature(npc), Book.Item(itemID)
    if not (M.db.drops and rec) then return end
    return { icon = item and item.icon, title = L.BANNER_DROP,
        sub = format(L.BANNER_DROP_FROM, item and item.name or "?", rec.name), open = function() ns.ShowItem(itemID) end }
end

local QUEST_LOOK = {
    giver = { atlas = "QuestNormal", title = L.BANNER_GIVER },
    ender = { atlas = "QuestTurnin", title = L.BANNER_ENDER },
    item = { icon = "Interface\\Icons\\INV_Misc_Note_02", title = L.BANNER_QUEST_ITEM },
}

local function questNote(questID, role)
    local look = QUEST_LOOK[role]
    if not (M.db.quests and look and Book.Quest(questID)) then return end
    return { atlas = look.atlas, icon = look.icon, title = look.title, sub = Book.QuestName(questID),
        open = function() ns.ShowQuest(questID) end }
end

local function badgeNote(key, tier)
    local Badges = ns.Badges
    if not (M.db.badges and Badges and Badges.BY_KEY[key]) then return end
    return { icon = Badges.BY_KEY[key].icon, title = L.BANNER_BADGE, sub = Badges.TierName(key, tier),
        open = function() ns.Journal.Open("badges") end }
end

local function trophyNote(npc)
    local rec = Book.Creature(npc)
    if not (M.db.trophies and rec) then return end
    return { atlas = "VignetteKill", title = L.BANNER_TROPHY, sub = rec.name,
        open = function() ns.Journal.Open("trophies") end }
end

local NOTES = { CREATURE_NEW = creatureNote, LOOT_NEW = dropNote, QUEST_PLACE = questNote, BADGE_EARNED = badgeNote,
    TROPHY = trophyNote }

ns:OnNews(M, function(_, event, ...)
    local make = M.active and NOTES[event]
    local note = make and make(...)
    if note then notify(note) end
end)

function M:OnEnable()
    if not banner then build() end
    ns.EditMode.Register(banner, editInfo)
end

function M:OnDisable()
    queue = {}
    if banner then
        ns.EditMode.Unregister(banner)
        banner:Hide()
    end
end

function M:OnSettingChanged(key)
    if banner and (key == "scale" or key == "x" or key == "y") then place() end
end
