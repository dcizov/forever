--[[
    Forever Core - UI/MapPins.lua
    Pins on the world map and the minimap, for modules that show places (Forever Tweaks' Gathering
    Map, Forever Compendium's quest and rare pins). The module says what to draw; this keeps the
    frames, as a part of the module (Core/Module.lua: it stops with it).

      * World map: a holder of ours on the map's canvas (WorldMapFrame.ScrollContainer.Child),
        drawn only while the map is open, and again when it changes map or scale; pins keep their
        size on screen however far you zoom (sized against WorldMapFrame:GetCanvasScale).
      * Minimap: what's within the minimap's reach, placed by its distance in yards from you
        (C_Map.GetMapWorldSize) against the minimap's radius at its zoom (indoors and out differ),
        turned with it when Rotate Minimap is on. Looked at five times a second while there's
        something on your map, not at all otherwise (zone changes look again); hidden in instances.

    A pin is a spec the module makes: { x, y (0..1 on the map), atlas (or texture, a file),
    color ({ r, g, b, a } tint), size (px; else the layer's) or span (a share of the map's width,
    for an area that grows with the map), gray (desaturated), layer (drawn over lower ones), and
    anything the module wants back in its tooltip or click }.

    MapPins.World(mod, opts) and MapPins.Minimap(mod, opts), where opts has:
      specs(mapID)            the pins on `mapID` (asked only while shown)
      shown()                 whether this layer draws at all (the module being on is checked too)
      size()                  the pins' size in px
      tooltip(pin, spec)      fills and shows GameTooltip
      click(pin, spec, mouse) world map only, optional: a right-click on a pin
      level                   optional: frame levels above the other layers (pins over areas)
    Each returns the layer: layer.Refresh() draws it again (call it when what it shows changes).
]]

local _, ns = ...

local ipairs, math = ipairs, math
local CreateFrame = CreateFrame
local Plain = ns.Plain

local MapPins = {}
ns.MapPins = MapPins

local EVERY = 0.2 -- seconds between the minimap's looks
-- Above the map: Blizzard's map art and pins take frame levels from 2000 up (Blizzard_MapCanvas's
-- PinFrameLevelsManager), not from the canvas's, so a holder just over the canvas is drawn under
-- the map itself.
local WORLD_LEVEL = 2100
-- The minimap's radius in yards at each zoom (0 to 5), outdoors and indoors (as GatherMate2 has them).
local OUTDOOR = { 233.33, 200, 166.67, 133.33, 100, 66.67 }
local INDOOR = { 150, 120, 90, 60, 40, 25 }
local ZONE_EVENTS = { "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS" }

-- A pin frame on `holder` whose mouse runs the module's tooltip (and click).
local function newPin(mod, opts, holder, kind)
    local pin = CreateFrame(kind, nil, holder)
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetAllPoints()
    pin:SetScript("OnEnter", function(self) ns.RunCall(mod, "map pin", opts.tooltip, self, self.spec) end)
    pin:SetScript("OnLeave", GameTooltip_Hide)
    if opts.click and kind == "Button" then
        pin:RegisterForClicks("RightButtonUp")
        pin:SetScript("OnClick", function(self, mouse) ns.RunCall(mod, "map pin click", opts.click, self, self.spec, mouse) end)
    end
    return pin
end

-- Shows pin `i` of `pins` (made when needed) as `spec` at `size` px.
local function showPin(layer, i, spec, size)
    local pin = layer.pins[i] or newPin(layer.mod, layer.opts, layer.holder, layer.kind)
    layer.pins[i] = pin
    pin.spec = spec
    if spec.atlas then pin.icon:SetAtlas(spec.atlas) else pin.icon:SetTexture(spec.texture) end
    local color = spec.color
    if color then pin.icon:SetVertexColor(color[1], color[2], color[3], color[4] or 1) else pin.icon:SetVertexColor(1, 1, 1, 1) end
    pin.icon:SetDesaturated(spec.gray or false)
    pin:SetSize(size, size)
    pin:SetFrameLevel(layer.holder:GetFrameLevel() + (spec.layer or 0))
    pin:ClearAllPoints()
    pin:Show()
    return pin
end

local function hideFrom(layer, first)
    for i = first, #layer.pins do layer.pins[i]:Hide() end
end

local function wanted(layer)
    return layer.mod.active and layer.opts.shown()
end

---------------------------------------------------------------------------
-- World map
---------------------------------------------------------------------------

local function drawWorld(layer)
    if not layer.holder then return end
    local shown = 0
    if wanted(layer) and WorldMapFrame:IsShown() then
        local mapID = WorldMapFrame:GetMapID()
        local canvas = layer.holder:GetParent()
        local width, height = canvas:GetWidth(), canvas:GetHeight()
        local scale = WorldMapFrame:GetCanvasScale()
        local size = layer.opts.size()
        for _, spec in ipairs(layer.opts.specs(mapID)) do
            shown = shown + 1
            local px = spec.span and spec.span * width or (spec.size or size) / scale
            local pin = showPin(layer, shown, spec, px)
            pin:SetPoint("CENTER", canvas, "TOPLEFT", spec.x * width, -spec.y * height)
        end
    end
    hideFrom(layer, shown + 1)
end

function MapPins.World(mod, opts)
    local layer = { mod = mod, opts = opts, pins = {}, kind = "Button" }
    local function drawSoon() mod:Soon(function() drawWorld(layer) end) end
    function layer.Refresh()
        -- The world map loads on demand: the holder is made once it's there.
        if mod.active and not layer.holder and WorldMapFrame then
            local canvas = WorldMapFrame.ScrollContainer.Child
            layer.holder = CreateFrame("Frame", nil, canvas)
            layer.holder:SetAllPoints(canvas)
            layer.holder:SetFrameLevel(canvas:GetFrameLevel() + WORLD_LEVEL + (opts.level or 0))
            mod:Hook(WorldMapFrame, "OnMapChanged", drawSoon)
            mod:Hook(WorldMapFrame, "OnCanvasScaleChanged", drawSoon)
            mod:HookScript(WorldMapFrame, "OnShow", drawSoon)
        end
        drawWorld(layer)
    end
    layer.Enable, layer.Disable, layer.Changed = layer.Refresh, layer.Refresh, layer.Refresh
    mod:AddPart(layer)
    return layer
end

---------------------------------------------------------------------------
-- Minimap
---------------------------------------------------------------------------

local function here()
    local mapID = Plain(C_Map.GetBestMapForUnit("player"))
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return nil end
    local x, y = pos:GetXY()
    x, y = Plain(x), Plain(y)
    if not (x and y) then return nil end
    return mapID, x, y
end

local updateMinimap

local function lookMinimap(layer)
    local mapID, px, py = here()
    -- Another map than the pins were read for (a city's own map, say): read them again.
    if mapID ~= layer.specsMap then return updateMinimap(layer) end
    local width, height
    if mapID then width, height = C_Map.GetMapWorldSize(mapID) end
    if not (width and width > 0) then return hideFrom(layer, 1) end
    local zoom = (Minimap:GetZoom() or 0) + 1
    local reach = (IsIndoors() and INDOOR or OUTDOOR)[zoom] or OUTDOOR[1]
    local radius = Minimap:GetWidth() / 2
    local facing = C_CVar.GetCVar("rotateMinimap") == "1" and Plain(GetPlayerFacing()) or nil
    local size, shown = layer.opts.size(), 0
    for _, spec in ipairs(layer.specs or {}) do
        local dx, dy = (spec.x - px) * width, (spec.y - py) * height
        if dx * dx + dy * dy <= reach * reach then
            if facing then
                local c, s = math.cos(facing), math.sin(facing)
                dx, dy = dx * c - dy * s, dx * s + dy * c
            end
            shown = shown + 1
            local px = spec.span and spec.span * width / reach * radius or spec.size or size
            local pin = showPin(layer, shown, spec, px)
            pin:SetPoint("CENTER", Minimap, "CENTER", dx / reach * radius, -dy / reach * radius)
        end
    end
    hideFrom(layer, shown + 1)
end

local function stopMinimap(layer)
    layer.mod:CancelTimer(layer.ticker)
    layer.ticker, layer.specs, layer.specsMap = nil, nil, nil
    if layer.holder then hideFrom(layer, 1) end
end

-- Looks only while it's wanted and there's something on the player's map.
function updateMinimap(layer)
    local mod = layer.mod
    if not wanted(layer) or IsInInstance() then return stopMinimap(layer) end
    local mapID = here()
    layer.specs, layer.specsMap = mapID and layer.opts.specs(mapID) or nil, mapID
    if not (layer.specs and #layer.specs > 0) then return stopMinimap(layer) end
    if not layer.holder then
        layer.holder = CreateFrame("Frame", nil, Minimap)
        layer.holder:SetAllPoints(Minimap)
        layer.holder:SetFrameLevel(Minimap:GetFrameLevel() + 5 + (layer.opts.level or 0))
    end
    if not mod:IsPending(layer.ticker) then
        layer.ticker = mod:NewTicker(EVERY, function() lookMinimap(layer) end)
    end
    lookMinimap(layer)
end

function MapPins.Minimap(mod, opts)
    -- Its zone events are its own (a module has one handler per event, which stays the module's).
    local layer = { mod = mod, opts = opts, pins = {}, kind = "Frame", name = mod.name .. " minimap pins" }
    function layer.Refresh() updateMinimap(layer) end
    function layer.Enable()
        for _, event in ipairs(ZONE_EVENTS) do ns:On(event, layer, layer.Refresh) end
        updateMinimap(layer)
    end
    function layer.Disable()
        for _, event in ipairs(ZONE_EVENTS) do ns:Off(event, layer) end
        stopMinimap(layer)
    end
    layer.Changed = layer.Refresh
    mod:AddPart(layer)
    return layer
end
