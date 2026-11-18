--[[
    Forever suite - tests/scenarios/core/codexintegration.lua
    Forever Gearbox's Forever Codex Integration module: offered only while Codex is loaded,
    off by default, and read by Plugin.CodexLoaded/CodexIntegrated.
    Run by tests/run.lua (lua5.1 tests/run.lua codexintegration), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

local function find(frame, test)
    if test(frame) then return frame end
    for _, child in ipairs(frame._children or {}) do
        local got = find(child, test)
        if got then return got end
    end
end

local function texted(text) return function(f) return f._kind == "FontString" and f._text == text end end

W.Strict()
W.withoutForeverPlusPlus = true
local ns = W.LoadAddon(root, "ForeverGearbox")
login()

eq(ns.modules.ForeverCodex.db.enabled, false, "Forever Codex Integration is off by default")
eq(ns.Plugin.CodexLoaded(), false, "Codex API not loaded yet")
eq(ns.Plugin.CodexIntegrated(), false, "not integrated while off")

local entry = W.categories[ns.title]
W.Slash("/fg")
local canvas = entry.frame
eq(find(canvas, texted(ns.L.FCODEX_TITLE)), nil, "not offered while Forever Codex isn't loaded")

W.loaded.ForeverCodex = true
ForeverCodexAPI = { v1 = { IsModuleEnabled = function() return false end } }
check(ns.Plugin.CodexLoaded(), "Codex API loaded")

ns:SetEnabled("ForeverCodex", true)
W.RunTimers()
eq(ns.Plugin.CodexIntegrated(), true, "integrated while module is on and API is there")
ns:SetEnabled("ForeverCodex", false)
eq(ns.Plugin.CodexIntegrated(), false, "not integrated once turned off")

finish()