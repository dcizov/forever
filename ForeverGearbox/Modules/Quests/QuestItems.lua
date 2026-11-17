--[[
    Forever Gearbox - Quest Items
    Which quest a bag item is for. Baganator's "Quest" category and Blizzard's quest border only
    say an item is of the Quest class, not whether a quest still needs it, and many are left over
    from quests long turned in. This tells three kinds apart:

      * needed:   a quest in your log needs it: an objective names it ("Murloc Eye: 2/3"), or
                  QuestieDB lists it for the quest (its item objectives, the item the quest hands
                  you, the items it takes), finished or not (collected items are handed in at
                  turn-in). Any item, food and cloth too.
      * starts:   it begins a quest (the bag's quest info has its questID).
      * leftover: of the Quest class, no objective in your log names it, it begins no quest and
                  has no Use: spell (an item a quest gives you to use somewhere has one, so it's
                  never called a leftover).

    What each item is comes from ns.QuestLog (Lib/QuestLog.lua), which Full Bags asks
    too. This module shows it as a quest "!" on bag items, gray on leftovers, in Blizzard's bags and
    Baganator's. Needed items and quest starters get no tooltip line: Questie names the quest an
    item is for and Plumber marks quest starters. Questie says nothing on a leftover (it only
    knows quests in your log, and has no setting for done ones), so a leftover's tooltip says what
    it is: the quest it was for and whether you turned that in, when QuestieDB knows it (an item's
    relatedQuests, which Forever's data fills for some items only), and what to do with it.
    It needs QuestieDB, as Forever++'s Quest Pins does (Shared/Lib/QuestieDB.lua): without it the module
    is red and locked off on Forever++'s page.

    Matching objectives by item name is LootTriage's way (Krelock). LootTriage also ships a list of
    what quests not picked up yet ask for; it's GPL licensed data, so it isn't used here.
]]

local _, ns = ...
local L = ns.L
local QuestLog = assert(ns.QuestLog, "QuestItems.lua loads after QuestLog.lua")

local pairs, ipairs, type, format, select = pairs, ipairs, type, string.format, select
local C_Item = C_Item

local MAX_TOOLTIP_QUESTS = 3

---------------------------------------------------------------------------
-- The module
---------------------------------------------------------------------------

local BagButtons = assert(ns.BagButtons, "QuestItems.lua loads after UI/BagButtons.lua")

local M = ns:NewModule("QuestItems", {
    title = L.QUESTITEMS_TITLE,
    category = "quests",
    group = L.GROUP_QUEST_ITEMS,
    description = L.QUESTITEMS_DESC,
    added = "1.4.0",
    defaults = {
        markNeeded = true,
        markStarts = true,
        markLeftover = true,
        tooltip = true,
    },
    options = {
        { key = "markNeeded", type = "checkbox", label = L.QUESTITEMS_MARK_NEEDED, tooltip = L.QUESTITEMS_MARK_NEEDED_TIP },
        { key = "markStarts", type = "checkbox", label = L.QUESTITEMS_MARK_STARTS, tooltip = L.QUESTITEMS_MARK_STARTS_TIP,
          added = "1.5.0" },
        { key = "markLeftover", type = "checkbox", label = L.QUESTITEMS_MARK_LEFTOVER,
          tooltip = L.QUESTITEMS_MARK_LEFTOVER_TIP },
        { key = "tooltip", type = "checkbox", label = L.QUESTITEMS_TOOLTIP, tooltip = L.QUESTITEMS_TOOLTIP_TIP,
          added = "1.8.1" },
    },
    features = { "markNeeded", "markStarts", "markLeftover", "tooltip" },
    notice = {
        {
            text = L.QUESTITEMS_BAGANATOR,
            addon = "Baganator", advice = L.QUESTITEMS_ADVICE_BAGANATOR,
            shown = function(db)
                return (db.markNeeded or db.markStarts or db.markLeftover)
                    and BagButtons.WidgetPlaced({ "ForeverTweaks_QuestNeeded", "ForeverTweaks_QuestLeftover" }) == false
            end,
        },
    },
})

ns.QuestieDB.Require(M)

-- Marks in the bags ----------------------------------------------------------------------------

local markOf = {} -- Blizzard bag item button -> its "!"

local function newMark(owner, button)
    local mark = owner:CreateTexture(nil, "OVERLAY", nil, 7)
    mark:SetAtlas("QuestNormal")
    mark:SetSize(16, 16)
    mark:SetPoint("TOPRIGHT", button, "TOPRIGHT", 2, 2)
    return mark
end

-- Whether a kind of item gets a mark: needed ones with Mark Needed, quest starters with Mark Quest
-- Starters, leftovers with Mark Leftovers.
local function markWanted(kind)
    if kind == "needed" then return M.db.markNeeded end
    if kind == "starts" then return M.db.markStarts end
    return kind == "leftover" and M.db.markLeftover
end

-- Colours `mark` for a kind: yellow for needed and quest starters, gray for leftovers.
local function styleMark(mark, kind)
    mark:SetDesaturated(kind == "leftover")
    mark:SetAlpha(kind == "leftover" and 0.7 or 1)
end

local function paintButton(button, bag, slot)
    local mark = markOf[button]
    local wanted = M.active and (M.db.markNeeded or M.db.markStarts or M.db.markLeftover)
    local kind = wanted and QuestLog.ForBagSlot(bag, slot) or nil
    if not mark then
        if not kind then return end
        mark = newMark(button, button)
        markOf[button] = mark
    end
    if kind then styleMark(mark, kind) end
    mark:SetShown(M.active and kind ~= nil and markWanted(kind) and true or false)
end

local function paintBags() BagButtons.PaintBlizzard(paintButton) end

-- Baganator: one widget for needed items, one for leftovers, so each can be placed on its own.
local widgetButton = setmetatable({}, { __mode = "k" }) -- widget -> its item button

local function buttonKind(frame, details)
    local button = widgetButton[frame]
    if button and button.GetBagID then return QuestLog.ForBagSlot(button:GetBagID(), button:GetID()) end
    local link = type(details) == "table" and details.itemLink
    if not link then return nil end
    local name, _, _, _, _, _, _, _, _, _, _, classID = C_Item.GetItemInfo(link)
    return name and QuestLog.Kind(name, classID, false, link) or nil
end

local function widgetInit(button)
    local mark = newMark(button, button)
    widgetButton[mark] = button
    return mark
end

local function registerWidgets()
    BagButtons.RegisterWidget(M, { label = L.QUESTITEMS_WIDGET_NEEDED, id = "ForeverTweaks_QuestNeeded",
        onUpdate = function(frame, details)
            local kind = buttonKind(frame, details)
            if not ((kind == "needed" or kind == "starts") and markWanted(kind)) then return false end
            styleMark(frame, kind)
            return true
        end,
        onInit = widgetInit, position = { corner = "top_right", priority = 1 } })
    BagButtons.RegisterWidget(M, { label = L.QUESTITEMS_WIDGET_LEFTOVER, id = "ForeverTweaks_QuestLeftover",
        onUpdate = function(frame, details)
            if not (markWanted("leftover") and buttonKind(frame, details) == "leftover") then return false end
            styleMark(frame, "leftover")
            return true
        end,
        onInit = widgetInit, position = { corner = "top_right", priority = 2 } })
end

-- The leftover's tooltip ----------------------------------------------------------------------

-- Whether Blizzard's tooltip says the item begins a quest (an item ID alone can't tell).
local function startsQuest(lines)
    for _, line in ipairs(lines or {}) do
        local text = line.leftText
        if ns.Plain(text) == ITEM_STARTS_QUEST then return true end
    end
    return false
end

-- The item's kind: from its bag slot when the tooltip is a bag item's, else from the item.
local function tooltipKind(tooltip, data)
    local info = tooltip:GetPrimaryTooltipInfo()
    if info and info.getterName == "GetBagItem" and info.getterArgs then
        return QuestLog.ForBagSlot(info.getterArgs[1], info.getterArgs[2])
    end
    local name, _, _, _, _, _, _, _, _, _, _, classID = C_Item.GetItemInfo(data.id)
    return name and QuestLog.Kind(name, classID, startsQuest(data.lines), data.id) or nil
end

local function addTooltipLines(mod, tooltip, data)
    if not mod.db.tooltip or not ns.Plain(data.id) then return end
    if tooltipKind(tooltip, data) ~= "leftover" then return end
    tooltip:AddLine(L.QUESTITEMS_TOOLTIP_LEFTOVER, 0.6, 0.6, 0.6)
    local open = false
    for _, quest in ipairs(ns.QuestieDB.ItemQuests(M, data.id, MAX_TOOLTIP_QUESTS)) do
        open = open or not quest.done
        tooltip:AddLine(format(quest.done and L.QUESTITEMS_TOOLTIP_DONE or L.QUESTITEMS_TOOLTIP_OPEN, quest.name),
            0.6, 0.6, 0.6)
    end
    local sell = select(11, C_Item.GetItemInfo(data.id))
    local hint = open and L.QUESTITEMS_TOOLTIP_KEEP
        or (sell and sell > 0) and L.QUESTITEMS_TOOLTIP_SELL or L.QUESTITEMS_TOOLTIP_DESTROY
    tooltip:AddLine(hint, 1, 0.82, 0, true)
end

-- Quest log changes ----------------------------------------------------------------------------

local lastSignature

-- Once a frame at most: read the log again, and repaint only when what it asks for changed.
local function repaint()
    local now = QuestLog.Signature()
    if now == lastSignature then return end
    lastSignature = now
    paintBags()
    BagButtons.RefreshBaganator(M)
end

local function requestRepaint() M:Soon(repaint) end

function M:OnEnable()
    registerWidgets()
    BagButtons.HookBlizzard(self, paintButton)
    QuestLog.Listen(self, requestRepaint)
    self:HookCallback(TooltipDataProcessor, "tooltip", function(hook)
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, hook)
    end, addTooltipLines)
    lastSignature = nil
    paintBags()
    BagButtons.RefreshBaganator(M)
end

function M:OnDisable()
    for _, mark in pairs(markOf) do mark:Hide() end
    BagButtons.RefreshBaganator(M)
end

function M:OnSettingChanged()
    paintBags()
    BagButtons.RefreshBaganator(M)
end

function M:DebugLine()
    local count = 0
    local log = QuestLog.Needed()
    for _ in pairs(log.names) do count = count + 1 end
    for _ in pairs(log.ids) do count = count + 1 end
    return format(L.QUESTITEMS_DEBUG, count)
end
