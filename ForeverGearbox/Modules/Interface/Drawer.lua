--[[
    Forever Gearbox - Drawer (module key Drawer)
    A drawer macro opens a flyout of spells, items, mounts and other macro lines, from your action
    bar, the way Blizzard's own flyouts (a mage's portals) open, and in combat too. The idea is
    Plumber's Drawer Macro; this is our own code (Plumber has no license).

    A drawer is a macro of yours (account or character) whose first line is #drawer; each line
    after it starting with #/ is an action, written as the macro line it runs without the # (a
    comment, so the macro itself never runs it):

        #drawer
        #/use Hearthstone
        #/cast Teleport: Moonglade
        #/use item:6948

    Drag the macro to an action bar; clicking it opens the drawer at the mouse (DrawerFlyout.lua).
    Blizzard's macro window gets a Drawer panel beside it to make one and fill it by dragging
    spells, items and mounts onto it (DrawerEditor.lua).

    Out of combat, every macro is read (UPDATE_MACROS, and when spells or bags change while Hide
    Unusable is on): each drawer gets the next flyout handler and its macro's last line becomes
    /click on it (written with EditMacro only when it differs; a question-mark icon becomes its first
    action's). In combat that waits until it ends. Turned off, the /click lines come out again.
    Options: the direction drawers open in, Close After Click, Hide Unusable (spells you don't
    know and items you don't have left out).
]]

local _, ns = ...
local L = ns.L

local format, type, tostring, tonumber, strtrim = string.format, type, tostring, tonumber, strtrim
local Flyout = ns.DrawerFlyout

local MARK = "#drawer"
local ACCOUNT_MACROS = 120  -- Constants.MacroConsts.MAX_ACCOUNT_MACROS: character macros come after
local MOST_TEXT = 255       -- a macro's text, at most
local QUESTION_MARK = 134400 -- the icon a new macro without one shows
local CLICK = "/click " .. Flyout.HandlerName("") -- our line's start (letters only: a plain pattern)

local M = ns:NewModule("Drawer", {
    title = L.DRAWER_TITLE,
    category = "interface",
    description = L.DRAWER_DESC,
    added = "3.3.0",
    defaults = { enabled = true, direction = "UP", closeAfter = true, hideUnusable = false },
    options = {
        { key = "direction", type = "dropdown", label = L.DRAWER_DIRECTION, tooltip = L.DRAWER_DIRECTION_TIP,
          choices = { { "UP", L.DRAWER_UP }, { "DOWN", L.DRAWER_DOWN }, { "LEFT", L.DRAWER_LEFT }, { "RIGHT", L.DRAWER_RIGHT } } },
        { key = "closeAfter", type = "checkbox", label = L.DRAWER_CLOSE, tooltip = L.DRAWER_CLOSE_TIP },
        { key = "hideUnusable", type = "checkbox", label = L.DRAWER_HIDE, tooltip = L.DRAWER_HIDE_TIP },
    },
})
Flyout.owner = M

local Drawer = {}
ns.Drawer = Drawer
Drawer.MARK = MARK

---------------------------------------------------------------------------
-- Reading a drawer
---------------------------------------------------------------------------

-- Whether a macro's text is a drawer's: its first line is #drawer.
function Drawer.IsDrawer(body)
    local first = type(body) == "string" and body:match("^[^\n]*") or ""
    return strtrim(first):lower() == MARK
end

-- What an action line names: the spell or item after its command, conditions ([...]) left out.
local function targetOf(text)
    local rest = text:match("^/%a+%s+(.+)$")
    if not rest then return nil end
    rest = strtrim(rest:gsub("%b[]", ""))
    return rest ~= "" and rest or nil
end

-- An action from a line ("/use Hearthstone"): its text, and what it is (spellID or itemID,
-- icon), as far as the game knows it.
function Drawer.Action(text)
    local action = { text = text }
    local target = targetOf(text)
    if not target then return action end
    local itemID = tonumber(target:match("^item:(%d+)"))
    if not itemID then
        local spell = C_Spell.GetSpellInfo(target)
        if spell and spell.spellID then
            action.spellID, action.icon = spell.spellID, spell.iconID
            return action
        end
        itemID = C_Item.GetItemInfoInstant(target)
    end
    if itemID then
        action.itemID = itemID
        action.icon = C_Item.GetItemIconByID(itemID)
    end
    return action
end

-- Whether you can use an action now: a spell you know, an item you have; a line that's neither
-- (a /say, a /click) always.
local function usable(action)
    if action.spellID then return C_SpellBook.IsSpellKnown(action.spellID) and true or false end
    if action.itemID then return (C_Item.GetItemCount(action.itemID) or 0) > 0 end
    return true
end

-- A drawer's actions: each #/ line after the first, as Drawer.Action reads it.
function Drawer.Actions(body, hideUnusable)
    local actions = {}
    local first = true
    for line in (body .. "\n"):gmatch("([^\n]*)\n") do
        if first then
            first = false
        else
            local text = line:match("^#(/.+)$")
            if text then
                local action = Drawer.Action(strtrim(text))
                action.usable = usable(action)
                if not hideUnusable or action.usable then actions[#actions + 1] = action end
            end
        end
    end
    return actions
end

-- A drawer macro's text without our /click line, and with it for handler `n`.
function Drawer.WithoutClick(body)
    local lines = {}
    for line in (body .. "\n"):gmatch("([^\n]*)\n") do
        if not line:find(CLICK .. "%d+%s*$") then lines[#lines + 1] = line end
    end
    while lines[#lines] == "" do lines[#lines] = nil end
    return table.concat(lines, "\n")
end

local function withClick(body, n)
    return Drawer.WithoutClick(body) .. "\n/click " .. Flyout.HandlerName(n)
end

---------------------------------------------------------------------------
-- Every macro, out of combat
---------------------------------------------------------------------------

-- Each macro's index, account macros then character macros.
local function eachMacro(fn)
    local account, character = GetNumMacros()
    for i = 1, account or 0 do fn(i) end
    for i = ACCOUNT_MACROS + 1, ACCOUNT_MACROS + (character or 0) do fn(i) end
end

local told = {} -- macro names said once to be too long for the /click line

local function rebuild()
    if InCombatLockdown() then return ns:AfterCombat(M, rebuild) end
    local count = 0
    eachMacro(function(index)
        local name, icon, body = GetMacroInfo(index)
        if not Drawer.IsDrawer(body) then return end
        if not M.active then
            -- Off: our line comes out, the macro stays as you wrote it.
            local plain = Drawer.WithoutClick(body)
            if plain ~= body then EditMacro(index, nil, nil, plain) end
            return
        end
        count = count + 1
        local actions = Drawer.Actions(body, M.db.hideUnusable)
        Flyout.Set(count, actions, M.db.closeAfter)
        local wanted = withClick(body, count)
        if #wanted > MOST_TEXT then
            if not told[name] then
                told[name] = true
                M:Print(format(L.DRAWER_TOO_LONG, tostring(name)))
            end
            return
        end
        local newIcon = icon == QUESTION_MARK and actions[1] and actions[1].icon or nil
        if wanted ~= body or newIcon then EditMacro(index, nil, newIcon, wanted) end
    end)
    Flyout.Clear(count)
    M.drawers = count
end

local function rebuildSoon() M:Soon(rebuild) end
Drawer.Rebuild = rebuildSoon

function M:OnEnable()
    Flyout.SetDirection(self.db.direction)
    self:RegisterEvent("UPDATE_MACROS", rebuildSoon)
    self:RegisterEvent("SPELLS_CHANGED", function() if self.db.hideUnusable then rebuildSoon() end end)
    self:RegisterEvent("BAG_UPDATE_DELAYED", function() if self.db.hideUnusable then rebuildSoon() end end)
    self:RegisterEvent("PLAYER_REGEN_DISABLED", function() Flyout.Close() end)
    rebuild()
end

function M:OnDisable()
    Flyout.Clear(0)
    -- Our /click lines out of every drawer (after combat, if need be).
    rebuild()
end

function M:OnSettingChanged(key)
    if key == "direction" then
        if InCombatLockdown() then
            ns:AfterCombat(self, function() Flyout.SetDirection(self.db.direction) end)
        else
            Flyout.SetDirection(self.db.direction)
        end
    end
    rebuild()
end

function M:DebugLine() return format(L.DRAWER_DEBUG, self.drawers or 0) end
