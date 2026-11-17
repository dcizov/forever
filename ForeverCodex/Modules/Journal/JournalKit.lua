--[[
    Forever Codex - Modules/Journal/JournalKit.lua
    The pieces the journal's pages are built from, in the look of the game's own books (the way
    Spoken's Azeroth's Compendium dresses its window, all of it the game's art): the window's
    lists on Blizzard's dark insets in gold, the pages on the spellbook's parchment
    (spellbook-Page-Right-C60) in the spellbook's brown ink, headings over the spellbook's
    divider, cards on the spellbook's item backplates, progress bars as the character window's.
    Here: the palette (J.COLOR), the insets, the count box, round creature portraits in a gold
    ring, item slots in quality borders, icon buttons, dropdowns, a search box and the
    window's tabs along its foot. The parchment and its ink (pages, sections, headings, cards) are
    JournalPage.lua's; the spellbook's layout (Trophies, Badges) JournalSpells.lua's; links and the scrolling
    lines of text JournalLines.lua's; the lists and the
    list pages' layout JournalLists.lua's; Shared/UI/Kit.lua has the rest (scroll frames).
]]

local _, ns = ...

local ipairs, pairs, next, math, type, select, format = ipairs, pairs, next, math, type, select, string.format
local CreateFrame = CreateFrame

local J = {}
ns.JournalKit = J

-- The journal's colours. On the dark insets: gold names, light counts (share), greyed locked
-- rows, the faint gold rail down an open group, the gold edge of the chosen row. On the
-- parchment: the spellbook's ink, a softer ink for what's said in passing, and the link brown.
J.COLOR = {
    gold = { 1, 0.82, 0 }, share = { 0.80, 0.76, 0.70 }, locked = { 0.50, 0.48, 0.45 },
    rail = { 0.84, 0.71, 0.31, 0.2 }, edge = { 1, 0.82, 0, 0.9 },
    ink = { 0.25, 0.16, 0.08 }, inkSoft = { 0.36, 0.27, 0.17 }, link = { 0.5, 0.12, 0.04 },
    heading = { 0.42, 0.26, 0.04 }, good = { 0.1, 0.4, 0.06 },
}
local C = J.COLOR
-- The spellbook's own ink where the client names it (Mainline's SharedColorConstants; probed).
local spellbookInk = rawget(_G, "SPELLBOOK_FONT_COLOR")
if type(spellbookInk) == "table" and spellbookInk.GetRGB then C.ink = { spellbookInk:GetRGB() } end

-- "|cffRRGGBB" for colour `key` of J.COLOR.
function J.Hex(key)
    local c = C[key]
    return format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255)
end

---------------------------------------------------------------------------
-- Layout and insets
---------------------------------------------------------------------------

-- A page's layout: a strip STRIP high at the page's top, right of the portrait (PORTRAIT wide),
-- for the count box and the page's menus; under it the list's inset, LIST_WIDTH wide, on the
-- left with GAP to the right of it for its scroll bar, and the parchment beside it.
J.STRIP = 36
-- A page's title, as the quest log writes a quest's (QuestInfoTitleHeader): its heading font.
J.TITLE_FONT = "QuestTitleFont"
J.PORTRAIT = 62
J.LIST_WIDTH = 280
J.GAP = 16

-- Blizzard's inset (InsetFrameTemplate).
function J.Inset(parent)
    return CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
end

-- The count box ("Creatures   213"): Blizzard's small inset with the label at its left, the
-- number at its right. Returns it; box.Count:SetText(...) sets the number.
function J.CountBox(parent, label)
    local box = CreateFrame("Frame", nil, parent, "InsetFrameTemplate3")
    box:SetSize(150, 20)
    box.Count = box:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    box.Count:SetPoint("RIGHT", -10, 0)
    box.Label = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    box.Label:SetPoint("LEFT", 10, 0)
    box.Label:SetPoint("RIGHT", box.Count, "LEFT", -3, 0)
    box.Label:SetJustifyH("LEFT")
    box.Label:SetText(label)
    return box
end

-- A creature's face, round, in a gold ring (the Journeys window's reward ring): `size` across.
-- portrait:SetCreature(rec) shows it (its look's portrait, else an icon for its kind).
local KIND_ICONS = {
    Beast = "Interface\\Icons\\Ability_Hunter_BeastTaming", Humanoid = "Interface\\Icons\\INV_Misc_Head_Human_01",
    Undead = "Interface\\Icons\\Spell_Shadow_RaiseDead", Demon = "Interface\\Icons\\Spell_Shadow_SummonImp",
    Elemental = "Interface\\Icons\\Spell_Nature_EarthElemental_Totem", Dragonkin = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
    Giant = "Interface\\Icons\\INV_Misc_Head_Troll_01", Mechanical = "Interface\\Icons\\INV_Gizmo_01",
    Critter = "Interface\\Icons\\INV_Misc_Food_15", Aberration = "Interface\\Icons\\Spell_Shadow_AntiShadow",
}
-- An icon for a creature of `rec`'s kind (a beast, a demon...), for one whose look isn't known.
function J.KindIcon(rec)
    return KIND_ICONS[rec and rec.creatureType] or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local Portrait = {}

function Portrait:SetCreature(rec)
    local display = rec and (rec.display or next(rec.displays or {}))
    if display then
        SetPortraitTextureFromCreatureDisplayID(self.face, display)
    else
        self.face:SetTexture(J.KindIcon(rec))
    end
end

function Portrait:SetDesaturated(on)
    self.face:SetDesaturated(on)
    self.ring:SetDesaturated(on)
end

function J.Portrait(parent, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    f.back = f:CreateTexture(nil, "BACKGROUND")
    f.back:SetAtlas("UI-Journeys-Delve-rewardicon-ring-BG")
    f.back:SetAllPoints()
    f.face = f:CreateTexture(nil, "ARTWORK")
    f.face:SetPoint("TOPLEFT", size * 0.12, -size * 0.12)
    f.face:SetPoint("BOTTOMRIGHT", -size * 0.12, size * 0.12)
    local mask = f:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(f.face)
    f.face:AddMaskTexture(mask)
    f.ring = f:CreateTexture(nil, "OVERLAY")
    f.ring:SetAtlas("UI-Journeys-Delve-rewardicon-ring-frame")
    f.ring:SetAllPoints()
    for k, fn in pairs(Portrait) do f[k] = fn end
    return f
end

-- Puts `model`'s camera on the whole of what it shows (Blizzard's ModelFrames: no portrait zoom,
-- the model at the centre, the camera fitted again); a model's first load can move it, so it's
-- done again a moment later while the model still shows the same.
local function fitCamera(model)
    model:SetPortraitZoom(0)
    model.zoomLevel = 0 -- the mouse wheel's zoom (ModelWithZoomTemplate) starts over too
    model:SetPosition(0, 0, 0)
    model:RefreshCamera()
end

function J.FitModel(model)
    fitCamera(model)
    model.fitToken = (model.fitToken or 0) + 1
    local token = model.fitToken
    for _, wait in ipairs({ 0.1, 0.5 }) do
        ns.modules.Journal:After(wait, function() if model.fitToken == token then fitCamera(model) end end)
    end
end

-- Shows GameTooltip on `owner`: a title, then lines (strings, or { text, r, g, b }).
function J.Tip(owner, title, ...)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 0.82, 0)
    for i = 1, select("#", ...) do
        local line = select(i, ...)
        if type(line) == "table" then
            GameTooltip:AddLine(line[1], line[2], line[3], line[4], true)
        elseif line then
            GameTooltip:AddLine(line, 1, 1, 1, true)
        end
    end
    GameTooltip:Show()
end

-- A square button with an icon (a file or an atlas), a highlight and a tooltip.
function J.IconButton(parent, size, icon, title, text, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    J.SetIcon(b.icon, icon)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self)
        J.Tip(self, self.title or title, self.text or text)
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end

-- Sets a texture to `icon`: a file path or ID, or an atlas name ("atlas:Name").
function J.SetIcon(texture, icon)
    if type(icon) == "string" and icon:find("^atlas:") then
        texture:SetAtlas(icon:sub(7))
    else
        texture:SetTexture(icon)
    end
end

-- A dropdown in the style of Blizzard's (WowStyle1DropdownTemplate; the filter one with
-- `filter`): setup(dropdown, root) fills its menu each time it opens.
function J.Dropdown(parent, width, setup, filter)
    local d = CreateFrame("DropdownButton", nil, parent, filter and "WowStyle1FilterDropdownTemplate" or "WowStyle1DropdownTemplate")
    d:SetWidth(width)
    d:SetupMenu(setup)
    return d
end

-- Blizzard's settings gear (GM-icon-settings) opening a menu: setup(button, root) fills it each
-- time; `title` its tooltip.
function J.MenuButton(parent, title, setup)
    local b = CreateFrame("DropdownButton", nil, parent)
    b:SetSize(24, 24)
    b:SetNormalAtlas("GM-icon-settings")
    b:SetHighlightAtlas("GM-icon-settings-hover")
    b:SetPushedAtlas("GM-icon-settings-pressed")
    b:SetupMenu(setup)
    b:SetScript("OnEnter", function(self) J.Tip(self, title) end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end

-- A search box: onChange(text) with its text, trimmed and lower case.
local searches = {} -- every search box made, with what hears it (J.ClearSearches)

function J.Search(parent, width, instructions, onChange)
    local box = CreateFrame("EditBox", nil, parent, "SearchBoxTemplate")
    searches[#searches + 1] = { box = box, onChange = onChange }
    box:SetSize(width, 20)
    box:SetAutoFocus(false)
    box.Instructions:SetText(instructions)
    box:HookScript("OnTextChanged", function(self) onChange(strlower(strtrim(self:GetText()))) end)
    return box
end

-- Empties every search box (each list then shows everything again): the journal closing.
function J.ClearSearches()
    for _, search in ipairs(searches) do
        if search.box:GetText() ~= "" then
            search.box:SetText("")
            search.onChange("") -- told at once, whether or not SetText fires OnTextChanged
        end
    end
end

---------------------------------------------------------------------------
-- Tabs
---------------------------------------------------------------------------

-- The window's tabs: Blizzard's panel tabs along its foot (PanelTabButtonTemplate, as the
-- Collections window and Spoken's Azeroth's Compendium have them), one per page { label },
-- onSelect(index) when one is clicked. Returns the holder: holder.Select(index), holder.list
-- (the tabs). Made once; Set(pages) shows them again for another list of pages.
function J.Tabs(window, onSelect)
    local holder = { list = {} }
    window.Tabs = holder.list
    function holder.Select(index)
        PanelTemplates_SetTab(window, index)
    end
    function holder.Set(pages)
        for i, page in ipairs(pages) do
            local tab = holder.list[i]
            if not tab then
                tab = CreateFrame("Button", window:GetName() .. "Tab" .. i, window, "PanelTabButtonTemplate")
                tab:SetID(i)
                if i == 1 then
                    tab:SetPoint("TOPLEFT", window, "BOTTOMLEFT", 11, 2)
                else
                    tab:SetPoint("TOPLEFT", holder.list[i - 1], "TOPRIGHT", 3, 0)
                end
                tab:SetScript("OnClick", function(self)
                    ns.Sound("tab")
                    holder.Select(self:GetID())
                    onSelect(self:GetID())
                end)
                holder.list[i] = tab
            end
            tab:SetText(page.label)
            PanelTemplates_TabResize(tab, 0)
            tab:Show()
        end
        for i = #pages + 1, #holder.list do holder.list[i]:Hide() end
        PanelTemplates_SetNumTabs(window, #pages)
    end
    return holder
end

-- A row of Blizzard's modern tabs (TabSystemTemplate, the Professions window's) on `parent`,
-- labelled `labels`; onSelect(index) when one is clicked. `onTop`: tabs standing on a panel
-- below them (TabSystemTopButtonTemplate; Forever has no tab system template made of those, so
-- its pool of tabs is swapped before any is made). Returns the holder: holder.Select(index)
-- (marks it, without calling onSelect), holder.SetLabel(index, text), holder.system.
function J.TopTabs(parent, labels, onSelect, onTop)
    local system = CreateFrame("Frame", nil, parent, "TabSystemTemplate")
    if onTop then
        system.tabTemplate = "TabSystemTopButtonTemplate"
        system.tabPool = CreateFramePool("BUTTON", system, "TabSystemTopButtonTemplate")
    end
    system:SetTabSelectedCallback(function(index)
        onSelect(index)
        return false
    end)
    for _, label in ipairs(labels) do system:AddTab(label) end
    local holder = { system = system }
    function holder.Select(index) system:SetTabVisuallySelected(index) end
    function holder.SetLabel(index, text)
        local tab = system:GetTabButton(index)
        tab.tabText = text
        tab:UpdateTabText()
        tab:UpdateTabWidth()
        system:MarkDirty()
    end
    holder.Select(1)
    return holder
end

---------------------------------------------------------------------------
-- Item slots and grids
---------------------------------------------------------------------------

-- An item slot: the item's icon in its quality's border, a text in the corner (a drop rate, a
-- price), a mark at the top right (quest items, limited stock). onEnter(slot) adds lines to the
-- item tooltip; onClick(slot, button).
function J.ItemSlot(parent, size, onEnter, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
    b.bg:SetAllPoints()
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.border = b:CreateTexture(nil, "OVERLAY")
    b.border:SetTexture("Interface\\Common\\WhiteIconFrame")
    b.border:SetAllPoints()
    b.corner = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    b.corner:SetPoint("BOTTOMRIGHT", -2, 2)
    b.mark = b:CreateTexture(nil, "OVERLAY", nil, 2)
    b.mark:SetSize(14, 14)
    b.mark:SetPoint("TOPRIGHT", 3, 3)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnEnter", function(self)
        if not self.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.itemID)
        if onEnter then onEnter(self) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnClick", function(self, button)
        if not self.itemID then return end
        if IsModifiedClick() then
            local _, link = C_Item.GetItemInfo(self.itemID)
            if link then HandleModifiedItemClick(link) end
            return
        end
        if onClick then onClick(self, button) end
    end)
    return b
end

-- Shows item `itemID` in slot `b`, with `corner` text and `mark` (a texture or nil).
function J.SetSlot(b, itemID, corner, mark)
    local text = ns.JournalText
    b.itemID = itemID
    b.icon:SetTexture(text.ItemIcon(itemID))
    b.border:SetVertexColor(text.ItemColor(itemID))
    b.corner:SetText(corner or "")
    b.mark:SetTexture(mark)
    b.mark:SetShown(mark ~= nil)
end

-- A grid of item slots in `parent`: grid:Fill(entries, set, width) shows one slot per entry
-- (set(slot, entry) fills it), as many across as `width` holds, and hides the rest; returns the
-- height used.
function J.Grid(parent, size, gap, onEnter, onClick)
    local grid = { slots = {} }
    function grid:Fill(entries, set, width)
        local perRow = math.max(1, math.floor(((width or 0) + gap) / (size + gap)))
        for i, entry in ipairs(entries) do
            local b = self.slots[i] or J.ItemSlot(parent, size, onEnter, onClick)
            self.slots[i] = b
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", ((i - 1) % perRow) * (size + gap), -math.floor((i - 1) / perRow) * (size + gap))
            set(b, entry)
            b:Show()
        end
        for i = #entries + 1, #self.slots do self.slots[i]:Hide() end
        return math.ceil(#entries / perRow) * (size + gap)
    end
    return grid
end
