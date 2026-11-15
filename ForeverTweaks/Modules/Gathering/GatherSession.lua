--[[
    Forever Tweaks - Gathering Session
    A small panel under the minimap once you gather something (as farm trackers like GatherHelper
    and GoldWatch show it; no code from them):

        Gathering  12:34
        23 nodes  84 items  1g 20s  5g 60s/h  +3 skill

    Nodes are loot from a game object (herbs, ore, chests: GetLootSourceInfo's GUID), fish are
    IsFishingLoot catches, items count when they reach your bags, and they're worth Auctionator's
    price when it has one, else a vendor's (as Full Bags prices them). Skill-ups are CHAT_MSG_SKILL.
    The clock starts at your first gather and stops while paused. Point at it for the items;
    right-click it to pause, start again or open the Gathering window (GatherWindow.lua, a part
    of this module). /ft session says the same in chat.
]]

local _, ns = ...
local L = ns.L

local format, floor, pairs, wipe, sort, select = string.format, math.floor, pairs, wipe, table.sort, select

local ANCHOR = { "TOP", "BOTTOM", 0, -24 } -- under the minimap
local MAX_TOOLTIP_ITEMS = 10
local MIN_RATE_TIME = 60 -- seconds of gathering before a per-hour figure means anything

local M = ns:NewModule("GatherSession", {
    title = L.GATHERSESSION_TITLE,
    category = "gathering",
    group = L.GROUP_HERBS,
    description = L.GATHERSESSION_DESC,
    added = "1.5.0",
    defaults = ns.Widgets.DisplayDefaults({
        enabled = true,
        rate = true,
        skill = true,
        hideInCombat = true,
    }, ANCHOR),
    options = ns.Widgets.DisplayOptions({
        { key = "rate", type = "checkbox", label = L.GATHERSESSION_RATE, tooltip = L.GATHERSESSION_RATE_TIP },
        { key = "skill", type = "checkbox", label = L.GATHERSESSION_SKILL, tooltip = L.GATHERSESSION_SKILL_TIP },
        { key = "hideInCombat", type = "checkbox", label = L.GATHERSESSION_COMBAT, tooltip = L.GATHERSESSION_COMBAT_TIP },
    }),
    notice = {
        text = L.GATHERSESSION_NO_AUCTION,
        addon = "Auctionator", advice = L.GATHERSESSION_ADVICE_AUCTION,
        shown = function() return ns.OtherAddons.Loaded("Auctionator") and not ns.OtherAddons.HasAuctionPrices() end,
    },
})

local display -- added below
local session = { nodes = 0, fish = 0, items = 0, value = 0, skillups = 0, byItem = {} }
local started, pausedAt, pausedFor = nil, nil, 0 -- GetTime() of the first gather, of the pause, and time paused
local seenNodes = {} -- GUIDs of the nodes counted this session
local lootSlots = {} -- loot slot -> { link, count } while the loot window is open
local inCombat = false
local clock

local function elapsed()
    if not started then return 0 end
    return (pausedAt or GetTime()) - started - pausedFor
end

local function clockText(seconds)
    seconds = floor(seconds)
    if seconds >= 3600 then return format("%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60) end
    return format("%d:%02d", seconds / 60, seconds % 60)
end

local money = ns.MoneyText

-- What the session made an hour, or nil before there's enough of it to say.
local function perHour()
    local time = elapsed()
    if time < MIN_RATE_TIME or session.value <= 0 then return nil end
    return session.value / time * 3600
end

local function updateDisplay()
    local show = started ~= nil and not (M.db.hideInCombat and inCombat)
    if show then
        local head = format(L.GATHERSESSION_HEAD, clockText(elapsed())) .. (pausedAt and L.GATHERSESSION_PAUSED or "")
        local parts = { format(L.GATHERSESSION_NODES, session.nodes) }
        if session.fish > 0 then parts[#parts + 1] = format(L.GATHERSESSION_FISH, session.fish) end
        parts[#parts + 1] = format(L.GATHERSESSION_ITEMS, session.items)
        if session.value > 0 then parts[#parts + 1] = money(session.value) end
        local rate = M.db.rate and perHour()
        if rate then parts[#parts + 1] = format(L.GATHERSESSION_PER_HOUR, money(rate)) end
        if M.db.skill and session.skillups > 0 then parts[#parts + 1] = format(L.GATHERSESSION_SKILLUPS, session.skillups) end
        display:SetLine(head .. "\n" .. table.concat(parts, "   "))
    end
    display:SetShown(show)
    if M.window then M.window.Refresh() end
end

-- The clock ticks once a second while the session runs and the panel shows.
local function syncClock()
    local want = M.active and started ~= nil and not pausedAt
    if want and not M:IsPending(clock) then
        clock = M:NewTicker(1, updateDisplay)
    elseif not want then
        M:CancelTimer(clock)
    end
end

local function startAgain()
    session.nodes, session.fish, session.items, session.value, session.skillups = 0, 0, 0, 0, 0
    wipe(session.byItem)
    wipe(seenNodes)
    started, pausedAt, pausedFor = nil, nil, 0
    syncClock()
    updateDisplay()
end

local function togglePause()
    if not started then return end
    if pausedAt then
        pausedFor = pausedFor + GetTime() - pausedAt
        pausedAt = nil
    else
        pausedAt = GetTime()
    end
    syncClock()
    updateDisplay()
end

-- Its key binding (Bindings.xml, Forever Core's Core/Bindings.lua).
ns:AddBinding(M, "FOREVERTWEAKS_SESSION_PAUSE", togglePause)

-- Something was gathered: the session starts (or carries on after a pause).
local function gathered()
    if not started then started = GetTime() end
    if pausedAt then togglePause() end
    syncClock()
end

local function priceOf(link, itemID)
    return ns.OtherAddons.AuctionPrice(link, itemID) or select(11, C_Item.GetItemInfo(link)) or 0
end

-- The loot window opened: is it from a node (a game object) or fishing? Remember what it holds.
local function onLootOpened()
    wipe(lootSlots)
    local fishing = IsFishingLoot()
    local fromNode = fishing
    for slot = 1, GetNumLootItems() do
        local guid = GetLootSourceInfo(slot)
        if type(guid) == "string" and guid:find("^GameObject%-") then
            fromNode = true
            if not seenNodes[guid] then
                seenNodes[guid] = true
                session.nodes = session.nodes + 1
            end
        end
    end
    if not fromNode then return end
    gathered()
    if fishing then session.fish = session.fish + 1 end
    for slot = 1, GetNumLootItems() do
        if GetLootSlotType(slot) == Enum.LootSlotType.Item then
            local count = select(3, GetLootSlotInfo(slot))
            lootSlots[slot] = { link = GetLootSlotLink(slot), count = count or 1 }
        end
    end
    updateDisplay()
end

-- A loot slot taken: it's in the bags now.
local function onSlotCleared(_, _, slot)
    local entry = lootSlots[slot]
    if not entry or not entry.link then return end
    lootSlots[slot] = nil
    local itemID = C_Item.GetItemInfoInstant(entry.link)
    session.items = session.items + entry.count
    session.value = session.value + priceOf(entry.link, itemID) * entry.count
    session.byItem[entry.link] = (session.byItem[entry.link] or 0) + entry.count
    updateDisplay()
end

local function onSkill()
    if not started then return end -- a skill-up before gathering anything isn't this session's
    session.skillups = session.skillups + 1
    updateDisplay()
end

local function onCombat(_, event)
    inCombat = event == "PLAYER_REGEN_DISABLED"
    updateDisplay()
end

-- The session's items, most first, each with its count.
local function itemsByCount()
    local links = {}
    for link in pairs(session.byItem) do links[#links + 1] = link end
    sort(links, function(a, b) return session.byItem[a] > session.byItem[b] end)
    return links
end

local function fillTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(L.GATHERSESSION_TITLE, 1, 0.82, 0)
    local links = itemsByCount()
    for i = 1, math.min(#links, MAX_TOOLTIP_ITEMS) do
        GameTooltip:AddDoubleLine(links[i], session.byItem[links[i]], 1, 1, 1, 1, 1, 1)
    end
    GameTooltip:AddDoubleLine(L.GATHERSESSION_WORTH, money(session.value), 1, 0.82, 0, 1, 1, 1)
    local rate = perHour()
    if rate then GameTooltip:AddDoubleLine(L.GATHERSESSION_RATE, money(rate), 1, 0.82, 0, 1, 1, 1) end
end

display = ns.Widgets.AddDisplay(M, { name = "ForeverTweaksGatherSession", relativeTo = Minimap,
    onEnter = fillTooltip,
    sample = format(L.GATHERSESSION_HEAD, "12:34") .. "\n" .. format(L.GATHERSESSION_NODES, 23) .. "   "
        .. format(L.GATHERSESSION_ITEMS, 84),
    menu = function(add)
        add(pausedAt and L.GATHERSESSION_RESUME or L.GATHERSESSION_PAUSE, togglePause)
        add(L.GATHERSESSION_RESET, startAgain)
        if M.window then add(L.GATHERWINDOW_OPEN, M.window.Toggle) end
    end })

-- What the Gathering window (GatherWindow.lua) reads and does: functions only.
ns.GatherSessionShared = {
    Session = function() return session end,
    Started = function() return started ~= nil end,
    Paused = function() return pausedAt ~= nil end,
    Elapsed = elapsed, ClockText = clockText, PerHour = perHour, ItemsByCount = itemsByCount,
    TogglePause = togglePause, StartAgain = startAgain,
}

-- /ft session: the session in chat; /ft session reset starts again.
M:AddCommand("session", L.GATHERSESSION_CMD_USAGE, L.GATHERSESSION_CMD_DESC, function(args)
    if (args or ""):lower() == "window" and M.window then return M.window.Toggle() end
    if (args or ""):lower() == "reset" then
        startAgain()
        M:Reply(L.GATHERSESSION_RESET_DONE)
        return
    end
    if not started then return M:Reply(L.GATHERSESSION_NONE) end
    M:Reply(format(L.GATHERSESSION_SUMMARY, clockText(elapsed()), session.nodes, session.items, money(session.value)))
    for _, link in ipairs(itemsByCount()) do ns:PrintLine(format("  %d x %s", session.byItem[link], link)) end
end)

function M:OnEnable()
    self:RegisterEvent("LOOT_OPENED", onLootOpened)
    self:RegisterEvent("LOOT_SLOT_CLEARED", onSlotCleared)
    self:RegisterEvent("CHAT_MSG_SKILL", onSkill)
    self:RegisterEvent("PLAYER_REGEN_DISABLED", onCombat)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", onCombat)
    inCombat = InCombatLockdown()
    syncClock()
    updateDisplay()
end

function M:OnSettingChanged()
    updateDisplay()
end

function M:DebugLine()
    return format(L.GATHERSESSION_DEBUG, clockText(elapsed()), session.nodes, session.skillups)
end
