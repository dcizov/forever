--[[
    Forever Core - Core/DebugReport.lua
    The debug report (/forever debug, the Debug page's Copy Debug Info): the game and addon versions,
    every module with its options, what each module says it's doing (DebugLine), the game's CPU
    profiler figures, and the log.
]]

local _, ns = ...

local ipairs, tostring, format = ipairs, tostring, string.format

-- Everything worth pasting into a bug report.
function ns:DebugInfo()
    local lines = {}
    local function add(...) lines[#lines + 1] = strjoin("", tostringall(...)) end
    local version, build, date, interface = GetBuildInfo()
    for _, member in ipairs(ns.members) do add(member.title, " ", member.version) end
    add("Game ", version, " (build ", build, ", ", date, ", interface ", interface, ")")
    add("Locale ", GetLocale(), ", ", ns.inWorld and "in world" or "loading", InCombatLockdown() and ", in combat" or "")
    local on, total = ns:CountModules()
    add(format("%d of %d modules on", on, total))
    for _, name in ipairs(ns.order) do
        local mod = ns.modules[name]
        add("")
        add(mod.db.enabled and "[on]  " or "[off] ", mod.title, " (", name, ")")
        for _, option in ipairs(mod.options) do
            add("      ", option.key, " = ", tostring(mod.db[option.key]),
                ns.Store.IsDefault(mod, option.key) and " (default)" or "")
        end
        if mod.active and mod.DebugLine then
            -- One module's error doesn't stop the report.
            local ok, line = ns.ChargedCall(mod, "DebugLine", ns.Succeeded, mod.DebugLine, mod)
            add("      ", ok and line or "(DebugLine failed: see the log)")
        end
    end

    if C_AddOnProfiler.IsEnabled() then
        local metric = Enum.AddOnProfilerMetric
        add("")
        add("CPU (game profiler, ms per frame, last 60 frames / peak):")
        for _, member in ipairs(ns.members) do
            add(format("  %s: %.3f / %.3f", member.title, C_AddOnProfiler.GetAddOnMetric(member.name, metric.RecentAverageTime),
                C_AddOnProfiler.GetAddOnMetric(member.name, metric.PeakTime)))
        end
        add(format("  all addons: %.3f, whole game: %.3f", C_AddOnProfiler.GetOverallMetric(metric.RecentAverageTime),
            C_AddOnProfiler.GetApplicationMetric(metric.RecentAverageTime)))
        for _, result in ipairs(C_AddOnProfiler.GetTopKAddOnsForMetric(metric.RecentAverageTime, 5)) do
            add(format("  top: %s %.3f", result.addOnName, result.metricValue))
        end
    end
    add(format("FPS %.0f", GetFramerate()))
    add("")
    add("Log:")
    for _, line in ipairs(ns:GetLog()) do add("  ", line) end
    return table.concat(lines, "\n")
end
