--[[
    Forever Compendium - tests/scenarios/compendium/banner.lua
    The notifications: a new creature (a rare saying so) by default, with the discovery sound;
    what's learned of a known creature gathered into one ("Information updated"), none just after
    it was met; one after another, fading out after their time but kept while the mouse is on
    one; waiting through combat and a merchant's window; quest places only when ticked; a badge
    with its tier's sound; a click opening the journal; Edit Mode moving it; no sound with Sounds
    off; nothing while off.
    Run by tests/run.lua (lua5.1 tests/run.lua banner), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverCompendium")
login()
local Book, L = ns.Book, ns.L
local mod = ns.modules.Banner
local FADE_IN, FADE_OUT = 0.3, 0.8
local life = FADE_IN + mod.db.duration + FADE_OUT + 0.05 -- one notification, start to end

local function isFile(ids, id)
    for _, f in ipairs(ids) do if f == id then return true end end
    return false
end
local function soundsOf(key)
    local n = 0
    for _, s in ipairs(W.sounds) do
        if s.file and isFile(ns.SOUNDS[key].file, s.id) then n = n + 1 end
    end
    return n
end

-- A new creature: by default, with the discovery sound a moment later.
Book.Meet(1, "Plain Wolf").classification = "normal"
local rare = Book.Meet(2, "Old Greyjaw")
rare.classification = "rare"
ns:Announce("CREATURE_NEW", 1)
local banner = ForeverCompendiumBanner
check(banner and banner:IsShown(), "a new creature: a notification")
eq(banner.title._text, "Plain Wolf", "naming it")
eq(banner.sub._text, L.BANNER_ADDED, "added to the journal")
eq(soundsOf("discover"), 0, "the sound waits a moment")
W.Advance(0.5)
eq(soundsOf("discover"), 1, "then the discovery sound")
for _, s in ipairs(W.sounds) do eq(s.channel, "SFX", "on the SFX channel") end

-- More wait their turn, and a run makes one sound.
ns:Announce("CREATURE_NEW", 2)
eq(banner.title._text, "Plain Wolf", "the first stays its time")
W.Advance(life)
eq(banner.title._text, "Old Greyjaw", "then the next")
eq(banner.sub._text, L.BANNER_RARE_ADDED, "a rare says so")
W.Advance(0.5)
eq(soundsOf("discover"), 1, "one sound for a run")
W.Advance(life)
check(not banner:IsShown(), "gone once nothing waits")

-- What's learned of a known creature: none just after it was met; later, gathered into one.
Book.Meet(8, "Hungry Hyena")
ns:Announce("CREATURE_NEW", 8)
ns:Announce("CREATURE_LEARNED", 8, "abilities")
W.Advance(life)
check(not banner:IsShown(), "nothing in the first seconds after it was met (its \"added\" says it)")
ns:Announce("CREATURE_LEARNED", 1, "abilities")
Book.SetItem(769, "Chunk of Boar Meat", 1, 133970)
ns:Announce("LOOT_NEW", 1, 769)
check(not banner:IsShown(), "gathered for a moment")
W.Advance(0.6)
check(banner:IsShown(), "then shown")
eq(banner.title._text, "Plain Wolf", "naming the creature")
eq(banner.sub._text, L.BANNER_UP_MANY, "several things learned: information updated")
W.Advance(life)
ns:Announce("CREATURE_LEARNED", 2, "locations")
W.Advance(0.6)
eq(banner.sub._text, L.BANNER_UP_LOCATIONS, "one thing: says which")
ns:Announce("CREATURE_LEARNED", 2, "looks")
W.Advance(life + 0.6)
check(not banner:IsShown(), "a new look says nothing")
ns:SetOption("Banner", "upLoot", false)
ns:Announce("LOOT_NEW", 2, 769)
W.Advance(0.6)
check(not banner:IsShown(), "loot updates off: nothing")

-- The mouse on it keeps it.
Book.Meet(3, "Young Boar")
ns:Announce("CREATURE_NEW", 3)
function banner:IsMouseOver() return true end
banner:Fire("OnEnter")
W.Advance(life * 3)
check(banner:IsShown(), "kept while the mouse is on it")
banner.IsMouseOver = nil
banner:Fire("OnLeave")
W.Advance(life)
check(not banner:IsShown(), "and goes its time after")

-- Combat and a merchant's window: they wait.
W.combat = true
W.Fire("PLAYER_REGEN_DISABLED")
Book.Meet(4, "Bristleback Quilboar")
ns:Announce("CREATURE_NEW", 4)
check(not banner:IsShown(), "not in combat")
W.combat = false
W.Fire("PLAYER_REGEN_ENABLED")
check(not banner:IsShown(), "a moment after combat")
W.Advance(1.1)
check(banner:IsShown(), "then shown")
eq(banner.title._text, "Bristleback Quilboar", "the one that waited")
W.Fire("MERCHANT_SHOW")
check(not banner:IsShown(), "put away while you talk to a merchant")
W.Fire("MERCHANT_CLOSED")
W.Advance(1.1)
eq(banner.title._text, "Bristleback Quilboar", "and back once done")
W.Advance(life)
ns:SetOption("Banner", "pause", false)
W.combat = true
Book.Meet(5, "Durotar Tiger")
ns:Announce("CREATURE_NEW", 5)
check(banner:IsShown(), "Wait in Combat off: shown in combat")
W.combat = false
W.Advance(life)

-- Quests only when ticked.
Book.QuestRecord(50).title = "Wolf Trouble"
Book.QuestRecord(50).giver = { npc = 1, map = 1, x = 0.5, y = 0.5 }
ns:Announce("QUEST_PLACE", 50, "giver")
check(not banner:IsShown(), "Quest Places off: nothing")
ns:SetOption("Banner", "quests", true)
ns:Announce("QUEST_PLACE", 50, "giver")
eq(banner.title._text, L.BANNER_GIVER, "Quest Places on: a giver found")
eq(banner.sub._text, "Wolf Trouble", "the quest by its title")
eq(banner.icon._texture, "Interface\\Icons\\INV_Scroll_03", "a full icon fills the slot")
check(banner.badge:IsShown() and banner.badge._atlas == "QuestNormal", "the quest's ! as a badge on its corner")

-- A click opens the journal on it, and lets the next one in.
banner:Fire("OnClick", "LeftButton")
check(not banner:IsShown(), "a click puts the notification away")
Book.Meet(6, "Dire Mottled Boar")
ns:Announce("CREATURE_NEW", 6)
banner:Fire("OnClick", "LeftButton")
check(ForeverCompendiumJournal and ForeverCompendiumJournal:IsShown(), "a click opens the journal")
ForeverCompendiumJournal:Hide()

-- A badge: its tier's sound.
W.sounds = {}
ns:Announce("BADGE_EARNED", "creatures", 5)
eq(banner.sub._text, L.BANNER_BADGE, "a badge earned")
check(not banner.badge:IsShown(), "no map mark on a badge's icon")
W.Advance(0.5)
eq(soundsOf("badgeGold"), 1, "tier V: the gold sound")
W.Advance(life)

-- Sounds off: none.
ns:SetOption("Journal", "sounds", false)
W.sounds = {}
Book.Meet(7, "Kul Tiras Sailor")
ns:Announce("CREATURE_NEW", 7)
W.Advance(life)
eq(#W.sounds, 0, "Sounds off: silent")
ns:SetOption("Journal", "sounds", true)

-- Edit Mode: a sample to move; moving it keeps its place.
EditModeManagerFrame:EnterEditMode()
check(banner:IsShown(), "shown in Edit Mode")
eq(banner.sub._text, L.BANNER_SAMPLE, "as a sample")
local selection
for _, f in ipairs(W.frames) do
    if f:GetParent() == banner and rawget(f, "info") then selection = f end
end
selection.info.moveTo(1000, 900)
eq(mod.db.x, 40, "moved: its top centre's offset from the screen's, across")
eq(mod.db.y, -141, "and down")
EditModeManagerFrame:ExitEditMode()
check(not banner:IsShown(), "and hidden after")

-- Off: nothing.
ns:SetEnabled("Banner", false)
ns:Announce("CREATURE_NEW", 2)
check(not banner:IsShown(), "off: no banner")
finish()
