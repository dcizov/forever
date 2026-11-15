--[[
    Forever Core - UI/MapPins.lua
    Pins on the world map and the minimap, for modules that show places (Forever Tweaks' Gathering
    Map, Forever Compendium's quest and rare pins). The module says what to draw; this keeps the
    frames, as a part of the module (Core/Module.lua: it stops with it).

      * World map: a holder of ours on the map's canvas (WorldMapFrame.ScrollContainer.Child),
        drawn only while the map is open, and again when it changes map or scale; pins keep their
        size on screen however far you zoom (sized against WorldMapFrame:GetCanvasScale).
        With OpenMap (MIT), whose stitched map draws its art on the same canvas, the holder sits
        above the art's top level (OpenMapAPI.ArtTopLevel) and draws again when the stitched
        view moves or OpenMap switches between its map and Blizzard's (its callbacks).
      * Minimap: what's within the minimap's reach, placed by its distance in yards from you
        (C_Map.GetMapWorldSize) against the yards the minimap shows from its centre to its edge
        (C_Minimap.GetViewRadius, the game's own figure for its zoom, indoors or out, as Forever++
        reads it), turned with it when Rotate Minimap is on. Kept inside its edge, round or
        square (GetMinimapShape, which a square-minimap addon defines): a pin whose icon would
        cross the edge isn't drawn, and an area is cut at the edge by a mask the minimap's shape.
        Looked at often while there's something on your map, but redrawn only when you move,
        turn or zoom; not at all with nothing to show (zone changes look again); hidden in
        instances. The edge test is HereBeDragons-Pins' (BSD), in our own code.

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
    MapPins.Both(mod, opts) makes the pair a pin module shows (below): specs, tooltip and click
    once, and `world` and `minimap` with each layer's shown, size and level.
]]

local _, ns = ...

local ipairs, math, tostring, type, pcall = ipairs, math, tostring, type, pcall
local CreateFrame = CreateFrame
local Plain = ns.Plain

local MapPins = {}
ns.MapPins = MapPins

local EVERY = 0.05 -- seconds between the minimap's looks (it redraws only when the view changed)
-- Above the map: Blizzard's map art and pins take frame levels from 2000 up (Blizzard_MapCanvas's
-- PinFrameLevelsManager), not from the canvas's, so a holder just over the canvas is drawn under
-- the map itself.
local WORLD_LEVEL = 2100
local EDGE = 0.4 -- an icon may reach this share of its size past its centre before it's dropped
-- The masks that cut areas to the minimap's shape.
local ROUND_MASK, SQUARE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask", "Interface\\Buttons\\WHITE8X8"
local ZONE_EVENTS = { "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS" }

-- A pin frame on `holder` whose mouse runs the module's tooltip (and click).
local function newPin(mod, opts, holder, kind)
    local pin = CreateFrame(kind, nil, holder)
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetAllPoints()
    pin:SetScript("OnEnter", function(self) ns.ChargedCall(mod, "map pin", opts.tooltip, self, self.spec) end)
    pin:SetScript("OnLeave", GameTooltip_Hide)
    if opts.click and kind == "Button" then
        pin:RegisterForClicks("RightButtonUp")
        pin:SetScript("OnClick", function(self, mouse) ns.ChargedCall(mod, "map pin click", opts.click, self, self.spec, mouse) end)
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

-- OpenMap's API (optional), or nil.
local function openMap()
    local api = _G.OpenMapAPI
    if type(api) == "table" and type(api.ArtTopLevel) == "function" then return api end
end

-- The holder's level: over Blizzard's map art and pins, and over OpenMap's stitched art.
local function placeHolder(layer)
    local canvas = layer.holder:GetParent()
    local level = canvas:GetFrameLevel() + WORLD_LEVEL + (layer.opts.level or 0)
    local api = openMap()
    local art = api and Plain(api.ArtTopLevel())
    if type(art) == "number" and art + 1 + (layer.opts.level or 0) > level then
        level = art + 1 + (layer.opts.level or 0)
    end
    if layer.holder:GetFrameLevel() ~= level then layer.holder:SetFrameLevel(level) end
end

local function drawWorld(layer)
    if not layer.holder then return end
    placeHolder(layer)
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
            mod:Hook(WorldMapFrame, "OnMapChanged", drawSoon)
            mod:Hook(WorldMapFrame, "OnCanvasScaleChanged", drawSoon)
            mod:HookScript(WorldMapFrame, "OnShow", drawSoon)
        end
        local api = openMap()
        if mod.active and api and type(api.RegisterCallback) == "function" then
            for _, event in ipairs({ "OpenMap_StitchedChanged", "OpenMap_ViewChanged" }) do
                mod:HookCallback(api, event, function(hook)
                    local ok, err = pcall(api.RegisterCallback, layer, event, function(...) hook(...) end)
                    if not ok then mod:Debug("OpenMap:", tostring(err)) end
                    return ok
                end, drawSoon)
            end
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
    if not (x and y) or (x == 0 and y == 0) then return nil end -- 0, 0: the game doesn't know
    return mapID, x, y
end

-- Whether the minimap is square: an addon that squares it says so through GetMinimapShape.
local function square()
    return GetMinimapShape ~= nil and GetMinimapShape() == "SQUARE"
end

-- Whether (x, y) px from the minimap's centre is within `edge` px of it, by its shape.
local function inside(x, y, edge, isSquare)
    if isSquare then return math.abs(x) <= edge and math.abs(y) <= edge end
    return x * x + y * y <= edge * edge
end

-- Cuts a pin's art to the minimap's `shape` (a mask texture's file), or uncuts it (nil). The mask
-- is the pin's own (a mask works on its own frame's textures), laid over the whole minimap.
local function maskPin(pin, shape)
    if shape then
        if not pin.mask then
            pin.mask = pin:CreateMaskTexture()
            pin.mask:SetAllPoints(Minimap)
        end
        if pin.maskShape ~= shape then
            pin.mask:SetTexture(shape, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            pin.maskShape = shape
        end
        if not pin.masked then
            pin.icon:AddMaskTexture(pin.mask)
            pin.masked = true
        end
    elseif pin.masked then
        pin.icon:RemoveMaskTexture(pin.mask)
        pin.masked = nil
    end
end

local updateMinimap

local function lookMinimap(layer)
    local mapID, px, py = here()
    -- Another map than the pins were read for (a city's own map, say): read them again.
    if mapID ~= layer.specsMap then return updateMinimap(layer) end
    local width, height
    if mapID then width, height = C_Map.GetMapWorldSize(mapID) end
    local reach = Plain(C_Minimap.GetViewRadius())
    if not (width and width > 0 and reach and reach > 0) then
        layer.seen = nil
        return hideFrom(layer, 1)
    end
    local radius = Minimap:GetWidth() / 2
    local facing = C_CVar.GetCVar("rotateMinimap") == "1" and Plain(GetPlayerFacing()) or nil
    local isSquare = square()
    -- Nothing moved, turned or zoomed: what's drawn is still right.
    local seen = px .. ":" .. py .. ":" .. (facing or "-") .. ":" .. reach .. ":" .. radius .. ":" .. tostring(isSquare)
    if seen == layer.seen then return end
    layer.seen = seen
    local shape = isSquare and SQUARE_MASK or ROUND_MASK
    local c, s = 1, 0
    if facing then c, s = math.cos(facing), math.sin(facing) end
    local perYard = radius / reach
    local size, shown = layer.opts.size(), 0
    for _, spec in ipairs(layer.specs or {}) do
        local dx, dy = (spec.x - px) * width, (spec.y - py) * height
        dx, dy = (dx * c - dy * s) * perYard, (dx * s + dy * c) * perYard
        local px2 = spec.span and spec.span * width * perYard or spec.size or size
        -- An area may overlap the edge (the mask cuts it there); an icon must fit inside it.
        local fits
        if spec.span then
            fits = inside(dx, dy, radius + px2 / 2, isSquare)
        else
            fits = inside(dx, dy, radius - px2 * EDGE, isSquare)
        end
        if fits then
            shown = shown + 1
            local pin = showPin(layer, shown, spec, px2)
            pin:SetPoint("CENTER", Minimap, "CENTER", dx, -dy)
            maskPin(pin, spec.span and shape)
        end
    end
    hideFrom(layer, shown + 1)
end

local function stopMinimap(layer)
    layer.mod:CancelTimer(layer.ticker)
    layer.ticker, layer.specs, layer.specsMap, layer.seen = nil, nil, nil, nil
    if layer.holder then hideFrom(layer, 1) end
end

-- Looks only while it's wanted and there's something on the player's map.
function updateMinimap(layer)
    local mod = layer.mod
    if not wanted(layer) or IsInInstance() then return stopMinimap(layer) end
    local mapID = here()
    layer.specs, layer.specsMap, layer.seen = mapID and layer.opts.specs(mapID) or nil, mapID, nil
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

-- Both layers from one set of pins, the way every pin module shows them: opts has specs,
-- tooltip and click (world map only) once, and each layer's own `world` and `minimap`
-- { shown, size, level }. Returns { world, minimap, Refresh } (Refresh draws both again).
function MapPins.Both(mod, opts)
    local function layerOpts(own)
        return { specs = opts.specs, tooltip = opts.tooltip, shown = own.shown, size = own.size, level = own.level }
    end
    local worldOpts = layerOpts(opts.world)
    worldOpts.click = opts.click
    local pins = { world = MapPins.World(mod, worldOpts), minimap = MapPins.Minimap(mod, layerOpts(opts.minimap)) }
    function pins.Refresh()
        pins.world.Refresh()
        pins.minimap.Refresh()
    end
    return pins
end
