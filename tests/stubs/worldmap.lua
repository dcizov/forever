--[[
    Forever suite - tests/stubs/worldmap.lua
    The world map: WorldMapFrame (showing W.worldMapID) and its ScrollContainer, which does what
    Blizzard's MapCanvasScrollControllerMixin does (Blizzard_MapCanvas/MapCanvas_ScrollContainerMixin.lua
    on the forever branch) for the parts the addons use: zoom levels (three for any map, one art
    layer), the wheel's own zoom, scroll extents, the view's scale and center, and the cursor's
    place on the canvas. The container is 1000 x 700 at the screen's origin, and the canvas
    (Child) is a map's art, 1000 x 700, scaled.
]]

Enum.UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6 }
MAP_CANVAS_MOUSE_WHEEL_ZOOM_BEHAVIOR_NONE = 1
MAP_CANVAS_MOUSE_WHEEL_ZOOM_BEHAVIOR_SMOOTH = 2
MAP_CANVAS_MOUSE_WHEEL_ZOOM_BEHAVIOR_FULL = 3

-- Pins and the mixins they're made from (Blizzard_MapCanvas/MapCanvas_PinMixin.lua and
-- SuperTrackablePinMixin): what they asked for while out of combat, in W.pinCalls.
W.pinCalls = {}
MapCanvasPinMixin = {}
function MapCanvasPinMixin:CheckMouseButtonPassthrough(...) W.pinCalls[#W.pinCalls + 1] = { self, "passthrough", ... } end
SuperTrackablePinMixin = {}
function SuperTrackablePinMixin:UpdateMousePropagation(...) W.pinCalls[#W.pinCalls + 1] = { self, "propagation", ... } end
SomeAddonPinMixin = { CheckMouseButtonPassthrough = MapCanvasPinMixin.CheckMouseButtonPassthrough }

WorldMapFrame = W.NewFrame("Frame", "WorldMapFrame", UIParent)
WorldMapFrame._shown = false
WorldMapFrame.pinPools = {}
local sc = W.NewFrame("ScrollFrame", nil, WorldMapFrame)
WorldMapFrame.ScrollContainer = sc
sc.Child = W.NewFrame("Frame", nil, sc)
W.canvasScale = 1
function WorldMapFrame:GetMapID() return W.worldMapID end
function WorldMapFrame:GetCanvasScale() return sc.currentScale or W.canvasScale end
function WorldMapFrame:OnMapChanged() end
function WorldMapFrame:OnCanvasScaleChanged() W.canvasChanges = (W.canvasChanges or 0) + 1 end

local WIDTH, HEIGHT = 1000, 700
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

function sc:GetWidth() return WIDTH end
function sc:GetHeight() return HEIGHT end
function sc.Child:GetWidth() return WIDTH end
function sc.Child:GetHeight() return HEIGHT end
-- The canvas's left and top in its own (scaled) units, for the view centered on the scroll.
function sc.Child:GetLeft() return (WIDTH / 2) / sc:GetCanvasScale() - (sc:GetCurrentScrollX() or 0.5) * WIDTH end
function sc.Child:GetTop() return (HEIGHT / 2) / sc:GetCanvasScale() + (sc:GetCurrentScrollY() or 0.5) * HEIGHT end

sc.mouseWheelZoomMode = MAP_CANVAS_MOUSE_WHEEL_ZOOM_BEHAVIOR_FULL
sc.scalingMode = "SCALING_MODE_TRANSLATE_FASTER_THAN_SCALE"
sc.mouseButtonInfo = { LeftButton = { down = false }, RightButton = { down = false } }

function sc:SetMouseWheelZoomMode(mode) self.mouseWheelZoomMode = mode end
function sc:SetScalingMode(mode) self.scalingMode = mode end
function sc:CreateZoomLevels()
    self.baseScale = 1
    self.zoomLevels = { { scale = 1, layerIndex = 1 }, { scale = 1.5, layerIndex = 1 }, { scale = 2, layerIndex = 1 } }
end
function sc:GetCanvasScale()
    if self.currentScale and self.currentScale ~= 0 then return self.currentScale end
    if self.targetScale and self.targetScale ~= 0 then return self.targetScale end
    return 1
end
function sc:GetCurrentScrollX() return self.currentScrollX or self.targetScrollX end
function sc:GetCurrentScrollY() return self.currentScrollY or self.targetScrollY end
function sc:NormalizeHorizontalSize(size) return size / self.Child:GetWidth() end
function sc:NormalizeVerticalSize(size) return size / self.Child:GetHeight() end
function sc:CalculateScrollExtentsAtScale(scale)
    local x = math.min(self:NormalizeHorizontalSize(WIDTH * 0.5 / scale), 0.5)
    local y = math.min(self:NormalizeVerticalSize(HEIGHT * 0.5 / scale), 0.5)
    return x, 1 - x, y, 1 - y
end
function sc:CalculateScrollExtents()
    self.scrollXExtentsMin, self.scrollXExtentsMax, self.scrollYExtentsMin, self.scrollYExtentsMax =
        self:CalculateScrollExtentsAtScale(self:GetCanvasScale())
end
function sc:SetNormalizedHorizontalScroll(x) self._scrollX = x end
function sc:SetNormalizedVerticalScroll(y) self._scrollY = y end
function sc:MarkAreaTriggersDirty() end
function sc:MarkViewRectDirty() end
function sc:MarkCanvasDirty() end
function sc:GetCursorPosition() return W.cursor[1], W.cursor[2] end
function sc:InstantPanAndZoom(scale, x, y)
    self.currentScale, self.targetScale = scale, scale
    self:CalculateScrollExtents()
    self.targetScrollX = clamp(x, self.scrollXExtentsMin, self.scrollXExtentsMax)
    self.targetScrollY = clamp(y, self.scrollYExtentsMin, self.scrollYExtentsMax)
    self.currentScrollX, self.currentScrollY = self.targetScrollX, self.targetScrollY
    WorldMapFrame:OnCanvasScaleChanged()
end
function sc:ResetZoom() self:InstantPanAndZoom(self.zoomLevels[1].scale, 0.5, 0.5) end
function sc:OnCanvasSizeChanged()
    if not self.mapID then return end
    self:CreateZoomLevels()
    self:ResetZoom()
end
-- The map shown: Blizzard's SetMapID, then its size (WorldMapFrame:SetMapID calls through).
function WorldMapFrame:SetMapID(mapID)
    W.worldMapID = mapID
    sc.mapID = mapID
    sc:OnCanvasSizeChanged()
end
-- Blizzard's own wheel: a level in or out, unless switched off.
sc:SetScript("OnMouseWheel", function(self, delta)
    if self.mouseWheelZoomMode == MAP_CANVAS_MOUSE_WHEEL_ZOOM_BEHAVIOR_NONE then return end
    local levels, scale, at = self.zoomLevels, self:GetCanvasScale(), 1
    for i, level in ipairs(levels) do if scale >= level.scale then at = i end end
    local level = levels[clamp(at + (delta > 0 and 1 or -1), 1, #levels)]
    self:InstantPanAndZoom(level.scale, self:GetCurrentScrollX(), self:GetCurrentScrollY())
end)
sc:SetScript("OnUpdate", function() end)
