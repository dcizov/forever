--[[
    Forever Tweaks - Gathering Tracking
    Keeps Find Minerals or Find Herbs on: after login, a loading screen and coming back to life it
    turns one back on when nothing is tracked (a hunter's own tracking counts as something), and it
    can swap between the two every few seconds so both kinds of node show on the minimap (only one
    tracking spell is on at a time). Never in combat, on a flight or while casting: tracking is a
    spell, and casting it would stop a cast or channel such as mining or fishing.
    C_Minimap.SetTracking from an addon isn't confirmed to work for a spell on Forever
    (docs/forever-api.md): if the game refuses it, this says so once and stops until a /reload.
    Left to Forever++'s Gathering Tracking or WilduTools' tracking on login while those are on.
    Adapted from Forever++'s Gathering Tracking by xIGBClutchIx (MIT License).
]]

local _, ns = ...
local L = ns.L

local ipairs, type, pcall, format, GetTime = ipairs, type, pcall, string.format, GetTime
local C_Minimap = C_Minimap
local Plain = ns.Plain
local OtherAddons = ns.OtherAddons

local HERBS, MINERALS = 2383, 2580
local SPELLS = { both = { MINERALS, HERBS }, minerals = { MINERALS }, herbs = { HERBS } }
local RETRY, WATCH, FASTEST = 2, 12, 3 -- seconds
local COVERS = { { "ForeverPlusPlus", "GatheringTracking" }, { "!WilduTools", "automation_trackOnLoginEnabled" } }

local M = ns:NewModule("GatheringTracking", {
    title = L.GTRACK_TITLE,
    category = "gathering",
    group = L.GROUP_HERBS,
    description = L.GTRACK_DESC,
    added = "1.9.0",
    defaults = { track = "both", swap = false, swapEvery = 10, chat = true },
    options = {
        { key = "track", type = "dropdown", label = L.GTRACK_TRACK, tooltip = L.GTRACK_TRACK_TIP,
          choices = { { "both", L.GTRACK_BOTH }, { "minerals", L.GTRACK_MINERALS }, { "herbs", L.GTRACK_HERBS } } },
        { key = "swap", type = "checkbox", label = L.GTRACK_SWAP, tooltip = L.GTRACK_SWAP_TIP, slider = "swapEvery",
          shown = function(db) return db.track == "both" end },
        { key = "swapEvery", type = "slider", label = L.GTRACK_SWAP_EVERY, tooltip = L.GTRACK_SWAP_TIP,
          requires = "swap", min = FASTEST, max = 30, step = 1, format = function(v) return format(L.SECONDS, v) end },
        ns.ChatOption(),
    },
})

M.notice = OtherAddons.CoveredNotices(M, COVERS, L.GTRACK_WHAT)

-- The index of each of our spells the player knows, which of ours is on, and whether any
-- tracking spell is on. Read each time: it changes as spells are learned.
local function scan()
    local index, ours, any = {}, nil, false
    for i = 1, C_Minimap.GetNumTrackingTypes() do
        local info = C_Minimap.GetTrackingInfo(i)
        if type(info) == "table" then
            local spellID = info.spellID
            if spellID == HERBS or spellID == MINERALS then index[spellID] = i end
            if info.active and (info.type == "spell" or (spellID and spellID > 0)) then
                any = true
                if spellID == HERBS or spellID == MINERALS then ours = spellID end
            end
        end
    end
    return index, ours, any
end

-- Whether a unit-state answer may be yes: a secret one counts as yes (wait until it can be read).
local function maybeTrue(v)
    if v == nil then return false end
    return Plain(v) == nil or (v and true or false)
end

local function busy()
    return InCombatLockdown() or maybeTrue(UnitIsDeadOrGhost("player")) or maybeTrue(UnitOnTaxi("player"))
        or maybeTrue(UnitCastingInfo("player")) or maybeTrue(UnitChannelInfo("player"))
end

local blocked = false -- the game refused SetTracking: stop until /reload
local last -- the last of our spells seen on, turned back on first

-- The game refused SetTracking: say so once, and leave tracking alone until /reload.
local function giveUp()
    if blocked then return end
    blocked = true
    M:Print(L.GTRACK_FAILED)
end

-- pcall, not ns.SafeCall: the game may refuse this from an addon (docs/forever-api.md), and that
-- refusal is the answer to act on, not a bug to report. A refusal can also come as an event.
local function track(i)
    if not pcall(C_Minimap.SetTracking, i, true) then giveUp() end
end

local function onBlocked(_, _, addon, action)
    if ns.membersByName[addon] and type(action) == "string" and action:find("SetTracking", 1, true) then giveUp() end
end

local function inCharge() return not blocked and not OtherAddons.CoveredBy(M, COVERS) end

---------------------------------------------------------------------------
-- Turning tracking back on
---------------------------------------------------------------------------

local deadline, timer = 0, nil

local function firstKnown(index)
    local first
    for _, spellID in ipairs(SPELLS[M.db.track]) do
        if index[spellID] then
            if spellID == last then return spellID end
            first = first or spellID
        end
    end
    return first
end

local function reapply()
    if not inCharge() then return end
    if busy() then
        deadline = GetTime() + WATCH -- the watch starts once the player can cast
        timer = M:After(RETRY, reapply)
        return
    end
    local index, _, any = scan()
    if not any then
        local spellID = firstKnown(index)
        if spellID then track(index[spellID]) end
    end
    -- The list can lag the event, or show what was lost at death as on for a moment: look again.
    if GetTime() < deadline then timer = M:After(RETRY, reapply) end
end

local function request()
    deadline = GetTime() + WATCH
    if not M:IsPending(timer) then timer = M:After(1, reapply) end
end

---------------------------------------------------------------------------
-- Swapping
---------------------------------------------------------------------------

local ticker

local function swap()
    if not inCharge() or busy() then return end
    local index, ours = scan()
    local other = (ours == MINERALS and HERBS) or (ours == HERBS and MINERALS)
    if other and M.db.track == "both" and index[other] then track(index[other]) end
end

local function startSwapping()
    M:CancelTimer(ticker)
    ticker = nil
    if M.db.swap and M.db.track == "both" then ticker = M:NewTicker(M.db.swapEvery, swap) end
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

local function onTrackingChanged()
    local _, ours = scan()
    last = ours or last
end

function M:OnEnable()
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_ALIVE", "PLAYER_UNGHOST" }) do
        self:RegisterEvent(event, request)
    end
    self:RegisterEvent("MINIMAP_UPDATE_TRACKING", onTrackingChanged)
    self:RegisterEvent("ADDON_ACTION_BLOCKED", onBlocked)
    self:RegisterEvent("ADDON_ACTION_FORBIDDEN", onBlocked)
    onTrackingChanged()
    startSwapping()
    request()
end

function M:OnSettingChanged(key)
    if key == "swap" or key == "swapEvery" or key == "track" then startSwapping() end
    if key == "track" then request() end
end

function M:DebugLine()
    if blocked then return L.GTRACK_FAILED end
    local _, ours = scan()
    return ours == HERBS and L.GTRACK_HERBS or ours == MINERALS and L.GTRACK_MINERALS or L.GTRACK_NONE
end
