--[[
    Forever Tweaks - FPS & Latency
    A small line with your framerate and latency, updated once a second (the game's own figures:
    GetFramerate, and GetNetStats' local and world latency). Its tooltip has the details,
    including which addons use the most CPU (the game's own profiler, the same numbers as
    Blizzard's performance tooltip), to find what makes the game stutter.
]]

local _, ns = ...
local L = ns.L

local GetFramerate, GetNetStats, format, floor, ipairs = GetFramerate, GetNetStats, string.format, math.floor, ipairs

-- Just above the quest tracker, under the minimap: left of center, growing left.
local ANCHOR = { "BOTTOMRIGHT", "TOP", -8, 6 }

local function nothingShown(db) return not db.fps and db.latency == "off" end

local M = ns:NewModule("Performance", {
    title = L.PERF_TITLE,
    category = "interface",
    description = L.PERF_DESC,
    added = "0.7.0",
    defaults = ns.Widgets.DisplayDefaults({
        enabled = true,
        fps = true,
        latency = "world",
        colors = true,
    }, ANCHOR),
    options = ns.Widgets.DisplayOptions({
        { key = "fps", type = "checkbox", label = L.PERF_FPS, tooltip = L.PERF_FPS_TIP,
          conflicts = { { key = "latency", when = nothingShown, text = L.PERF_NOTHING } } },
        { key = "latency", type = "dropdown", label = L.PERF_LATENCY, tooltip = L.PERF_LATENCY_TIP,
          choices = {
              { "world", L.PERF_WORLD },
              { "home", L.PERF_LOCAL },
              { "both", L.PERF_BOTH },
              { "off", L.OFF },
          } },
        { key = "colors", type = "checkbox", label = L.PERF_COLORS, tooltip = L.PERF_COLORS_TIP },
    }),
})

local display -- added below, once the functions it uses are

local function fpsColor(fps)
    if fps >= 50 then return "|cff40ff40" elseif fps >= 30 then return "|cffffd100" end
    return "|cffff4040"
end

local function msColor(ms)
    if ms <= 100 then return "|cff40ff40" elseif ms <= 250 then return "|cffffd100" end
    return "|cffff4040"
end

-- One reading ("58 fps"), its number tinted by colorOf(value) when colored is on.
local function reading(value, unit, colorOf, colored)
    if colored then return format("%s%d|r %s", colorOf(value), value, unit) end
    return format("%d %s", value, unit)
end

local function update()
    local db = M.db
    local colors = db.colors
    local text
    if db.fps then text = reading(floor(GetFramerate() + 0.5), "fps", fpsColor, colors) end
    local mode = db.latency
    if mode ~= "off" then
        local _, _, home, world = GetNetStats()
        local ms
        if mode == "home" then
            ms = reading(home, "ms", msColor, colors)
        elseif mode == "world" then
            ms = reading(world, "ms", msColor, colors)
        else
            ms = reading(home, "/", msColor, colors) .. " " .. reading(world, "ms", msColor, colors)
        end
        text = text and (text .. "   " .. ms) or ms
    end
    display:SetLine(text or "")
    display:SetShown(text ~= nil)
end

-- A share of CPU as the game's AddOns list shows it: this addon's time against all the time
-- it could have been charged. nil while the game's profiler is off.
local function cpuShare(addon)
    if not C_AddOnProfiler.IsEnabled() then return end
    local metric = Enum.AddOnProfilerMetric.RecentAverageTime
    local value = C_AddOnProfiler.GetAddOnMetric(addon, metric)
    local total = C_AddOnProfiler.GetApplicationMetric(metric) - C_AddOnProfiler.GetOverallMetric(metric) + value
    return total > 0 and value / total * 100 or 0
end

local function fillTooltip(self)
    local bandIn, bandOut, home, world = GetNetStats()
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(L.PERF_TITLE, 1, 0.82, 0)
    GameTooltip:AddDoubleLine(L.PERF_FRAMERATE, format("%.0f fps", GetFramerate()), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(L.PERF_LOCAL_LATENCY, format("%d ms", home), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(L.PERF_WORLD_LATENCY, format("%d ms", world), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(L.PERF_BANDWIDTH, format("%.1f / %.1f KB/s", bandIn, bandOut), 1, 1, 1, 1, 1, 1)
    if C_AddOnProfiler.IsEnabled() then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.PERF_TOP_CPU, 1, 0.82, 0)
        local top = C_AddOnProfiler.GetTopKAddOnsForMetric(Enum.AddOnProfilerMetric.RecentAverageTime, 5)
        for _, result in ipairs(top) do
            GameTooltip:AddDoubleLine(result.addOnName, format("%.1f%%", cpuShare(result.addOnName)), 1, 1, 1, 1, 1, 1)
        end
        -- Each Forever addon's own share (the suite's core and every member loaded).
        for _, member in ipairs(ns.members) do
            GameTooltip:AddDoubleLine(member.title, format("%.2f%%", cpuShare(member.name)), 0.6, 0.6, 0.6, 0.6, 0.6, 0.6)
        end
    end
end

display = ns.Widgets.AddDisplay(M, { name = "ForeverTweaksPerformance", onEnter = fillTooltip })

function M:OnEnable()
    update()
    self:NewTicker(1, update) -- cancelled with the module
end

function M:OnSettingChanged()
    update()
end

-- For the public API.
function M:GetNumbers()
    local _, _, home, world = GetNetStats()
    return GetFramerate(), home, world
end
