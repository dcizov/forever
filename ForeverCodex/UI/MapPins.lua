--[[
    Forever Codex - UI/MapPins.lua
    Pins on the world map and the minimap, for modules that show places (Forever Gearbox' Gathering
    Map, Forever Codex's quest and rare pins). The module says what to draw; this keeps the
    frames, as a part of the module (Core/Module.lua: it stops with it).

      * World map: a holder of ours on the map's canvas (WorldMapFrame.ScrollContainer.Child),
        drawn only while the map is open, and again when it changes map or scale; pins keep their
        size on screen however far you zoom (sized against WorldMapFrame:GetCanvasScale).
        With OpenMap (MIT), whose stitched map draws its art on the same canvas, the holder sits
        above the art's top level (OpenMapAPI.ArtTopLevel) and draws again when the stitched
        view moves or OpenMap switches between its map and Blizzard's (its callbacks). On its
        stitched map, as Questie's pins are there, the pins of every zone in view (and a little
        round it) are drawn, not only the zone underneath: each zone's points are carried onto
        the map underneath through OpenMap's stitched world (OpenMapAPI.WorldFromMap, then
        MapFromWorld), an area's span by how wide its zone is there.
      * Minimap: what's within the minimap's reach, placed by its distance in yards from you
        (C_Map.GetMapWorldSize) against the yards the minimap shows from its centre to its edge
        (C_Minimap.GetViewRadius, the game's own figure for its zoom, indoors or out, as Forever++
        reads it), turned with it when Rotate Minimap is on. Kept inside its edge, round or
        square (GetMinimapShape, which a square-minimap addon defines): a pin whose icon would
        cross the edge isn't drawn, and an area is cut at the edge by a mask the minimap's shape.
        Looked at every frame while there's something on your map, but redrawn only when you
        move, turn or zoom, and then the pins are only moved (their art is set when it changes); not at all with nothing to show (zone changes look again); hidden in
        instances. The edge test is HereBeDragons-Pins' (BSD), in our own code.

    A pin is a spec the module makes: { x, y (0..1 on the map), atlas (or texture, a file),
    color ({ r, g, b, a } tint), size (px; else the layer's) or span (a share of the map's width,
    for an area that grows with the map), gray (desaturated), alpha (0..1), layer (drawn over
    lower ones), and anything the module wants back in its tooltip or click }.

    World map pins are Forever++'s (Lib/MapPins.lua, MIT): they light up under the mouse (the
    icon again, added on top), and let clicks through to the map (zooming, changing maps) except
    while Ctrl or Shift is held over them, when the module's click takes it; the tooltip is drawn
    again when Shift goes up or down, for hints shown only with it.

        MapPins.World(mod, opts) and MapPins.Minimap(mod, opts), where opts has:
            specs(mapID, host, kind) the pins on `mapID` (asked only while shown), for world map
                                                            (`kind` = "world", `host` = map shown) or minimap
                                                            (`kind` = "minimap", `host` = nil)
      shown()                 whether this layer draws at all (the module being on is checked too)
      size()                  the pins' size in px
      tooltip(pin, spec)      fills and shows GameTooltip
      click(pin, spec, mouse) world map only, optional: a click on a pin with Ctrl or Shift held
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

-- Seconds between the minimap's looks: every frame, so pins turn with a rotating minimap (it
-- redraws only when the view changed, and then only moves them: showPin).
local EVERY = 0
-- Above the map: Blizzard's map art and pins take frame levels from 2000 up (Blizzard_MapCanvas's
-- PinFrameLevelsManager), not from the canvas's, so a holder just over the canvas is drawn under
-- the map itself.
local WORLD_LEVEL = 2100
local EDGE = 0.4 -- an icon may reach this share of its size past its centre before it's dropped
-- The masks that cut areas to the minimap's shape.
local ROUND_MASK, SQUARE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask", "Interface\\Buttons\\WHITE8X8"
local ZONE_EVENTS = { "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS" }

local function showTip(mod, opts, pin)
    ns.ChargedCall(mod, "map pin", opts.tooltip, pin, pin.spec)
end

-- While the mouse is over a world map pin: clicks are the pin's only with Ctrl or Shift held, and
-- the tooltip is drawn again when Shift changes (its hints).
local function watchKeys(pin)
    local shift = IsShiftKeyDown()
    pin:SetMouseClickEnabled(shift or IsControlKeyDown())
    if pin.shiftWas ~= nil and pin.shiftWas ~= shift then showTip(pin.mod, pin.opts, pin) end
    pin.shiftWas = shift
end

-- A pin frame on `holder` whose mouse runs the module's tooltip (and click).
local function newPin(mod, opts, holder, kind)
    local pin = CreateFrame(kind, nil, holder)
    pin.mod, pin.opts = mod, opts
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetAllPoints()
    pin.highlight = pin:CreateTexture(nil, "OVERLAY")
    pin.highlight:SetAllPoints()
    pin.highlight:SetBlendMode("ADD")
    pin.highlight:SetAlpha(0.5)
    pin.highlight:Hide()
    local clicks = opts.click and kind == "Button"
    pin:SetScript("OnEnter", function(self)
        self.highlight:Show()
        showTip(mod, opts, self)
        if clicks then
            self.shiftWas = nil
            watchKeys(self)
            self:SetScript("OnUpdate", watchKeys)
        end
    end)
    pin:SetScript("OnLeave", function(self)
        self.highlight:Hide()
        GameTooltip_Hide()
        if clicks then
            self:SetScript("OnUpdate", nil)
            self:SetMouseClickEnabled(false)
        end
    end)
    if clicks then
        pin:SetMouseMotionEnabled(true)
        pin:SetMouseClickEnabled(false)
        pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        pin:SetScript("OnClick", function(self, mouse) ns.ChargedCall(mod, "map pin click", opts.click, self, self.spec, mouse) end)
    end
    return pin
end

-- Shows pin `i` of `pins` (made when needed) as `spec` at `size` px. Its art is set again only
-- when it shows another spec (the minimap moves the same pins every frame while it turns).
local function showPin(layer, i, spec, size)
    local pin = layer.pins[i] or newPin(layer.mod, layer.opts, layer.holder, layer.kind)
    layer.pins[i] = pin
    if pin.spec ~= spec then
        pin.spec = spec
        for _, texture in ipairs({ pin.icon, pin.highlight }) do
            if spec.atlas then texture:SetAtlas(spec.atlas) else texture:SetTexture(spec.texture) end
            local color = spec.color
            if color then texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1) else texture:SetVertexColor(1, 1, 1, 1) end
            texture:SetDesaturated(spec.gray or false)
        end
        pin:SetAlpha(spec.alpha or 1)
        pin:SetFrameLevel(layer.holder:GetFrameLevel() + (spec.layer or 0))
    end
    if pin.size ~= size then
        pin.size = size
        pin:SetSize(size, size)
    end
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

---------------------------------------------------------------------------
-- OpenMap's stitched map: every zone in view, as Questie's pins are there
---------------------------------------------------------------------------

-- How far round the view's centre zones are drawn, in the stitched world's units at zoom 1 (the
-- whole world): a little more than half the view, so pins come in before they're in sight.
local VIEW_REACH = 0.8

local rects = {}   -- zone map ID -> { u0, v0, u1, v1 } on OpenMap's stitched world, or false
local zoneList     -- every zone of every continent (once)

-- Zone `mapID`'s rectangle on the stitched world, or false where OpenMap hasn't stitched it.
local function rectOf(api, mapID)
    if rects[mapID] == nil then
        local u0, v0 = api.WorldFromMap(mapID, 0, 0)
        local u1, v1 = api.WorldFromMap(mapID, 1, 1)
        rects[mapID] = type(u0) == "number" and type(u1) == "number" and { u0, v0, u1, v1 } or false
    end
    return rects[mapID]
end

-- The continent a map is on (itself if it's one), or nil.
local function continentOf(mapID)
    local info = C_Map.GetMapInfo(mapID)
    while info and info.mapType > Enum.UIMapType.Continent and info.parentMapID do
        info = C_Map.GetMapInfo(info.parentMapID)
    end
    return info and info.mapType == Enum.UIMapType.Continent and info.mapID or nil
end

-- Every zone of the continents beside the one `mapID` is on (all of them are stitched together).
local function allZones(mapID)
    if zoneList then return zoneList end
    local continent = continentOf(mapID)
    local world = continent and C_Map.GetMapInfo(continent).parentMapID
    local continents = world and C_Map.GetMapChildrenInfo(world, Enum.UIMapType.Continent) or {}
    if #continents == 0 and continent then continents = { { mapID = continent } } end
    local list = {}
    for _, each in ipairs(continents) do
        for _, zone in ipairs(C_Map.GetMapChildrenInfo(each.mapID, Enum.UIMapType.Zone, true) or {}) do
            list[#list + 1] = zone.mapID
        end
    end
    -- Kept once found (the maps don't change); none found (a dungeon underneath) is asked again.
    if #list > 0 then zoneList = list end
    return list
end

-- The zones OpenMap's stitched view shows (and a little round it), with the map underneath; nil
-- when the map isn't OpenMap's stitched one.
local function stitchedZones(api, host)
    if type(api.IsStitched) ~= "function" or not api.IsStitched() or type(api.GetView) ~= "function"
        or type(api.WorldFromMap) ~= "function" or type(api.MapFromWorld) ~= "function" then
        return nil
    end
    local u, v, zoom = api.GetView()
    if type(u) ~= "number" or type(zoom) ~= "number" or zoom <= 0 then return nil end
    local reach = VIEW_REACH / zoom
    local list, hasHost = {}, false
    for _, zone in ipairs(allZones(host)) do
        local r = rectOf(api, zone)
        if r and r[1] < u + reach and r[3] > u - reach and r[2] < v + reach and r[4] > v - reach then
            list[#list + 1] = zone
            hasHost = hasHost or zone == host
        end
    end
    if not hasHost then list[#list + 1] = host end
    return list
end

-- Where point x, y of zone `mapID` is on the map underneath (`host`), 0..1 of its canvas (and
-- past it), through OpenMap's stitched world; nil where it can't say.
local function onHost(api, mapID, host, x, y)
    if mapID == host then return x, y end
    local u, v = api.WorldFromMap(mapID, x, y)
    if type(u) ~= "number" then return nil end
    local hx, hy = api.MapFromWorld(host, u, v)
    if type(hx) ~= "number" or type(hy) ~= "number" then return nil end
    return hx, hy
end

-- How wide zone `mapID` is on the host's canvas, as a share of it (an area's span).
local function widthOnHost(api, mapID, host)
    if mapID == host then return 1 end
    local x0 = onHost(api, mapID, host, 0, 0.5)
    local x1 = onHost(api, mapID, host, 1, 0.5)
    return x0 and x1 and math.abs(x1 - x0) or 1
end

local function drawWorld(layer)
    if not layer.holder then return end
    placeHolder(layer)
    local shown = 0
    if wanted(layer) and WorldMapFrame:IsShown() then
        local host = WorldMapFrame:GetMapID()
        local canvas = layer.holder:GetParent()
        local width, height = canvas:GetWidth(), canvas:GetHeight()
        local scale = WorldMapFrame:GetCanvasScale()
        local size = layer.opts.size()
        local api = openMap()
        -- On OpenMap's stitched map, every zone in view; else the map shown.
        local zones = api and stitchedZones(api, host) or { host }
        for _, mapID in ipairs(zones) do
            local share = api and widthOnHost(api, mapID, host) or 1
            for _, spec in ipairs(layer.opts.specs(mapID, host, "world")) do
                local x, y = spec.x, spec.y
                if mapID ~= host then x, y = onHost(api, mapID, host, x, y) end
                if x then
                    shown = shown + 1
                    local px = spec.span and spec.span * share * width or (spec.size or size) / scale
                    local pin = showPin(layer, shown, spec, px)
                    pin:SetPoint("CENTER", canvas, "TOPLEFT", x * width, -y * height)
                end
            end
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
            pin.highlight:AddMaskTexture(pin.mask)
            pin.masked = true
        end
    elseif pin.masked then
        pin.icon:RemoveMaskTexture(pin.mask)
        pin.highlight:RemoveMaskTexture(pin.mask)
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
    layer.specs, layer.specsMap, layer.seen = mapID and layer.opts.specs(mapID, nil, "minimap") or nil, mapID, nil
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
