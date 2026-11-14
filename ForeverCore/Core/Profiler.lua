--[[
    Forever Core - Core/Profiler.lua
    The Profiler: how much CPU each module takes (the debug report is Core/DebugReport.lua). The game measures only the addon as a whole
    (C_AddOnProfiler), so while recording, every event, hook, timer and settings call into a
    module (they all go through ns.Run) is timed with debugprofilestop and charged to it, split
    by source ("LOOT_OPENED", "OnUpdate"). Each frame the suite took longer than SPIKE_MS
    in is kept as a spike, with the call that took the most of it.
    Off (the default) nothing is timed: ns.Run checks `recording` and calls straight through.

    Approach adapted from Forever++ by xIGBClutchIx (MIT License).
]]

local _, ns = ...

local debugprofilestop, GetTime, pairs, ipairs, sort, format = debugprofilestop, GetTime, pairs, ipairs, table.sort, string.format
local call = ns.Call

local Profiler = { recording = false }
ns.Profiler = Profiler

local SPIKE_MS, MAX_SPIKES = 2, 20

local stats    -- owner name -> { ms, calls, sources = { name -> { ms, calls } } }
local spikes   -- { { at, ms, top = "owner source" of the call that took the most } }
local frameMs, frameTop, frameTopMs = 0, nil, 0
local started = 0
local depth = 0     -- timed calls running, one inside another
local childMs = {}  -- depth -> time spent in timed calls made inside the call at that depth
local ticker = CreateFrame("Frame")

local function ownerName(owner)
    return type(owner) == "table" and owner.name or "Core"
end

-- Charges ms to owner and source.
local function charge(owner, source, ms)
    local name = ownerName(owner)
    local entry = stats[name]
    if not entry then
        entry = { ms = 0, calls = 0, sources = {} }
        stats[name] = entry
    end
    entry.ms, entry.calls = entry.ms + ms, entry.calls + 1
    source = source or "?"
    local src = entry.sources[source]
    if not src then
        src = { ms = 0, calls = 0 }
        entry.sources[source] = src
    end
    src.ms, src.calls = src.ms + ms, src.calls + 1
    frameMs = frameMs + ms
    if ms > frameTopMs then frameTop, frameTopMs = name .. " " .. source, ms end
end

-- Charges the call its own time (less the timed calls made inside it, which are charged to
-- theirs), and hands every value back unchanged.
local function finish(owner, source, start, ...)
    local ms = debugprofilestop() - start
    local own = ms - childMs[depth]
    depth = depth - 1
    if depth > 0 then childMs[depth] = childMs[depth] + ms end
    charge(owner, source, own)
    return ...
end

-- Times fn(...) and charges it to owner and source, returning everything fn returns. A timed
-- call made inside another (one module calling into another through ns.RunCall) is charged to
-- its own owner, and the outer call only its own share.
function Profiler.Call(owner, source, fn, ...)
    depth = depth + 1
    childMs[depth] = 0
    local start = debugprofilestop()
    return finish(owner, source, start, call(fn, ...))
end

-- Wraps an OnUpdate script (or any function) so its time is charged to `owner` and `source`.
-- Isolated (securecallfunction) whether recording or not, like everything run through ns.Run.
function Profiler.Wrap(owner, source, fn)
    return function(...) return ns.RunCall(owner, source, fn, ...) end
end

local function endOfFrame()
    if frameMs >= SPIKE_MS then
        spikes[#spikes + 1] = { at = GetTime() - started, ms = frameMs, top = frameTop }
        if #spikes > MAX_SPIKES then
            sort(spikes, function(a, b) return a.ms > b.ms end)
            spikes[#spikes] = nil
        end
    end
    frameMs, frameTop, frameTopMs = 0, nil, 0
end

function Profiler.Start()
    stats, spikes, started = {}, {}, GetTime()
    frameMs, frameTop, frameTopMs = 0, nil, 0
    Profiler.recording = true
    ticker:SetScript("OnUpdate", endOfFrame)
end

function Profiler.Stop()
    Profiler.recording = false
    ticker:SetScript("OnUpdate", nil)
    Profiler.seconds = GetTime() - started
end

-- The recording as text: each module's time and calls by source, slowest first, then spikes.
function Profiler.Report()
    local L = ns.L
    if not stats then return L.PROFILER_NOTHING end
    local seconds = Profiler.recording and (GetTime() - started) or Profiler.seconds or 0
    local lines = { format(L.PROFILER_HEADER, seconds) }
    local names = {}
    for name in pairs(stats) do names[#names + 1] = name end
    sort(names, function(a, b) return stats[a].ms > stats[b].ms end)
    for _, name in ipairs(names) do
        local entry = stats[name]
        lines[#lines + 1] = format("%s: %.2f ms, %d calls, %.3f ms/s", name, entry.ms, entry.calls,
            seconds > 0 and entry.ms / seconds or 0)
        local sources = {}
        for source in pairs(entry.sources) do sources[#sources + 1] = source end
        sort(sources, function(a, b) return entry.sources[a].ms > entry.sources[b].ms end)
        for _, source in ipairs(sources) do
            local src = entry.sources[source]
            lines[#lines + 1] = format("    %s: %.2f ms, %d calls", source, src.ms, src.calls)
        end
    end
    if #spikes > 0 then
        sort(spikes, function(a, b) return a.ms > b.ms end)
        lines[#lines + 1] = ""
        lines[#lines + 1] = format(L.PROFILER_SPIKES, SPIKE_MS)
        for _, spike in ipairs(spikes) do
            lines[#lines + 1] = format("    %.1f s: %.2f ms (%s)", spike.at, spike.ms, spike.top or "?")
        end
    end
    return table.concat(lines, "\n")
end
