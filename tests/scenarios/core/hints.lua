--[[
    Forever Gearbox - tests/scenarios/core/hints.lua
    The settings hints (module notices) about other addons, console variables and game options,
    on Forever Gearbox' own page: each shows only while something needs doing (and its module is
    on); a console variable's has a button setting it.
    Run by tests/run.lua (lua5.1 tests/run.lua hints), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverGearbox")
local B = W.UseBaganator()
login()

-- The notice of `module` with this text, and whether it shows now.
local function notice(module, text)
    local mod = ns.modules[module]
    for _, n in ipairs(mod.notice) do
        if n.text == text then return n, (not n.shown or n.shown(mod.db)) and true or false end
    end
    error("no notice " .. tostring(text) .. " in " .. module)
end
local function showing(module, text) return select(2, notice(module, text)) end
local L = ns.L

-- Console variables, asked for the way Plumber asks: an orange line, then "- Set CVar name to value".
W.cvars.nameplateShowFriendlyNpcs = "0"
ns:SetEnabled("LayerInfo", true)
local Requires = ns.Options.Requires
local asked
for _, n in ipairs(ns.modules.LayerInfo.notice) do
    if n.requires and n.requires[1].cvar == "nameplateShowFriendlyNpcs" then asked = n end
end
check(asked ~= nil and Requires.Missing(asked.requires), "friendly NPC nameplates off: Layer Info asks for them")
local text = Requires.Text(asked.requires)
check(text:find("|cffd4641c" .. L.REQUIRES_HEADER, 1, true) ~= nil, "under Plumber's orange line")
check(text:find("- Set CVar |cffffd100nameplateShowFriendlyNpcs|r to |cffffffff1|r", 1, true) ~= nil, "naming the CVar and its value")
Requires.Set(ns.modules.LayerInfo, asked.requires)
eq(W.cvars.nameplateShowFriendlyNpcs, "1", "its button sets it")
check(not Requires.Missing(asked.requires), "then the request is gone")

-- Baganator shows our marks only from an icon corner of the profile in use.
eq(showing("QuestItems", L.QUESTITEMS_BAGANATOR), false, "our widgets in a corner: no hint")
eq(showing("FullBags", L.FULL_BAGANATOR), false, "Full Bags' too")
for _, list in pairs(B.corners) do
    for i = #list, 1, -1 do
        if tostring(list[i]):find("^ForeverTweaks_") then table.remove(list, i) end
    end
end
eq(showing("QuestItems", L.QUESTITEMS_BAGANATOR), true, "taken out of every corner: Quest Items says so")
eq(showing("FullBags", L.FULL_BAGANATOR), true, "and Full Bags")
ns:SetOption("FullBags", "borders", false)
eq(showing("FullBags", L.FULL_BAGANATOR), false, "not with Number What to Delete off")
BAGANATOR_CURRENT_PROFILE = "Gone"
eq(showing("QuestItems", L.QUESTITEMS_BAGANATOR), false, "a profile it can't read: no guess")

-- Only about addons that are installed.
eq(showing("FullBags", L.FULL_NOTICE), false, "no Auctionator: nothing about it in Full Bags")
W.loaded.Auctionator = true
eq(showing("FullBags", L.FULL_NOTICE), true, "Auctionator without prices: Full Bags says to scan")
eq(showing("ButtonBag", L.BUTTONBAG_MBB), false, "no MinimapButtonButton: no hint")
W.loaded.MinimapButtonButton = true
eq(showing("ButtonBag", L.BUTTONBAG_MBB), true, "MinimapButtonButton loaded: pick one")

eq(#W.errors, 0, "no errors")
_G.Baganator = nil
finish()
