--[[
    Forever runtime - Shared/Settings/Window.lua
    The settings window: every settings page in one window of its own: a portrait frame, its pages
    listed down the left on Blizzard's dark inset (gold names, the recipe list's light under the
    mouse and on the chosen one, with a gold edge), the chosen one at the right, on Blizzard's
    inset, or in the addon's own look (Window.SetLook: the journal's, for one, is the
    spellbook's parchment with its words in the parchment's ink). The pages are the same frames
    Shared/Settings/Modules.lua makes (Settings, a Modules page per member, member pages, About, Debug,
    Changelog): each is shown inside the window when chosen. Settings > AddOns > Forever is a
    short page with a button opening it (Shared/Settings/Modules.lua).

    It moves by its title bar and stays where you leave it (ns.db.window), keeps its scale
    (ns.db.windowScale), closes with Escape, and stays open when other windows open: it isn't one
    of Blizzard's panels. /forever, each member's slash command, the minimap button and the
    Open Forever Settings key binding open it.

      Window.AddPage(key, label, frame)   a page, in the order added (Shared/Settings/Modules.lua)
      Window.Open(key)                    shows the window on page `key` (or the last one)
      Window.Toggle(), Window.IsShown()
      Window.Page(key)                    { frame, label } of page `key`, or nil
      Window.Current()                    the page showing while the window is open, or nil
      Window.SetLook(look)                the addon's look, before the window first opens: any of
                                          Page(frame) -> holder, inner (where the page goes);
                                          Ink(frame) (a page's words, now and as it draws);
                                          Fade(frame) (the window, while you move); Sound(key)
]]

local _, ns = ...
local Kit, L = ns.Kit, ns.L

local ipairs, pairs, type, math = ipairs, pairs, type, math

local Window = {}
ns.SettingsWindow = Window

local WIDTH, HEIGHT = 900, 640
local NAV_WIDTH, NAV_ROW = 168, 24

local pages, byKey = {}, {}
local frame, nav, content, current

-- Blizzard's own look: the chosen page on an inset, words as they are, no sounds.
local look = {
    Page = function(parent)
        local inset = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
        return inset, inset
    end,
    Ink = function() end,
    Fade = function() end,
    Sound = function() end,
}

function Window.SetLook(own)
    for key, fn in pairs(own) do look[key] = fn end
end

-- A frame's words in the look's ink (a page part built after the window inked the page).
function Window.Ink(target) look.Ink(target) end

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

-- A nav row's look: lit and edged in gold while chosen.
local function paintRow(row)
    local chosen = current == row.key
    row.chosen:SetShown(chosen)
    row.edge:SetShown(chosen)
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
    -- In the look's ink, now and whenever the page draws again (what it adds since too).
    look.Ink(page.frame)
    if not page.inks then
        page.inks = true
        page.frame:HookScript("OnShow", function(self) look.Ink(self) end)
        page.frame:HookScript("OnSizeChanged", function(self) look.Ink(self) end)
    end
    for _, row in ipairs(nav.rows) do paintRow(row) end
end

local function addNavRow(page, index)
    local row = CreateFrame("Button", nil, nav)
    row.key = page.key
    row:SetSize(NAV_WIDTH - 8, NAV_ROW)
    row:SetPoint("TOPLEFT", 4, -6 - (index - 1) * NAV_ROW)
    row:SetHighlightAtlas("Professions_Recipe_Hover", "ADD")
    row.chosen = row:CreateTexture(nil, "BACKGROUND")
    row.chosen:SetAtlas("Professions_Recipe_Hover")
    row.chosen:SetAllPoints()
    row.edge = row:CreateTexture(nil, "BORDER")
    row.edge:SetColorTexture(1, 0.82, 0, 0.9)
    row.edge:SetWidth(2)
    row.edge:SetPoint("TOPLEFT")
    row.edge:SetPoint("BOTTOMLEFT")
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", 12, 0)
    text:SetPoint("RIGHT", -4, 0)
    text:SetJustifyH("LEFT")
    text:SetText(page.label)
    row:SetScript("OnClick", function()
        look.Sound("tab")
        select(page.key)
    end)
    nav.rows[#nav.rows + 1] = row
    paintRow(row)
end

local function buildWindow()
    local name = ns.name .. "SettingsFrame"
    frame = CreateFrame("Frame", name, UIParent, "PortraitFrameTemplate")
    look.Fade(frame)
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
    tinsert(UISpecialFrames, name)

    -- The pages, down the left in an inset (the Professions window's recipe list's place).
    nav = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
    nav:SetPoint("TOPLEFT", 4, -60)
    nav:SetPoint("BOTTOMLEFT", 4, 34)
    nav:SetWidth(NAV_WIDTH)
    nav.rows = {}
    for i, page in ipairs(pages) do addNavRow(page, i) end

    -- The chosen page, in the look's holder.
    local page, paper = look.Page(frame)
    page:SetPoint("TOPLEFT", nav, "TOPRIGHT", 6, 0)
    page:SetPoint("BOTTOMRIGHT", -6, 34)
    content = CreateFrame("Frame", nil, paper)
    content:SetPoint("TOPLEFT", 12, -8)
    content:SetPoint("BOTTOMRIGHT", -8, 6)

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
