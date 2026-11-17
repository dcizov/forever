--[[
    Forever Codex - Recorder
    Learns as you play: every creature you meet, what its corpses held, how it fights, what it
    sells, and where your quests are given, turned in and done. Everything else in the addon reads
    what it learned (Lib/Book.lua). Its parts, each its own checkbox:

      * Creatures: a creature you could fight (UnitCanAttack) that you target, mouse over or see
        a nameplate of is met: its name and title, level range, kind and how it stands toward
        you, its look (RecorderNpcs.lua), and where you were (Places: at most once every
        PLACE_EVERY seconds for each creature; in an instance without a map, the instance's
        name). A kill by you or your group (PARTY_KILL) counts for it. A friendly NPC is met only
        when you deal with it (INTERACTIONS: its gossip, quests, wares, training, flights or
        bank), and is an NPC from then on (Book.Interacted). Never met: what you can neither
        fight nor deal with (scenery, escorts, other players' mounts), vehicles, critters, battle
        pets, totems, anything a player owns (pets, guardians, minions: UnitIsOtherPlayersPet, or
        an owner line in its tooltip, RecorderNpcs.IsOwned), and anything seen from a flight path.
        Looting a corpse meets its creature too (RecorderLoot.lua).
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

local pairs, ipairs, type, math, time, format, GetTime = pairs, ipairs, type, math, time, string.format, GetTime
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

-- Creature kinds never met: critters, battle pets and totems (L: the game's names for them).
local NOT_MET = { [L.CFILTER_CRITTER_TYPE] = true, [L.RECORDER_PET_TYPE] = true, [L.RECORDER_WILD_PET_TYPE] = true,
    [L.RECORDER_TOTEM_TYPE] = true }

-- Meets the creature `unit` is (see the header); `service` when you're dealing with it.
local function see(unit, service)
    if not UnitExists(unit) or Plain(UnitIsPlayer(unit)) ~= false or Plain(UnitPlayerControlled(unit)) ~= false
        or Plain(UnitIsOtherPlayersPet(unit)) ~= false or Npcs.IsOwned(unit) then
        return
    end
    local guid = Plain(UnitGUID(unit))
    if type(guid) ~= "string" or not guid:find("^Creature%-") then return end -- vehicles and objects
    local npc = Book.NpcOf(guid)
    local name = Plain(UnitName(unit))
    if not (npc and name) then return end
    local creatureType = Plain(UnitCreatureType(unit))
    local hostile = Plain(UnitCanAttack("player", unit)) == true
    if not (service or Book.Creature(npc)) then
        if not hostile or NOT_MET[creatureType] or Plain(UnitOnTaxi("player")) then return end
    end
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
    rec.creatureType = creatureType or rec.creatureType
    rec.family = Plain(UnitCreatureFamily(unit)) or rec.family
    rec.reaction = Plain(UnitReaction(unit, "player")) or rec.reaction
    local newService = service and Book.Interacted(rec, service, hostile)
    local newPlace = placeSeen(npc, rec)
    Npcs.RecordTitle(unit, rec)
    Npcs.RecordLook(M, unit, npc, rec)
    if isNew then
        M:Debug("met", name)
        ns:Announce("CREATURE_NEW", npc)
        Loot.Met(M, npc)
    elseif newPlace then
        ns:Announce("CREATURE_LEARNED", npc, "locations")
    elseif newService then
        ns:Announce("CREATURE_LEARNED", npc, "services")
    end
end

---------------------------------------------------------------------------
-- Turning the parts on and off
---------------------------------------------------------------------------

local CREATURE_EVENTS = {
    PLAYER_TARGET_CHANGED = function() see("target") end,
    UPDATE_MOUSEOVER_UNIT = function() see("mouseover") end,
    NAME_PLATE_UNIT_ADDED = function(_, _, unit) see(unit) end,
    PARTY_KILL = function(self, _, _, targetGUID) Combat.OnPartyKill(self, targetGUID) end,
}
-- The windows that mean you're dealing with an NPC, and what for (Creatures meets it first, so
-- the other parts find its record).
local INTERACTIONS = {
    GOSSIP_SHOW = "gossip", QUEST_GREETING = "quest", QUEST_DETAIL = "quest", QUEST_PROGRESS = "quest",
    QUEST_COMPLETE = "quest", MERCHANT_SHOW = "vendor", TRAINER_SHOW = "trainer", TAXIMAP_OPENED = "flight",
    BANKFRAME_OPENED = "bank",
}
for event, service in pairs(INTERACTIONS) do
    CREATURE_EVENTS[event] = function() see(UnitExists("questnpc") and "questnpc" or "npc", service) end
end
local LOOT_EVENTS = {
    LOOT_READY = function(self) Loot.Ready(self, see) end,
    LOOT_OPENED = function(self, _, _, isFromItem) Loot.Opened(self, see, isFromItem) end,
    LOOT_CLOSED = function() Loot.Closed() end,
    UNIT_SPELLCAST_SUCCEEDED = function(_, _, unit, _, spellID) Loot.Cast(unit, spellID) end,
}
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
-- Each part's events, in the order their handlers run when parts share one (Creatures first).
local PARTS = {
    { "learnCreatures", CREATURE_EVENTS }, { "learnLoot", LOOT_EVENTS }, { "learnCombat", COMBAT_EVENTS },
    { "learnVendors", VENDOR_EVENTS }, { "learnQuests", QUEST_EVENTS },
}

-- Registers each event of the parts that are on (several parts' handlers in turn on one
-- event), and unregisters the rest.
local function applyLearning(mod)
    local db = mod.db
    local handlers, all = {}, {}
    for _, part in ipairs(PARTS) do
        for event, fn in pairs(part[2]) do
            all[event] = true
            if db[part[1]] then
                handlers[event] = handlers[event] or {}
                handlers[event][#handlers[event] + 1] = fn
            end
        end
    end
    for event in pairs(all) do
        local list = handlers[event]
        if not list then
            mod:UnregisterEvent(event)
        elseif #list == 1 then
            mod:RegisterEvent(event, list[1])
        else
            mod:RegisterEvent(event, function(...) for _, fn in ipairs(list) do fn(...) end end)
        end
    end
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
