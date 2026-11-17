--[[
    Forever Codex - Lib/QuestGivers.lua
    Where the quests you can take now start, for Quest Pins' "!" (Modules/Map/QuestPins.lua),
    read from QuestieDB (Shared/Lib/QuestieDB.lua) the way Forever++'s Quest Pins reads it, so the
    two agree on what a player can take: the pins step back while Forever++'s are on.

      * QuestGivers.Build(owner, done): reads every quest QuestieDB knows, a few each frame, into
        what the rules need and the givers on each map (NPCs and objects with their spawns there,
        and what drops an item that starts a quest), then done(). Nothing of QuestieDB's own
        tables is kept.
      * QuestGivers.On(mapID): those givers, { kind, id, map, xs, ys, quests, friendly }.
      * QuestGivers.Category(questID): what kind of quest it is, for a pin's colour and the kinds
        shown: "holiday", "instance", "class", "profession", "repeatable", "war" or "normal".
      * QuestGivers.Check(questID, rules): whether you can take it, and why it's shown: true, or
        true with "upcoming" (a few levels short, shown ahead) or "low" (far under you, shown
        faded); false otherwise. Not done, not in your log, a kind `rules.kinds` shows, not shut
        out by one done, what it needs first done (a breadcrumb, or one no NPC gives, counts as
        done once its own needs are), your race (by its own bit: Forever's two new races 95 and
        96 have bits 33 and 34), class, profession and its rank, and level: `rules.upcoming`
        levels ahead at most, `rules.low` ("hide", "fade" or "off") for one `rules.lowGap` or more
        levels under you, and hidden `rules.highGap` or more levels above. The war effort's
        quests never show (nothing says when it runs).
      * QuestGivers.CanTake(questID): Check with the plain rules (normal, class, profession and
        dungeon quests, nothing ahead of your level).
      * QuestGivers.Level(questID), QuestGivers.RequiredLevel(questID).
    Adapted from Forever++'s Modules/Quests/QuestPins/Index.lua and Rules.lua by xIGBClutchIx
    (MIT License).
]]

local _, ns = ...

local ipairs, pairs, type, floor, min = ipairs, pairs, type, math.floor, math.min
local QuestieDB = ns.QuestieDB

local QuestGivers = {}
ns.QuestGivers = QuestGivers

local PER_FRAME = 60   -- quests read a frame
local DROP_SOURCES = 8 -- NPCs and objects counted at most as where an item that starts a quest drops
local CLASSIC_RACES = 8
-- QuestieDB's race mask: the race ID's own bit for Classic's eight, and bits 33 and 34 for
-- Forever's two new races, 95 (Alliance) and 96 (Horde), as QuestieDB's raceMaskById has them.
local NEW_RACE_BITS = { [95] = 33, [96] = 34 }
-- QuestieDB's quest sorts for holidays and events (a negative zoneOrSort), and the war effort's.
local HOLIDAY = { [404] = true, [402] = true, [378] = true, [376] = true, [375] = true, [374] = true, [370] = true,
    [369] = true, [366] = true, [364] = true, [41] = true, [22] = true, [21] = true }
local WAR_EFFORT = 365
-- The plain rules (CanTake): the kinds Forever++ shows by default, nothing ahead or faded.
local PLAIN = { kinds = { normal = true, class = true, profession = true, instance = true }, upcoming = 0 }

local info, byMap, sources = {}, {}, {}
local ids, position, building
QuestGivers.ready = false

---------------------------------------------------------------------------
-- The index
---------------------------------------------------------------------------

-- A giver's sources, one for each map it spawns on, made when the first quest it starts is read.
local function sourcesOf(kind, id)
    local key = kind .. ":" .. id
    local found = sources[key]
    if found then return found end
    found = {}
    sources[key] = found
    local record = kind == "npc" and QuestieDB.Npc(id) or QuestieDB.Object(id)
    for _, spawn in ipairs(record and record.spawns or {}) do
        local source
        for _, known in ipairs(found) do
            if known.map == spawn.uiMapID then source = known end
        end
        if not source then
            source = { kind = kind, id = id, map = spawn.uiMapID, xs = {}, ys = {}, quests = {}, friendly = record.friendlyTo }
            found[#found + 1] = source
            byMap[spawn.uiMapID] = byMap[spawn.uiMapID] or {}
            local list = byMap[spawn.uiMapID]
            list[#list + 1] = source
        end
        source.xs[#source.xs + 1] = spawn.x
        source.ys[#source.ys + 1] = spawn.y
    end
    return found
end

local function addTo(kind, id, questID)
    for _, source in ipairs(sourcesOf(kind, id)) do source.quests[#source.quests + 1] = questID end
end

local function nonEmpty(list) return list and #list > 0 and list or nil end

local function indexQuest(questID)
    local q = QuestieDB.Quest(questID)
    if not q then return end
    info[questID] = {
        level = q.level, required = q.requiredLevel, max = q.maxLevel, races = q.races, classes = q.classes,
        all = nonEmpty(q.prerequisites.all), any = nonEmpty(q.prerequisites.any), exclusive = nonEmpty(q.exclusiveTo),
        breadcrumbFor = q.breadcrumbFor, npcGiver = #q.starters.npcs > 0,
        sort = q.sortID, repeatable = q.repeatable, raid = q.raid, skill = q.skill,
    }
    for _, npc in ipairs(q.starters.npcs) do addTo("npc", npc, questID) end
    for _, object in ipairs(q.starters.objects) do addTo("object", object, questID) end
    for _, itemID in ipairs(q.starters.items) do
        local item = QuestieDB.Item(itemID)
        local left = DROP_SOURCES
        for _, npc in ipairs(item and item.npcDrops or {}) do
            if left > 0 then addTo("npc", npc, questID) end
            left = left - 1
        end
        for _, object in ipairs(item and item.objectDrops or {}) do
            if left > 0 then addTo("object", object, questID) end
            left = left - 1
        end
    end
end

-- Reads QuestieDB (PER_FRAME quests a frame, never in combat, on `owner`'s timers), then
-- finished(). At once when it's read already; nothing while QuestieDB can't be read.
function QuestGivers.Build(owner, finished)
    if QuestGivers.ready then return finished() end
    if building or QuestieDB.Status() ~= "ready" then return end
    building, ids, position = true, QuestieDB.Ids("Quest"), 1
    local function step()
        if InCombatLockdown() then return owner:After(1, step) end
        local last = min(position + PER_FRAME - 1, #ids)
        for i = position, last do indexQuest(ids[i]) end
        position = last + 1
        if position <= #ids then return owner:After(0, step) end
        ids, building, QuestGivers.ready = nil, nil, true
        finished()
    end
    step()
end

-- The givers on `mapID` (none before Build has read them).
function QuestGivers.On(mapID) return byMap[mapID] or {} end

---------------------------------------------------------------------------
-- The rules
---------------------------------------------------------------------------

local function inMask(mask, id) return floor(mask / 2 ^ (id - 1)) % 2 == 1 end

-- By the race's own bit, never another of its side's; a race the masks have no bit for lets it show.
local function raceInMask(mask, race)
    if race <= CLASSIC_RACES then return inMask(mask, race) end
    local bit = NEW_RACE_BITS[race]
    return not bit or inMask(mask, bit)
end

local function done(id) return C_QuestLog.IsQuestFlaggedCompleted(id) == true end
local function inLog(id) return C_QuestLog.IsOnQuest(id) == true end

function QuestGivers.Category(questID)
    local q = info[questID]
    if not q then return "normal" end
    if q.sort and HOLIDAY[q.sort] then return "holiday" end
    if q.raid then return "instance" end
    if q.classes then return "class" end
    if q.skill then return "profession" end
    if q.sort == WAR_EFFORT then return "war" end
    if q.repeatable then return "repeatable" end
    return "normal"
end

function QuestGivers.Level(questID)
    local q = info[questID]
    return q and (q.level or q.required) or nil
end

function QuestGivers.RequiredLevel(questID)
    local q = info[questID]
    return q and q.required or nil
end

local met

-- One a quest needs first is as good as done once turned in, a breadcrumb (skippable), or one no
-- NPC gives (an object or item starts it: it often never shows as turned in) whose own needs are
-- met and that you aren't in the middle of.
local function satisfied(id, seen)
    if done(id) then return true end
    local q = info[id]
    if not q then return false end
    if q.breadcrumbFor then return true end
    if q.npcGiver or inLog(id) or seen[id] then return false end
    seen[id] = true
    return (q.all or q.any) ~= nil and met(q, seen)
end

met = function(q, seen)
    for _, id in ipairs(q.all or {}) do
        if not satisfied(id, seen) then return false end
    end
    if not q.any then return true end
    for _, id in ipairs(q.any) do
        if satisfied(id, seen) then return true end
    end
    return false
end

-- Whether you have the profession a quest needs, at its rank.
local function skillMet(skill)
    for _, index in pairs({ GetProfessions() }) do
        local _, _, rank, _, _, _, line = GetProfessionInfo(index)
        if line == skill.id then return (rank or 0) >= skill.value end
    end
    return false
end

-- Whether it's yours to take by who you are: race, class, profession.
local function yours(q)
    if q.races then
        local _, _, race = UnitRace("player")
        if race and not raceInMask(q.races, race) then return false end
    end
    if q.classes then
        local _, _, class = UnitClass("player")
        if class and not inMask(q.classes, class) then return false end
    end
    return not q.skill or skillMet(q.skill)
end

-- Whether you can take quest `questID` (see the header).
function QuestGivers.Check(questID, rules)
    local q = info[questID]
    if not q or done(questID) or inLog(questID) then return false end
    if not rules.kinds[QuestGivers.Category(questID)] then return false end
    for _, other in ipairs(q.exclusive or {}) do
        if done(other) then return false end
    end
    if q.breadcrumbFor and (done(q.breadcrumbFor) or inLog(q.breadcrumbFor)) then return false end
    if not met(q, {}) or not yours(q) then return false end
    local player = UnitLevel("player")
    if q.max and player > q.max then return false end
    local upcoming = q.required ~= nil and player < q.required
    if upcoming and q.required - player > (rules.upcoming or 0) then return false end
    local level = QuestGivers.Level(questID)
    local low = level ~= nil and rules.low ~= nil and rules.low ~= "off" and player - level >= rules.lowGap
    if low and rules.low == "hide" then return false end
    if level and rules.highGap and level - player >= rules.highGap then return false end
    return true, upcoming and "upcoming" or low and "low" or nil
end

function QuestGivers.CanTake(questID) return (QuestGivers.Check(questID, PLAIN)) end

-- Whether a giver QuestieDB marks friendly to one side ("A", "H") or both is friendly to yours.
function QuestGivers.Friendly(friendly)
    if type(friendly) ~= "string" then return true end
    local side = UnitFactionGroup("player")
    local letter = side == "Alliance" and "A" or side == "Horde" and "H" or nil
    return letter == nil or friendly:find(letter, 1, true) ~= nil
end
