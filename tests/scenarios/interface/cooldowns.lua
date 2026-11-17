--[[
    Forever Gearbox - tests/scenarios/interface/cooldowns.lua
    Cooldown Layout on stand-ins for Blizzard's Cooldown Manager viewers: tracked buffs closed up
    from the centre (no gap where a buff isn't up), buff bars stacked from the bottom, Essential
    rows centred with new rows below, each viewer left to Blizzard when asked, and the key of each
    ability's action button on its icon (a spell, or a macro casting it).
    Run by tests/run.lua (lua5.1 tests/run.lua cooldowns), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

-- A viewer with `count` item frames (`bar`: buff bars). The stand-in frames are all 100 x 20,
-- whatever size they're given, so the places below are in those.
local function newViewer(name, count, w, h, bar)
    local frame = W.NewFrame("Frame", name, UIParent)
    frame.iconLimit, frame.childXPadding, frame.childYPadding, frame.isHorizontal = 4, 2, 2, true
    frame.layouts = 0
    function frame:Layout() self.layouts = self.layouts + 1 end
    frame.items = {}
    for i = 1, count do
        local item = W.NewFrame("Frame", nil, frame)
        item:SetSize(w, h)
        item.layoutIndex = i
        if bar then item.Bar = W.NewFrame("StatusBar", nil, item) else item.Icon = item:CreateTexture() end
        item.cooldownID = 100 + i
        function item:OnActiveStateChanged() end
        frame.items[i] = item
    end
    _G[name] = frame
    return frame
end
local essential = newViewer("EssentialCooldownViewer", 6, 40, 40)
local utility = newViewer("UtilityCooldownViewer", 2, 30, 30)
local buffIcons = newViewer("BuffIconCooldownViewer", 4, 30, 30)
local buffBars = newViewer("BuffBarCooldownViewer", 3, 200, 20, true)
-- The cooldown each icon is for: Essential's first two are spells 5001 and 5002.
C_CooldownViewer = { GetCooldownViewerCooldownInfo = function(id)
    return { spellID = 4900 + id - 100 + 100 }
end }
-- Blizzard's action bars: ActionButton1 holds spell 5001 on "1", ActionButton2 a macro casting
-- 5002 on "S-2"; the rest are empty.
local actions = { [1] = { "spell", 5001 }, [2] = { "macro", 7 } }
function GetActionInfo(slot) local a = actions[slot]; if a then return a[1], a[2] end end
function GetMacroSpell(index) if index == 7 then return 5002 end end
RANGE_INDICATOR = "*"
NumberFontNormal = { GetFont = function() return "Fonts\\ARIALN.TTF", 12, "OUTLINE" end }
for _, bar in ipairs({ "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
    "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button" }) do
    for i = 1, 12 do
        local button = W.NewFrame("Button", bar .. i, UIParent)
        button.action = bar == "ActionButton" and i or (100 + i)
        button.HotKey = button:CreateFontString()
        button.HotKey:SetText(bar == "ActionButton" and ({ "1", "S-2" })[i] or RANGE_INDICATOR)
        _G[bar .. i] = button
    end
end

W.Strict()
local ns = W.LoadAddon(root, "ForeverGearbox")
login()
ns:SetEnabled("CooldownLayout", true)
W.RunTimers()

local function at(item) return { item:GetPoint() } end

-- Tracked buffs: two of four up, closed up round the centre.
buffIcons.items[1]:Hide()
buffIcons.items[3]:Hide()
buffIcons:Layout()
W.RunTimers()
local a, b = at(buffIcons.items[2]), at(buffIcons.items[4])
eq(a[1], "TOP", "buffs placed from the row's centre")
eq(a[4], -51, "the first half its width and a gap left of centre")
eq(b[4], 51, "the second as far right of it")

-- Buff bars: the ones up stacked from the bottom, no gap.
buffBars.items[1]:Hide()
buffBars:Layout()
W.RunTimers()
eq(at(buffBars.items[2])[1], "BOTTOM", "bars from the bottom")
eq(at(buffBars.items[2])[5], 0, "the first bar at the bottom")
eq(at(buffBars.items[3])[5], 22, "the next right on top of it")

-- Essential: six icons, four a row: a row of four, then two centred below.
essential:Layout()
W.RunTimers()
eq(at(essential.items[1])[4], -153, "row one centred")
eq(at(essential.items[5])[5], -22, "the new row below")
eq(at(essential.items[5])[4], -51, "and centred too")

-- Keybinds: a spell's own button, and a macro casting it.
local key1, key2 = essential.items[1].ftKeybind, essential.items[2].ftKeybind
eq(key1 and key1:GetText(), "1", "the key of the spell's button")
eq(key2 and key2:GetText(), "S-2", "the key of a macro casting it")
check(not (essential.items[3].ftKeybind and essential.items[3].ftKeybind:IsShown()), "nothing for a spell on no button")
ns:SetOption("CooldownLayout", "keybinds", false)
check(not key1:IsShown(), "Show Keybinds off: none")
ns:SetOption("CooldownLayout", "keybinds", true)
check(key1:IsShown(), "and back")

-- A viewer set to Blizzard's own: laid out by it again, and left alone.
local before = essential.layouts
ns:SetOption("CooldownLayout", "essential", "off")
check(essential.layouts > before, "Blizzard's layout again")
essential.items[1]:ClearAllPoints()
essential:Layout()
W.RunTimers()
eq(#at(essential.items[1]), 0, "then left alone")

-- Off: everything back to Blizzard's, no keys.
ns:SetEnabled("CooldownLayout", false)
check(not key1:IsShown(), "off: no keys")
check(utility.layouts > 0, "each viewer laid out by Blizzard again")
finish()
