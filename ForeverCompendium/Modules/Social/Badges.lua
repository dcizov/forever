--[[
    Forever Compendium - Badges
    Milestones for what your journal holds: each badge has tiers (I to VIII), earned as a count
    grows (creatures met, kills, loot, abilities, money, rares, elites and bosses killed,
    subzones, zones explored, quests, deaths, vendors). A new tier is announced (the
    Notification Banner shows it) and kept with its date. The journal's Badges page shows them
    all; click a badge there to show it (up to three) on your tooltip, where other Compendium
    players in your group see it, as you see theirs.

    Creatures known only from other players (Sharing) count for none. The counts are made from
    the journal each time it changes (a moment after, once for a burst of changes).
]]

local _, ns = ...
local L = ns.L

local pairs, ipairs, type, format, time, math, unpack, table = pairs, ipairs, type, string.format, time, math, unpack, table
local Book, Transport, Plain = ns.Book, ns.Transport, ns.Plain

local MAX_SHOWN = 3
local SEND_WAIT = 3 -- seconds after a group change before our shown badges go out

local M = ns:NewModule("Badges", {
    title = L.BADGES_TITLE,
    category = "social",
    description = L.BADGES_DESC,
    added = "2.3.0",
    defaults = {
        tooltip = true, announce = true,
        earned = {}, shown = {}, -- data: key -> { tier, at }; the keys shown on your tooltip, in order
    },
    options = {
        { key = "tooltip", type = "checkbox", label = L.BADGES_TOOLTIP, tooltip = L.BADGES_TOOLTIP_TIP },
        { key = "announce", type = "checkbox", label = L.BADGES_ANNOUNCE, tooltip = L.BADGES_ANNOUNCE_TIP },
    },
})

local Badges = { module = M }
local sendTimer -- the pending send of our shown badges after a group change
ns.Badges = Badges

-- Each badge: its key, icon, the count it follows, and the count each tier needs.
Badges.LIST = {
    { key = "creatures", icon = "Interface\\Icons\\INV_Misc_Book_09", tiers = { 10, 25, 50, 100, 250, 500, 1000, 2500 } },
    { key = "kills", icon = "Interface\\Icons\\Ability_DualWield", tiers = { 50, 100, 500, 1000, 2500, 5000, 10000, 50000 } },
    { key = "items", icon = "Interface\\Icons\\INV_Misc_Bag_10", tiers = { 10, 25, 50, 100, 250, 500, 1000, 2000 } },
    { key = "abilities", icon = "Interface\\Icons\\Spell_Holy_MagicalSentry", tiers = { 5, 10, 25, 50, 100, 250, 500, 1000 } },
    { key = "copper", icon = "Interface\\Icons\\INV_Misc_Coin_02", money = true,
      tiers = { 10000, 50000, 100000, 250000, 500000, 1000000, 2500000, 10000000 } },
    { key = "rares", icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01", tiers = { 1, 5, 10, 25, 50, 100, 150, 250 } },
    { key = "elites", icon = "Interface\\Icons\\Ability_Warrior_Rampage", tiers = { 1, 5, 10, 25, 50, 100, 250, 500 } },
    { key = "bosses", icon = "Interface\\Icons\\Achievement_Boss_Ragnaros", tiers = { 1, 5, 10, 25, 50, 75, 100, 150 } },
    { key = "subzones", icon = "Interface\\Icons\\INV_Misc_Map_01", tiers = { 10, 25, 50, 100, 200, 300, 500, 750 } },
    { key = "zones", icon = "Interface\\Icons\\INV_Misc_Map02", tiers = { 3, 5, 10, 15, 20, 25, 30, 40 } },
    { key = "quests", icon = "Interface\\Icons\\INV_Scroll_03", tiers = { 10, 25, 50, 100, 250, 500, 1000, 1500 } },
    { key = "deaths", icon = "Interface\\Icons\\Ability_Rogue_FeignDeath", tiers = { 5, 10, 25, 50, 100, 200, 300, 500 } },
    { key = "vendors", icon = "Interface\\Icons\\INV_Misc_Coin_17", tiers = { 3, 5, 10, 25, 50, 75, 100, 150 } },
}
local BY_KEY = {}
for _, badge in ipairs(Badges.LIST) do BY_KEY[badge.key] = badge end
Badges.BY_KEY = BY_KEY

-- A tier's colour: bronze, silver, gold, then epic purple.
local TIER_COLORS = { { 0.8, 0.5, 0.2 }, { 0.8, 0.5, 0.2 }, { 0.75, 0.78, 0.85 }, { 0.75, 0.78, 0.85 }, { 1, 0.82, 0 },
    { 1, 0.82, 0 }, { 0.64, 0.21, 0.93 }, { 0.64, 0.21, 0.93 } }
local NUMERALS = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII" }

function Badges.TierColor(tier) return unpack(TIER_COLORS[tier] or { 0.5, 0.5, 0.5 }) end
function Badges.Name(key) return L["BADGE_" .. key:upper()] end
function Badges.Describe(key, count) return format(L["BADGE_" .. key:upper() .. "_DESC"], Badges.CountText(key, count)) end
function Badges.TierName(key, tier) return Badges.Name(key) .. (tier and tier > 0 and (" " .. NUMERALS[tier]) or "") end

function Badges.CountText(key, count)
    if BY_KEY[key].money then return C_CurrencyInfo.GetCoinTextureString(count) end
    return BreakUpLargeNumbers(count)
end

---------------------------------------------------------------------------
-- The counts
---------------------------------------------------------------------------

local RARE = { rare = true, rareelite = true }

local function countCreature(stats, sets, rec)
    stats.creatures = stats.creatures + 1
    stats.kills = stats.kills + (rec.kills or 0)
    stats.copper = stats.copper + (rec.money or 0)
    stats.deaths = stats.deaths + (rec.deaths or 0)
    local killed = (rec.kills or 0) > 0
    if killed and RARE[rec.classification] then stats.rares = stats.rares + 1 end
    if killed and (rec.classification == "elite" or rec.classification == "rareelite") then stats.elites = stats.elites + 1 end
    if killed and (rec.classification == "worldboss" or rec.skull) then stats.bosses = stats.bosses + 1 end
    if rec.wares then stats.vendors = stats.vendors + 1 end
    for itemID in pairs(rec.loot or {}) do sets.items[itemID] = true end
    for spellID in pairs(rec.abilities or {}) do sets.abilities[spellID] = true end
    for mapID, zone in pairs(rec.zones or {}) do
        sets.zones[mapID] = (sets.zones[mapID] or 0) + 1
        for sub in pairs(zone.sub or {}) do sets.subzones[sub] = true end
    end
end

-- Every badge's count now: key -> number.
function Badges.Stats()
    local stats = { creatures = 0, kills = 0, copper = 0, deaths = 0, rares = 0, elites = 0, bosses = 0, vendors = 0 }
    local sets = { items = {}, abilities = {}, zones = {}, subzones = {} }
    for _, rec in pairs(Book.Creatures()) do
        if not rec.shared then countCreature(stats, sets, rec) end
    end
    stats.items, stats.abilities, stats.subzones = Book.Count(sets.items), Book.Count(sets.abilities), Book.Count(sets.subzones)
    stats.zones = 0
    for _, n in pairs(sets.zones) do
        if n >= 10 then stats.zones = stats.zones + 1 end
    end
    stats.quests = 0
    for _, q in pairs(Book.Quests()) do
        if q.title then stats.quests = stats.quests + 1 end
    end
    return stats
end

-- The tier a count reaches (0: none yet), and the count the next one needs (nil at the top).
function Badges.TierOf(key, count)
    local tiers = BY_KEY[key].tiers
    local tier = 0
    for i, need in ipairs(tiers) do
        if count >= need then tier = i end
    end
    return tier, tiers[tier + 1]
end

local primed = false -- the first look of a session finds what was earned while off: no news

-- Looks for new tiers: each is kept with its date and announced.
local function check()
    local stats = Badges.Stats()
    for _, badge in ipairs(Badges.LIST) do
        local tier = Badges.TierOf(badge.key, stats[badge.key] or 0)
        local had = M.db.earned[badge.key]
        if tier > (had and had.tier or 0) then
            M.db.earned[badge.key] = { tier = tier, at = time() }
            if M.db.announce and primed then ns:Announce("BADGE_EARNED", badge.key, tier) end
        end
    end
    primed = true
end
Badges.Check = check

---------------------------------------------------------------------------
-- Shown on tooltips
---------------------------------------------------------------------------

local others = {} -- player name -> { { key, tier } }, from their messages this session

function Badges.IsShown(key)
    for _, k in ipairs(M.db.shown) do
        if k == key then return true end
    end
    return false
end

local function mine()
    local list = {}
    for _, key in ipairs(M.db.shown) do
        local earned = M.db.earned[key]
        if earned and BY_KEY[key] then list[#list + 1] = { key, earned.tier } end
    end
    return list
end

local function groupChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

local function sendMine()
    local channel = groupChannel()
    if channel then Transport.Send(M, "badges", { shown = mine() }, channel) end
end

-- Shows or hides a badge on your tooltip (at most three; the oldest goes for a fourth).
function Badges.ToggleShown(key)
    local shown = M.db.shown
    for i, k in ipairs(shown) do
        if k == key then
            table.remove(shown, i)
            M:Soon(sendMine)
            return
        end
    end
    if not M.db.earned[key] then return end
    shown[#shown + 1] = key
    if #shown > MAX_SHOWN then table.remove(shown, 1) end
    M:Soon(sendMine)
end

local function onBadges(sender, data)
    local list = {}
    for _, entry in ipairs(type(data.shown) == "table" and data.shown or {}) do
        if type(entry) == "table" and BY_KEY[entry[1]] and type(entry[2]) == "number" then
            list[#list + 1] = { entry[1], math.max(1, math.min(8, math.floor(entry[2]))) }
        end
        if #list >= MAX_SHOWN then break end
    end
    others[sender] = list
end

local function badgeText(list)
    local parts = {}
    for _, entry in ipairs(list) do
        local r, g, b = Badges.TierColor(entry[2])
        parts[#parts + 1] = "|T" .. BY_KEY[entry[1]].icon .. ":14|t " .. ns.JournalText.Color(r, g, b)
            .. Badges.TierName(entry[1], entry[2]) .. "|r"
    end
    return table.concat(parts, "  ")
end

local function onUnit(_, tooltip, data)
    if not M.db.tooltip then return end
    local guid = Plain(data and data.guid)
    if type(guid) ~= "string" or not guid:find("^Player") then return end
    local list
    if guid == UnitGUID("player") then
        list = mine()
    else
        local _, _, _, _, _, name, realm = GetPlayerInfoByGUID(guid)
        name, realm = ns.Plain(name), ns.Plain(realm)
        name = Plain(name)
        list = name and (others[name] or (realm and realm ~= "" and others[name .. "-" .. realm]))
    end
    if list and #list > 0 then tooltip:AddLine(badgeText(list), 1, 1, 1) end
end

---------------------------------------------------------------------------
-- The module
---------------------------------------------------------------------------

local CHANGES = { CREATURE_NEW = true, LOOT_NEW = true, CREATURE_LEARNED = true, QUEST_PLACE = true, QUEST_TITLE = true,
    BOOK_MERGED = true }

ns:OnNews(M, function(_, event)
    if M.active and CHANGES[event] then M:Soon(check) end
end)

function M:OnEnable()
    Transport.Start(self)
    Transport.Listen(self, "badges", onBadges)
    self:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        if not self:IsPending(sendTimer) then sendTimer = self:After(SEND_WAIT, sendMine) end
    end)
    self:HookCallback(TooltipDataProcessor, "unit", function(hook)
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, hook)
    end, onUnit)
    check()
end

function M:OnDisable() Transport.Stop(self) end

function M:DebugLine()
    return format(L.BADGES_DEBUG, Book.Count(self.db.earned), #self.db.shown, Book.Count(others))
end
