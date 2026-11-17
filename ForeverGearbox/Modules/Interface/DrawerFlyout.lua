--[[
    Forever Gearbox - Modules/Interface/DrawerFlyout.lua
    Drawer's flyout (Drawer.lua): the buttons a drawer macro opens, in Blizzard's own action bar
    flyout look (Blizzard_Flyout's FlyoutPopupTemplate art: UI-HUD-ActionBar-IconFrame-FlyoutBottom,
    the tiled !UI-HUD-ActionBar-IconFrame-FlyoutMid and -FlyoutButton at its end, turned with its
    direction as Blizzard turns it; buttons in ActionButtonTemplate's art: the icon in its
    UI-HUD-ActionBar-IconFrame mask and frame, pushed and mouseover art, count, cooldown, tooltip).
    It works in combat: everything that acts is secure.

      * One handler per drawer (a SecureHandlerClickTemplate button, ForeverGearboxDrawer<n>,
        covering the screen and hidden): the drawer's macro ends with /click on it. Its snippet
        (restricted code, run by the game) gives the shared action buttons the drawer's actions
        (type "macro", its macrotext), lays them out in a strip from the mouse in the drawer's
        direction, and shows it; clicked again, it closes.
      * The root (ForeverGearboxDrawerRoot): the screen behind the strip while it's open. A click
        anywhere else, or Escape (a click binding while it's shown), closes it. With Close After
        Click, each action's text ends with /click on the root.
      * An action button's look (icon, count, cooldown, tooltip) is set from Lua as its drawer
        opens (the handler's PreClick: textures may change in combat; attributes may not).
    Everything that needs attributes set (Flyout.Set, the direction) is done only out of combat
    (Drawer.lua waits for it to end). The way a macro opens a secure flyout with /click is
    Plumber's idea (its Drawer Macro); this is our own code.
]]

local _, ns = ...

local ipairs, pairs, format, type, math = ipairs, pairs, string.format, type, math
local Plain = ns.Plain

local Flyout = {}
ns.DrawerFlyout = Flyout

local MOST = 24          -- buttons a drawer can have
local SIZE = 36          -- a button, as Blizzard's flyout buttons
local GAP = 4            -- between buttons
local PAD = 5            -- from the strip's edge to the first button
local OFFSET = 18        -- from the mouse to the strip
local ROOT = "ForeverGearboxDrawerRoot"
Flyout.MOST, Flyout.ROOT = MOST, ROOT

local root, strip
local buttons = {}       -- the shared action buttons
local handlers = {}      -- n -> the handler of the n-th drawer
local direction = "UP"

function Flyout.HandlerName(n) return "ForeverGearboxDrawer" .. n end

---------------------------------------------------------------------------
-- The secure parts
---------------------------------------------------------------------------

-- The handler's click, in the game's restricted environment: open this drawer, or close it.
local OPEN = format([=[
    local root = self:GetFrameRef("root")
    local strip = self:GetFrameRef("strip")
    local id = self:GetID()
    if root:IsShown() and root:GetID() == id then
        root:Hide()
        return
    end
    root:SetID(id)
    local count = self:GetAttribute("count") or 0
    local dir = self:GetAttribute("direction") or "UP"
    local size, gap, pad, offset = %d, %d, %d, %d
    for i = 1, %d do
        local button = self:GetFrameRef("button" .. i)
        if i <= count then
            button:SetAttribute("type", "macro")
            button:SetAttribute("macrotext", self:GetAttribute("action" .. i))
            button:ClearAllPoints()
            local step = pad + (i - 1) * (size + gap)
            if dir == "DOWN" then
                button:SetPoint("TOP", strip, "TOP", 0, -step)
            elseif dir == "LEFT" then
                button:SetPoint("RIGHT", strip, "RIGHT", -step, 0)
            elseif dir == "RIGHT" then
                button:SetPoint("LEFT", strip, "LEFT", step, 0)
            else
                button:SetPoint("BOTTOM", strip, "BOTTOM", 0, step)
            end
            button:Show()
        else
            button:Hide()
        end
    end
    local shown = count
    if shown < 1 then shown = 1 end
    local along = pad * 2 + shown * (size + gap) - gap
    local across = size + pad * 2
    local x, y = self:GetMousePosition()
    x = (x or 0.5) * self:GetWidth()
    y = (y or 0.5) * self:GetHeight()
    strip:ClearAllPoints()
    if dir == "DOWN" then
        strip:SetPoint("TOP", self, "BOTTOMLEFT", x, y - offset)
    elseif dir == "LEFT" then
        strip:SetPoint("RIGHT", self, "BOTTOMLEFT", x - offset, y)
    elseif dir == "RIGHT" then
        strip:SetPoint("LEFT", self, "BOTTOMLEFT", x + offset, y)
    else
        strip:SetPoint("BOTTOM", self, "BOTTOMLEFT", x, y + offset)
    end
    if dir == "LEFT" or dir == "RIGHT" then
        strip:SetWidth(along)
        strip:SetHeight(across)
    else
        strip:SetWidth(across)
        strip:SetHeight(along)
    end
    root:Show()
]=], SIZE, GAP, PAD, OFFSET, MOST)
Flyout.OPEN = OPEN

-- The background, as Blizzard's FlyoutPopupMixin:UpdateBackground lays it out for a direction.
local ROTATION = { UP = 0, DOWN = 180, LEFT = 90, RIGHT = 270 }

local function layoutBackground()
    local back = strip.back
    back.start:ClearAllPoints()
    back.finish:ClearAllPoints()
    back.vertical:ClearAllPoints()
    back.horizontal:ClearAllPoints()
    local horizontal = direction == "LEFT" or direction == "RIGHT"
    back.vertical:SetShown(not horizontal)
    back.horizontal:SetShown(horizontal)
    local near = ({ UP = "BOTTOM", DOWN = "TOP", LEFT = "RIGHT", RIGHT = "LEFT" })[direction]
    local far = ({ UP = "TOP", DOWN = "BOTTOM", LEFT = "LEFT", RIGHT = "RIGHT" })[direction]
    back.start:SetPoint(near)
    back.finish:SetPoint(far)
    local middle = horizontal and back.horizontal or back.vertical
    middle:SetPoint(near, back.start, far)
    middle:SetPoint(far, back.finish, near)
    for _, texture in ipairs({ back.start, back.finish, back.vertical, back.horizontal }) do
        SetClampedTextureRotation(texture, ROTATION[direction])
    end
end

-- A button in ActionButtonTemplate's art, acting through its attributes (type "macro").
local function newButton(i)
    local b = CreateFrame("Button", "ForeverGearboxDrawerButton" .. i, strip, "SecureActionButtonTemplate")
    b:SetSize(SIZE, SIZE)
    b:RegisterForClicks("AnyUp")
    b:Hide()
    b.icon = b:CreateTexture(nil, "BACKGROUND")
    b.icon:SetAllPoints()
    local mask = b:CreateMaskTexture()
    mask:SetAtlas("UI-HUD-ActionBar-IconFrame-Mask")
    mask:SetAllPoints(b.icon)
    b.icon:AddMaskTexture(mask)
    b:SetNormalAtlas("UI-HUD-ActionBar-IconFrame")
    b:SetPushedAtlas("UI-HUD-ActionBar-IconFrame-Down")
    b:SetHighlightAtlas("UI-HUD-ActionBar-IconFrame-Mouseover", "ADD")
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", -3, 3)
    b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cooldown:SetAllPoints(b.icon)
    b.cooldown:SetDrawEdge(false)
    b:SetScript("OnEnter", function(self)
        local action = self.action
        if not action then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if action.spellID then
            GameTooltip:SetSpellByID(action.spellID)
        elseif action.itemID then
            GameTooltip:SetItemByID(action.itemID)
        else
            GameTooltip:SetText(action.text, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

-- Made once, out of combat (Drawer.lua's first look at the macros).
local function build()
    root = CreateFrame("Button", ROOT, UIParent,
        "SecureHandlerClickTemplate, SecureHandlerShowHideTemplate, SecureHandlerMouseUpDownTemplate")
    root:Hide()
    root:SetAllPoints(UIParent)
    root:SetFrameStrata("BACKGROUND")
    root:EnableMouse(true)
    root:RegisterForClicks("AnyUp")
    root:SetAttribute("_onclick", [=[ self:Hide() ]=])
    root:SetAttribute("_onmousedown", [=[ self:Hide() ]=])
    root:SetAttribute("_onshow", [=[ self:SetBindingClick(true, "ESCAPE", self) ]=])
    root:SetAttribute("_onhide", [=[ self:ClearBindings() ]=])

    strip = CreateFrame("Frame", nil, root, "SecureFrameTemplate")
    strip:SetFrameStrata("DIALOG")
    strip:SetClampedToScreen(true)
    strip:SetSize(SIZE + PAD * 2, SIZE + PAD * 2)
    local back = CreateFrame("Frame", nil, strip)
    back:SetAllPoints()
    back:SetFrameLevel(strip:GetFrameLevel())
    back.finish = back:CreateTexture(nil, "BACKGROUND")
    back.finish:SetAtlas("UI-HUD-ActionBar-IconFrame-FlyoutButton", true)
    back.horizontal = back:CreateTexture(nil, "BACKGROUND")
    back.horizontal:SetAtlas("_UI-HUD-ActionBar-IconFrame-FlyoutMidLeft", true)
    back.horizontal:SetHorizTile(true)
    back.vertical = back:CreateTexture(nil, "BACKGROUND")
    back.vertical:SetAtlas("!UI-HUD-ActionBar-IconFrame-FlyoutMid", true)
    back.vertical:SetVertTile(true)
    back.start = back:CreateTexture(nil, "BACKGROUND")
    back.start:SetAtlas("UI-HUD-ActionBar-IconFrame-FlyoutBottom", true)
    strip.back = back
    layoutBackground()
    for i = 1, MOST do buttons[i] = newButton(i) end
end

---------------------------------------------------------------------------
-- What Drawer.lua asks (each only out of combat)
---------------------------------------------------------------------------

-- The look an action button takes as its drawer opens: icon, count, cooldown.
local function paint(button, action)
    button.action = action
    button.icon:SetTexture(action.icon or 134400)
    local count = action.itemID and Plain(C_Item.GetItemCount(action.itemID, false, true))
    button.count:SetText(type(count) == "number" and count > 1 and count or "")
    local start, duration
    if action.spellID then
        local info = C_Spell.GetSpellCooldown(action.spellID)
        start, duration = info and Plain(info.startTime), info and Plain(info.duration)
    elseif action.itemID then
        start, duration = C_Item.GetItemCooldown(action.itemID)
        start, duration = Plain(start), Plain(duration)
    end
    if type(start) == "number" and type(duration) == "number" and duration > 1.5 then
        button.cooldown:SetCooldown(start, duration)
    else
        button.cooldown:Clear()
    end
    button.icon:SetDesaturated(action.usable == false)
end

-- The handler of the n-th drawer (made the first time).
function Flyout.Handler(n)
    if not root then build() end
    local handler = handlers[n]
    if handler then return handler end
    handler = CreateFrame("Button", Flyout.HandlerName(n), UIParent, "SecureHandlerClickTemplate")
    handler:Hide()
    handler:SetAllPoints(UIParent)
    handler:SetID(n)
    handler:RegisterForClicks("AnyUp") -- as Plumber registers its handlers, which /click opens
    handler:SetFrameRef("root", root)
    handler:SetFrameRef("strip", strip)
    for i, button in ipairs(buttons) do handler:SetFrameRef("button" .. i, button) end
    handler:SetAttribute("_onclick", OPEN)
    -- Plain Lua before the snippet: the buttons' look for this drawer.
    handler:SetScript("PreClick", function(self)
        for i, action in ipairs(self.actions or {}) do
            if buttons[i] then ns.ChargedCall(Flyout.owner, "drawer look", paint, buttons[i], action) end
        end
    end)
    handlers[n] = handler
    return handler
end

-- Gives the n-th drawer its actions ({ text, icon, spellID, itemID, usable } each, at most MOST).
-- With `close`, an action closes the drawer after it.
function Flyout.Set(n, actions, close)
    local handler = Flyout.Handler(n)
    local count = math.min(#actions, MOST)
    handler.actions = actions
    handler:SetAttribute("count", count)
    handler:SetAttribute("direction", direction)
    for i = 1, MOST do
        local action = i <= count and actions[i]
        handler:SetAttribute("action" .. i, action and (close and action.text .. "\n/click " .. ROOT or action.text) or nil)
    end
end

-- Every drawer from `count` + 1 on has nothing (a macro that was a drawer and isn't now).
function Flyout.Clear(count)
    for n, handler in pairs(handlers) do
        if n > count then
            handler.actions = {}
            handler:SetAttribute("count", 0)
        end
    end
end

-- The direction drawers open in ("UP", "DOWN", "LEFT", "RIGHT").
function Flyout.SetDirection(dir)
    direction = dir
    if not root then return end
    layoutBackground()
    for _, handler in pairs(handlers) do handler:SetAttribute("direction", dir) end
end

function Flyout.Close()
    if root and root:IsShown() then root:Hide() end
end
