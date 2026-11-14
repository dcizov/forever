--[[
    Forever Compendium - tests/scenarios/compendium/social.lua
    Sharing and Badges. The wire format reads back what it wrote and refuses anything else; a
    shared creature goes out in pieces, is asked about, and comes in marked as shared without
    your own counts growing; Receive Shares off takes nothing; Group Sync sends what you learn
    to the group. Badges earn tiers from the journal's counts (shared creatures don't count),
    announce a new tier, show up to three on your tooltip, and show other players' sent ones.
    Run by tests/run.lua (lua5.1 tests/run.lua social), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverCompendium")
login()
local Book, Transport, Badges = ns.Book, ns.Transport, ns.Badges
local sharing = ns.modules.Sharing
local news = {}
ns:OnNews({ name = "Test" }, function(_, event, ...) news[#news + 1] = { event, ... } end)

-- The wire format.
local data = { kind = "x", n = 3.5, s = "a:b{c}", t = { [1] = true, [2] = false }, nested = { deep = { "y" } } }
local back = Transport.Decode(Transport.Encode(data))
eq(back and back.s, "a:b{c}", "a string with the format's own marks")
eq(back and back.n, 3.5, "a number")
eq(back and back.t[2], false, "false")
eq(back and back.nested.deep[1], "y", "nested tables")
eq(Transport.Decode("{s3:abc"), nil, "a cut-off message is refused")
eq(Transport.Decode("return os.exit()"), nil, "code is never run")

-- What a player sends arrives as addon messages; this one hears them back in.
local function deliver(sender)
    for _, m in ipairs(W.addonMessages) do W.Fire("CHAT_MSG_ADDON", m.prefix, m.text, m.channel, sender) end
    W.addonMessages = {}
end

-- Sharing a creature with a target.
local boar = Book.Meet(3100, "Mottled Boar")
boar.minLevel, boar.maxLevel, boar.kills, boar.looted, boar.loot = 3, 5, 9, 4, { [769] = 3 }
boar.zones = { [1411] = { cells = { [10] = 2 }, sub = { ["Valley of Trials"] = true } } }
boar.deaths, boar.note = 2, "mine"
for i = 1, 60 do boar.loot[10000 + i] = 1 end -- long enough for several pieces
W.unitInfo.target = { guid = "Player-1-0001", name = "Thrall", player = true }
ns.ShareCreature(3100)
W.Advance(5)
check(#W.addonMessages > 1, "sent in several pieces")
eq(W.addonMessages[1].channel, "WHISPER", "to the target")
local sent = W.addonMessages

-- The other side: a fresh journal hears it (Book swapped for an empty one).
local mine = Book.Creatures()
local theirs = { creatures = {}, quests = {}, items = {} }
Book.Attach(theirs)
deliver("Thrall")
eq(#W.popups, 1, "asked whether to take it")
W.Accept()
local rec = Book.Creature(3100)
eq(rec and rec.name, "Mottled Boar", "taken in")
eq(rec.shared, true, "marked as shared")
eq(rec.sharedBy, "Thrall", "by whom")
eq(rec.kills, 0, "their kills aren't yours")
eq(rec.deaths, nil, "nor their deaths")
eq(rec.note, nil, "nor their note")
eq(rec.looted, 4, "their corpses, for the drop rates")
check(rec.zones[1411] and rec.zones[1411].sub["Valley of Trials"], "where it lives")
eq(news[#news][1], "BOOK_MERGED", "news of it")

-- Receive Shares off: never asked, nothing taken.
Book.Attach({ creatures = {}, quests = {}, items = {} })
ns:SetOption("Sharing", "receive", false)
W.addonMessages = sent
local popups = #W.popups
deliver("Thrall")
eq(#W.popups, popups, "not asked")
eq(Book.Creature(3100), nil, "nothing taken")
ns:SetOption("Sharing", "receive", true)

-- Group Sync: what you learn goes to the group a few seconds after.
Book.Attach({ creatures = mine, quests = {}, items = {} })
ns:SetOption("Sharing", "autoSync", true)
W.group = "party"
W.addonMessages = {}
ns:Announce("LOOT_NEW", 3100, 769)
W.Advance(10)
check(#W.addonMessages > 0 and W.addonMessages[1].channel == "PARTY", "sent to the party")
W.group = nil

-- Badges: tiers from the counts.
Book.Attach({ creatures = {}, quests = {}, items = {} })
for i = 1, 12 do
    local c = Book.Meet(5000 + i, "Creature " .. i)
    c.kills = 5
end
Book.Meet(6000, "Shared One").shared = true
Badges.Check()
local stats = Badges.Stats()
eq(stats.creatures, 12, "shared creatures don't count")
eq(stats.kills, 60, "kills add up")
eq(Badges.module.db.earned.creatures.tier, 1, "tier I of creatures met")
eq(Badges.module.db.earned.kills.tier, 1, "tier I of kills")
eq(Badges.TierOf("kills", 100), 2, "100 kills is tier II")
local c = Book.Meet(7000, "Big One")
c.kills = 50
Badges.Check()
eq(Badges.module.db.earned.kills.tier, 2, "a new tier")
local last = news[#news]
eq(last[1] == "BADGE_EARNED" and last[2], "kills", "announced")

-- Shown on tooltips: yours, up to three, and another player's sent badges.
Badges.ToggleShown("kills")
Badges.ToggleShown("creatures")
check(Badges.IsShown("kills") and Badges.IsShown("creatures"), "two shown")
Badges.ToggleShown("deaths")
check(not Badges.IsShown("deaths"), "a badge not earned can't be shown")
W.group = "party"
W.addonMessages = {}
-- Badges' message queued, then Sharing (the first to start Transport) turned off before it goes
-- out: it still goes.
W.Fire("GROUP_ROSTER_UPDATE")
W.Advance(5)
eq(#W.addonMessages, 0, "queued, not sent yet")
ns:SetEnabled("Sharing", false)
W.Advance(1)
check(#W.addonMessages > 0, "shown badges sent to the group, with Sharing turned off meanwhile")
ns:SetEnabled("Sharing", true)
deliver("Thrall")
W.playersByGUID["Player-1-0001"] = "Thrall"
local added = W.UnitTooltip("Player-1-0001", "target")
local line = added[#added]
check(line and line.text:find(ns.L.BADGE_KILLS, 1, true), "another player's badges on their tooltip")
eq(ns.modules.Badges:DebugLine() ~= nil, true, "a debug line")
local data = { shown = {} }
Transport.Send(ns.modules.Badges, "badges", data, "PARTY")
eq(data.kind, nil, "sending leaves the caller's table as it was")
finish()
