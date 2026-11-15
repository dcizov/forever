--[[
    Forever Tweaks - New in Forever
    A small Forever medallion after the name of a quest that's new to Forever (one original
    Classic didn't have) in the quest log, the objective tracker, a quest giver's list and the
    title of a quest's details, and a "New in WoW Forever" line on the tooltip of an item new to
    Forever: each place its own checkbox.

    New is told apart by ID: every quest of original Classic has an ID of 9665 or less, every item
    24283 or less (Forever++ and Forever Quest Tint use the same lines), so a higher ID is
    something Forever added. The icon is a texture in the title's text, cut down to its art; a
    title the icon would push onto another line is left without one, since Blizzard measured the
    row's height from its text before we added to it.
    Left to Forever++'s Forever Quest Icons while that's on (the quest places only).
    Adapted from Forever++'s Forever Quest Icons by xIGBClutchIx (MIT License).
]]

local _, ns = ...
local L = ns.L

local _G, ipairs, type, format, floor, setmetatable, sub = _G, ipairs, type, string.format, math.floor,
    setmetatable, string.sub
local OtherAddons, ItemTooltip = ns.OtherAddons, ns.ItemTooltip

local LAST_CLASSIC_QUEST, LAST_CLASSIC_ITEM = 9665, 24283
local COVERS = { { "ForeverPlusPlus", "ForeverQuestIcons" } }
local TRACKERS = { "QuestObjectiveTracker", "CampaignQuestObjectiveTracker" }
local TRACKER_ADDON = "Blizzard_ObjectiveTracker"

local M = ns:NewModule("ForeverMarks", {
    title = L.FMARKS_TITLE,
    category = "quests",
    group = L.GROUP_QUEST_WINDOWS,
    description = L.FMARKS_DESC,
    added = "2.7.0",
    defaults = { log = true, tracker = true, givers = true, details = true, items = true, size = 100 },
    options = {
        { key = "log", type = "checkbox", label = L.FMARKS_LOG, tooltip = L.FMARKS_LOG_TIP },
        { key = "tracker", type = "checkbox", label = L.FMARKS_TRACKER, tooltip = L.FMARKS_TRACKER_TIP },
        { key = "givers", type = "checkbox", label = L.FMARKS_GIVERS, tooltip = L.FMARKS_GIVERS_TIP },
        { key = "details", type = "checkbox", label = L.FMARKS_DETAILS, tooltip = L.FMARKS_DETAILS_TIP },
        { key = "items", type = "checkbox", label = L.FMARKS_ITEMS, tooltip = L.FMARKS_ITEMS_TIP },
        { key = "size", type = "slider", label = L.FMARKS_SIZE, tooltip = L.FMARKS_SIZE_TIP,
          min = 50, max = 200, step = 10, format = "%d%%" },
    },
})
M.notice = OtherAddons.CoveredNotices(M, COVERS, L.FMARKS_WHAT)

-- The blue medallion of the login screen (a file every Forever client has), cut to its art:
-- left, right, top, bottom as shares; its width over its height; its height against the font's.
local ICON = { file = "Interface\\Glues\\Common\\Glues-WoW-ForeverLogo-Infinity",
    crop = { 0.1191, 0.5488, 0, 1 }, aspect = 220 / 256, height = 1.35 }
local TEXELS = 10000 -- |T texel coordinates are out of the size given with them
-- How far to raise the icon in a place, as a share of the font's size, so it sits on the letters.
local LIFT = { tracker = 0.15, givers = -0.08 }
-- The details title's font is larger, so a smaller share keeps the icon near the lists' size.
local PLACE_SIZE = { givers = 0.8, details = 0.6 }

function M.IsNewQuest(questID) return type(questID) == "number" and questID > LAST_CLASSIC_QUEST end
function M.IsNewItem(itemID) return type(itemID) == "number" and itemID > LAST_CLASSIC_ITEM end

-- The icon as text markup, sized for `fontString`'s font in `place`.
local function markup(fontString, place, fontSize)
    if not fontSize then
        local _, size = fontString:GetFont()
        fontSize = size or 12
    end
    local size = fontSize * M.db.size / 100 * (PLACE_SIZE[place] or 1)
    local height = floor(size * ICON.height + 0.5)
    local width = floor(height * ICON.aspect + 0.5)
    local lift = floor(fontSize * (LIFT[place] or 0) + 0.5)
    local c = ICON.crop
    return format("|T%s:%d:%d:0:%d:%d:%d:%d:%d:%d:%d|t", ICON.file, height, width, lift, TEXELS, TEXELS,
        floor(c[1] * TEXELS + 0.5), floor(c[2] * TEXELS + 0.5), floor(c[3] * TEXELS + 0.5), floor(c[4] * TEXELS + 0.5))
end
M.Markup = markup

-- Quest titles -----------------------------------------------------------------------------------

local added = setmetatable({}, { __mode = "k" }) -- font string -> what we last put at its end

-- A title without our icon at its end, so it can be marked again without stacking icons. A title
-- Blizzard wrote again doesn't end with it, and stays as it is.
local function plain(fontString, text)
    local suffix = added[fontString]
    if suffix and #text >= #suffix and sub(text, -#suffix) == suffix then return sub(text, 1, #text - #suffix) end
    return text
end

local function questsOn() return M.active and not OtherAddons.CoveredBy(M, COVERS) end

-- Adds the icon to a quest title (or takes it off): `place` is its checkbox.
local function mark(fontString, questID, place)
    if not fontString then return end
    local text = fontString:GetText()
    if type(text) ~= "string" then return end
    text = plain(fontString, text)
    local suffix = questsOn() and M.db[place] and M.IsNewQuest(questID) and " " .. markup(fontString, place) or nil
    local wanted = suffix and text .. suffix or text
    if wanted ~= fontString:GetText() then
        fontString:SetText(text)
        local lines = suffix and fontString.GetNumLines and fontString:GetNumLines()
        fontString:SetText(wanted)
        if lines and fontString:GetNumLines() > lines then
            fontString:SetText(text)
            suffix = nil
        end
    end
    added[fontString] = suffix
end

-- The quest log beside the world map.
local function markLog()
    local pool = _G.QuestScrollFrame and _G.QuestScrollFrame.titleFramePool
    if not pool then return end
    for button in pool:EnumerateActive() do mark(button.Text, button.questID, "log") end
end

-- The objective tracker: each block's id is its quest's.
local function markBlock(block) mark(block.HeaderText, block.id, "tracker") end

local function markTracker()
    for _, name in ipairs(TRACKERS) do
        local tracker = _G[name]
        if tracker and tracker.EnumerateActiveBlocks then tracker:EnumerateActiveBlocks(markBlock) end
    end
end

-- A quest giver's list, the gossip way (most NPCs).
local function markGossip()
    local panel = _G.GossipFrame and _G.GossipFrame.GreetingPanel
    local box = panel and panel.ScrollBox
    if not (box and box.ForEachFrame) then return end
    box:ForEachFrame(function(button)
        local data = button.GetElementData and button:GetElementData()
        local kind = data and data.buttonType
        if kind == _G.GOSSIP_BUTTON_TYPE_ACTIVE_QUEST or kind == _G.GOSSIP_BUTTON_TYPE_AVAILABLE_QUEST then
            mark(button:GetFontString(), data.info and data.info.questID, "givers")
        end
    end)
end

-- A quest giver's list, the older greeting way: active quests first, each button's ID its place
-- in its own list.
local function markGreeting()
    local panel = _G.QuestFrameGreetingPanel
    local pool = panel and panel.titleButtonPool
    if not pool then return end
    for button in pool:EnumerateActive() do
        local index = button:GetID()
        local questID
        if button.isActive == 1 then
            questID = GetActiveQuestID(index)
        else
            questID = select(5, GetAvailableQuestInfo(index))
        end
        mark(button:GetFontString(), questID, "givers")
    end
end

-- A quest's details, from a giver or from the quest log on the map, and the window asking for
-- its items before you turn it in.
local function markDetails()
    local questID = _G.QuestInfoFrame and _G.QuestInfoFrame.questLog and C_QuestLog.GetSelectedQuest() or GetQuestID()
    mark(_G.QuestInfoTitleHeader, questID, "details")
    mark(_G.QuestProgressTitleText, GetQuestID(), "details")
end

local function markAll()
    markLog()
    markTracker()
    markGossip()
    markGreeting()
    markDetails()
end

-- The tracker is its own Blizzard addon; each tracker frame has its own copy of the method.
local function hookTracker()
    for _, name in ipairs(TRACKERS) do
        if _G[name] then
            M:Hook(_G[name], "UpdateSingle", function(_, tracker, quest)
                local block = quest and quest.GetID and tracker:GetExistingBlock(quest:GetID())
                if block then markBlock(block) end
            end)
        end
    end
    markTracker()
end

-- Items -----------------------------------------------------------------------------------------

local function itemLine(tooltip, data)
    -- (ItemTooltip runs every provider whether its module is on: so it's checked here.)
    if not (M.active and M.db.items and M.IsNewItem(ItemTooltip.ItemID(data))) then return end
    tooltip:AddLine(markup(tooltip, "items", 12) .. " " .. L.FMARKS_ITEM_LINE, 0.25, 0.75, 0.9)
end

function M:OnEnable()
    self:Hook("QuestLogQuests_Update", markLog)
    if _G.GossipFrame and _G.GossipFrame.GreetingPanel then
        -- Runs when the list is filled and when it scrolls.
        self:Hook(_G.GossipFrame.GreetingPanel.ScrollBox, "Update", markGossip)
    end
    if _G.QuestFrameGreetingPanel then
        -- The panel's script holds the function it had at load, and Blizzard calls the global
        -- itself too, so both are hooked.
        self:HookScript(_G.QuestFrameGreetingPanel, "OnShow", markGreeting)
        self:Hook("QuestFrameGreetingPanel_OnShow", markGreeting)
    end
    self:Hook("QuestInfo_Display", markDetails)
    self:Hook("QuestFrameProgressPanel_OnShow", markDetails)
    if OtherAddons.Loaded(TRACKER_ADDON) then hookTracker() end
    self:RegisterEvent("ADDON_LOADED", function(_, _, name) if name == TRACKER_ADDON then hookTracker() end end)
    ItemTooltip.OnInfo(self, itemLine)
    markAll()
end

-- Hooks stop by themselves; the titles showing now get their own text back.
function M:OnDisable() markAll() end

function M:OnSettingChanged() markAll() end
