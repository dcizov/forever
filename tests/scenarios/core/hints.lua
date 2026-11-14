--[[
    Forever Tweaks - tests/scenarios/core/hints.lua
    The settings hints (module notices) about other addons, console variables and game options:
    each shows only while something needs doing, and its button does it.
    Run by tests/run.lua (lua5.1 tests/run.lua hints), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
local ns = W.LoadAddon(root, "ForeverTweaks")
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

-- Fishing Cast does what Forever++'s Fishing Cast and Auto Weapon Buff do: while theirs is on, its
-- page says so, with a button opening Forever++ there.
local function covered(module, what)
    local text = L.COVERED_BY:format("Forever++", what)
    return notice(module, text), showing(module, text)
end
local fpp, opened = { FishingCast = false, AutoWeaponBuff = true }, nil
eq(select(2, covered("FishingCast", L.FCAST_WHAT_CAST)), false, "no Forever++: nothing")
W.loaded.ForeverPlusPlus = true
ForeverPlusPlusAPI = { v1 = {
    IsModuleEnabled = function(name) return fpp[name] end,
    OpenSettings = function(name) opened = name; return true end,
} }
eq(select(2, covered("FishingCast", L.FCAST_WHAT_CAST)), false, "its Fishing Cast off: ours casts, no notice")
eq(select(2, covered("FishingCast", L.FCAST_WHAT_LURE)), true, "its Auto Weapon Buff on: left to it, said so")
covered("FishingCast", L.FCAST_WHAT_LURE).fn()
eq(opened, "AutoWeaponBuff", "the button opens Forever++ there")
ForeverPlusPlusAPI.v1.IsModuleEnabled = function() error("Forever++ broke") end
eq(select(2, covered("FishingCast", L.FCAST_WHAT_LURE)), false, "Forever++ failing: nothing")
eq(#W.errors, 0, "and its error isn't ours")
W.loaded.ForeverPlusPlus = nil

-- The Chat Window's Keep Chat Visible hint opens Forever++ there.
ForeverPlusPlusAPI.v1.IsModuleEnabled = function(name) return name == "PersistentChat" end
ns:SetOption("ChatFade", "messages", true)
eq(showing("ChatFade", L.CHATFADE_KEEP_VISIBLE), true, "Keep Chat Visible on: the hint shows")
notice("ChatFade", L.CHATFADE_KEEP_VISIBLE).fn()
eq(opened, "PersistentChat", "its button opens Forever++ on it")
ForeverPlusPlusAPI = nil

-- Console variables, asked for the way Plumber asks: an orange line, then "- Set CVar name to value".
-- The row on the open settings page whose text has `part`, if it's shown.
local function shownRow(part)
    for i = #W.frames, 1, -1 do
        local f = W.frames[i]
        if f._kind == "FontString" and type(f._text) == "string" and f._text:find(part, 1, true) then
            local row = f:GetParent()
            if row:IsVisible() then return row end
        end
    end
end
local function buttonOf(row)
    for _, c in ipairs(row._children or {}) do if c._kind == "Button" then return c end end
end
W.cvars.equipmentManager = "0"
ns:OpenSettings("Fishing")
local row = shownRow("equipmentManager")
check(row ~= nil, "the Equipment Manager off: the Fishing page asks for it")
local text = ""
for i = #W.frames, 1, -1 do
    local f = W.frames[i]
    if f._kind == "FontString" and f:GetParent() == row then text = f._text end
end
check(text:find("|cffd4641c" .. L.REQUIRES_HEADER, 1, true) ~= nil, "under Plumber's orange line")
check(text:find("- Set CVar |cffffd100equipmentManager|r to |cffffffff1|r", 1, true) ~= nil, "naming the CVar and its value")
buttonOf(row):Fire("OnClick")
eq(W.cvars.equipmentManager, "1", "its button sets it")
W.RunTimers()
W.Advance(1)
ns:OpenSettings("Fishing")
eq(shownRow("equipmentManager"), nil, "then the request is gone")
W.cvars.nameplateShowFriendlyNpcs = "0"
ns:OpenSettings("LayerInfo")
check(shownRow("nameplateShowFriendlyNpcs") ~= nil, "Layer Info asks for friendly NPC nameplates the same way")

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
eq(showing("GatherSession", L.GATHERSESSION_NO_AUCTION), false, "no Auctionator: nothing about it")
eq(showing("FullBags", L.FULL_NOTICE), false, "in Full Bags either")
W.loaded.Auctionator = true
eq(showing("GatherSession", L.GATHERSESSION_NO_AUCTION), true, "Auctionator without prices: scan the auction house")
eq(showing("FullBags", L.FULL_NOTICE), true, "Full Bags too")
eq(showing("ButtonBag", L.BUTTONBAG_MBB), false, "no MinimapButtonButton: no hint")
W.loaded.MinimapButtonButton = true
eq(showing("ButtonBag", L.BUTTONBAG_MBB), true, "MinimapButtonButton loaded: pick one")

-- The Tweaks for Addons page lists what to set in each installed addon, done or to do.
ForeverPlusPlusAPI = { v1 = { IsModuleEnabled = function(name) return name == "PersistentChat" end,
    OpenSettings = function(name) opened = name; return true end } }
ns:SetOption("ChatFade", "messages", true)
W.loaded.ForeverPlusPlus = true
C_SettingsUtil.OpenSettingsPanel(L.CATEGORY_ADDONS)
check(shownRow("Forever++") ~= nil, "a section titled Forever++, as a module's title")
check(shownRow(L.ADDONS_SETTINGS_IN:format("Forever++")) ~= nil, "with a line under it, as a module's description")
eq(shownRow("Baganator"), nil, "Baganator isn't loaded here: no section for it")
eq(shownRow(L.DJSKIN_TITLE), nil, "nor for DungeonJournal, which isn't loaded")
W.loaded.ForeverDungeonJournal = true
W.categories[L.CATEGORY_ADDONS].frame:Hide()
C_SettingsUtil.OpenSettingsPanel(L.CATEGORY_ADDONS) -- shown again, the page looks again
check(shownRow(L.DJSKIN_TITLE) ~= nil, "loaded: its section shows, titled Dungeon Journal")
check(shownRow(L.CHATFADE_ADVICE_KEEP_VISIBLE) ~= nil, "with Forever++'s Keep Chat Visible")
check(shownRow(L.FULL_ADVICE_AUCTION) ~= nil, "Auctionator, installed")
eq(shownRow(L.CHATFADE_ADVICE_CHATTYNATOR), nil, "not Chattynator, which isn't")
local keep = shownRow(L.CHATFADE_ADVICE_KEEP_VISIBLE)
buttonOf(keep):Fire("OnClick")
eq(opened, "PersistentChat", "its button opens Forever++ there")
local state
for i = #W.frames, 1, -1 do
    local f = W.frames[i]
    if f._kind == "FontString" and f:GetParent() == keep and f._text ~= L.CHATFADE_ADVICE_KEEP_VISIBLE then state = f._text end
end
check(state and state:find("ReadyCheck-Waiting", 1, true) ~= nil, "still to do: marked so")
ForeverPlusPlusAPI = nil

-- Every hint's page draws.
for _, name in ipairs({ "Fishing", "FishingCast", "QuestItems", "FullBags", "GatherSession", "ButtonBag", "ChatFade", "LayerInfo" }) do
    ns:OpenSettings(name)
end
_G.Baganator = nil
finish()
