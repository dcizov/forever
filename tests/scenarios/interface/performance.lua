--[[
    Forever Tweaks - tests/scenarios/interface/performance.lua
    FPS & Latency's line: each latency choice, colours on and off, hidden with nothing chosen,
    and read again each second.
    Run by tests/run.lua (lua5.1 tests/run.lua performance), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverTweaks")
login()
local mod = ns.modules.Performance
check(mod.active, "on by default")
local frame = _G.ForeverTweaksPerformance
local display = frame.display
local GREEN, YELLOW, RED = "|cff40ff40", "|cffffd100", "|cffff4040"

-- The stand-in game: 58.4 fps, 42 ms home, 71 ms world.
eq(display:GetLine(), GREEN .. "58|r fps   " .. GREEN .. "71|r ms", "by default: fps and world latency, coloured")
ns:SetOption("Performance", "colors", false)
eq(display:GetLine(), "58 fps   71 ms", "colours off: plain numbers")
ns:SetOption("Performance", "latency", "home")
eq(display:GetLine(), "58 fps   42 ms", "home latency")
ns:SetOption("Performance", "latency", "both")
eq(display:GetLine(), "58 fps   42 / 71 ms", "both")
ns:SetOption("Performance", "fps", false)
eq(display:GetLine(), "42 / 71 ms", "latency alone")
check(frame:IsShown(), "shown")
ns:SetOption("Performance", "latency", "off")
eq(frame:IsShown(), false, "nothing chosen: hidden")
check(mod.options[1].conflicts[1].when(mod.db), "and the page says why")

-- Read again each second, coloured by how good it is.
ns:SetOption("Performance", "fps", true)
ns:SetOption("Performance", "colors", true)
W.framerate, W.netStats = 24.6, { 1, 1, 42, 180 }
W.Advance(1)
eq(display:GetLine(), RED .. "25|r fps", "a second later: the new framerate, red below 30")
ns:SetOption("Performance", "latency", "world")
eq(display:GetLine(), RED .. "25|r fps   " .. YELLOW .. "180|r ms", "world latency over 100 is yellow")
finish()
