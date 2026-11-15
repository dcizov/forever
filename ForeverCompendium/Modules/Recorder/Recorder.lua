--[[
    Forever Compendium - Recorder
    Learns as you play: every creature you meet, what its corpses held, how it fights, what it
    sells, and where your quests are given, turned in and done. Everything else in the addon reads
    what it learned (Lib/Book.lua). Its parts, each its own checkbox:

      * Creatures: a creature you target, mouse over or see a nameplate of is met: its name and
        title, level range, kind and how it stands toward you, its look (RecorderNpcs.lua), and
        where you were (Places: at most once every PLACE_EVERY seconds for each creature; in an
        instance without a map, the instance's name). A kill by you or your group (PARTY_KILL)
        counts for it.
      * Loot: Modules/Recorder/RecorderLoot.lua (items, money, quest drops).
      * Combat: Modules/Recorder/RecorderCombat.lua (abilities, resistances, your deaths,
        reputation).
      * Vendors: Modules/Recorder/RecorderNpcs.lua (what vendors sell).
      * Quests: Modules/Recorder/RecorderQuests.lua (givers, turn-ins, objectives, rewards).
    Players, pets and guardians aren't creatures here. A secret value (Midnight's restricted
    unit information, in some instances) is never kept: what it would have said is left out.
    It says nothing in chat; news (a new creature, new loot, a quest's place, something learned
    about a creature) goes out with ns:Announce for the journal, pins, badges and notifications.
]]

local _, ns = ...
local L = ns.L

local pairs, math, time, format, GetTime = pairs, math, time, string.format, GetTime
local Book, Places, Plain = ns.Book, ns.Places, ns.Plain
local Loot = assert(ns.RecorderLoot, "Recorder.lua loads after RecorderLoot.lua")
local Quests = assert(ns.RecorderQuests, "Recorder.lua loads after RecorderQuests.lua")
local Combat = assert(ns.RecorderCombat, "Recorder.lua loads after RecorderCombat.lua")
local Npcs = assert(ns.RecorderNpcs, "Recorder.lua loads after RecorderNpcs.lua")

local PLACE_EVERY = 5 -- seconds between places counted for one creature

local M = ns:NewModule("Recorder", {
    title = L.RECORDER_TITLE,
    category = "recorder",
    description = L.RECORDER_DESC,
    added = "0.2.0",
    defaults = {
        learnCreatures = true, learnLoot = true, learnCombat = true, learnVendors = true, learnQuests = true,
        creatures = {}, quests = {}, items = {}, -- data: what was learned (Book.lua)
    },
    options = {
        { key = "learnCreatures", type = "checkbox", label = L.RECORDER_CREATURES, tooltip = L.RECORDER_CREATURES_TIP },
        { key = "learnLoot", type = "checkbox", label = L.RECORDER_LOOT, tooltip = L.RECORDER_LOOT_TIP },
        { key = "learnCombat", type = "checkbox", label = L.RECORDER_COMBAT, tooltip = L.RECORDER_COMBAT_TIP, added = "2.3.0" },
        { key = "learnVendors", type = "checkbox", label = L.RECORDER_VENDORS, tooltip = L.RECORDER_VENDORS_TIP, added = "2.3.0" },
        { key = "learnQuests", type = "checkbox", label = L.RECORDER_QUESTS, tooltip = L.RECORDER_QUESTS_TIP },
    },
    features = { "learnCreatures", "learnLoot", "learnCombat", "learnVendors", "learnQuests" },
})

---------------------------------------------------------------------------
-- Creatures
---------------------------------------------------------------------------

local placedAt = {} -- npcID -> GetTime() its place was last counted

-- Counts where the creature is. Returns whether that's a place it wasn't known in (a map, an
-- area on it, an instance).
local function placeSeen(npc, rec)
    local now = GetTime()
    if placedAt[npc] and now - placedAt[npc] < PLACE_EVERY then return false end
    placedAt[npc] = now
    local map, x, y = Places.Here()
    if map then
        local newMap = rec.zones[map] == nil
        local zone = Places.Add(rec.zones, map, x, y)
        local sub = Plain(GetSubZoneText())
        local newSub = false
        if sub and sub ~= "" then
            zone.sub = zone.sub or {}
            newSub = not zone.sub[sub]
            zone.sub[sub] = true
        end
        return newMap or newSub
    end
    local name, kind = GetInstanceInfo()
    name, kind = Plain(name), Plain(kind)
    if not (name and kind and kind ~= "none") then return false end
    local newInstance = not (rec.instances and rec.instances[name])
    Book.Mark(rec, "instances", name, kind)
    return newInstance
end

local function see(unit)
    if not UnitExists(unit) or Plain(UnitIsPlayer(unit)) ~= false or Plain(UnitPlayerControlled(unit)) ~= false then
        return
    end
    local npc = Book.NpcOf(UnitGUID(unit))
    local name = Plain(UnitName(unit))
    if not (npc and name) then return end
    local rec, isNew = Book.Meet(npc, name)
    rec.name, rec.last, rec.shared = name, time(), nil
    local level = Plain(UnitLevel(unit))
    if level and level > 0 then
        rec.minLevel = math.min(rec.minLevel or level, level)
        rec.maxLevel = math.max(rec.maxLevel or level, level)
    elseif level == -1 then
        rec.skull = true
    end
    rec.classification = Plain(UnitClassification(unit)) or rec.classification
    rec.creatureType = Plain(UnitCreatureType(unit)) or rec.creatureType
    rec.family = Plain(UnitCreatureFamily(unit)) or rec.family
    rec.reaction = Plain(UnitReaction(unit, "player")) or rec.reaction
    local newPlace = placeSeen(npc, rec)
    Npcs.RecordTitle(unit, rec)
    Npcs.RecordLook(M, unit, npc, rec)
    if isNew then
        M:Debug("met", name)
        ns:Announce("CREATURE_NEW", npc)
    elseif newPlace then
        ns:Announce("CREATURE_LEARNED", npc, "locations")
    end
end

---------------------------------------------------------------------------
-- Turning the parts on and off
---------------------------------------------------------------------------

local function listen(mod, on, events)
    for event, fn in pairs(events) do
        if on then mod:RegisterEvent(event, fn) else mod:UnregisterEvent(event) end
    end
end

local CREATURE_EVENTS = {
    PLAYER_TARGET_CHANGED = function() see("target") end,
    UPDATE_MOUSEOVER_UNIT = function() see("mouseover") end,
    NAME_PLATE_UNIT_ADDED = function(_, _, unit) see(unit) end,
    PARTY_KILL = function(self, _, _, targetGUID) Combat.OnPartyKill(self, targetGUID) end,
}
local LOOT_EVENTS = { LOOT_OPENED = function(self) Loot.Opened(self) end }
local function cast(_, _, unit, _, spellID) Combat.Cast(unit, spellID) end
local COMBAT_EVENTS = {
    UNIT_SPELLCAST_START = cast,
    UNIT_SPELLCAST_CHANNEL_START = cast,
    UNIT_SPELLCAST_SUCCEEDED = cast,
    UNIT_COMBAT = function(_, _, unit, action, _, _, school) Combat.Hit(unit, action, school) end,
    PLAYER_DEAD = function() Combat.Died() end,
    CHAT_MSG_COMBAT_FACTION_CHANGE = function(self, _, text) Combat.Reputation(self, text) end,
}
local VENDOR_EVENTS = { MERCHANT_SHOW = function() Npcs.RecordWares() end }
local QUEST_EVENTS = {
    QUEST_DETAIL = function() Quests.Detail() end,
    QUEST_PROGRESS = function() Quests.RecordEnder() end,
    QUEST_COMPLETE = function() Quests.RecordEnder() end,
    GOSSIP_SHOW = function() Quests.Gossip() end,
    QUEST_GREETING = function() Quests.Greeting() end,
    QUEST_ACCEPTED = function(_, _, questID) Quests.Accepted(questID) end,
    QUEST_TURNED_IN = function() Combat.NoteTurnIn() end,
    QUEST_LOG_UPDATE = function(self) self:Soon(Quests.LogChanged) end,
}

local function applyLearning(mod)
    local db = mod.db
    listen(mod, db.learnCreatures, CREATURE_EVENTS)
    listen(mod, db.learnLoot, LOOT_EVENTS)
    listen(mod, db.learnCombat, COMBAT_EVENTS)
    listen(mod, db.learnVendors, VENDOR_EVENTS)
    listen(mod, db.learnQuests, QUEST_EVENTS)
    if not db.learnQuests then Quests.Reset() end
end

function M:OnInitialize() Book.Attach(self.db) end

function M:OnEnable()
    applyLearning(self)
    -- Titles of quests known only by number arrive whatever the parts (asked by the journal).
    self:RegisterEvent("QUEST_DATA_LOAD_RESULT", function(_, _, questID, success) Quests.Loaded(questID, success) end)
end

function M:OnDisable() Quests.Reset() end
function M:OnSettingChanged() applyLearning(self) end

function M:DebugLine()
    return format(L.RECORDER_DEBUG, Book.Count(Book.Creatures()), Book.Count(Book.Quests()), Book.Count(Book.Items()))
end
