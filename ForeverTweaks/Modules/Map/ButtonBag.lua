--[[
    Forever Tweaks - Button Bag
    Gathers addons' minimap buttons (Forever Tweaks' own included) into one bag that opens from
    its own button on the minimap (or /ft bag), so the minimap's edge stays clear.

    Which buttons: every LibDBIcon button (most addons use it), any other button on the minimap
    wearing the round minimap-button border, and the few addons' buttons drawn without one, known
    by name (KNOWN: Forever Bestiary's). Map pins, Blizzard's own buttons and protected frames are
    never taken. Right-click the bag's button to choose which buttons go in.
    Turning the module off puts every button back.

    LibDBIcon locks its buttons to the MEDIUM strata at a fixed level (SetFixedFrameStrata /
    SetFixedFrameLevel), so the bag sits at MEDIUM too, and a bagged button is unlocked, raised
    above the bag, and locked again. The bag itself never takes the mouse, so it can't cover a
    button; hovering is checked with IsMouseOver (Forever has no MouseIsOver global).
]]

local _, ns = ...
local L = ns.L

local pairs, ipairs, type, math, strlower, format = pairs, ipairs, type, math, string.lower, string.format

local M = ns:NewModule("ButtonBag", {
    title = L.BUTTONBAG_TITLE,
    category = "map",
    description = L.BUTTONBAG_DESC,
    added = "0.4.0",
    defaults = {
        enabled = true,
        columns = 6,
        autoHide = true,
        closeDelay = 1,
        icon = "forever",
        angle = 225,  -- the bag button's place around the minimap, in degrees
        ignored = {}, -- data: button id -> true, left on the minimap
    },
    options = {
        { key = "columns", type = "slider", label = L.BUTTONBAG_COLUMNS, min = 1, max = 12, step = 1,
          tooltip = L.BUTTONBAG_COLUMNS_TIP },
        { key = "icon", type = "dropdown", label = L.BUTTONBAG_ICON, tooltip = L.BUTTONBAG_ICON_TIP,
          choices = {
              { "forever", L.BUTTONBAG_ICON_FOREVER },
              { "classic", L.BUTTONBAG_ICON_CLASSIC },
              { "backpack", L.BUTTONBAG_ICON_BACKPACK },
          } },
        { key = "autoHide", type = "checkbox", label = L.BUTTONBAG_AUTOHIDE, tooltip = L.BUTTONBAG_AUTOHIDE_TIP,
          slider = "closeDelay" },
        { key = "closeDelay", type = "slider", label = L.BUTTONBAG_DELAY, min = 0.5, max = 5, step = 0.5,
          format = function(v) return format(L.SECONDS, v) end, tooltip = L.BUTTONBAG_DELAY_TIP, added = "1.0.0" },
    },
    -- The Forever Tweaks button only goes into the bag while it's on the minimap.
    notice = {
        { text = L.BUTTONBAG_MBB, shown = function() return ns.OtherAddons.Loaded("MinimapButtonButton") end,
          addon = "MinimapButtonButton", advice = L.BUTTONBAG_ADVICE_MBB },
        {
        text = L.BUTTONBAG_NOTICE,
        tooltip = L.BUTTONBAG_NOTICE_TIP,
        button = L.BUTTONBAG_NOTICE_BUTTON,
        shown = function() return not ns.modules.MinimapButton:IsOnMinimap() end,
        fn = function() ns.modules.MinimapButton:ShowOnMinimap() end,
        },
    },
})

local SIZE, GAP, PAD = 32, 4, 10
local BORDER_FILE_ID = 136430 -- Interface\Minimap\MiniMap-TrackingBorder
local BAG_LEVEL = 50

-- Region methods from Blizzard's own frame metatable, to move bagged buttons while their own
-- SetPoint, ClearAllPoints and SetParent are switched off.
local Meta = getmetatable(UIParent).__index
local noop = function() end

local frame          -- the bag, made the first time the module turns on
local bagButton      -- its button on the minimap (never bagged itself)
local collected = {} -- button -> saved state
local known = {}     -- id -> { button, label }: every button seen, bagged or left out

---------------------------------------------------------------------------
-- Finding buttons
---------------------------------------------------------------------------

local BLIZZARD = { "^Minimap", "^MiniMap", "^GameTime", "^QueueStatus", "^Expansion", "^AddonCompartment",
    "^TimeManager", "^Garrison", "^HybridMinimap", "^ForeverTweaksBag" }

-- Addons' own buttons without the round border, by name -> the name the menu shows.
local KNOWN = { ForeverBestiaryMinimapButton = "Forever Bestiary" }

local function libDBIcon()
    return LibStub and LibStub("LibDBIcon-1.0", true)
end

-- button -> its LibDBIcon name, rebuilt per scan.
local libNames = {}

local function hasMinimapBorder(button)
    for _, region in ipairs({ button:GetRegions() }) do
        if region:IsObjectType("Texture") then
            local texture = region:GetTexture()
            if texture == BORDER_FILE_ID or (type(texture) == "string" and texture:lower():find("trackingborder", 1, true)) then
                return true
            end
        end
    end
    return false
end

local function iconOf(button)
    if button.icon and button.icon.GetTexture then return button.icon:GetTexture() end
    for _, region in ipairs({ button:GetRegions() }) do
        if region:IsObjectType("Texture") and region:GetDrawLayer() == "ARTWORK" then
            return region:GetTexture()
        end
    end
end

local function idOf(button)
    return libNames[button] or button:GetName() or ("unnamed:" .. tostring(iconOf(button)))
end

local function labelOf(button)
    if libNames[button] then return libNames[button] end
    if ns.modules.MinimapButton:IsOurButton(button) then return ns.title end -- the suite's button
    local name = button:GetName()
    if KNOWN[name] then return KNOWN[name] end
    if name then
        local short = name:gsub("^LibDBIcon10_", ""):gsub("_?Mini[Mm]ap_?Button$", "")
        return short ~= "" and short or name
    end
    return L.BUTTONBAG_UNNAMED
end

local function isAddonButton(child)
    if not child:IsObjectType("Button") or child == bagButton or collected[child] then return false end
    if child:IsProtected() then return false end
    if libNames[child] then return true end
    local name = child:GetName()
    if KNOWN[name] then return true end
    if name then
        for _, pattern in ipairs(BLIZZARD) do
            if name:find(pattern) then return false end
        end
    end
    local w, h = child:GetSize()
    if not (w and h and w >= 20 and w <= 40 and h >= 20 and h <= 40) then return false end
    return hasMinimapBorder(child)
end

local function candidates()
    wipe(libNames)
    local list, seen = {}, {}
    local function add(button)
        if button and not seen[button] and isAddonButton(button) then
            seen[button] = true
            list[#list + 1] = button
        end
    end
    local lib = libDBIcon()
    if lib and lib.objects then
        for name, button in pairs(lib.objects) do libNames[button] = name end
        for _, button in pairs(lib.objects) do add(button) end
    end
    for _, parent in ipairs({ Minimap, MinimapBackdrop }) do
        if parent then
            for _, child in ipairs({ parent:GetChildren() }) do add(child) end
        end
    end
    return list
end

---------------------------------------------------------------------------
-- Taking buttons and giving them back
---------------------------------------------------------------------------

local function layout()
    if not frame then return end
    local shown = {}
    for button, state in pairs(collected) do
        if button:IsShown() then shown[#shown + 1] = state end
    end
    table.sort(shown, function(a, b) return strlower(a.label) < strlower(b.label) end)
    local columns = math.max(1, M.db.columns)
    for i, state in ipairs(shown) do
        local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
        Meta.ClearAllPoints(state.button)
        Meta.SetPoint(state.button, "TOPLEFT", frame, "TOPLEFT", PAD + col * (SIZE + GAP), -PAD - row * (SIZE + GAP))
    end
    local count = #shown
    frame.empty:SetShown(count == 0)
    if count == 0 then
        frame:SetSize(200, 50)
    else
        local cols = math.min(columns, count)
        local rows = math.ceil(count / columns)
        frame:SetSize(PAD * 2 + cols * SIZE + (cols - 1) * GAP, PAD * 2 + rows * SIZE + (rows - 1) * GAP)
    end
end

-- Buttons that show or hide (some addons flash theirs) redraw the bag once, on the next frame.
local function requestLayout() M:Soon(layout) end

-- Unlocks a button's strata and level, sets them, and locks them again the way they were.
local function setLayer(button, strata, level, fixedStrata, fixedLevel)
    button:SetFixedFrameStrata(false)
    button:SetFixedFrameLevel(false)
    button:SetFrameStrata(strata)
    button:SetFrameLevel(level)
    button:SetFixedFrameStrata(fixedStrata)
    button:SetFixedFrameLevel(fixedLevel)
end

local function collect(button)
    local strata = button:GetFrameStrata()
    local state = {
        button = button,
        id = idOf(button),
        label = labelOf(button),
        parent = button:GetParent(),
        points = {},
        strata = ns.Plain(strata) or "MEDIUM",
        level = button:GetFrameLevel(),
        -- Probed: the setters are confirmed on Forever (LibDBIcon uses them), these getters aren't.
        fixedStrata = button.HasFixedFrameStrata and button:HasFixedFrameStrata() or false,
        fixedLevel = button.HasFixedFrameLevel and button:HasFixedFrameLevel() or false,
        dragStart = button:GetScript("OnDragStart"),
        dragStop = button:GetScript("OnDragStop"),
    }
    state.points = ns.Points(button)
    collected[button] = state
    known[state.id] = { button = button, label = state.label }

    Meta.SetParent(button, frame)
    -- Locked above the bag, so LibDBIcon can't drop it back under the bag's background.
    setLayer(button, "MEDIUM", BAG_LEVEL + 5, true, true)
    button:SetAlpha(1)
    button:SetScript("OnDragStart", nil)
    button:SetScript("OnDragStop", nil)
    -- Addons move their buttons back onto the minimap (on drag, on refresh): not while bagged.
    button.SetPoint, button.ClearAllPoints, button.SetParent = noop, noop, noop
    -- Hooked once ever (module:HookScript), and only doing anything while it's bagged.
    M:HookScript(button, "OnShow", function() if collected[button] then requestLayout() end end)
    M:HookScript(button, "OnHide", function() if collected[button] then requestLayout() end end)
    M:Debug("bagged", state.label)
end

local function release(button)
    local state = collected[button]
    if not state then return end
    collected[button] = nil
    button.SetPoint, button.ClearAllPoints, button.SetParent = nil, nil, nil
    Meta.SetParent(button, state.parent)
    setLayer(button, state.strata, state.level, state.fixedStrata, state.fixedLevel)
    button:SetScript("OnDragStart", state.dragStart)
    button:SetScript("OnDragStop", state.dragStop)
    Meta.ClearAllPoints(button)
    for _, point in ipairs(state.points) do Meta.SetPoint(button, unpack(point)) end
    M:Debug("put back", state.label)
end

function M:Scan()
    if not (self.active and frame) then return end
    ns:AfterCombat(self, function()
        if not self.active then return end
        for _, button in ipairs(candidates()) do
            local id = idOf(button)
            known[id] = known[id] or { button = button, label = labelOf(button) }
            if not self.db.ignored[id] then collect(button) end
        end
        layout()
    end)
end

function M:Count()
    local n = 0
    for button in pairs(collected) do
        if button:IsShown() then n = n + 1 end
    end
    return n
end

function M:DebugLine()
    return format(L.BUTTONBAG_COUNT, self:Count())
end

---------------------------------------------------------------------------
-- The bag
---------------------------------------------------------------------------

local function newFrame()
    local f = CreateFrame("Frame", "ForeverTweaksButtonBag", UIParent, "TooltipBackdropTemplate")
    f:SetFrameStrata("MEDIUM")
    f:SetFrameLevel(BAG_LEVEL)
    f:SetClampedToScreen(true)
    f:EnableMouse(false) -- never in the way of a button
    f:Hide()
    f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    f.empty:SetPoint("CENTER")
    f.empty:SetText(L.BUTTONBAG_EMPTY)
    tinsert(UISpecialFrames, "ForeverTweaksButtonBag")

    -- Close a moment after the mouse leaves the bag and the button it opened from (checked
    -- five times a second, only while the bag is open; charged to this module by the Profiler).
    local away, tick = 0, 0
    f:SetScript("OnUpdate", ns.Profiler.Wrap(M, "OnUpdate", function(self, elapsed)
        tick = tick + elapsed
        if tick < 0.2 then return end
        if not M.db.autoHide then tick = 0 return end
        local anchor = self.anchor
        if self:IsMouseOver(4, -4, -4, 4) or (anchor and anchor:IsShown() and anchor:IsMouseOver()) then
            away = 0
        else
            away = away + tick
            if away > M.db.closeDelay then self:Hide() end
        end
        tick = 0
    end))
    f:SetScript("OnShow", function() away, tick = 0, 0 end)
    return f
end

function M:Toggle(anchor)
    if not frame then return end
    if frame:IsShown() then
        frame:Hide()
        return
    end
    self:Scan()
    anchor = anchor or bagButton or Minimap
    frame.anchor = anchor
    -- Open toward the middle of the screen.
    local x, y = anchor:GetCenter()
    local w, h = UIParent:GetSize()
    local vertical = (y and y > h / 2) and "TOP" or "BOTTOM"
    local right = x and x > w / 2
    frame:ClearAllPoints()
    frame:SetPoint(vertical .. (right and "RIGHT" or "LEFT"), anchor, vertical .. (right and "LEFT" or "RIGHT"),
        right and -4 or 4, 0)
    frame:Show()
end

-- The bag button's right-click menu: which buttons go in the bag.
local function openMenu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, root) M:AddMenu(root) end)
end

function M:AddMenu(sub)
    sub:CreateTitle(L.BUTTONBAG_IN_BAG)
    local ids = {}
    for id in pairs(known) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b) return strlower(known[a].label) < strlower(known[b].label) end)
    if #ids == 0 then sub:CreateTitle(L.BUTTONBAG_EMPTY) end
    for _, id in ipairs(ids) do
        local entry = known[id]
        sub:CreateCheckbox(entry.label, function() return not self.db.ignored[id] end, function()
            if self.db.ignored[id] then
                self.db.ignored[id] = nil
                self:Scan()
            else
                self.db.ignored[id] = true
                ns:AfterCombat(M, function()
                    if not M.active then return end -- turned off meanwhile: OnDisable released them all
                    release(entry.button)
                    layout()
                end)
            end
        end)
    end
    sub:CreateDivider()
    sub:CreateButton(L.BUTTONBAG_RESCAN, function() self:Scan() end)
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

local function onIconCreated() M:After(0, M.Scan) end

-- The Forever Tweaks button comes and goes with its own module's settings: look again then.
M:OnChanged(function(_, name)
    if name == "MinimapButton" then M:Scan() end
end)

M:AddCommand("bag", nil, L.CMD_BAG, function() M:Toggle() end)

-- The bag button's icon. Square item icons are trimmed so they sit inside the round border.
local ICONS = {
    forever = { file = ns.bagIcon },
    classic = { file = "Interface\\Icons\\INV_Misc_Bag_08", trim = true },
    backpack = { atlas = "hud-backpack" },
}

local function setIcon()
    local icon = bagButton.icon
    local choice = ICONS[M.db.icon] or ICONS.forever
    if choice.atlas then
        icon:SetAtlas(choice.atlas)
        icon:SetTexCoord(0, 1, 0, 1)
        return
    end
    icon:SetTexture(choice.file)
    if choice.trim then
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    else
        icon:SetTexCoord(0, 1, 0, 1)
    end
end

local function fillTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(L.BUTTONBAG_TITLE, 1, 0.82, 0)
    GameTooltip:AddLine(format(L.BUTTONBAG_COUNT, M:Count()), 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.BUTTONBAG_HINT_CLICK, 0.1, 1, 0.1)
    GameTooltip:AddLine(L.BUTTONBAG_HINT_RIGHT, 0.1, 1, 0.1)
    GameTooltip:AddLine(L.MMB_HINT_DRAG, 0.1, 1, 0.1)
end

function M:OnEnable()
    frame = frame or newFrame()
    bagButton = bagButton or ns.Widgets.MinimapButton(self, {
        name = "ForeverTweaksBagButton",
        icon = ns.bagIcon,
        angleKey = "angle",
        onClick = function(button, mouse)
            GameTooltip:Hide()
            if mouse == "RightButton" then openMenu(button) else self:Toggle(button) end
        end,
        onEnter = fillTooltip,
    })
    setIcon()
    bagButton:Show()
    -- On the next frame, once every module (the Forever Tweaks button's included) has started;
    -- then one more look once things settle, for addons that make theirs late without LibDBIcon.
    self:After(0, self.Scan)
    self:After(5, self.Scan)
    -- A button LibDBIcon makes later is taken in too (installed once, idle while off).
    local lib = libDBIcon()
    if lib and lib.RegisterCallback then
        self:HookCallback(lib, "LibDBIcon_IconCreated", function(hook)
            return ns.OtherAddons.Call(M, "LibDBIcon", lib.RegisterCallback, M, "LibDBIcon_IconCreated", hook)
        end, onIconCreated)
    end
end

function M:OnDisable()
    if bagButton then bagButton:Hide() end
    ns:AfterCombat(self, function()
        for button in pairs(collected) do release(button) end
        if frame then frame:Hide() end
    end)
end

function M:OnSettingChanged(key)
    if key == "columns" then
        layout()
    elseif key == "icon" and bagButton then
        setIcon()
    end
end
