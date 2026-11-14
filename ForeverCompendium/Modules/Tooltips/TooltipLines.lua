--[[
    Forever Compendium - Tooltip Lines
    What the Recorder learned (Modules/Journal/Book.lua), under the game's own tooltips:
      * Creatures: how many you killed and looted.
      * Abilities: on a creature, the spells it was seen casting (the first few, by name).
      * Quests: on a creature, the quests in your log it counts for or takes in, and those it
        offered you that you haven't taken or done.
      * Drops: on an item, the creatures it dropped from and how often (the likeliest few).
    Added through TooltipDataProcessor's post calls (unit and item tooltips), once; they do
    nothing while the module is off. Which creatures drop an item is kept in an index made when
    first asked and made again after the Recorder learns new loot.
]]

local _, ns = ...
local L = ns.L

local pairs, ipairs, format, sort, floor, math, table = pairs, ipairs, string.format, table.sort, math.floor, math, table
local Book, Plain = ns.Book, ns.Plain

local MAX_SOURCES = 3 -- creatures an item's tooltip names, at most
local MAX_ABILITIES = 4 -- spells a creature's tooltip names, at most

local M = ns:NewModule("TooltipLines", {
    title = L.TIPS_TITLE,
    category = "tooltips",
    description = L.TIPS_DESC,
    added = "2.1.0",
    defaults = { creatures = true, abilities = true, quests = true, drops = true },
    options = {
        { key = "creatures", type = "checkbox", label = L.TIPS_CREATURES, tooltip = L.TIPS_CREATURES_TIP },
        { key = "abilities", type = "checkbox", label = L.TIPS_ABILITIES, tooltip = L.TIPS_ABILITIES_TIP, added = "2.4.0" },
        { key = "quests", type = "checkbox", label = L.TIPS_QUESTS, tooltip = L.TIPS_QUESTS_TIP },
        { key = "drops", type = "checkbox", label = L.TIPS_DROPS, tooltip = L.TIPS_DROPS_TIP },
    },
    features = { "creatures", "abilities", "quests", "drops" },
})

local GRAY, GOLD = { 0.7, 0.7, 0.7 }, { 1, 0.82, 0 }

local function add(tooltip, text, color)
    tooltip:AddLine(text, color[1], color[2], color[3])
end

local function title(questID) return Book.QuestName(questID) end

---------------------------------------------------------------------------
-- Creatures
---------------------------------------------------------------------------

local function questLines(tooltip, rec)
    for questID in pairs(rec.quests or {}) do
        if C_QuestLog.IsOnQuest(questID) then add(tooltip, format(L.TIPS_FOR_QUEST, title(questID)), GOLD) end
    end
    for questID in pairs(rec.ends or {}) do
        if C_QuestLog.IsOnQuest(questID) then add(tooltip, format(L.TIPS_TAKES_IN, title(questID)), GOLD) end
    end
    for questID in pairs(rec.starts or {}) do
        if not C_QuestLog.IsOnQuest(questID) and not C_QuestLog.IsQuestFlaggedCompleted(questID) then
            add(tooltip, format(L.TIPS_OFFERS, title(questID)), GOLD)
        end
    end
end

-- "Abilities: [icon] Rabies, [icon] Thrash" (the first few by name, then "+2 more").
local function abilityLine(tooltip, rec)
    local spells = {}
    for spellID in pairs(rec.abilities or {}) do
        local name = C_Spell.GetSpellName(spellID)
        if name then spells[#spells + 1] = { name = name, icon = C_Spell.GetSpellTexture(spellID) } end
    end
    if #spells == 0 then return end
    sort(spells, function(a, b) return a.name < b.name end)
    local parts = {}
    for i = 1, math.min(#spells, MAX_ABILITIES) do
        local spell = spells[i]
        parts[i] = (spell.icon and ("|T" .. spell.icon .. ":0|t ") or "") .. spell.name
    end
    local text = table.concat(parts, ", ")
    if #spells > MAX_ABILITIES then text = text .. " " .. format(L.TIPS_MORE_ABILITIES, #spells - MAX_ABILITIES) end
    add(tooltip, format(L.TIPS_ABILITIES_LINE, text), GRAY)
end

local function onUnit(_, tooltip, data)
    local npc = Book.NpcOf(Plain(data and data.guid))
    local rec = npc and Book.Creature(npc)
    if not rec then return end
    local db = M.db
    if db.creatures and ((rec.kills or 0) > 0 or (rec.looted or 0) > 0) then
        add(tooltip, format(L.TIPS_KILLS, rec.kills or 0, rec.looted or 0), GRAY)
    end
    if db.abilities then abilityLine(tooltip, rec) end
    if db.quests then questLines(tooltip, rec) end
end

---------------------------------------------------------------------------
-- Items
---------------------------------------------------------------------------

local sources -- itemID -> { npcID, ... }, nil until asked (and after new loot)

local function index()
    sources = {}
    for npc, rec in pairs(Book.Creatures()) do
        for itemID in pairs(rec.loot or {}) do
            local list = sources[itemID] or {}
            sources[itemID] = list
            list[#list + 1] = npc
        end
    end
end

local function onItem(_, tooltip, data)
    if not M.db.drops then return end
    local itemID = Plain(data and data.id)
    if not itemID then return end
    if not sources then index() end
    local list = {}
    for _, npc in ipairs(sources[itemID] or {}) do
        local rec = Book.Creature(npc)
        local rate = rec and Book.DropRate(rec, itemID)
        if rate then list[#list + 1] = { name = rec.name, rate = rate } end
    end
    if #list == 0 then return end
    sort(list, function(a, b) return a.rate > b.rate end)
    for i = 1, math.min(MAX_SOURCES, #list) do
        add(tooltip, format(L.TIPS_DROPS_FROM, list[i].name, floor(list[i].rate * 100 + 0.5)), GRAY)
    end
    if #list > MAX_SOURCES then add(tooltip, format(L.TIPS_MORE, #list - MAX_SOURCES), GRAY) end
end

ns:OnNews(M, function(_, event)
    if event == "LOOT_NEW" or event == "BOOK_MERGED" then sources = nil end
end)

function M:OnEnable()
    self:HookCallback(TooltipDataProcessor, "unit", function(hook)
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, hook)
    end, onUnit)
    self:HookCallback(TooltipDataProcessor, "item", function(hook)
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, hook)
    end, onItem)
end
