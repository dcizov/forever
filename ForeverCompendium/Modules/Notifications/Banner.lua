--[[
    Forever Compendium - Notification Banner
    A notification at the top of the screen as the Recorder learns (its ns:Announce news), each
    kind its own checkbox:
      * a creature met for the first time ("Added to your journal"; a rare says so),
      * something new learned of a creature you already know: its loot, abilities, places,
        defenses or quests ("Loot updated"). What one creature teaches in a moment (GATHER
        seconds) is one notification ("Information updated"), merged into one still waiting,
        and none comes in the first FRESH seconds after it was met (the "added" one says it),
      * where a quest is given or turned in, or what item starts one (off by default),
      * a badge earned, a rare or boss defeated for the first time (a trophy).
    Blizzard's toast look (the scenario toast's gold frame, Toast-Frame: an icon slot and two
    bands of text, docs/forever-api.md). The slot holds a full icon cut to its art (as Blizzard's
    toasts draw them), and a quest or rare note adds its small map mark (the quest "!" or "?",
    the rare skull) as a badge on the icon's corner: those marks alone are mostly empty space. Each fades in, stays its time (as long as the mouse is on
    it) and fades out; several wait their turn. With Wait in Combat on, they wait while you fight
    or talk to someone (a gossip, quest, merchant, trainer, flight master, bank or auction house
    window), and the one showing goes back to the front of the line. A click opens the journal on
    what it's about. The first notification of a run makes the journal's discovery sound, a
    badge its tier's (Lib/Sound.lua, the Journal's Sounds option); nothing in chat.
    It moves in Edit Mode (Forever Core's UI/EditMode.lua, which shows it there as a sample):
    its place is kept as its top centre's offset from the screen's.
]]

local _, ns = ...
local L = ns.L

local math, ipairs, pairs, next, tremove, tinsert, GetTime = math, ipairs, pairs, next, table.remove, table.insert, GetTime
local CreateFrame, UIParent = CreateFrame, UIParent
local Book = ns.Book

local PLATE, PLATE_W, PLATE_H = "Toast-Frame", 311, 78
local SLOT_X, SLOT_Y, SLOT_W, SLOT_H = 21, -22, 36, 34 -- the plate's icon opening
local BADGE = 22
local CROP = { 0.08, 0.92, 0.08, 0.92 } -- an icon less its built-in border
local TEXT_LEFT, TEXT_RIGHT, TITLE_Y, SUB_Y = 78, -29, -25, -47
local QUEUE_MAX = 8 -- notifications waiting their turn, at most (the oldest go first)
local FADE_IN, FADE_OUT = 0.3, 0.8 -- seconds
local GATHER = 0.5 -- seconds what one creature teaches is gathered into one notification
local FRESH = 3 -- seconds after a creature is met that its updates say nothing
local SOUND_AFTER = 0.4 -- seconds after it shows that the sound plays
local RESUME_AFTER = 1 -- seconds after combat or a window ends that the line moves again
local BOOK_ICON = "Interface\\Icons\\INV_Misc_Book_09"
local SCROLL_ICON = "Interface\\Icons\\INV_Scroll_03"
local NOTE_ICON = "Interface\\Icons\\INV_Misc_Note_02"
local TROPHY_ICON = "Interface\\Icons\\INV_Misc_Head_Dragon_01" -- the Trophies tab's
local RARE = { rare = true, rareelite = true }

-- What was learned (CREATURE_LEARNED's reason; LOOT_NEW is "loot") -> its checkbox. Wares count
-- as loot; a look or your death to it say nothing.
local UPDATE_KEY = { loot = "upLoot", wares = "upLoot", abilities = "upAbilities", locations = "upLocations",
    defenses = "upDefenses", quests = "upQuests" }
local UPDATE_TEXT = { upLoot = L.BANNER_UP_LOOT, upAbilities = L.BANNER_UP_ABILITIES, upLocations = L.BANNER_UP_LOCATIONS,
    upDefenses = L.BANNER_UP_DEFENSES, upQuests = L.BANNER_UP_QUESTS }

-- The windows that mean you're talking to someone: the event that opens each, and the one that closes it.
local WINDOWS = {
    GOSSIP_SHOW = "gossip", GOSSIP_CLOSED = false,
    QUEST_GREETING = "quest", QUEST_DETAIL = "quest", QUEST_PROGRESS = "quest", QUEST_COMPLETE = "quest", QUEST_FINISHED = false,
    MERCHANT_SHOW = "merchant", MERCHANT_CLOSED = false,
    TRAINER_SHOW = "trainer", TRAINER_CLOSED = false,
    TAXIMAP_OPENED = "taxi", TAXIMAP_CLOSED = false,
    BANKFRAME_OPENED = "bank", BANKFRAME_CLOSED = false,
    AUCTION_HOUSE_SHOW = "auction", AUCTION_HOUSE_CLOSED = false,
}
local CLOSES = { GOSSIP_CLOSED = "gossip", QUEST_FINISHED = "quest", MERCHANT_CLOSED = "merchant", TRAINER_CLOSED = "trainer",
    TAXIMAP_CLOSED = "taxi", BANKFRAME_CLOSED = "bank", AUCTION_HOUSE_CLOSED = "auction" }

local function upOption(key, label, tip)
    return { key = key, type = "checkbox", label = label, tooltip = tip, added = "2.5.0", requires = "updates" }
end

local M = ns:NewModule("Banner", {
    title = L.BANNER_TITLE,
    category = "notifications",
    description = L.BANNER_DESC,
    added = "2.1.0",
    defaults = {
        creatures = true, rares = true, updates = true, quests = false, badges = true, trophies = true,
        upLoot = true, upAbilities = true, upLocations = true, upDefenses = true, upQuests = true,
        pause = true, duration = 4, scale = 100,
        x = 0, y = -160, -- the banner's top centre, from the screen's top centre (Edit Mode moves it)
    },
    options = {
        { key = "creatures", type = "checkbox", label = L.BANNER_CREATURES, tooltip = L.BANNER_CREATURES_TIP },
        { key = "rares", type = "checkbox", label = L.BANNER_RARES, tooltip = L.BANNER_RARES_TIP },
        { key = "updates", type = "checkbox", label = L.BANNER_UPDATES, tooltip = L.BANNER_UPDATES_TIP, added = "2.5.0" },
        upOption("upLoot", L.BANNER_UP_LOOT_LABEL, L.BANNER_UP_LOOT_TIP),
        upOption("upAbilities", L.BANNER_UP_ABILITIES_LABEL, L.BANNER_UP_ABILITIES_TIP),
        upOption("upLocations", L.BANNER_UP_LOCATIONS_LABEL, L.BANNER_UP_LOCATIONS_TIP),
        upOption("upDefenses", L.BANNER_UP_DEFENSES_LABEL, L.BANNER_UP_DEFENSES_TIP),
        upOption("upQuests", L.BANNER_UP_QUESTS_LABEL, L.BANNER_UP_QUESTS_TIP),
        { key = "quests", type = "checkbox", label = L.BANNER_QUESTS, tooltip = L.BANNER_QUESTS_TIP },
        { key = "badges", type = "checkbox", label = L.BANNER_BADGES, tooltip = L.BANNER_BADGES_TIP, added = "2.3.0" },
        { key = "trophies", type = "checkbox", label = L.BANNER_TROPHIES, tooltip = L.BANNER_TROPHIES_TIP, added = "2.4.0" },
        { key = "pause", type = "checkbox", label = L.BANNER_PAUSE, tooltip = L.BANNER_PAUSE_TIP, added = "2.5.0" },
        { key = "duration", type = "slider", label = L.BANNER_DURATION, min = 2, max = 15, step = 1, format = "%d s",
          tooltip = L.BANNER_DURATION_TIP },
        { key = "scale", type = "slider", label = L.BANNER_SCALE, min = 60, max = 150, step = 5, format = "%d%%",
          tooltip = L.BANNER_SCALE_TIP },
    },
})

local banner, editInfo
local queue = {} -- notes waiting: { key, icon, badge, title, sub, sound, open, reasons } (open: what a click opens)
local current -- the note showing, or nil
local holdTimer, fadeTimer, gatherTimer
local run = false -- a run of notifications is going (its first one made the sound)
local held = {} -- npcID -> { [option key] = true }: updates being gathered
local metAt = {} -- npcID -> GetTime() it was met
local windows = {} -- kind -> true while that window is open

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
    banner.icon:SetTexture(note.icon or BOOK_ICON)
    banner.icon:SetTexCoord(CROP[1], CROP[2], CROP[3], CROP[4])
    if note.badge then
        banner.badge:SetAtlas(note.badge)
        banner.badge:Show()
    else
        banner.badge:Hide()
    end
    banner.title:SetText(note.title)
    banner.sub:SetText(note.sub or "")
end

local function fader(from, to, seconds)
    local group = banner:CreateAnimationGroup()
    local alpha = group:CreateAnimation("Alpha")
    alpha:SetFromAlpha(from)
    alpha:SetToAlpha(to)
    alpha:SetDuration(seconds)
    group:SetToFinalAlpha(true)
    return group
end

local showNext, fadeOut, hold -- below

local function build()
    banner = CreateFrame("Button", "ForeverCompendiumBanner", UIParent)
    banner:SetSize(PLATE_W, PLATE_H)
    banner:SetFrameStrata("DIALOG")
    banner:SetClampedToScreen(true)
    banner:Hide()
    local plate = banner:CreateTexture(nil, "BACKGROUND")
    plate:SetAtlas(PLATE)
    plate:SetAllPoints()
    banner.icon = banner:CreateTexture(nil, "ARTWORK")
    banner.icon:SetSize(SLOT_W, SLOT_H)
    banner.icon:SetPoint("TOPLEFT", banner, "TOPLEFT", SLOT_X, SLOT_Y)
    banner.badge = banner:CreateTexture(nil, "OVERLAY")
    banner.badge:SetSize(BADGE, BADGE)
    banner.badge:SetPoint("CENTER", banner.icon, "BOTTOMRIGHT", -3, 3)
    banner.title = banner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    band(banner.title, TITLE_Y)
    banner.sub = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    band(banner.sub, SUB_Y)
    banner.fadeIn = fader(0, 1, FADE_IN)
    banner.fadeOut = fader(1, 0, FADE_OUT)
    banner:SetScript("OnClick", function()
        local open = current and current.open
        if open then ns.ChargedCall(M, "banner click", open) end
        ns.ChargedCall(M, "banner click", showNext)
    end)
    -- The mouse on it keeps it (fully shown); off it, it stays its time again.
    banner:SetScript("OnEnter", function()
        if not current then return end
        M:CancelTimer(holdTimer)
        M:CancelTimer(fadeTimer)
        banner.fadeOut:Stop()
        banner:SetAlpha(1)
    end)
    banner:SetScript("OnLeave", function()
        if current and not M:IsPending(fadeTimer) then ns.ChargedCall(M, "banner leave", hold, M.db.duration) end
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
                draw({ icon = BOOK_ICON, badge = "VignetteKill", title = L.BANNER_TITLE, sub = L.BANNER_SAMPLE })
                banner:SetAlpha(1)
                banner:Show()
            elseif not current then
                banner:Hide()
            end
        end,
    }
    place()
end

---------------------------------------------------------------------------
-- The line
---------------------------------------------------------------------------

-- Whether notifications wait: Wait in Combat is on, and you fight or talk to someone.
local function busy()
    return M.db.pause and (InCombatLockdown() or next(windows) ~= nil)
end

local function stopTimers()
    M:CancelTimer(holdTimer)
    M:CancelTimer(fadeTimer)
end

-- It stays `seconds`, then fades.
function hold(seconds)
    M:CancelTimer(holdTimer)
    holdTimer = M:After(seconds, fadeOut)
end

function fadeOut()
    banner.fadeOut:Play()
    fadeTimer = M:After(FADE_OUT, showNext)
end

local function playSound(note)
    if not note.sound then return end
    if note.sound == "discover" then
        if run then return end -- the run's first says it for all
        run = true
    end
    M:After(SOUND_AFTER, function() ns.Sound(note.sound) end)
end

-- The next notification waiting, or none (the banner put away).
function showNext()
    stopTimers()
    current = nil
    if busy() then
        banner:Hide()
        return
    end
    local note = tremove(queue, 1)
    if not note then
        run = false
        if not ns.EditMode.IsActive() then banner:Hide() end
        return
    end
    current = note
    draw(note)
    banner.fadeOut:Stop()
    banner:SetAlpha(0)
    banner:Show()
    banner.fadeIn:Play()
    playSound(note)
    hold(FADE_IN + M.db.duration)
end

-- Fighting or talking: the one showing goes back to the front of the line (unless the mouse is on it).
local function pauseNow()
    if not (current and busy()) or banner:IsMouseOver() then return end
    stopTimers()
    tinsert(queue, 1, current)
    current = nil
    banner:Hide()
end

local function resume()
    if not current and not busy() and #queue > 0 then showNext() end
end

local function resumeSoon() M:After(RESUME_AFTER, resume) end

-- A note for a key already waiting is merged into it (an update's reasons) or dropped.
local function notify(note)
    if not banner then build() end
    for _, waiting in ipairs(queue) do
        if waiting.key == note.key then
            if waiting.merge then waiting.merge(waiting, note) end
            return
        end
    end
    queue[#queue + 1] = note
    while #queue > QUEUE_MAX do tremove(queue, 1) end
    if not current then showNext() end
end

---------------------------------------------------------------------------
-- What's worth a notification
---------------------------------------------------------------------------

local function creatureNote(npc)
    metAt[npc] = GetTime()
    local rec = Book.Creature(npc)
    if not rec then return end
    local open = function() ns.ShowCreature(npc) end
    if RARE[rec.classification] and M.db.rares then
        return { key = "new" .. npc, badge = "VignetteKill", title = rec.name, sub = L.BANNER_RARE_ADDED, sound = "discover",
            open = open }
    elseif M.db.creatures then
        return { key = "new" .. npc, icon = BOOK_ICON, title = rec.name, sub = L.BANNER_ADDED, sound = "discover", open = open }
    end
end

local function updateText(reasons)
    local only = next(reasons)
    if next(reasons, only) then return L.BANNER_UP_MANY end
    return UPDATE_TEXT[only]
end

local function mergeUpdate(note, other)
    for reason in pairs(other.reasons) do note.reasons[reason] = true end
    note.sub = updateText(note.reasons)
    if current == note then banner.sub:SetText(note.sub) end
end

-- What was gathered: one notification for each creature.
local function flushUpdates()
    local gathered = held
    held = {}
    for npc, reasons in pairs(gathered) do
        local rec = Book.Creature(npc)
        if rec then
            notify({ key = "up" .. npc, icon = BOOK_ICON, title = rec.name, sub = updateText(reasons), reasons = reasons,
                sound = "discover", merge = mergeUpdate, open = function() ns.ShowCreature(npc) end })
        end
    end
end

local function learned(npc, reason)
    local key = UPDATE_KEY[reason]
    if not (key and M.db.updates and M.db[key]) then return end
    if metAt[npc] and GetTime() - metAt[npc] < FRESH then return end
    held[npc] = held[npc] or {}
    held[npc][key] = true
    if not M:IsPending(gatherTimer) then gatherTimer = M:After(GATHER, flushUpdates) end
end

local QUEST_LOOK = {
    giver = { icon = SCROLL_ICON, badge = "QuestNormal", title = L.BANNER_GIVER },
    ender = { icon = SCROLL_ICON, badge = "QuestTurnin", title = L.BANNER_ENDER },
    item = { icon = NOTE_ICON, badge = "QuestNormal", title = L.BANNER_QUEST_ITEM },
}

local function questNote(questID, role)
    local look = QUEST_LOOK[role]
    if not (M.db.quests and look and Book.Quest(questID)) then return end
    return { key = "quest" .. questID .. role, badge = look.badge, icon = look.icon, title = look.title,
        sub = Book.QuestName(questID), sound = "discover", open = function() ns.ShowQuest(questID) end }
end

local function badgeNote(key, tier)
    local Badges = ns.Badges
    if not (M.db.badges and Badges and Badges.BY_KEY[key]) then return end
    return { key = "badge" .. key, icon = Badges.BY_KEY[key].icon, title = Badges.TierName(key, tier), sub = L.BANNER_BADGE,
        sound = ns.TierSound(tier), open = function() ns.Journal.Open("badges") end }
end

local function trophyNote(npc)
    local rec = Book.Creature(npc)
    if not (M.db.trophies and rec) then return end
    return { key = "trophy" .. npc, icon = TROPHY_ICON, badge = "VignetteKill", title = rec.name, sub = L.BANNER_TROPHY,
        sound = "discover",
        open = function() ns.Journal.Open("trophies") end }
end

local NOTES = { CREATURE_NEW = creatureNote, QUEST_PLACE = questNote, BADGE_EARNED = badgeNote, TROPHY = trophyNote }

M:OnNews(function(_, event, a, b)
    if event == "CREATURE_LEARNED" then return learned(a, b) end
    if event == "LOOT_NEW" then return learned(a, "loot") end
    local make = NOTES[event]
    local note = make and make(a, b)
    if note then notify(note) end
end)

---------------------------------------------------------------------------
-- Waiting while you fight or talk
---------------------------------------------------------------------------

local function windowEvent(_, event)
    local opens = WINDOWS[event]
    if opens then
        windows[opens] = true
        pauseNow()
    else
        windows[CLOSES[event]] = nil
        resumeSoon()
    end
end

function M:OnEnable()
    if not banner then build() end
    ns.EditMode.Register(banner, editInfo)
    self:RegisterEvent("PLAYER_REGEN_DISABLED", pauseNow)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", resumeSoon)
    for event in pairs(WINDOWS) do self:RegisterEvent(event, windowEvent) end
end

function M:OnDisable()
    queue, held, windows, current, run = {}, {}, {}, nil, false
    if banner then
        ns.EditMode.Unregister(banner)
        banner:Hide()
    end
end

function M:OnSettingChanged(key)
    if banner and (key == "scale" or key == "x" or key == "y") then place() end
    if key == "pause" then resume() end
end
