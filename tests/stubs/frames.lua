--[[
    Forever Gearbox - tests/stubs/frames.lua
    The stand-in game's frames, loaded first by tests/wow.lua: CreateFrame and W.NewFrame, the
    methods the addon relies on behaving like the game's, and a generic answer for any other
    method named like a game method (Get*/Is* return plain defaults, everything else records what
    it was given). Under W.Strict() a name not in W.METHODS is reported.
]]

local VERBS = { "Get", "Set", "Is", "Has", "Can", "Create", "Register", "Unregister", "Enable", "Disable",
    "Show", "Hide", "Clear", "Hook", "Raise", "Lower", "Start", "Stop", "Play", "Add", "Remove", "Update",
    "Init", "Highlight", "Click", "Lock", "Unlock", "Apply", "Release", "Acquire", "Scroll", "Insert",
    "Select", "Reset", "Refresh", "Setup", "Layout", "Mark", "Adjust", "Cancel", "Toggle", "Open",
    "Close", "Save", "Rebuild", "Invalidate", "Validate", "Generate", "Should", "Flash", "Resize" }

local function isMethod(key)
    for _, verb in ipairs(VERBS) do
        if key:sub(1, #verb) == verb and (#key == #verb or key:sub(#verb + 1, #verb + 1):match("%u")) then return true end
    end
end

W.events = {}  -- event -> { frame = true }
W.frames = {}

local Frame = {}
W.FrameMethods = Frame -- the methods every stand-in frame has (wow.lua gives UIParent them as its metatable)

local defaults = {
    GetWidth = 100, GetHeight = 20, GetLeft = 0, GetRight = 100, GetTop = 20, GetBottom = 0,
    GetEffectiveScale = 1, GetScale = 1, GetFrameLevel = 1, GetFrameStrata = "MEDIUM", GetNumPoints = 0,
    GetStringWidth = 50, GetUnboundedStringWidth = 50, GetLineHeight = 12, GetStringHeight = 12, GetAlpha = 1, GetID = 0, GetValue = 0,
    GetObjectType = "Frame", GetVerticalScroll = 0, GetVerticalScrollRange = 0, GetNumLetters = 0,
}

function Frame:SetAtlas(atlas, useAtlasSize) self._atlas, self._useAtlasSize = atlas, useAtlasSize end
function Frame:GetAtlas() return self._atlas end
function Frame:GetTexture() return self._texture end
-- Sizes are recorded, not used: GetWidth and GetHeight keep their defaults above.
function Frame:SetWidth(width) self._width = width end
function Frame:SetSize(width, height) self._width, self._height = width, height end
function Frame:SetTexture(texture) self._texture = texture end
function Frame:SetScale(scale) self._scale = scale end
function Frame:SetIgnoreParentAlpha(v) self._ignoreParentAlpha = v end
function Frame:SetShadowOffset(x, y) self._shadowOffset = { x, y } end
function Frame:SetShadowColor() end
function Frame:GetScale() return self._scale or 1 end
function Frame:SetFontObject(font) self._fontObject = font end
function Frame:SetDesaturated(on) self._desaturated = on and true or false end
function Frame:SetHyperlink(link) self._hyperlink = link end
function Frame:GetText() return self._text end
function Frame:SetText(text) self._text = text end
function Frame:GetChecked() return self._checked end
function Frame:SetChecked(v) self._checked = v and true or false end
function Frame:IsShown() return self._shown ~= false end
-- Shown, and every parent too, as in the game.
function Frame:IsVisible()
    local f = self
    while f do
        if f._shown == false then return false end
        f = f._parent
    end
    return true
end
-- A protected frame (made from a Secure template) can't be shown, hidden, moved or given
-- attributes by addon code in combat: the game blocks it (ADDON_ACTION_BLOCKED). Here it's an error.
W.blocked = {}
local function guard(self, what)
    if self._protected and W.combat and not W.restricted then
        W.blocked[#W.blocked + 1] = what
        W.errors[#W.errors + 1] = "blocked in combat: " .. what .. " on a protected frame"
        return true
    end
end
function Frame:SetAttribute(key, value)
    if guard(self, "SetAttribute") then return end
    self._attrs = self._attrs or {}
    self._attrs[key] = value
end
function Frame:GetAttribute(key) return self._attrs and self._attrs[key] end
function Frame:Show() if guard(self, "Show") then return end local was = self:IsShown(); self._shown = true; if not was then self:Fire("OnShow") end end
function Frame:Hide() if guard(self, "Hide") then return end local was = self:IsShown(); self._shown = false; if was then self:Fire("OnHide") end end
function Frame:SetShown(v) if v then self:Show() else self:Hide() end end
function Frame:GetName() return self._name end
function Frame:SetID(id) self._id = id end
function Frame:SetFrameLevel(level) self._level = level end
function Frame:GetFrameLevel() return self._level or 1 end
function Frame:GetID() return self._id or 0 end
function Frame:GetParent() return self._parent end
function Frame:SetParent(p) self._parent = p end
function Frame:IsObjectType() return true end
function Frame:IsMouseOver() return false end
function Frame:IsProtected() return false end
function Frame:IsEnabled() return self._enabled ~= false end
function Frame:Enable() self._enabled = true end
function Frame:Disable() self._enabled = false end
function Frame:SetEnabled(v) self._enabled = v and true or false end
function Frame:GetSize() return self:GetWidth(), self:GetHeight() end
function Frame:GetCenter() return 50, 10 end
-- As the game gives it: point, relativeTo (the parent when left out), relativePoint (the
-- point when left out), x, y, whichever of SetPoint's short forms set it.
function Frame:GetPoint()
    local p = self._point
    if not p then return end
    local point, a, b, c, d = p[1], p[2], p[3], p[4], p[5]
    if type(a) == "number" then return point, self._parent, point, a, b or 0 end
    if type(b) == "number" then return point, a, point, b, c or 0 end
    return point, a or self._parent, b or point, c or 0, d or 0
end
function Frame:GetNumPoints() return self._point and 1 or 0 end
function Frame:ClearAllPoints() self._point = nil end
function Frame:SetPoint(point, ...)
    if guard(self, "SetPoint") then return end
    -- The game refuses a point that isn't a plain string (a secret one included).
    if type(point) ~= "string" or issecretvalue(point) then
        error('SetPoint(): Usage: ("point" [, region or nil] [, "relativePoint"] [, offsetX, offsetY]', 2)
    end
    self._point = { point, ... }
end
function Frame:GetChildren() return unpack(self._children or {}) end
-- Its font strings and textures, in the order made (the game keeps them apart from child frames;
-- here GetChildren lists them too).
function Frame:GetRegions()
    local regions = {}
    for _, child in ipairs(self._children or {}) do
        if child._kind == "FontString" or child._kind == "Texture" then regions[#regions + 1] = child end
    end
    return unpack(regions)
end
function Frame:GetObjectType() return self._kind or "Frame" end
function Frame:SetScrollChild(child) self._scrollChild = child end
function Frame:GetScrollChild() return self._scrollChild end
function Frame:GetFont() return self._fontFile or "Fonts\\FRIZQT__.TTF", self._fontSize or 12, self._fontFlags or "" end
function Frame:SetFont(file, size, flags) self._fontFile, self._fontSize, self._fontFlags = file, size, flags end
function Frame:SetValue(v) self._value = v end
function Frame:SetTextColor(r, g, b) self._textColor = { r, g, b } end
function Frame:GetTextColor()
    local c = self._textColor or { 1, 0.82, 0 }
    return c[1], c[2], c[3], 1
end
-- Status bars' and textures' tints, kept to be read back (Class Colors puts Blizzard's back).
function Frame:SetStatusBarColor(r, g, b, a) self._barColor = { r, g, b, a } end
function Frame:GetStatusBarColor()
    local c = self._barColor or { 0, 1, 0 }
    return c[1], c[2], c[3], c[4] or 1
end
function Frame:SetStatusBarDesaturated(on) self._barDesaturated = on and true or false end
function Frame:IsStatusBarDesaturated() return self._barDesaturated or false end
function Frame:SetVertexColor(r, g, b, a) self._vertexColor = { r, g, b, a } end
function Frame:GetVertexColor()
    local c = self._vertexColor or { 1, 1, 1 }
    return c[1], c[2], c[3], c[4] or 1
end
function Frame:GetScript(name) return self._scripts[name] end
function Frame:SetScript(name, fn) self._scripts[name] = fn end
function Frame:HookScript(name, fn)
    local old = self._scripts[name]
    self._scripts[name] = old and function(...) old(...) fn(...) end or fn
end
function Frame:Click(mouse) return self:Fire("OnClick", mouse or "LeftButton") end
-- Whether a key the frame hears goes on to the game (Dialogue Keys).
function Frame:SetPropagateKeyboardInput(on)
    if InCombatLockdown() then W.errors[#W.errors + 1] = "SetPropagateKeyboardInput in combat" end
    self._propagate = on
end
function Frame:Fire(name, ...)
    local fn = self._scripts[name]
    if fn then return fn(self, ...) end
end
function Frame:RegisterEvent(event)
    assert(W.validEvent(event), "RegisterEvent: no such event " .. tostring(event))
    W.events[event] = W.events[event] or {}
    W.events[event][self] = true
end
function Frame:UnregisterEvent(event) if W.events[event] then W.events[event][self] = nil end end
function Frame:UnregisterAllEvents() for _, set in pairs(W.events) do set[self] = nil end end
function Frame:CreateTexture(name) return W.NewFrame("Texture", name, self) end
function Frame:CreateFontString(name) return W.NewFrame("FontString", name, self) end
function Frame:GetEditBox() return self.EditBox end
function Frame:SetupMenu(fn) self._menu = fn end
function Frame:SetColorTexture(r, g, b, a) self._color = { r, g, b, a } end
-- Texture:SetGradient (SimpleTextureBaseAPI): the orientation and a colour mixin at each end,
-- the first at the bottom in Forever (see the sky gradient in Modules/Interface/Visuals.lua).
function Frame:SetGradient(orientation, minColor, maxColor)
    self._gradient = { orientation, minColor, maxColor }
end
function Frame:SetAlpha(a) self._alpha = a end
function Frame:GetAlpha() return self._alpha or 1 end
function Frame:EnableMouse(on) self._mouse = on and true or false end
-- Hover and clicks apart (a map pin that lets clicks through to the map).
function Frame:SetMouseMotionEnabled(on) self._motion = on and true or false end
function Frame:SetMouseClickEnabled(on) self._clicks = on and true or false end
function Frame:IsMouseClickEnabled() return self._clicks ~= false end
-- A dropdown's button text from its selections (WowStyle1Dropdown's DropdownSelectionTextMixin).
function Frame:SetSelectionText(fn) self._selectionText = fn end
function Frame:GetSelectionText() return self._selectionText and self._selectionText({}) end
function Frame:HasFixedFrameStrata() return false end
function Frame:HasFixedFrameLevel() return false end

local FrameMT = {
    __index = function(self, key)
        local method = Frame[key]
        if method then return method end
        if type(key) ~= "string" or not key:match("^%u") then return nil end
        if isMethod(key) then
            if W.PROBED[key] then return nil end
            if W.strict and not W.METHODS[key] then W.missing["frame method " .. key] = true end
            local default = defaults[key]
            if default ~= nil then return function() return default end end
            if key:match("^Get.*Texture$") or key:match("^Get.*FontString$") then
                return function(s)
                    local t = rawget(s, "_" .. key) or W.NewFrame("Texture", nil, s)
                    rawset(s, "_" .. key, t)
                    return t
                end
            end
            if key:match("^Get") or key:match("^Is") or key:match("^Has") or key:match("^Can") or key:match("^Should") then
                return function() return nil end
            end
            if key:match("^Create") then return function(s) return W.NewFrame(key:sub(7), nil, s) end end
            return function(s) return nil end
        end
        -- A child a template would make (Text, Label, Slider, ScrollBar, ...).
        local child = W.NewFrame("Frame", nil, self)
        rawset(self, key, child)
        return child
    end,
}

function W.NewFrame(kind, name, parent)
    local f = setmetatable({ _scripts = {}, _kind = kind, _name = name, _parent = parent }, FrameMT)
    if name then _G[name] = f end
    if parent and type(parent) == "table" and rawget(parent, "_scripts") then
        local children = rawget(parent, "_children") or {}
        rawset(parent, "_children", children)
        children[#children + 1] = f
    end
    W.frames[#W.frames + 1] = f
    return f
end

-- Children a template makes that aren't capitalized (the stand-in makes capitalized ones on
-- first use): ActionButtonTemplate's icon texture (Blizzard_ActionBar/Mainline/ActionButtonTemplate.xml).
local TEMPLATE_CHILDREN = { ActionButtonTemplate = { icon = "Texture" }, SmallActionButtonTemplate = { icon = "Texture" },
    ButtonFrameTemplate = { Inset = "Frame", CloseButton = "Button" } }

-- Blizzard_SharedXML/Backdrop.lua: BackdropTemplate's methods, copied onto each frame made from
-- it (so a hook on the mixin reaches frames made after it). Colour calls do nothing once cleared.
BackdropTemplateMixin = {}
function BackdropTemplateMixin:SetBackdrop(info) self.backdropInfo = info end
function BackdropTemplateMixin:ClearBackdrop() self.backdropInfo = nil end
function BackdropTemplateMixin:SetBackdropColor(...) if self.backdropInfo then self._backdropColor = { ... } end end
function BackdropTemplateMixin:SetBackdropBorderColor(...) if self.backdropInfo then self._borderColor = { ... } end end
function BackdropTemplateMixin:GetBackdropBorderColor() return unpack(self._borderColor or { 1, 1, 1, 1 }) end

-- What some templates' mixins do, copied onto each frame made from them.
W.TEMPLATE_METHODS = {}

-- Blizzard_SharedXML/Shared/TabSystem/TabSystemTemplates.lua: AddTab makes a tab button (its
-- click selects it through the callback), SetTab and SetTabVisuallySelected mark one.
local TabSystem = {}
W.TEMPLATE_METHODS.TabSystemTemplate = TabSystem
function TabSystem:SetTabSelectedCallback(fn) self._onTab = fn end
function TabSystem:AddTab(text)
    self._tabs = rawget(self, "_tabs") or {}
    local id = #self._tabs + 1
    local tab = CreateFrame("Button", nil, self, "TabSystemButtonTemplate")
    tab.tabID, tab.tabText = id, text
    tab:SetText(text)
    tab:SetScript("OnClick", function() self:SetTab(id, true) end)
    self._tabs[id] = tab
    return id
end
function TabSystem:SetTab(id, isUser)
    if not self._onTab(id, isUser) then self:SetTabVisuallySelected(id) end
end
function TabSystem:SetTabVisuallySelected(id) self.selectedTabID = id end
function TabSystem:GetTabButton(id) return self._tabs[id] end
function TabSystem:MarkDirty() end
W.TEMPLATE_METHODS.TabSystemButtonTemplate = {
    UpdateTabText = function(self) self:SetText(self.tabText) end,
    UpdateTabWidth = function() end,
}

-- LargeSideTabButtonTemplate (SidePanelTabButtonMixin): checked or not, and a mouse-up handler
-- (W.ClickSideTab presses it).
W.TEMPLATE_METHODS.LargeSideTabButtonTemplate = {
    SetChecked = function(self, on) self._checked = on and true or false end,
    GetChecked = function(self) return self._checked == true end,
    SetCustomOnMouseUpHandler = function(self, fn) self._mouseUp = fn end,
}
function W.ClickSideTab(tab) tab._mouseUp(tab, "LeftButton", true) end

function CreateFrame(kind, name, parent, template)
    local f = W.NewFrame(kind, name, parent)
    f._template = template
    if tostring(template):find("BackdropTemplate", 1, true) then
        for key, fn in pairs(BackdropTemplateMixin) do f[key] = fn end
    end
    for each in tostring(template):gmatch("[%w_]+") do
        for key, childKind in pairs(TEMPLATE_CHILDREN[each] or {}) do f[key] = W.NewFrame(childKind, nil, f) end
        for key, fn in pairs(W.TEMPLATE_METHODS[each] or {}) do f[key] = fn end
    end
    f._protected = type(template) == "string" and template:find("Secure") ~= nil
    return f
end

-- Blizzard_SharedXML/Shared/Scroll/ScrollUtil.lua: joins a scroll frame to a scroll bar (here it
-- only remembers the bar; the frame's own scrolling stand-in does the rest).
ScrollUtil = {}
function ScrollUtil.InitScrollFrameWithScrollBar(scroll, bar) scroll._scrollBar = bar end

-- Blizzard_SharedXMLBase/Pools: a frame pool (TabSystemTemplate keeps its tabs in one).
function CreateFramePool(kind, parent, template)
    local pool = { active = {} }
    function pool:Acquire()
        local f = CreateFrame(kind, nil, parent, template)
        self.active[#self.active + 1] = f
        return f, true
    end
    function pool:ReleaseAll() self.active = {} end
    return pool
end

-- Mask textures: made and added, nothing drawn.
function Frame:CreateMaskTexture() return W.NewFrame("MaskTexture", nil, self) end
