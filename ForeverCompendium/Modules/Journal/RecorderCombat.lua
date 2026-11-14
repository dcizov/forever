--[[
    Forever Compendium - Modules/Journal/RecorderCombat.lua
    The Recorder's Combat part (Modules/Journal/Recorder.lua registers the events and calls these):
    what fighting a creature teaches.

      * Abilities: a spell a creature you can see casts or channels (your target, focus, mouse
        over or a nameplate): UNIT_SPELLCAST_START, _CHANNEL_START and _SUCCEEDED. Auto attack
        isn't a spell here.
      * Defenses: an attack of yours it resisted or was immune to (UNIT_COMBAT on its unit), by
        the attack's school.
      * Deaths: when you die, each creature that had you targeted counts one of your deaths.
      * Reputation: a reputation message within a second of one kill of yours goes to the
        creature killed (its total, how many kills and the least and most one gave). Within a
        few seconds of a quest turned in it goes to neither (the quest gave it).
    Secret values (restricted unit information) are left out, as everywhere in the Recorder.
]]

local _, ns = ...

local ipairs, tonumber, type, math, GetTime, time = ipairs, tonumber, type, math, GetTime, time
local Book, Plain = ns.Book, ns.Plain

local Combat = {}
ns.RecorderCombat = Combat

local SKIP_SPELLS = { [1] = true, [6603] = true } -- auto attack
local SCHOOLS = { { 1, "Physical" }, { 2, "Holy" }, { 4, "Fire" }, { 8, "Nature" }, { 16, "Frost" },
    { 32, "Shadow" }, { 64, "Arcane" } }
local REP_WINDOW, TURNIN_WINDOW = 1.5, 3

-- The creature a unit is, when it's one the journal knows: npcID, record.
local function creatureOf(unit)
    if not unit or Plain(UnitIsPlayer(unit)) ~= false then return nil end
    local npc = Book.NpcOf(UnitGUID(unit))
    local rec = npc and Book.Creature(npc)
    if rec then return npc, rec end
end

-- Units whose casts are watched: those you can see a creature through.
local function watched(unit)
    return unit == "target" or unit == "focus" or unit == "mouseover" or (unit and unit:find("^nameplate") ~= nil)
end

---------------------------------------------------------------------------
-- Abilities and defenses
---------------------------------------------------------------------------

function Combat.Cast(unit, spellID)
    spellID = Plain(spellID)
    if not (watched(unit) and type(spellID) == "number") or SKIP_SPELLS[spellID] then return end
    local npc, rec = creatureOf(unit)
    if not rec or (rec.abilities and rec.abilities[spellID]) then return end
    if not Plain(C_Spell.GetSpellName(spellID)) then return end
    Book.Mark(rec, "abilities", spellID)
    ns:Announce("CREATURE_LEARNED", npc, "abilities")
end

function Combat.Hit(unit, action, school)
    action, school = Plain(action), tonumber(Plain(school))
    if not (action == "IMMUNE" or action == "RESIST") or not school or school <= 0 or unit == "player" then return end
    local npc, rec = creatureOf(unit)
    if not rec then return end
    local kind = action == "IMMUNE" and "immune" or "resist"
    local learned = false
    for _, bit in ipairs(SCHOOLS) do
        if math.floor(school / bit[1]) % 2 == 1 and (rec.defenses or {})[bit[2]] ~= kind then
            Book.Mark(rec, "defenses", bit[2], kind)
            learned = true
        end
    end
    if learned then ns:Announce("CREATURE_LEARNED", npc, "defenses") end
end

---------------------------------------------------------------------------
-- Deaths
---------------------------------------------------------------------------

local function targetingYou(unit)
    return UnitExists(unit) and Plain(UnitIsUnit(unit .. "target", "player")) == true
end

function Combat.Died()
    local units = { "target", "focus", "mouseover" }
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do units[#units + 1] = plate.namePlateUnitToken end
    local blamed = {}
    for _, unit in ipairs(units) do
        local npc, rec = creatureOf(unit)
        if rec and not blamed[npc] and targetingYou(unit) then
            blamed[npc] = true
            rec.deaths = (rec.deaths or 0) + 1
            ns:Announce("CREATURE_LEARNED", npc, "deaths")
        end
    end
end

---------------------------------------------------------------------------
-- Reputation
---------------------------------------------------------------------------

local patterns -- { { pattern, sign } }, made from the game's own messages when first needed
local lastTurnIn = -100

local function pattern(text)
    local escaped = text:gsub("([%(%)%.%[%]%+%-%*%?%^%$])", "%%%1"):gsub("%%s", "(.-)"):gsub("%%d", "(%%d+)")
    return "^" .. escaped
end

local function repPatterns()
    if not patterns then
        patterns = {}
        if type(FACTION_STANDING_INCREASED) == "string" then patterns[#patterns + 1] = { pattern(FACTION_STANDING_INCREASED), 1 } end
        if type(FACTION_STANDING_DECREASED) == "string" then patterns[#patterns + 1] = { pattern(FACTION_STANDING_DECREASED), -1 } end
    end
    return patterns
end

function Combat.TurnedIn() lastTurnIn = GetTime() end

function Combat.Reputation(mod, text)
    text = Plain(text)
    local kill = mod.lastKill
    if type(text) ~= "string" or not kill or GetTime() - kill.at > REP_WINDOW or GetTime() - lastTurnIn < TURNIN_WINDOW then
        return
    end
    for _, p in ipairs(repPatterns()) do
        local faction, amount = text:match(p[1])
        amount = tonumber(amount)
        if faction and amount then
            local rec = Book.Creature(kill.npc)
            if not rec then return end
            amount = amount * p[2]
            rec.rep = rec.rep or {}
            local r = rec.rep[faction] or { total = 0, count = 0 }
            rec.rep[faction] = r
            r.total, r.count = r.total + amount, r.count + 1
            r.min, r.max = math.min(r.min or amount, amount), math.max(r.max or amount, amount)
            return
        end
    end
end

---------------------------------------------------------------------------
-- Kills
---------------------------------------------------------------------------

-- A kill by you or your group (PARTY_KILL): counted, dated, and kept a moment for what follows it
-- (a quest objective going up, a reputation message).
function Combat.Kill(mod, targetGUID)
    local npc = Book.NpcOf(targetGUID)
    local rec = npc and Book.Creature(npc)
    if not rec then return end
    local now = time()
    rec.kills = (rec.kills or 0) + 1
    local first = rec.firstKill == nil
    rec.firstKill = rec.firstKill or now
    rec.lastKill = now
    mod.lastKill = { npc = npc, at = GetTime() }
    -- A rare's or a boss's first defeat: a trophy (the journal's Trophies page, the banner).
    if first and Book.TrophyKind(rec) then ns:Announce("TROPHY", npc) end
end
