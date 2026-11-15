--[[
    Forever Compendium - Sharing
    Sends what you know of a creature to another Compendium player, and takes what they send:

      * Share: the button over a creature's model in the journal sends it to your target (a
        player). What goes: its name, title, level, kind, where it lives, its loot (with how
        many corpses it was on), what it sells, its abilities and resistances, its looks, and the
        quests it gives or takes in. What doesn't: your kills, deaths, money, reputation, pins
        and notes.
      * Receiving: a box asks whether to take it ("Receive Shares" off: never asked, nothing
        taken). A creature you'd never met comes in marked as shared until you meet it yourself.
      * Group Sync (off unless ticked): while you're in a group, each creature you learn
        something new of goes to the group's other Compendium players with Group Sync on too, a
        few seconds after, and theirs come to you without asking.
    Merging is Book.MergeCreature's (Lib/BookMerge.lua): the same corpses are never
    counted twice, and your own counts never grow. Messages go through Lib/Transport.lua.
]]

local _, ns = ...
local L = ns.L

local pairs, ipairs, type, format = pairs, ipairs, type, string.format
local Book, Transport = ns.Book, ns.Transport

local SYNC_WAIT = 5 -- seconds learned creatures gather before Group Sync sends them

local M = ns:NewModule("Sharing", {
    title = L.SHARING_TITLE,
    category = "social",
    description = L.SHARING_DESC,
    added = "2.3.0",
    defaults = { receive = true, autoSync = false },
    options = {
        { key = "receive", type = "checkbox", label = L.SHARING_RECEIVE, tooltip = L.SHARING_RECEIVE_TIP },
        { key = "autoSync", type = "checkbox", label = L.SHARING_SYNC, tooltip = L.SHARING_SYNC_TIP },
    },
})

---------------------------------------------------------------------------
-- What goes
---------------------------------------------------------------------------

local function copy(value)
    if type(value) ~= "table" then return value end
    local t = {}
    for k, v in pairs(value) do t[k] = copy(v) end
    return t
end

local function questOf(questID)
    local q = Book.Quest(questID)
    if not q then return nil end
    return { title = q.title, level = q.level, cat = q.cat, daily = q.daily, giver = copy(q.giver), ender = copy(q.ender),
        objectives = copy(q.objectives), rewards = copy(q.rewards), choices = copy(q.choices) }
end

local function itemsOf(rec)
    local items = {}
    for _, field in ipairs({ "loot", "wares" }) do
        for itemID in pairs(rec[field] or {}) do
            local item = Book.Item(itemID)
            -- Name, quality and icon (all Book.MergeItem keeps): no link, whose "|" escapes stay off the wire.
            if item then items[itemID] = { name = item.name, quality = item.quality, icon = item.icon } end
        end
    end
    return items
end

-- A creature as it goes out: { npc, rec, quests = { [questID] = quest }, items }.
function M.Pack(npcID)
    local rec = Book.Creature(npcID)
    if not rec then return nil end
    local out = { zones = copy(rec.zones), loot = copy(rec.loot), looted = rec.looted, wares = copy(rec.wares),
        first = rec.first, last = rec.last }
    for _, key in ipairs(Book.SHARED_FIELDS) do out[key] = rec[key] end
    for _, key in ipairs(Book.SHARED_SETS) do out[key] = copy(rec[key]) end
    local quests = {}
    for _, field in ipairs({ "starts", "ends" }) do
        for questID in pairs(rec[field] or {}) do quests[questID] = questOf(questID) end
    end
    return { npc = npcID, rec = out, quests = quests, items = itemsOf(rec) }
end

---------------------------------------------------------------------------
-- Taking it in
---------------------------------------------------------------------------

-- Takes in a packed creature from `sender` (Book.MergeCreature, leaving your own history alone).
-- Returns whether it was new to you.
function M.Merge(sender, pack)
    local npcID = pack.npc
    local rec, isNew = Book.MergeCreature(npcID, pack.rec, false)
    if not rec then return false end
    if isNew then
        rec.shared, rec.sharedBy = true, sender
        rec.first, rec.last = nil, nil
    end
    for itemID, item in pairs(type(pack.items) == "table" and pack.items or {}) do Book.MergeItem(itemID, item) end
    for questID, quest in pairs(type(pack.quests) == "table" and pack.quests or {}) do Book.MergeQuest(questID, quest) end
    Book.Merged(npcID)
    return isNew
end

---------------------------------------------------------------------------
-- Sending and receiving
---------------------------------------------------------------------------

-- Whether the Share button can send now: Sharing on and a player (not you) targeted.
function ns.CanShare()
    return M.active and UnitExists("target") and UnitIsPlayer("target") and not UnitIsUnit("target", "player")
end

function ns.ShareCreature(npcID)
    if not ns.CanShare() then return M:Reply(L.SHARING_NO_TARGET) end
    local pack = M.Pack(npcID)
    local target = GetUnitName("target", true)
    if pack and target then
        Transport.Send(M, "creature", pack, "WHISPER", target)
        M:Reply(format(L.SHARING_SENT, pack.rec.name, target))
    end
end

local function onCreature(sender, data)
    if not M.db.receive then return end
    local name = type(data.rec) == "table" and data.rec.name
    if type(name) ~= "string" then return end
    ns:Confirm(M, "FC_SHARE", format(L.SHARING_ASK, sender, name), function()
        M.Merge(sender, data)
        M:Reply(format(L.SHARING_TAKEN, name, sender))
    end)
end

local function onSync(sender, data)
    if not M.db.autoSync then return end
    for _, pack in ipairs(type(data.list) == "table" and data.list or {}) do
        if type(pack) == "table" then M.Merge(sender, pack) end
    end
end

---------------------------------------------------------------------------
-- Group Sync
---------------------------------------------------------------------------

local waiting = {} -- npcID -> true, learned since the last send

local function groupChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

local function sendWaiting()
    local channel = groupChannel()
    local list = {}
    for npcID in pairs(waiting) do
        local rec = Book.Creature(npcID)
        if rec and not rec.shared then list[#list + 1] = M.Pack(npcID) end
    end
    waiting = {}
    if channel and #list > 0 then Transport.Send(M, "sync", { list = list }, channel) end
end

local LEARNED = { CREATURE_NEW = true, LOOT_NEW = true, CREATURE_LEARNED = true }

M:OnNews(function(_, event, npcID)
    if not (M.db.autoSync and LEARNED[event] and type(npcID) == "number" and groupChannel()) then return end
    local first = next(waiting) == nil
    waiting[npcID] = true
    if first then M:After(SYNC_WAIT, sendWaiting) end
end)

function M:OnEnable()
    Transport.Start(self)
    Transport.Listen(self, "creature", onCreature)
    Transport.Listen(self, "sync", onSync)
end

function M:OnDisable() Transport.Stop(self) end

function M:DebugLine()
    return format(L.SHARING_DEBUG, Transport.Waiting(), Book.Count(waiting))
end
