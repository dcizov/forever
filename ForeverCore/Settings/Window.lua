--[[
    Forever Core - Settings/Window.lua
    The Forever window: every settings page of the suite in one window of its own, built like
    Blizzard's Collections and Professions windows (a portrait frame, its pages listed down the
    left in an inset, the chosen one filling the right). The pages are the same frames
    Settings/Modules.lua makes (Settings, a Modules page per member, member pages, About, Debug,
    Changelog): each is shown inside the window when chosen. Settings > AddOns > Forever is a
    short page with a button opening it (Settings/Modules.lua).

    It moves by its title bar and stays where you leave it (ns.db.window), keeps its scale
    (ns.db.windowScale), closes with Escape, and stays open when other windows open: it isn't one
    of Blizzard's panels. /forever, each member's slash command, the minimap button and the
    Open Forever Settings key binding open it.

      Window.AddPage(key, label, frame)   a page, in the order added (Settings/Modules.lua)
      Window.Open(key)                    shows the window on page `key` (or the last one)
      Window.Toggle(), Window.IsShown()
      Window.Page(key)                    { frame, label } of page `key`, or nil
      Window.Current()                    the page showing while the window is open, or nil
]]

local _, ns = ...
local Kit, L = ns.Kit, ns.L

local ipairs, type, math = ipairs, type, math

local Window = {}
ns.SettingsWindow = Window

local WIDTH, HEIGHT = 900, 640
local NAV_WIDTH, NAV_ROW = 168, 26

local pages, byKey = {}, {}
local frame, nav, content, current

function Window.AddPage(key, label, pageFrame)
    local page = { key = key, label = label, frame = pageFrame }
    pages[#pages + 1] = page
    byKey[key] = page
end

function Window.Page(key) return byKey[key] end

function Window.IsShown() return frame ~= nil and frame:IsShown() end

-- The page showing while the window is open, or nil.
function Window.Current() return Window.IsShown() and current or nil end

local function savePosition()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    ns.db.window = { point = point, relativePoint = relativePoint, x = x, y = y }
end

local function placeWindow()
    frame:ClearAllPoints()
    local at = ns.db.window
    if type(at) == "table" and at.point then
        frame:SetPoint(at.point, UIParent, at.relativePoint or at.point, at.x or 0, at.y or 0)
    else
        frame:SetPoint("CENTER")
    end
    frame:SetScale(ns.db.windowScale or 1)
end

local function select(key)
    local page = byKey[key] or pages[1]
    if not page then return end
    current = page.key
    for _, other in ipairs(pages) do
        if other ~= page and other.frame:GetParent() == content then other.frame:Hide() end
    end
    page.frame:SetParent(content)
    page.frame:ClearAllPoints()
    page.frame:SetAllPoints(content)
    page.frame:Show()
    for _, row in ipairs(nav.rows) do Kit.Paint(row) end
end

local function addNavRow(page, index)
    local row = Kit.NewListButton(nav, function() return current == page.key end)
    row:SetSize(NAV_WIDTH - 12, NAV_ROW)
    row:SetPoint("TOPLEFT", 6, -6 - (index - 1) * NAV_ROW)
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", 8, 0)
    text:SetPoint("RIGHT", -4, 0)
    text:SetJustifyH("LEFT")
    text:SetText(page.label)
    row:SetScript("OnClick", function() select(page.key) end)
    nav.rows[#nav.rows + 1] = row
    Kit.Paint(row)
end

local function buildWindow()
    frame = CreateFrame("Frame", "ForeverSettingsFrame", UIParent, "PortraitFrameTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition()
    end)
    frame:SetTitle(ns.title)
    frame:SetPortraitToAsset(ns.icon)
    frame:Hide()
    tinsert(UISpecialFrames, "ForeverSettingsFrame")

    -- The pages, down the left in an inset (the Professions window's recipe list's place).
    nav = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
    nav:SetPoint("TOPLEFT", 4, -60)
    nav:SetPoint("BOTTOMLEFT", 4, 34)
    nav:SetWidth(NAV_WIDTH)
    nav.rows = {}
    for i, page in ipairs(pages) do addNavRow(page, i) end

    -- The chosen page.
    content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", nav, "TOPRIGHT", 12, 30)
    content:SetPoint("BOTTOMRIGHT", -8, 34)

    -- The bottom bar: key bindings, then the window's size.
    local keys = Kit.NewButton(frame, L.WINDOW_KEYBINDINGS, 140, function()
        frame:Hide()
        Kit.OpenID(Settings.KEYBINDINGS_CATEGORY_ID)
    end)
    keys:SetPoint("BOTTOMLEFT", 8, 6)
    local smaller = Kit.NewButton(frame, L.WINDOW_SMALLER, 28, function()
        ns.db.windowScale = math.max(0.7, (ns.db.windowScale or 1) - 0.1)
        placeWindow()
    end)
    smaller:SetPoint("BOTTOMRIGHT", -40, 6)
    local larger = Kit.NewButton(frame, L.WINDOW_LARGER, 28, function()
        ns.db.windowScale = math.min(1.3, (ns.db.windowScale or 1) + 0.1)
        placeWindow()
    end)
    larger:SetPoint("LEFT", smaller, "RIGHT", 2, 0)
    Kit.AddTooltip(smaller, L.WINDOW_SMALLER, L.WINDOW_SMALLER_TIP)
    Kit.AddTooltip(larger, L.WINDOW_LARGER, L.WINDOW_LARGER_TIP)
    placeWindow()
end

function Window.Open(key)
    if not frame then buildWindow() end
    frame:Show()
    select(key or current)
end

function Window.Toggle()
    if Window.IsShown() then frame:Hide() else Window.Open() end
end
