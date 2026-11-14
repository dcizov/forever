--[[
    Forever Compendium - tests/scenarios/compendium/banner.lua
    The Notification Banner: a rare creature's banner by default (a plain creature's only when
    asked), new drops and quest places when ticked, one after another for a few seconds each,
    a click opening the journal on the creature, Edit Mode moving it (showing a sample), and
    nothing while off.
    Run by tests/run.lua (lua5.1 tests/run.lua banner), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverCompendium")
login()
local Book, L = ns.Book, ns.L
local mod = ns.modules.Banner

Book.Meet(1, "Plain Wolf").classification = "normal"
local rare = Book.Meet(2, "Old Greyjaw")
rare.classification = "rare"

ns:Announce("CREATURE_NEW", 1)
local banner = ForeverCompendiumBanner
check(banner == nil or not banner:IsShown(), "a plain creature: no banner by default")
ns:Announce("CREATURE_NEW", 2)
banner = ForeverCompendiumBanner
check(banner and banner:IsShown(), "a rare: a banner")
eq(banner.title._text, L.BANNER_RARE, "saying so")
eq(banner.sub._text, "Old Greyjaw", "and naming it")

-- More at once wait their turn.
ns:SetOption("Banner", "creatures", true)
ns:SetOption("Banner", "drops", true)
Book.SetItem(769, "Chunk of Boar Meat", 1, 133970)
Book.Meet(3, "Young Boar")
ns:Announce("CREATURE_NEW", 3)
ns:Announce("LOOT_NEW", 3, 769)
eq(banner.sub._text, "Old Greyjaw", "the first stays its time")
W.Advance(mod.db.duration + 0.1)
eq(banner.title._text, L.BANNER_CREATURE, "then the next")
W.Advance(mod.db.duration + 0.1)
eq(banner.sub._text, string.format(L.BANNER_DROP_FROM, "Chunk of Boar Meat", "Young Boar"), "then the drop")
W.Advance(mod.db.duration + 0.1)
check(not banner:IsShown(), "gone once nothing waits")

-- Quests only when ticked.
Book.QuestRecord(50).title = "Wolf Trouble"
Book.QuestRecord(50).giver = { npc = 1, map = 1, x = 0.5, y = 0.5 }
ns:Announce("QUEST_PLACE", 50, "giver")
check(not banner:IsShown(), "Quest Places off: nothing")
ns:SetOption("Banner", "quests", true)
ns:Announce("QUEST_PLACE", 50, "giver")
eq(banner.title._text, L.BANNER_GIVER, "Quest Places on: a giver found")

-- A click opens the journal on the creature, and lets the next one in.
banner:Fire("OnClick", "LeftButton")
check(ForeverCompendiumJournal and ForeverCompendiumJournal:IsShown(), "a click opens the journal")
check(not banner:IsShown(), "and puts the banner away")

-- Edit Mode: a sample to move; moving it keeps its place.
EditModeManagerFrame:EnterEditMode()
check(banner:IsShown(), "shown in Edit Mode")
eq(banner.title._text, L.BANNER_RARE, "as a sample")
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
