--[[
    Forever runtime - Shared/Core/Core.lua
    The addon's namespace: locale, printing, the log, combat-safe calls and events. Shared/ is
    the runtime Forever Gearbox and Forever Codex each carry a copy of (scripts/sync-shared.sh
    copies it into <Addon>/Shared/; edit only the one at the repository's root). Modules (their hooks, timers and on/off life) are in Core/Module.lua;
    saved settings are laid out in Core/Store.lua.

    Cost and safety rules every module follows:
      * One event frame for the whole addon, and every handler, hook and timer runs through
        securecallfunction, so an error in one is reported without stopping the others.
      * An event this client doesn't have is never registered (C_EventUtils.IsEventValid).
      * A module that's off has no events, hooks doing work, timers or frames running: its
        events and timers stop by themselves, and its hooks do nothing.
      * While the Profiler records (Debug page), every call into a module is timed and charged to it.

    Approach adapted from Forever++ by xIGBClutchIx (MIT License).
]]

local addonName, ns = ...

local ipairs, type, next = ipairs, type, next
local setmetatable, tremove = setmetatable, table.remove
local CreateFrame, InCombatLockdown, C_Timer = CreateFrame, InCombatLockdown, C_Timer

-- Calls fn so an error in it is reported but doesn't stop the caller. The three ways to call
-- code are named for what they add: SafeCall only isolates; ChargedCall (below) also charges the
-- time to an owner in the Profiler; ChargedHandler also passes that owner first.
local call = securecallfunction
ns.SafeCall = call

ns.name    = addonName
ns.title   = addonName -- the addon's own title, once Part.lua has said it (Core/Members.lua)
ns.icon    = "Interface\\AddOns\\" .. addonName .. "\\Media\\Icon"
ns.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "0"
ns.modules = {} -- name -> module
ns.order   = {} -- module names in load order

---------------------------------------------------------------------------
-- Locale: ns.L holds the player-facing text, by key. Locales/enUS.lua has every key and is the fallback;
-- another language's file sets only what it translates. A missing key shows as itself.
---------------------------------------------------------------------------

local enUS = {}
ns.L = setmetatable({}, { __index = function(_, key) return enUS[key] or key end })

-- The table a locale file fills, or nil when the client uses another language.
function ns:NewLocale(locale)
    if locale == "enUS" then return enUS end
    if locale == GetLocale() then return ns.L end
end

local L = ns.L

-- Whether version a is newer than b ("1.10.0" > "1.9.2").
function ns:IsNewer(a, b)
    if not b then return a ~= nil end
    if not a then return false end
    local x, y = { strsplit(".-", a) }, { strsplit(".-", b) }
    for i = 1, math.max(#x, #y) do
        local p, q = tonumber(x[i]) or 0, tonumber(y[i]) or 0
        if p ~= q then return p > q end
    end
    return false
end

-- Module categories are each member's (Core/Members.lua: member.categories, in the order its
-- Settings page lists them). A module without one its member knows goes under Other.
function ns:CategoryOf(mod)
    local member = mod.member
    return member and member.ranks[mod.category or ""] and mod.category or "other"
end

-- Where a category comes in its member's list (Settings pages sort by it).
function ns:CategoryRank(mod)
    local member = mod.member
    return member and member.ranks[self:CategoryOf(mod)] or 99
end

function ns:CategoryLabel(key)
    return L["CATEGORY_" .. key:upper()]
end

---------------------------------------------------------------------------
-- Printing. The addon speaks in chat only in reply to something the player did; what modules
-- do goes to the log (ns:Debug), and a module that says something unprompted gives the player
-- a Chat Messages checkbox for it (ns.ChatOption).
---------------------------------------------------------------------------

-- The chat timestamp, when the player has them on, as Blizzard's own lines get.
local function stamp()
    local fmt = ChatFrameUtil.GetTimestampFormat()
    return fmt and TimeUtil.BetterDate(fmt, time()) or ""
end

-- A chat line with no name in front, for lines following an ns:Print.
function ns:PrintLine(text)
    print(stamp() .. text)
end

-- A chat line under the name of the member addon it comes from (self: a member's namespace, or a
-- module), "Forever" for the core's own.
function ns:Print(...)
    local member = self.member or ns.member
    ns:PrintLine("|cffd4a017" .. member.title .. "|r: " .. strjoin(" ", tostringall(...)))
end

-- `value`, or nil when it's secret (Midnight's restricted values: passable, but not comparable).
-- What a module compares or keeps from the game goes through this first.
function ns.Plain(value)
    if value ~= nil and issecretvalue(value) then return nil end
    return value
end

-- Whether `t` is a frame (or table) addon code may use. Blizzard's protected frames come two
-- ways: a forbidden table, which can't even be read (canaccesstable says so), and a forbidden
-- object, readable but whose methods error (only IsForbidden answers). Anything the game hands a
-- hook, or a look through another frame's children finds, is checked with this first.
function ns.Usable(t)
    if type(t) ~= "table" or not canaccesstable(t) then return false end
    local isForbidden = t.IsForbidden
    return isForbidden == nil or not isForbidden(t)
end

-- A frame's anchors as plain lists { point, relativeTo, relativePoint, x, y }, to put back later
-- with ns.SetPoints. An anchor the game keeps secret (Midnight hides some frames' geometry) or
-- that isn't whole is left out: SetPoint refuses secret or missing points.
function ns.Points(frame)
    local points = {}
    if not ns.Usable(frame) then return points end
    for i = 1, frame:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(i)
        if type(ns.Plain(point)) == "string" and type(ns.Plain(relativePoint)) == "string"
            and ns.Plain(x) and ns.Plain(y) and (relativeTo == nil or ns.Usable(relativeTo)) then
            points[#points + 1] = { point, relativeTo, relativePoint, x, y }
        end
    end
    return points
end

-- Anchors `frame` at `points` (ns.Points' lists), clearing its old ones.
function ns.SetPoints(frame, points)
    frame:ClearAllPoints()
    for _, p in ipairs(points) do frame:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
end

-- fn(questID, info) for each quest in the quest log (C_QuestLog.GetInfo's info; headers left
-- out). The log is read until it runs out, as Questie does, not up to GetNumQuestLogEntries():
-- that counts the entries shown, so quests under a collapsed header would be missed.
local MAX_LOG_INDEX = 75 -- past the last entry the log can have (Questie's QuestLogCache uses the same)
function ns.EachLogQuest(fn)
    for i = 1, MAX_LOG_INDEX do
        local info = C_QuestLog.GetInfo(i)
        if not info then return end
        if not info.isHeader and info.questID then fn(info.questID, info) end
    end
end

-- Copper as money, the game's way: gold, silver and copper with their coin icons, thousands
-- grouped, rounded to whole copper. Every Forever addon's money goes through this.
function ns.MoneyText(copper)
    return GetMoneyString(math.floor(copper + 0.5), true)
end

-- "On" in green or "Off" in red.
function ns:StateText(on)
    return on and ("|cff44dd44" .. L.ON .. "|r") or ("|cffdd4444" .. L.OFF .. "|r")
end

local LOG_SIZE = 100
local log, logNext = {}, 1

-- What modules do goes into a small in-memory log, and into chat only with Show Log in Chat on.
function ns:Debug(...)
    local line = strjoin(" ", tostringall(...))
    log[logNext] = date("%H:%M:%S ") .. line
    logNext = logNext % LOG_SIZE + 1
    if self.db and self.db.debug then
        self:PrintLine("|cff888888" .. ns.title .. ": " .. line .. "|r")
    end
end

-- The log, oldest first.
function ns:GetLog()
    local lines = {}
    for i = 0, LOG_SIZE - 1 do
        local line = log[(logNext + i - 1) % LOG_SIZE + 1]
        if line then lines[#lines + 1] = line end
    end
    return lines
end

---------------------------------------------------------------------------
-- Combat: changes that may touch protected things wait until combat ends, in order.
---------------------------------------------------------------------------

local combatQueue = {} -- { owner, fn } in order

-- fn() now, or once combat ends: run as `owner`'s code (ns.ChargedCall), like everything else that
-- calls into a module. A module's queued work runs even if it turned off meanwhile (its
-- OnDisable's cleanup is such work); a closure that only makes sense while on checks that.
function ns:AfterCombat(owner, fn)
    if InCombatLockdown() then
        combatQueue[#combatQueue + 1] = { owner, fn }
    else
        ns.ChargedCall(owner, "after combat", fn)
    end
end

---------------------------------------------------------------------------
-- Events: one frame for everything. Each event keeps an array of { owner, fn },
-- rebuilt on change (copy on write), so dispatching allocates nothing and handlers may
-- subscribe or unsubscribe while it runs. owner is a module (charged by the Profiler) or any
-- other table.
---------------------------------------------------------------------------

local dispatcher = CreateFrame("Frame")
local handlers = {} -- event -> array of { owner, fn }

-- Calls fn(...) through `call`; while the Profiler records, timed and charged to owner.
-- (Core/Profiler.lua loads after this file but before anything can be dispatched: every file
-- loads before the first event.)
local function timed(owner, source, fn, ...)
    if ns.Profiler.recording then return ns.Profiler.Call(owner, source, fn, ...) end
    return call(fn, ...)
end

-- Runs fn(owner, ...) that way: how every handler, hook and timer is called.
local function run(owner, source, fn, ...)
    return timed(owner, source, fn, owner, ...)
end
ns.ChargedHandler = run

-- Runs fn(...) the same way, isolated and charged to owner, but without passing owner: for a
-- callback that isn't the owner's method (a part's, an Edit Mode frame's, a command's).
ns.ChargedCall = timed

-- true and fn(...)'s results. Run through either of those, an error answers nothing, so
-- ns.ChargedCall(owner, source, ns.Succeeded, fn, ...) tells an error apart from a nil result.
function ns.Succeeded(fn, ...) return true, fn(...) end

-- Module news: fn(owner, event, ...) for a module's news that isn't a setting (Layer Info's
-- LAYER_CHANGED) or the addon's (READY): API.lua passes it on to other addons. Modules announce
-- with ns:Announce, so they never reach into API.lua.
local newsListeners = {} -- { owner, fn }
function ns:OnNews(owner, fn)
    newsListeners[#newsListeners + 1] = { owner, fn }
end
function ns:Announce(event, ...)
    for i = 1, #newsListeners do
        local listener = newsListeners[i]
        ns.ChargedHandler(listener[1], "OnNews", listener[2], event, ...)
    end
end

-- A one-off timer for code that isn't a module (the Settings pages): fn(owner) runs through
-- ns.ChargedHandler, charged to owner. A module uses its own module:After, which stops when it turns off.
function ns:After(owner, seconds, fn)
    C_Timer.After(seconds, function() run(owner, "timer", fn) end)
end

-- fn(owner) on the next frame, once however often this is called before then: for redrawing
-- once after a burst of changes (the Settings pages). A module uses its own module:Soon.
local soonFor = setmetatable({}, { __mode = "k" }) -- owner -> { [fn] = true } while pending
function ns:Soon(owner, fn)
    local pending = soonFor[owner]
    if not pending then
        pending = {}
        soonFor[owner] = pending
    end
    if pending[fn] then return end
    pending[fn] = true
    ns:After(owner, 0, function(o)
        pending[fn] = nil
        return fn(o)
    end)
end

dispatcher:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        local entry = list[i]
        run(entry[1], event, entry[2], event, ...)
    end
end)

-- Whether this client has `event`. Registering one it doesn't have is an error.
function ns:HasEvent(event)
    return C_EventUtils.IsEventValid(event)
end

-- fn(owner, event, ...) runs for `event` until ns:Off(event, owner). False if the client
-- doesn't have the event. One handler per owner and event: calling it again replaces it.
function ns:On(event, owner, fn)
    local old = handlers[event]
    if not old then
        if not self:HasEvent(event) then
            self:Debug("no such event:", event)
            return false
        end
        dispatcher:RegisterEvent(event)
    end
    local list = {}
    for i = 1, old and #old or 0 do
        if old[i][1] ~= owner then list[#list + 1] = old[i] end
    end
    list[#list + 1] = { owner, fn }
    handlers[event] = list
    return true
end

function ns:Off(event, owner)
    local old = handlers[event]
    if not old then return end
    local list = {}
    for i = 1, #old do
        if old[i][1] ~= owner then list[#list + 1] = old[i] end
    end
    if #list == 0 then
        handlers[event] = nil
        dispatcher:UnregisterEvent(event)
    else
        handlers[event] = list
    end
end

local core = { name = "Core" }
ns:On("PLAYER_REGEN_ENABLED", core, function()
    while #combatQueue > 0 do
        local entry = tremove(combatQueue, 1)
        ns.ChargedCall(entry[1], "after combat", entry[2])
    end
end)
ns:On("PLAYER_ENTERING_WORLD", core, function()
    ns.inWorld = true
    ns:Off("PLAYER_ENTERING_WORLD", core)
end)
