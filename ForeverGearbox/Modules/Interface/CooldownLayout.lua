--[[
    Forever Gearbox - Cooldown Layout
    How Blizzard's Cooldown Manager lays out its four viewers, and the key each ability is bound to
    on its icon:
      * Tracked Buff Icons (BuffIconCooldownViewer): the buffs up now, closed up from the start,
        the centre or the end of the row (Blizzard's leaves a gap where a buff isn't up).
      * Tracked Buff Bars (BuffBarCooldownViewer): the bars up now, stacked from the bottom or the
        top.
      * Essential and Utility Icons: each row of icons centred, new rows below the first or above
        it.
      * Show Keybinds: on each Essential and Utility icon, the key of the action button its spell
        (or a macro casting it) is on, as that button shows it (Blizzard's bars).
    Each choice can be Blizzard's ("off": that viewer is left alone). The icons are Blizzard's own:
    after a viewer lays itself out (its Layout, and a buff turning on or off) they're only moved,
    so Edit Mode still places and sizes each viewer. A vertical viewer is left as Blizzard lays it.
    The idea of Cooldown Manager Centered by Wildu (all rights reserved: its look and choices,
    none of its code).
]]

local _, ns = ...
local L = ns.L

local ipairs, pairs, type, math, sort = ipairs, pairs, type, math, table.sort
local Plain = ns.Plain

local VIEWERS = {
    essential = "EssentialCooldownViewer", utility = "UtilityCooldownViewer",
    buffIcons = "BuffIconCooldownViewer", buffBars = "BuffBarCooldownViewer",
}
-- Blizzard's action bars: each button's name and how many there are.
local BARS = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
    "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button" }
local BUTTONS = 12
local KEY_EVENTS = { "UPDATE_BINDINGS", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
    "PLAYER_ENTERING_WORLD" }

local ICON_GROWTH = { { "start", L.CDLAYOUT_START }, { "center", L.CDLAYOUT_CENTER }, { "end", L.CDLAYOUT_END },
    { "off", L.CDLAYOUT_OFF } }
local BAR_GROWTH = { { "bottom", L.CDLAYOUT_BOTTOM }, { "top", L.CDLAYOUT_TOP }, { "off", L.CDLAYOUT_OFF } }
local ROW_GROWTH = { { "below", L.CDLAYOUT_BELOW }, { "above", L.CDLAYOUT_ABOVE }, { "off", L.CDLAYOUT_OFF } }

local M = ns:NewModule("CooldownLayout", {
    title = L.CDLAYOUT_TITLE,
    category = "interface",
    group = L.GROUP_COMBAT,
    description = L.CDLAYOUT_DESC,
    added = "3.2.0",
    defaults = { enabled = false, buffIcons = "center", buffBars = "bottom", essential = "below", utility = "below",
        keybinds = true, keybindSize = 12 },
    options = {
        { key = "buffIcons", type = "dropdown", label = L.CDLAYOUT_BUFF_ICONS, tooltip = L.CDLAYOUT_BUFF_ICONS_TIP,
          choices = ICON_GROWTH },
        { key = "buffBars", type = "dropdown", label = L.CDLAYOUT_BUFF_BARS, tooltip = L.CDLAYOUT_BUFF_BARS_TIP,
          choices = BAR_GROWTH },
        { key = "essential", type = "dropdown", label = L.CDLAYOUT_ESSENTIAL, tooltip = L.CDLAYOUT_ROWS_TIP,
          choices = ROW_GROWTH },
        { key = "utility", type = "dropdown", label = L.CDLAYOUT_UTILITY, tooltip = L.CDLAYOUT_ROWS_TIP,
          choices = ROW_GROWTH },
        { key = "keybinds", type = "checkbox", label = L.CDLAYOUT_KEYBINDS, tooltip = L.CDLAYOUT_KEYBINDS_TIP,
          slider = "keybindSize" },
        { key = "keybindSize", type = "slider", label = L.CDLAYOUT_KEYBIND_SIZE, tooltip = L.CDLAYOUT_KEYBIND_SIZE_TIP,
          min = 8, max = 20, step = 1, requires = "keybinds" },
    },
})

---------------------------------------------------------------------------
-- The viewers' icons
---------------------------------------------------------------------------

local function viewer(key) return _G[VIEWERS[key]] end

-- A viewer's item frames (its icons or bars), shown ones only, in Blizzard's order. Its
-- children directly: Blizzard's own list of them is sorted in a table addons mustn't touch.
local function shownItems(frame)
    local list = {}
    for _, child in ipairs({ frame:GetChildren() }) do
        if child.layoutIndex and (child.Icon or child.Bar) and child:IsShown() then list[#list + 1] = child end
    end
    sort(list, function(a, b) return a.layoutIndex < b.layoutIndex end)
    return list
end

local function place(item, frame, point, x, y)
    item:ClearAllPoints()
    item:SetPoint(point, frame, point, x, y)
end

-- Icons in rows of the viewer's width (iconLimit), each row closed up from `from` ("start",
-- "center", "end"), new rows below the first (`down`) or above it.
local function layIcons(frame, items, from, down)
    if #items == 0 then return end
    local per = math.max(1, frame.iconLimit or #items)
    local w, h = items[1]:GetWidth(), items[1]:GetHeight()
    local padX, padY = frame.childXPadding or 2, frame.childYPadding or 2
    local edge = down and "TOP" or "BOTTOM"
    for first = 1, #items, per do
        local row = math.floor((first - 1) / per)
        local count = math.min(per, #items - first + 1)
        local width = count * w + (count - 1) * padX
        local y = row * (h + padY) * (down and -1 or 1)
        for i = 0, count - 1 do
            local item = items[first + i]
            if from == "start" then
                place(item, frame, edge .. "LEFT", i * (w + padX), y)
            elseif from == "end" then
                place(item, frame, edge .. "RIGHT", -i * (w + padX), y)
            else
                place(item, frame, edge, -width / 2 + w / 2 + i * (w + padX), y)
            end
        end
    end
end

-- Bars stacked from the bottom or the top, with no gap where a bar isn't up.
local function layBars(frame, items, fromBottom)
    local padY = frame.childYPadding or 2
    for i, item in ipairs(items) do
        local step = (i - 1) * (item:GetHeight() + padY)
        if fromBottom then place(item, frame, "BOTTOM", 0, step) else place(item, frame, "TOP", 0, -step) end
    end
end

local layoutAll -- after the hooks it installs

-- A buff's icon or bar turning on or off: lay its viewer out again (once, next frame).
local function hookItems(frame)
    for _, child in ipairs({ frame:GetChildren() }) do
        if child.layoutIndex and type(child.OnActiveStateChanged) == "function" then
            M:Hook(child, "OnActiveStateChanged", function() M:Soon(layoutAll) end)
        end
    end
end

local function layOut(key)
    local frame = viewer(key)
    local mode = M.db[key]
    if not frame or mode == "off" or frame.isHorizontal == false then return end
    hookItems(frame)
    local items = shownItems(frame)
    if key == "buffBars" then
        layBars(frame, items, mode == "bottom")
    elseif key == "buffIcons" then
        layIcons(frame, items, mode, true)
    else
        layIcons(frame, items, "center", mode == "below")
    end
end

---------------------------------------------------------------------------
-- Keybinds
---------------------------------------------------------------------------

-- Spell ID -> the key text its action button shows, from Blizzard's bars (first bar first).
local function keysBySpell()
    local keys = {}
    for _, bar in ipairs(BARS) do
        for i = 1, BUTTONS do
            local button = _G[bar .. i]
            local slot = button and button.action
            local text = button and button.HotKey and Plain(button.HotKey:GetText())
            if slot and type(text) == "string" and text ~= "" and text ~= RANGE_INDICATOR then
                local kind, id = GetActionInfo(slot)
                kind, id = Plain(kind), Plain(id)
                if kind == "macro" then kind, id = "spell", Plain(GetMacroSpell(id)) end
                if kind == "spell" and id and not keys[id] then keys[id] = text end
            end
        end
    end
    return keys
end

-- The spell an icon is for (its cooldown's), or nil.
local function spellOf(item)
    local id = Plain(item.cooldownID)
    local info = id and C_CooldownViewer.GetCooldownViewerCooldownInfo(id)
    return info and (Plain(info.overrideSpellID) or Plain(info.spellID)) or nil
end

local function keyText(item)
    local text = item.ftKeybind
    if not text then
        text = item:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        text:SetPoint("TOPRIGHT", -1, -2)
        item.ftKeybind = text
    end
    local file, _, flags = NumberFontNormal:GetFont()
    text:SetFont(file, M.db.keybindSize, flags)
    return text
end

-- Each Essential and Utility icon's key, while Show Keybinds is on (`off`: none, the module
-- turning off).
local function refreshKeys(off)
    local on = not off and M.db.keybinds
    local keys = on and keysBySpell() or {}
    for _, name in ipairs({ "essential", "utility" }) do
        local frame = viewer(name)
        for _, child in ipairs(frame and { frame:GetChildren() } or {}) do
            if child.layoutIndex and child.Icon then
                local spell = on and spellOf(child)
                local bound = spell and keys[spell]
                if bound then
                    local text = keyText(child)
                    text:SetText(bound)
                    text:Show()
                elseif child.ftKeybind then
                    child.ftKeybind:Hide()
                end
            end
        end
    end
end

-- Keys again once next frame, however often asked (one function, so M:Soon runs it once).
local function keysNow() refreshKeys() end

---------------------------------------------------------------------------
-- Turning on and off
---------------------------------------------------------------------------

function layoutAll()
    for key in pairs(VIEWERS) do layOut(key) end
    refreshKeys()
end

local function hookViewers()
    for key in pairs(VIEWERS) do
        local frame = viewer(key)
        if frame then
            M:Hook(frame, "Layout", function()
                layOut(key)
                M:Soon(keysNow)
            end)
        end
    end
end

-- Blizzard's own layout again (a viewer set back to "off", or the module off).
local function blizzardLayout()
    for key in pairs(VIEWERS) do
        local frame = viewer(key)
        if frame and type(frame.Layout) == "function" and (not M.active or M.db[key] == "off") then frame:Layout() end
    end
end

function M:OnEnable()
    hookViewers()
    for _, event in ipairs(KEY_EVENTS) do self:RegisterEvent(event, function() self:Soon(keysNow) end) end
    self:Soon(layoutAll)
end

function M:OnDisable()
    blizzardLayout()
    refreshKeys(true)
end

function M:OnSettingChanged()
    blizzardLayout()
    layoutAll()
end

function M:DebugLine()
    local shown = 0
    for key in pairs(VIEWERS) do
        local frame = viewer(key)
        if frame then shown = shown + #shownItems(frame) end
    end
    return L.CDLAYOUT_DEBUG:format(shown)
end
