--[[
    Forever Gearbox - Lib/QuestLog.lua
    Quest Log
    Which quest a bag item is for, as plain functions any module can ask (Quest Items shows it;
    Full Bags keeps needed items and deletes leftovers first). Three kinds:

      * needed:   a quest in your log asks for it, finished or not (collected items are handed in
                  at turn-in). Any item, food and cloth too. Found two ways:
                    - by name: an item objective of the quest names it ("Murloc Eye: 2/3");
                    - by ID, from QuestieDB (Shared/Lib/QuestieDB.lua; the modules asking need it): the
                      quest's item objectives, the item it hands you to deliver (sourceItemId: a
                      letter or package, which has no objective of its own) and the items it needs
                      that aren't objectives (requiredSourceItems).
      * starts:   it begins a quest (the bag's quest info has its questID).
      * leftover: of the Quest class, not needed, it begins no quest and has no Use: spell (an
                  item a quest gives you to use somewhere has one, so it's never called a leftover).

    It reads the quest log when first asked and keeps it until Invalidate(); a module using it
    calls QuestLog.Listen from OnEnable, which clears it on the quest events while the module is on.
    The log is read with ns.EachLogQuest (Shared/Core/Core.lua), every quest whatever its header shows.

    Matching objectives by item name is LootTriage's way (Krelock). LootTriage also ships a list of
    what quests not picked up yet ask for; it's GPL licensed data, so it isn't used here.
]]

local _, ns = ...

local ipairs, pairs, type, concat, sort = ipairs, pairs, type, table.concat, table.sort
local C_Container, C_Item, C_QuestLog = C_Container, C_Item, C_QuestLog

local QUEST_CLASS = Enum.ItemClass.Questitem

local QuestLog = {}
ns.QuestLog = QuestLog

local needed -- { names = { [item name] = true }, ids = { [item ID] = true } }, read when first asked

-- "Murloc Eye: 2/3" or "2/3 Murloc Eye" -> the item's name.
local function objectiveItem(text)
    return text:match("^(.-):%s*%d+%s*/%s*%d+%s*$") or text:match("^%s*%d+%s*/%s*%d+%s+(.-)%s*$") or text
end

function QuestLog.Invalidate() needed = nil end

-- The items the quests in the log need: { names = { [name] = true }, ids = { [itemID] = true } }.
function QuestLog.Needed()
    if needed then return needed end
    needed = { names = {}, ids = {} }
    ns.EachLogQuest(function(questID)
        for _, o in ipairs(C_QuestLog.GetQuestObjectives(questID) or {}) do
            if o.type == "item" and type(ns.Plain(o.text)) == "string" then
                needed.names[objectiveItem(o.text)] = true
            end
        end
        ns.QuestieDB.QuestItems(nil, questID, needed.ids)
    end)
    return needed
end

-- An item's kind: "needed", "starts", "leftover", or nil. `starts` is whether it begins a quest;
-- `item` its link or ID, for its ID and Use: spell.
function QuestLog.Kind(name, classID, starts, item)
    local log = QuestLog.Needed()
    local itemID = item and C_Item.GetItemInfoInstant(item)
    if (name and log.names[name]) or (itemID and log.ids[itemID]) then return "needed" end
    if starts then return "starts" end
    if classID == QUEST_CLASS and item and not C_Item.GetItemSpell(item) then return "leftover" end
    return nil
end

-- The kind of the item in a bag slot (as Kind), or nil for an empty slot or one not loaded yet.
function QuestLog.ForBagSlot(bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info then return nil end
    local name, _, _, _, _, _, _, _, _, _, _, classID = C_Item.GetItemInfo(info.hyperlink)
    if not name then return nil end
    local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
    return QuestLog.Kind(name, classID, quest and quest.questID ~= nil, info.hyperlink)
end

-- What the log asks for, as one string: equal strings mean nothing a module shows changed
-- (QUEST_LOG_UPDATE comes often, mostly with nothing new for items).
function QuestLog.Signature()
    local log, parts = QuestLog.Needed(), {}
    for name in pairs(log.names) do parts[#parts + 1] = name end
    for id in pairs(log.ids) do parts[#parts + 1] = "#" .. id end
    sort(parts)
    return concat(parts, "\n")
end

-- The quest events that may change what the log asks for.
local EVENTS = { "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN" }

-- For a module using the log: onChange(module, event, ...) after a quest event, with the cache
-- already cleared, while the module is on. Call it from OnEnable: it clears the cache then too,
-- since the log may have changed while no module was listening.
function QuestLog.Listen(mod, onChange)
    QuestLog.Invalidate()
    -- QuestieDB loads on demand: once it has, what it knows of the log's quests counts too.
    ns.QuestieDB.OnReady(mod, function()
        QuestLog.Invalidate()
        onChange(mod, "QUESTIEDB_READY")
    end)
    for _, event in ipairs(EVENTS) do
        mod:RegisterEvent(event, function(self, ...)
            QuestLog.Invalidate()
            return onChange(self, ...)
        end)
    end
end
