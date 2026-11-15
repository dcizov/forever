--[[
    Forever Compendium - Modules/Journal/JournalKit.lua
    The pieces the journal's pages are built from, the ones Blizzard's Collections window (its
    Mount Journal and Toy Box) is made of: insets, the count box, round creature portraits in a
    gold ring, the Collections page background, collection slots (collected or not), scrolling
    "lines" of text under gold headers, item slots in quality borders, icon buttons, dropdowns, a
    search box and tabs. The lists and the list pages' layout are JournalLists.lua's; Forever
    Core's UI/Kit.lua has the rest (scroll frames).
]]

local _, ns = ...

local ipairs, pairs, next, math, type, select = ipairs, pairs, next, math, type, select
local CreateFrame = CreateFrame
local Kit = ns.Kit

local J = {}
ns.JournalKit = J

-- A page's layout, the Collections window's: a strip STRIP high at the page's top, right of the
-- portrait (PORTRAIT wide), for the count box and the page's menus; under it the insets (60
-- down the window, as Blizzard's), the list LIST_WIDTH wide on the left with GAP to the right
-- of it for its scroll bar.
J.STRIP = 36
J.PORTRAIT = 62
J.LIST_WIDTH = 270
J.GAP = 20

-- Blizzard's inset: a sunken panel with its dark ground (InsetFrameTemplate).
function J.Inset(parent)
    return CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
end

-- An inset with Blizzard's divider under a header strip HEADER_INSET high (the caller fills
-- it), and box.content for what it holds below.
J.HEADER_INSET = 34
function J.HeaderInset(parent)
    local box = J.Inset(parent)
    local line = box:CreateTexture(nil, "ARTWORK")
    line:SetAtlas("Options_HorizontalDivider", true)
    line:SetPoint("TOPLEFT", 8, -J.HEADER_INSET)
    line:SetPoint("TOPRIGHT", -8, -J.HEADER_INSET)
    box.content = CreateFrame("Frame", nil, box)
    box.content:SetPoint("TOPLEFT", 12, -J.HEADER_INSET - 8)
    box.content:SetPoint("BOTTOMRIGHT", -8, 8)
    return box
end

-- The Collections window's count box ("Creatures   213"): label at its left, number at its right.
-- Returns it; box.Count:SetText(...) sets the number.
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

-- The Collections window's page background (the Toy Box's and Heirlooms'): its stone tile, the
-- shadow in from the edges, gold corners and the filigree at the top, inside `inset`.
function J.CollectionsBackground(inset)
    local tile = inset:CreateTexture(nil, "BACKGROUND", nil, 1)
    tile:SetAtlas("collections-background-tile", false)
    tile:SetHorizTile(true)
    tile:SetVertTile(true)
    tile:SetPoint("TOPLEFT", 3, -3)
    tile:SetPoint("BOTTOMRIGHT", -3, 3)
    local corners = {
        { "TOPLEFT", false, false }, { "TOPRIGHT", true, false }, { "BOTTOMLEFT", false, true }, { "BOTTOMRIGHT", true, true },
    }
    for _, c in ipairs(corners) do
        local corner = inset:CreateTexture(nil, "BORDER")
        corner:SetAtlas("collections-background-corner", true)
        corner:SetPoint(c[1], c[2] and -3 or 3, c[3] and 3 or -3)
        corner:SetTexCoord(c[2] and 1 or 0, c[2] and 0 or 1, c[3] and 1 or 0, c[3] and 0 or 1)
    end
    local filigree = inset:CreateTexture(nil, "BORDER")
    filigree:SetAtlas("collections-background-filagree", true)
    filigree:SetPoint("TOP", 0, -3)
    return tile
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
local Portrait = {}

function Portrait:SetCreature(rec)
    local display = rec and (rec.display or next(rec.displays or {}))
    if display then
        SetPortraitTextureFromCreatureDisplayID(self.face, display)
    else
        self.face:SetTexture(KIND_ICONS[rec and rec.creatureType] or "Interface\\Icons\\INV_Misc_QuestionMark")
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

-- A collection slot (the Toy Box's): an icon or portrait in Blizzard's collected border, or the
-- grey uncollected one; slot:SetCollected(on).
function J.CollectionSlot(parent, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    f.border = f:CreateTexture(nil, "OVERLAY")
    f.border:SetPoint("CENTER")
    function f.SetCollected(self, on)
        self.border:SetAtlas(on and "collections-itemborder-collected" or "collections-itemborder-uncollected")
        self.border:SetSize(size * (on and 1.17 or 1.05), size * (on and 1.17 or 1.05))
    end
    return f
end

-- A gold header with Blizzard's divider under it.
function J.Header(parent, text, font)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(24)
    f.text = f:CreateFontString(nil, "OVERLAY", font or "GameFontNormalLarge")
    f.text:SetPoint("BOTTOMLEFT", 2, 5)
    f.text:SetText(text)
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetAtlas("Options_HorizontalDivider", true)
    line:SetPoint("BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", 0, 0)
    return f
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
function J.Search(parent, width, instructions, onChange)
    local box = CreateFrame("EditBox", nil, parent, "SearchBoxTemplate")
    box:SetSize(width, 20)
    box:SetAutoFocus(false)
    box.Instructions:SetText(instructions)
    box:HookScript("OnTextChanged", function(self) onChange(strlower(strtrim(self:GetText()))) end)
    return box
end

---------------------------------------------------------------------------
-- Tabs
---------------------------------------------------------------------------

-- The window's tabs: Forever's big icon tabs down its right edge (LargeSideTabButtonTemplate,
-- as on the Character, Legacy System and Professions windows), one per page { label, icon },
-- the first 60 down and each under the last. onSelect(index) when one is clicked. Returns the
-- holder: holder.Select(index), holder.list (the tabs). Made once; Set(pages) shows them again
-- for another list of pages.
function J.SideTabs(window, onSelect)
    local holder = CreateFrame("Frame", nil, window)
    holder:SetSize(1, 1)
    holder:SetPoint("TOPLEFT", window, "TOPRIGHT", 0, -60)
    holder.list = {}
    function holder.Select(index)
        for i, tab in ipairs(holder.list) do tab:SetChecked(i == index) end
    end
    function holder.Set(pages)
        for i, page in ipairs(pages) do
            local tab = holder.list[i]
            if not tab then
                tab = CreateFrame("Frame", nil, holder, "LargeSideTabButtonTemplate")
                tab:SetID(i)
                if i == 1 then
                    tab:SetPoint("TOPLEFT")
                else
                    tab:SetPoint("TOPLEFT", holder.list[i - 1], "BOTTOMLEFT", 0, -2)
                end
                tab:SetCustomOnMouseUpHandler(function(self, button, upInside)
                    if button == "LeftButton" and upInside then
                        ns.Sound("tab")
                        holder.Select(self:GetID())
                        onSelect(self:GetID())
                    end
                end)
                holder.list[i] = tab
            end
            tab.tooltipText = page.label
            J.SetIcon(tab.Icon, page.icon)
            tab:Show()
        end
        for i = #pages + 1, #holder.list do holder.list[i]:Hide() end
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
-- Lines: a scrolling column of headers and text lines (icons, clicks and tooltips optional)
---------------------------------------------------------------------------

local Lines = {}
Lines.__index = Lines

-- A scroll frame in `parent` (the caller places lines.scroll) holding lines as wide as it is
-- (`width` until it has been laid out).
function J.NewLines(parent, width)
    local scroll = Kit.NewScroll(parent)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(width, 1)
    scroll:SetScrollChild(content)
    return setmetatable({ scroll = scroll, content = content, width = width, heads = {}, lines = {} }, Lines)
end

function Lines:Begin()
    self.y, self.usedHeads, self.usedLines = 0, 0, 0
    local width = self.scroll:GetWidth()
    if width and width > 1 then
        self.width = width
        self.content:SetWidth(width)
    end
end

function Lines:Gap(height) self.y = self.y + (height or 10) end

function Lines:Head(text)
    if self.y > 0 then self:Gap(8) end
    self.usedHeads = self.usedHeads + 1
    local head = self.heads[self.usedHeads]
    if not head then
        head = J.Header(self.content, "", "GameFontNormal")
        self.heads[self.usedHeads] = head
    end
    head.text:SetText(text)
    head:ClearAllPoints()
    head:SetPoint("TOPLEFT", 0, -self.y)
    head:SetWidth(self.width)
    head:Show()
    self.y = self.y + head:GetHeight() + 4
end

local function newLine(content)
    local b = CreateFrame("Button", nil, content)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(16, 16)
    b.icon:SetPoint("TOPLEFT", 0, -1)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.text:SetJustifyH("LEFT")
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 0.82, 0, 0.08)
    b:SetScript("OnClick", function(self, button) if self.opts.onClick then self.opts.onClick(self, button) end end)
    b:SetScript("OnEnter", function(self) if self.opts.onEnter then self.opts.onEnter(self) end end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end

-- A line of text. opts: icon (file, ID or "atlas:Name") or display (a creature look: its
-- round portrait), indent, font, onClick(line, button),
-- onEnter(line) (a tooltip), data (kept on the line for those).
function Lines:Line(text, opts)
    opts = opts or {}
    self.usedLines = self.usedLines + 1
    local b = self.lines[self.usedLines]
    if not b then
        b = newLine(self.content)
        self.lines[self.usedLines] = b
    end
    b.opts, b.data = opts, opts.data
    local indent = opts.indent or 0
    b.text:SetFontObject(opts.font or "GameFontHighlight")
    b.text:ClearAllPoints()
    if opts.display then
        SetPortraitTextureFromCreatureDisplayID(b.icon, opts.display)
        b.icon:Show()
    elseif opts.icon then
        J.SetIcon(b.icon, opts.icon)
        b.icon:Show()
        b.text:SetPoint("TOPLEFT", 20, -2)
    else
        b.icon:Hide()
        b.text:SetPoint("TOPLEFT", 0, -1)
    end
    local hasIcon = opts.icon ~= nil or opts.display ~= nil
    b.text:SetWidth(self.width - indent - (hasIcon and 20 or 0))
    b.text:SetText(text)
    local height = math.max(hasIcon and 18 or 0, b.text:GetStringHeight() + 3)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", indent, -self.y)
    b:SetSize(self.width - indent, height)
    b:EnableMouse(opts.onClick ~= nil or opts.onEnter ~= nil)
    b.hl:SetShown(opts.onClick ~= nil)
    b:Show()
    self.y = self.y + height + 1
    return b
end

function Lines:End()
    for i = self.usedHeads + 1, #self.heads do self.heads[i]:Hide() end
    for i = self.usedLines + 1, #self.lines do self.lines[i]:Hide() end
    self.content:SetHeight(math.max(self.y, 1))
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
