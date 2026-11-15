--[[
    Forever Tweaks - Lib/Professions.lua
    For Profession Tooltips and Item Tooltips: the player's profession skills by skill line (read
    once, again after they change), the herbs and veins of the world with the skill they take, the
    lockboxes and what Lockpicking opens them, and how hard something is at a skill, in a trainer's
    colors. The herbs and veins are Classic's, in English; what the game says ("Requires Herbalism
    (75)" under a node) is learned over them, so other languages and Forever's changes fill in as
    the player meets them (kept in Profession Tooltips' data: Professions.Attach). Lockboxes come
    from the client's tables (build 1.60.1.70938). Adapted from Forever++'s Lib/Professions.lua,
    Lib/GameData.lua and Lib/LockboxSkills.lua by xIGBClutchIx (MIT License).
]]

local _, ns = ...

local type, ipairs, pairs, select, tonumber, match = type, ipairs, pairs, select, tonumber, string.match
local Plain, Kit = ns.Plain, ns.TooltipKit

local Professions = {
    HERBALISM = 182, MINING = 186, SKINNING = 393, FISHING = 356, LOCKPICKING = 633, BLACKSMITHING = 164,
}
ns.Professions = Professions

local HERB, MINE = Professions.HERBALISM, Professions.MINING
local PICK_LOCK = 1804 -- the spell a rogue picks locks with
local LOCKPICKING_CAP = 300

-- Herbs and veins by their name in the world: { skill line, skill, item ID }.
local SEED = {
    ["Peacebloom"] = { HERB, 1, 2447 },
    ["Silverleaf"] = { HERB, 1, 765 },
    ["Earthroot"] = { HERB, 15, 2449 },
    ["Mageroyal"] = { HERB, 50, 785 },
    ["Briarthorn"] = { HERB, 70, 2450 },
    ["Stranglekelp"] = { HERB, 85, 3820 },
    ["Bruiseweed"] = { HERB, 100, 2453 },
    ["Wild Steelbloom"] = { HERB, 115, 3355 },
    ["Grave Moss"] = { HERB, 120, 3369 },
    ["Kingsblood"] = { HERB, 125, 3356 },
    ["Liferoot"] = { HERB, 150, 3357 },
    ["Fadeleaf"] = { HERB, 160, 3818 },
    ["Goldthorn"] = { HERB, 170, 3821 },
    ["Khadgar's Whisker"] = { HERB, 185, 3358 },
    ["Wintersbite"] = { HERB, 195, 3819 },
    ["Firebloom"] = { HERB, 205, 4625 },
    ["Purple Lotus"] = { HERB, 210, 8831 },
    ["Arthas' Tears"] = { HERB, 220, 8836 },
    ["Sungrass"] = { HERB, 230, 8838 },
    ["Blindweed"] = { HERB, 235, 8839 },
    ["Ghost Mushroom"] = { HERB, 245, 8845 },
    ["Gromsblood"] = { HERB, 250, 8846 },
    ["Golden Sansam"] = { HERB, 260, 13464 },
    ["Dreamfoil"] = { HERB, 270, 13463 },
    ["Mountain Silversage"] = { HERB, 280, 13465 },
    ["Plaguebloom"] = { HERB, 285, 13466 },
    ["Icecap"] = { HERB, 290, 13467 },
    ["Black Lotus"] = { HERB, 300, 13468 },

    ["Copper Vein"] = { MINE, 1, 2770 },
    ["Tin Vein"] = { MINE, 65, 2771 },
    ["Incendicite Mineral Vein"] = { MINE, 65, 3340 },
    ["Silver Vein"] = { MINE, 75, 2775 },
    ["Ooze Covered Silver Vein"] = { MINE, 75, 2775 },
    ["Lesser Bloodstone Deposit"] = { MINE, 75, 4278 },
    ["Iron Deposit"] = { MINE, 125, 2772 },
    ["Ooze Covered Iron Deposit"] = { MINE, 125, 2772 },
    ["Indurium Mineral Vein"] = { MINE, 150, 5833 },
    ["Gold Vein"] = { MINE, 155, 2776 },
    ["Ooze Covered Gold Vein"] = { MINE, 155, 2776 },
    ["Mithril Deposit"] = { MINE, 175, 3858 },
    ["Ooze Covered Mithril Deposit"] = { MINE, 175, 3858 },
    ["Truesilver Deposit"] = { MINE, 230, 7911 },
    ["Ooze Covered Truesilver Deposit"] = { MINE, 230, 7911 },
    ["Dark Iron Deposit"] = { MINE, 230, 11370 },
    ["Small Thorium Vein"] = { MINE, 245, 10620 },
    ["Ooze Covered Thorium Vein"] = { MINE, 245, 10620 },
    ["Rich Thorium Vein"] = { MINE, 275, 10620 },
    ["Ooze Covered Rich Thorium Vein"] = { MINE, 275, 10620 },
    ["Hakkari Thorium Vein"] = { MINE, 275, 10620 },
    ["Small Obsidian Chunk"] = { MINE, 305, 22202 },
    ["Large Obsidian Chunk"] = { MINE, 305, 22203 },
}

-- The stone a vein gives besides its ore: item ID -> the Mining of the lowest vein giving it.
local STONES = {
    [2835] = 1, -- Rough Stone
    [2836] = 65, -- Coarse Stone
    [2838] = 125, -- Heavy Stone
    [7912] = 175, -- Solid Stone
    [12365] = 245, -- Dense Stone
}

-- Lockboxes: item ID -> the Lockpicking to open them.
Professions.LOCKBOXES = {
    [4632] = 1, -- Ornate Bronze Lockbox
    [4633] = 25, -- Heavy Bronze Lockbox
    [4634] = 70, -- Iron Lockbox
    [4636] = 125, -- Strong Iron Lockbox
    [4637] = 175, -- Steel Lockbox
    [4638] = 225, -- Reinforced Steel Lockbox
    [5046] = 70, -- Locked Gift
    [5758] = 225, -- Mithril Lockbox
    [5759] = 225, -- Thorium Lockbox
    [5760] = 225, -- Eternium Lockbox
    [6354] = 1, -- Small Locked Chest
    [6355] = 70, -- Sturdy Locked Chest
    [6712] = 1, -- Practice Lock
    [7209] = 1, -- Tazan's Satchel
    [7869] = 70, -- Lucius's Lockbox
    [12033] = 275, -- Thaurissan Family Jewels
    [13875] = 175, -- Ironbound Locked Chest
    [13918] = 250, -- Reinforced Locked Chest
    [16882] = 1, -- Battered Junkbox
    [16883] = 70, -- Worn Junkbox
    [16884] = 175, -- Sturdy Junkbox
    [16885] = 250, -- Heavy Junkbox
    [24282] = 5000, -- Rogue's Diary
    [208838] = 1, -- Dark Iron Lockbox
    [227937] = 175, -- Puzzle Box
}

local learned = { nodes = {}, lockboxes = {} } -- what the game taught (Profession Tooltips' data)

-- Learned nodes and lockboxes are kept in `data` ({ nodes, lockboxes }), the module's own.
function Professions.Attach(data)
    data.nodes, data.lockboxes = data.nodes or {}, data.lockboxes or {}
    learned = data
end

local itemSkills -- item ID -> { skill line, skill }, made when first asked

local function node(name) return learned.nodes[name] or SEED[name] end

-- The herb or vein named `name` (as the world writes it): { skill line, skill, item ID }, or nil.
-- A name that's a kind of a known one ("Poor Copper Vein") takes what it lacks from that one.
function Professions.Node(name)
    if type(name) ~= "string" then return nil end
    local found = node(name)
    if found and found[1] and found[2] then return found end
    local best, length = nil, 0
    for known, entry in pairs(SEED) do
        if #known > length and #known < #name
            and (name:sub(-#known - 1) == " " .. known or name:sub(1, #known + 1) == known .. " ") then
            best, length = entry, #known
        end
    end
    if not best then return found end
    if not found then return best end
    return { found[1] or best[1], found[2] or best[2], found[3] or best[3] }
end

-- The gathering skill an item comes from: its skill line and the skill of the lowest herb or vein
-- giving it, or nil.
function Professions.ItemSkill(itemID)
    if not itemSkills then
        itemSkills = {}
        for _, list in ipairs({ SEED, learned.nodes }) do
            for _, entry in pairs(list) do
                local line, skill, item = entry[1], entry[2], entry[3]
                local known = item and itemSkills[item]
                if line and skill and item and not (known and known[2] <= skill) then itemSkills[item] = { line, skill } end
            end
        end
        for item, skill in pairs(STONES) do itemSkills[item] = itemSkills[item] or { MINE, skill } end
    end
    local entry = itemSkills[itemID]
    if entry then return entry[1], entry[2] end
end

-- The Lockpicking a lockbox needs (learned over the client's), or nil.
function Professions.Lockbox(itemID) return learned.lockboxes[itemID] or Professions.LOCKBOXES[itemID] end

function Professions.LearnLockbox(itemID, need)
    if Professions.Lockbox(itemID) ~= need then learned.lockboxes[itemID] = need end
end

---------------------------------------------------------------------------
-- The player's skills
---------------------------------------------------------------------------

local known -- skill line -> { rank, name }, read when first asked and after skills change

local function read()
    known = {}
    for i = 1, 5 do -- two professions, archaeology, fishing, cooking; any may be nil
        local index = select(i, GetProfessions())
        if index then
            local name, _, level, _, _, _, line, modifier = GetProfessionInfo(index)
            line, level = Plain(line), Plain(level)
            if line and type(level) == "number" then
                known[line] = { rank = level + (Plain(modifier) or 0), name = Plain(name) }
            end
        end
    end
end

-- Forgets the skills read (the owning module calls it on SKILL_LINES_CHANGED and CHAT_MSG_SKILL).
function Professions.Forget() known = nil end

-- A rogue's Lockpicking: five times the level, up to 300, once Pick Lock is known.
local function lockpicking()
    if not C_SpellBook.IsSpellKnown(PICK_LOCK) then return nil end
    local level = Plain(UnitLevel("player"))
    if type(level) ~= "number" then return nil end
    return math.min(level * 5, LOCKPICKING_CAP), C_Spell.GetSpellName(PICK_LOCK)
end

-- The player's skill in a profession (gear included) and its name, or nil without it.
function Professions.Rank(line)
    if line == Professions.LOCKPICKING then return lockpicking() end
    if not known then read() end
    local info = known[line]
    if info then return info.rank, info.name end
end

local ENGLISH = { [HERB] = "Herbalism", [MINE] = "Mining" }

-- The gathering skill line (Herbalism or Mining) named `skill`, or nil.
local function gatheringLine(skill)
    for line, english in pairs(ENGLISH) do
        if skill == english or skill == select(2, Professions.Rank(line)) then return line end
    end
end

-- Learns what Blizzard's "Requires Herbalism (75)" under node `name` says.
function Professions.LearnRequirement(name, skill, need)
    local line = type(name) == "string" and name ~= "" and type(need) == "number" and gatheringLine(skill)
    if not line then return end
    local entry = node(name)
    if entry and entry[1] == line and entry[2] == need then return end
    learned.nodes[name] = { line, need, entry and entry[3] }
    itemSkills = nil
end

---------------------------------------------------------------------------
-- How hard it is, and Blizzard's requirement lines
---------------------------------------------------------------------------

local COLORS = QuestDifficultyColors
local RED, ORANGE, GREEN, GRAY = COLORS.impossible, COLORS.verydifficult, COLORS.standard, COLORS.trivial
-- Yellow is the classic (1, 1, 0): this client's "difficult" is close to a tooltip title's gold.
local YELLOW = { r = 1, g = 1, b = 0 }

-- How hard something needing `need` is at skill `rank`: red can't yet, then orange (a skill-up
-- every time), yellow (often), green (sometimes) and gray (never). Red without the profession.
function Professions.Difficulty(rank, need)
    if not rank or rank < need then return RED
    elseif rank < need + 25 then return ORANGE
    elseif rank < need + 50 then return YELLOW
    elseif rank < need + 100 then return GREEN end
    return GRAY
end

-- The Skinning a creature of `level` needs.
function Professions.SkinningNeed(level)
    if level <= 10 then return 1 elseif level <= 20 then return level * 10 - 100 end
    return level * 5
end

local requires -- the pattern for Blizzard's "Requires %s (%d)" (ITEM_MIN_SKILL)

-- The skill and rank in a requirement line ("Requires Lockpicking (25)"), or nil. `text` plain.
function Professions.Requires(text)
    if type(text) ~= "string" then return nil end
    requires = requires or ("^%s*" .. Kit.FormatPattern(ITEM_MIN_SKILL, true) .. "%s*$")
    local skill, rank = match(text, requires)
    rank = tonumber(rank)
    if skill and rank then return skill, rank end
end

-- The first requirement line in tooltip data after the title: its skill, rank and index, or nil.
function Professions.TooltipRequires(data)
    local lines = data and Plain(data.lines)
    if type(lines) ~= "table" then return nil end
    for i = 2, #lines do
        local text = lines[i] and Plain(lines[i].leftText)
        if type(text) == "string" then
            local skill, rank = Professions.Requires(Kit.StripCodes(text))
            if skill then return skill, rank, i end
        end
    end
end
