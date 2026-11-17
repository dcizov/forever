--[[
    Forever Codex - Modules/Journal/JournalText.lua
    What the journal says about creatures, quests and items, and in which colour: levels (coloured
    against yours, as Blizzard colours them), kinds, how a creature stands toward you, dates,
    money, places, quest states and what a creature does for a quest. The journal's pages, the
    tooltips and the pins all use these, so a thing reads the same everywhere.
]]

local _, ns = ...
local L = ns.L

local pairs, ipairs, format, date, table, tostring, type = pairs, ipairs, string.format, date, table, tostring, type
local Book = ns.Book

local Text = {}
ns.JournalText = Text

Text.GOLD = "|cffffd100"
Text.GRAY = "|cff9d9d9d"
Text.WHITE = "|cffffffff"
Text.GREEN = "|cff40c040"
Text.RED = "|cffff4040"

-- How a creature stands toward you (UnitReaction), in the colours of its nameplate.
local HOSTILE, NEUTRAL, FRIENDLY = { L.JOURNAL_HOSTILE, 1, 0.25, 0.25 }, { L.JOURNAL_NEUTRAL, 1, 1, 0 },
    { L.JOURNAL_FRIENDLY, 0.25, 1, 0.25 }
local REACTION = { HOSTILE, HOSTILE, HOSTILE, NEUTRAL, FRIENDLY, FRIENDLY, FRIENDLY, FRIENDLY }
local CLASSIFICATION = { elite = L.JOURNAL_ELITE, rare = L.JOURNAL_RARE, rareelite = L.JOURNAL_RARE_ELITE,
    worldboss = L.JOURNAL_BOSS }

-- What a creature does for a quest (Book's roles): its words, and a word (the tag at a quest
-- line's right). A role is words, never an icon: the one icon on a quest line is its state.
Text.ROLES = {
    starts = { label = L.JOURNAL_ROLE_STARTS, short = L.JOURNAL_ROLE_STARTS_SHORT },
    ends = { label = L.JOURNAL_ROLE_ENDS, short = L.JOURNAL_ROLE_ENDS_SHORT },
    item = { label = L.JOURNAL_ROLE_ITEM, short = L.JOURNAL_ROLE_ITEM_SHORT },
    slay = { label = L.JOURNAL_ROLE_SLAY, short = L.JOURNAL_ROLE_SLAY_SHORT },
    loot = { label = L.JOURNAL_ROLE_LOOT, short = L.JOURNAL_ROLE_LOOT_SHORT },
    speak = { label = L.JOURNAL_ROLE_SPEAK, short = L.JOURNAL_ROLE_SPEAK_SHORT },
    [true] = { label = L.JOURNAL_ROLE_FOR, short = L.JOURNAL_ROLE_FOR_SHORT },
}
Text.ROLE_ORDER = { "starts", "ends", "item", "slay", "loot", "speak", true }

-- Spell schools (RecorderCombat's defenses), each with its icon.
Text.SCHOOLS = {
    { "Physical", "Interface\\Icons\\Ability_MeleeDamage" }, { "Holy", "Interface\\Icons\\Spell_Holy_HolyBolt" },
    { "Fire", "Interface\\Icons\\Spell_Fire_FlameBolt" }, { "Nature", "Interface\\Icons\\Spell_Nature_Lightning" },
    { "Frost", "Interface\\Icons\\Spell_Frost_FrostBolt02" }, { "Shadow", "Interface\\Icons\\Spell_Shadow_ShadowBolt" },
    { "Arcane", "Interface\\Icons\\Spell_Nature_StarFall" },
}

function Text.Icon(path, size)
    return "|T" .. path .. ":" .. (size or 14) .. "|t"
end

function Text.Color(r, g, b)
    return format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
end

function Text.ReactionColor(reaction)
    local r = REACTION[reaction or 0]
    if not r then return 1, 1, 1 end
    return r[2], r[3], r[4]
end

-- How it stands toward you, as a word.
function Text.Reaction(reaction)
    local r = REACTION[reaction or 0]
    return r and r[1] or L.JOURNAL_UNKNOWN
end

-- The level's colour against yours, the way Blizzard colours them: red far above, orange
-- above, yellow near, green below, grey far below.
function Text.LevelColor(level)
    if not level then return 1, 0.1, 0.1 end
    local diff = level - (UnitLevel("player") or level)
    if diff >= 5 then return 1, 0.1, 0.1 end
    if diff >= 3 then return 1, 0.5, 0.25 end
    if diff >= -2 then return 1, 0.82, 0 end
    if diff >= -8 then return 0.25, 0.75, 0.25 end
    return 0.5, 0.5, 0.5
end

-- "12", "12-14" or "??".
function Text.LevelShort(rec)
    if not rec.minLevel then return "??" end
    if rec.minLevel == rec.maxLevel then return tostring(rec.minLevel) end
    return rec.minLevel .. "-" .. rec.maxLevel
end

function Text.LevelText(rec)
    if not rec.minLevel then return L.JOURNAL_LEVEL_UNKNOWN end
    if rec.minLevel == rec.maxLevel then return format(L.JOURNAL_LEVEL, rec.minLevel) end
    return format(L.JOURNAL_LEVEL_RANGE, rec.minLevel, rec.maxLevel)
end

function Text.Classification(rec)
    return CLASSIFICATION[rec.classification]
end

-- "12-14 (Rare Elite)", "?? (Boss)": its level with its rank.
function Text.LevelTagged(rec)
    local tag = CLASSIFICATION[rec.classification] or (rec.skull and L.JOURNAL_BOSS)
    return Text.LevelShort(rec) .. (tag and (" (" .. tag .. ")") or "")
end

-- "Level 12-14 Elite Beast (Boar)".
function Text.Kind(rec)
    local kind = { Text.LevelText(rec) }
    if CLASSIFICATION[rec.classification] then kind[#kind + 1] = CLASSIFICATION[rec.classification] end
    if rec.creatureType then kind[#kind + 1] = rec.creatureType end
    if rec.family then kind[#kind + 1] = "(" .. rec.family .. ")" end
    return table.concat(kind, " ")
end

function Text.Date(t) return t and date(L.JOURNAL_DATE_FORMAT, t) or L.JOURNAL_NEVER end


-- A map's name, by ID.
function Text.MapName(mapID)
    local info = C_Map.GetMapInfo(mapID)
    return info and info.name or tostring(mapID)
end

-- The zone (or dungeon) map `mapID` is in: itself for one, its zone for a city district or cave
-- (micro and orphan maps), nil for a continent or the world (Enum.UIMapType: 3 zone, 4
-- dungeon, 5 micro, 6 orphan; 0-2 cosmic, world, continent).
function Text.ZoneOf(mapID)
    local info = C_Map.GetMapInfo(mapID)
    while info and (info.mapType or 3) > 4 and info.parentMapID and info.parentMapID > 0 do
        info = C_Map.GetMapInfo(info.parentMapID)
    end
    if info and (info.mapType or 3) >= 3 then return info.mapID or mapID end
end

-- The places a creature was seen, by zone and name: { { mapID, name, subs = { sorted subzones },
-- seen = how often, dungeon = true for an instance's own map } }. Sightings on a continent or
-- world map count only when it has no zone.
function Text.Places(rec)
    local byZone, list = {}, {}
    for mapID, zone in pairs(rec.zones or {}) do
        local zoneID = Text.ZoneOf(mapID)
        if zoneID then
            local place = byZone[zoneID]
            if not place then
                local info = C_Map.GetMapInfo(zoneID)
                place = { mapID = zoneID, name = Text.MapName(zoneID), subs = {}, seen = 0, subSet = {},
                    dungeon = info ~= nil and info.mapType == 4 }
                byZone[zoneID] = place
                list[#list + 1] = place
            end
            for _, n in pairs(zone.cells or {}) do place.seen = place.seen + n end
            for sub in pairs(zone.sub or {}) do place.subSet[sub] = true end
        end
    end
    for _, place in ipairs(list) do
        for sub in pairs(place.subSet) do place.subs[#place.subs + 1] = sub end
        table.sort(place.subs)
        place.subSet = nil
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- One line of where a creature lives: "Durotar: Valley of Trials" (the first place, for lists).
function Text.Where(rec)
    local places = Text.Places(rec)
    local first = places[1]
    if first then return first.subs[1] or first.name end
    local instance = next(rec.instances or {})
    return instance or ""
end

---------------------------------------------------------------------------
-- Quests
---------------------------------------------------------------------------

-- A quest's state for you: "done", "ready", "log" (in your log), "locked" (one it needs isn't
-- done: QuestIndex knows, from QuestieDB) or "open" (yours to take).
function Text.QuestState(questID)
    if C_QuestLog.IsQuestFlaggedCompleted(questID) then return "done" end
    if C_QuestLog.IsOnQuest(questID) then
        return C_QuestLog.ReadyForTurnIn(questID) and "ready" or "log"
    end
    if ns.QuestIndex.IsLocked(questID) then return "locked" end
    return "open"
end

local STATE_COLOR = { done = Text.GRAY, ready = Text.GREEN, log = Text.WHITE, open = Text.GOLD, locked = Text.GRAY }
local STATE_LABEL = { done = L.JOURNAL_STATE_DONE, ready = L.JOURNAL_STATE_READY, log = L.JOURNAL_STATE_LOG,
    open = L.JOURNAL_STATE_OPEN, locked = L.JOURNAL_STATE_LOCKED }

function Text.QuestStateLabel(state) return STATE_LABEL[state] end

-- Each state's one icon (a file, or "atlas:Name"), in the order the legend shows them.
Text.STATE_ICONS = {
    open = "atlas:QuestNormal", log = "Interface\\GossipFrame\\IncompleteQuestIcon", ready = "atlas:QuestTurnin",
    done = "Interface\\RaidFrame\\ReadyCheck-Ready", locked = "atlas:communities-icon-lock",
}
Text.STATE_ORDER = { "open", "log", "ready", "done", "locked" }

-- A state's icon inline in text (|T or |A), `size` across.
function Text.StateIcon(state, size)
    local icon = Text.STATE_ICONS[state]
    size = size or 14
    if icon:find("^atlas:") then return format("|A:%s:%d:%d|a", icon:sub(7), size, size) end
    return Text.Icon(icon, size)
end

-- "[12] Title" in the colour of its state (the icon is the line's own: JournalKit's Lines:Quest).
function Text.QuestTitleLine(questID)
    local state = Text.QuestState(questID)
    local q = Book.Quest(questID) or {}
    local level = q.level or ns.QuestIndex.Level(questID)
    return STATE_COLOR[state] .. (level and format("[%d] ", level) or "") .. Book.QuestName(questID) .. "|r"
end

-- A quest's kind: "Elite", "Dungeon", "Daily, Elite", or nil.
function Text.QuestKind(q)
    local kinds = {}
    if q.cat then kinds[#kinds + 1] = L["JOURNAL_CAT_" .. q.cat:upper()] end
    if q.daily then kinds[#kinds + 1] = L.JOURNAL_CAT_DAILY end
    return #kinds > 0 and table.concat(kinds, ", ") or nil
end

-- The quests a creature has something to do with: { { questID, roles = { role, ... } } }, by title.
function Text.CreatureQuests(rec)
    local byQuest = {}
    local function addRoles(set, fixed)
        for questID, role in pairs(set or {}) do
            local entry = byQuest[questID] or { questID = questID, roles = {} }
            byQuest[questID] = entry
            entry.roles[#entry.roles + 1] = fixed or role
        end
    end
    addRoles(rec.starts, "starts")
    addRoles(rec.ends, "ends")
    addRoles(rec.quests)
    local list = {}
    for _, entry in pairs(byQuest) do list[#list + 1] = entry end
    table.sort(list, function(a, b) return Book.QuestName(a.questID) < Book.QuestName(b.questID) end)
    return list
end

-- A quest's roles as words, in their order ("Gives, a middle dot, Takes in").
function Text.RoleTags(roles)
    local seen, out = {}, {}
    for _, role in pairs(roles) do seen[role] = true end
    for _, role in ipairs(Text.ROLE_ORDER) do
        if seen[role] then out[#out + 1] = Text.ROLES[role].short end
    end
    return table.concat(out, " \194\183 ")
end

---------------------------------------------------------------------------
-- Items
---------------------------------------------------------------------------

function Text.ItemName(itemID)
    local item = Book.Item(itemID)
    return item and item.name or C_Item.GetItemNameByID(itemID) or format(L.JOURNAL_ITEM_ID, itemID)
end

function Text.ItemColor(itemID)
    local item = Book.Item(itemID)
    local quality = item and item.quality or C_Item.GetItemQualityByID(itemID) or 1
    local r, g, b = C_Item.GetItemQualityColor(quality)
    return r, g, b
end

function Text.ItemIcon(itemID)
    local item = Book.Item(itemID)
    return item and item.icon or C_Item.GetItemIconByID(itemID)
end

function Text.Percent(rate)
    if not rate then return "" end
    local pct = rate * 100
    if pct > 0 and pct < 1 then return format("%.1f%%", pct) end
    return format("%d%%", math.floor(pct + 0.5))
end

-- Whether `value` holds `query` (lower case), for searches.
function Text.Has(value, query)
    return type(value) == "string" and value:lower():find(query, 1, true) ~= nil
end
