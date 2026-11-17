--[[
    Forever runtime - Shared/UI/Widgets.lua
    Things modules put on screen: round minimap buttons, and small text displays (FPS and
    latency, layer) that move and resize.
]]

local _, ns = ...

local CreateFrame, math, setmetatable = CreateFrame, math, setmetatable

local Widgets = {}
ns.Widgets = Widgets

---------------------------------------------------------------------------
-- Round minimap button: Blizzard's tracking border around an icon, laid out as LibDBIcon does on
-- Mainline clients, at owner.db[angleKey] degrees around the minimap's edge and dragged along it.
--   owner: the module it belongs to. Its clicks, tooltip and drags run as the owner's code
--   (ns.ChargedCall), and a drag saves its setting angleKey with ns:StoreOption.
--   opts: name, icon, angleKey, onClick(self, mouse), onEnter(self) fills GameTooltip (the button
--   shows it). Hiding it ends a drag.
---------------------------------------------------------------------------

-- The round look's pieces around a 31x31 button's 20x20 icon: the dark disc behind it, the
-- tracking border and the mouse-over glow. Returns them.
function Widgets.MinimapButtonArt(b)
    local background = b:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(24, 24)
    background:SetPoint("CENTER")
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(50, 50)
    border:SetPoint("TOPLEFT")
    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    glow:SetBlendMode("ADD")
    glow:SetAllPoints()
    return { background, border, glow }
end

function Widgets.MinimapButton(owner, opts)
    local key = opts.angleKey
    local b = CreateFrame("Button", opts.name, Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    Widgets.MinimapButtonArt(b)
    -- LibDBIcon's and Forever++'s geometry: an 18 px icon in the middle of the border's ring, its
    -- outer 5% trimmed so a round icon's own edge doesn't sit on the ring.
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(opts.icon)
    icon:SetSize(18, 18)
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    icon:SetPoint("CENTER")
    b.icon = icon

    function b:Place()
        local angle = math.rad(owner.db[key])
        local radius = Minimap:GetWidth() / 2 + 10
        self:ClearAllPoints()
        self:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
    end
    local function follow()
        local x, y = Minimap:GetCenter()
        local scale = Minimap:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        ns:StoreOption(owner.name, key, math.floor(math.deg(math.atan2(cy / scale - y, cx / scale - x)) % 360))
        b:Place()
    end
    local drag = ns.Profiler.Wrap(owner, "minimap button drag", follow)

    b:SetScript("OnMouseDown", function() icon:SetPoint("CENTER", 1, -1) end)
    b:SetScript("OnMouseUp", function() icon:SetPoint("CENTER") end)
    b:SetScript("OnClick", function(self, mouse) ns.ChargedCall(owner, "minimap button click", opts.onClick, self, mouse) end)
    b:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", drag)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnEnter", function(self)
        ns.ChargedCall(owner, "tooltip", opts.onEnter, self)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:Place()
    return b
end

---------------------------------------------------------------------------
-- Text display: a line of text on screen, sized to its text (ideas from MiniMeter).
--   * It sits at an anchor (by default just above the quest tracker) with X and Y offsets, set
--     by the Horizontal and Vertical Position sliders, or by dragging it in Edit Mode, where
--     it gets Blizzard's selection box, snapping, arrow-key nudging and a size slider.
--   * It grows away from its anchor: a display anchored by its right edge grows left.
--   * Outside Edit Mode it doesn't move; right-click it for Reset Position and Settings.
-- A module using one passes its anchor to Widgets.DisplayDefaults, adds Widgets.DisplayOptions
-- to its options, and adds the display with Widgets.AddDisplay(module, opts). The display is a
-- part of the module (module:AddPart): it's made the first time the module turns on, shows and
-- joins Edit Mode while it's on, and redraws when its size, outline or place changes. The module
-- only sets its text: display:SetLine(text), display:SetShown(shown).
---------------------------------------------------------------------------

local L = ns.L
local MIN_SIZE, MAX_SIZE = 8, 32
local RANGE_X, RANGE_Y = 1200, 800

local anchorOf = setmetatable({}, { __mode = "k" }) -- a module's defaults -> its display's anchor

-- anchor: { point, relativePoint, x, y }, relative to the quest tracker (the minimap without one),
-- or to opts.relativeTo. Given here once: Widgets.AddDisplay finds it by the module's defaults.
function Widgets.DisplayDefaults(defaults, anchor)
    defaults.size = defaults.size or 12
    if defaults.outline == nil then defaults.outline = true end
    defaults.x, defaults.y = anchor[3], anchor[4]
    anchorOf[defaults] = anchor
    return defaults
end

function Widgets.DisplayOptions(options)
    local list = options or {}
    list[#list + 1] = { key = "size", type = "slider", section = L.SECTION_DISPLAY, label = L.DISPLAY_SIZE,
        min = MIN_SIZE, max = MAX_SIZE, step = 1, format = "%d px", tooltip = L.DISPLAY_SIZE_TIP }
    list[#list + 1] = { key = "outline", type = "checkbox", label = L.DISPLAY_OUTLINE, tooltip = L.DISPLAY_OUTLINE_TIP }
    list[#list + 1] = { key = "x", type = "slider", input = true, label = L.DISPLAY_X, min = -RANGE_X, max = RANGE_X, step = 1,
        tooltip = L.DISPLAY_X_TIP }
    list[#list + 1] = { key = "y", type = "slider", input = true, label = L.DISPLAY_Y, min = -RANGE_Y, max = RANGE_Y, step = 1,
        tooltip = L.DISPLAY_Y_TIP }
    return list
end

local function edgeOf(point)
    return point:find("LEFT") and "LEFT" or point:find("RIGHT") and "RIGHT" or ""
end

-- Where a named point of a box (center cx, cy and size w, h) is.
local function pointOf(point, cx, cy, w, h)
    local x = point:find("LEFT") and cx - w / 2 or point:find("RIGHT") and cx + w / 2 or cx
    local y = point:find("TOP") and cy + h / 2 or point:find("BOTTOM") and cy - h / 2 or cy
    return x, y
end

-- A display is a part of its module (module:AddPart). Its frame is made the first time the module
-- turns on; until then SetLine and SetShown are ignored. What the module wants shown (wantLine,
-- wantShown) is kept apart from what is (frame.current), because in Edit Mode a hidden display
-- shows opts.sample instead, so it can still be found and moved.
local Display = {}
Display.__index = Display

local LOOK = { size = true, outline = true, x = true, y = true }

-- The frame the display's anchor is on: opts.relativeTo, else the quest tracker (the minimap
-- without one).
function Display:AnchorFrame()
    return self.opts.relativeTo or ObjectiveTrackerFrame or Minimap
end

function Display:Place()
    local anchor, f = self.opts.anchor, self.frame
    f:ClearAllPoints()
    f:SetPoint(anchor[1], self:AnchorFrame(), anchor[2], self.mod.db.x, self.mod.db.y)
end

-- Sizes the frame to its text.
function Display:Fit()
    local text = self.text
    self.frame:SetSize(math.max(text:GetUnboundedStringWidth(), 10), math.max(text:GetStringHeight(), 8))
end

-- Font, outline and place from the options; call after any of them changes.
function Display:Apply()
    local db = self.mod.db
    self.text:SetFont(GameFontHighlight:GetFont(), db.size, db.outline and "OUTLINE" or "")
    self.text:SetShadowOffset(db.outline and 0 or 1, db.outline and 0 or -1)
    self:Fit()
    self:Place()
    ns.EditMode.Refresh()
end

function Display:SetText(line)
    local f = self.frame
    if line == f.current then return end
    f.current = line
    self.text:SetText(line)
    self:Fit()
end

-- Shows or hides it as the module wants, or shows the sample while Edit Mode previews a
-- hidden display.
function Display:Refresh()
    local f, sample = self.frame, self.opts.sample
    if self.previewing and not self.wantShown and sample then
        self:SetText(sample)
        f:Show()
    else
        self:SetText(self.wantLine)
        f:SetShown(self.wantShown)
    end
end

-- Edit Mode puts the frame's center at (cx, cy): stored as offsets from the anchor.
function Display:MoveTo(cx, cy)
    local f, anchor, name = self.frame, self.opts.anchor, self.mod.name
    local ratio = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local px, py = pointOf(anchor[1], cx, cy, f:GetWidth() * ratio, f:GetHeight() * ratio)
    local acx, acy, aw, ah = ns.EditMode.Box(self:AnchorFrame())
    if not acx then return end
    local ax, ay = pointOf(anchor[2], acx, acy, aw, ah)
    ns:StoreOption(name, "x", math.floor((px - ax) / ratio + 0.5))
    ns:StoreOption(name, "y", math.floor((py - ay) / ratio + 0.5))
    self:Place()
end

function Display:ResetPosition()
    ns:ResetOption(self.mod.name, "x")
    ns:ResetOption(self.mod.name, "y")
end

function Display:OpenSettings() ns:OpenSettings(self.mod.name) end

-- What Edit Mode is told about the display. Made once, so Edit Mode keeps the selection box it
-- makes for it across Register calls.
function Display:EditInfo()
    local mod = self.mod
    return {
        label = mod.title,
        owner = mod,
        moveTo = function(cx, cy) self:MoveTo(cx, cy) end,
        reset = function() self:ResetPosition() end,
        settings = function() self:OpenSettings() end,
        size = { min = MIN_SIZE, max = MAX_SIZE, step = 1, format = "%d px",
            get = function() return self.mod.db.size end,
            set = function(value) ns:SetOption(mod.name, "size", value) end },
        onActive = function(active)
            self.previewing = active
            self:Refresh()
        end,
    }
end

-- Right-click: Reset Position and Settings, after the entries opts.menu adds (each runs as the
-- module's code).
local function onMouseUp(f, mouse)
    if mouse ~= "RightButton" then return end
    local display = f.display
    local mod = display.mod
    GameTooltip:Hide()
    MenuUtil.CreateContextMenu(f, function(_, root)
        root:CreateTitle(mod.title)
        if display.opts.menu then
            ns.ChargedCall(mod, "menu", display.opts.menu, function(text, fn)
                root:CreateButton(text, function() ns.ChargedCall(mod, "menu", fn) end)
            end)
        end
        root:CreateButton(L.EDITMODE_RESET_POSITION, function() display:ResetPosition() end)
        root:CreateButton(L.SETTINGS, function() display:OpenSettings() end)
    end)
end

local function onEnter(f)
    local fill = f.display.opts.onEnter
    if not fill then return end
    ns.ChargedCall(f.display.mod, "tooltip", fill, f)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.DISPLAY_HINT, 0.1, 1, 0.1, true)
    GameTooltip:Show()
end

function Display:Build()
    local opts = self.opts
    local f = CreateFrame("Frame", opts.name, UIParent)
    f:SetSize(20, 14)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:EnableMouse(not opts.clickThrough)
    f.display = self
    local text = f:CreateFontString(nil, "OVERLAY")
    local edge = edgeOf(opts.anchor[1])
    text:SetPoint(edge == "" and "CENTER" or edge)
    text:SetJustifyH(edge == "" and "CENTER" or edge)
    f:SetScript("OnMouseUp", onMouseUp)
    f:SetScript("OnEnter", onEnter)
    f:SetScript("OnLeave", GameTooltip_Hide)
    self.frame, self.text, self.editInfo = f, text, self:EditInfo()
    self:Apply()
end

function Display:Enable()
    if not self.frame then self:Build() end
    self:SetShown(true)
    ns.EditMode.Register(self.frame, self.editInfo)
end

function Display:Disable()
    ns.EditMode.Unregister(self.frame)
    self.frame:Hide()
end

function Display:Changed(key)
    if LOOK[key] then self:Apply() end
end

-- Its text, and whether it shows. Both are remembered before the module first turns on and
-- applied when the frame is made; turning the module on shows it, so a module sets whether it
-- shows in its OnEnable (which runs after its parts).
function Display:SetLine(line)
    self.wantLine = line
    if self.frame then self:Refresh() end
end

-- The text the module last set (what shows once the frame is made).
function Display:GetLine() return self.wantLine end

function Display:SetShown(shown)
    self.wantShown = shown and true or false
    if self.frame then self:Refresh() end
end

-- The module's defaults went through Widgets.DisplayDefaults, which holds its anchor.
--   opts: name, onEnter(self) fills GameTooltip,
--         menu(add) to add to its right-click menu: add(text, fn) for each entry,
--         relativeTo (the frame the anchor is on; the quest tracker without), sample (the text Edit Mode shows while it's hidden),
--         clickThrough (takes no mouse outside Edit Mode: for text
--         in the middle of the screen, where clicks are meant for the world)
function Widgets.AddDisplay(mod, opts)
    opts.anchor = assert(anchorOf[mod.defaults], "AddDisplay: make the defaults with Widgets.DisplayDefaults")
    local display = setmetatable({ opts = opts, mod = mod,
        wantLine = "", wantShown = true, previewing = false }, Display)
    mod:AddPart(display)
    return display
end
