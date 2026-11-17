--[[
    Forever Codex - Modules/Journal/JournalLines.lua
    More of JournalKit (ns.JournalKit): links and lines.

      * J.Link(kind, id, button): opens what a line, slot or row names: a creature or NPC on its
        page, a quest on the Quests page, an item on the Items page, a place on the world map;
        Shift-click puts a quest or item in chat (an item's Ctrl-click tries it on).
      * J.NewLines: a scrolling column of headings over the spellbook's divider and lines of text
        on the parchment, in its ink (J.Ink), each with an icon or a creature's round face, a
        softer tag at its right, and a link, a click or a tooltip; Lines:Quest is a quest's line,
        one icon for where it stands with you.
]]

local _, ns = ...

local math = math
local CreateFrame = CreateFrame
local Kit = ns.Kit
local J = assert(ns.JournalKit, "JournalLines.lua loads after JournalKit.lua")
local C = J.COLOR

---------------------------------------------------------------------------
-- Links: what a line, slot or row names, opened on a click
---------------------------------------------------------------------------

-- Opens what `kind` ("creature", "quest", "item", "place") and `id` name: Shift-click puts a
-- quest or item in chat (an item's Ctrl-click tries it on), any other click opens its journal
-- page (a place: the world map on it, `extra` its creature's pin). Returns whether it did something.
function J.Link(kind, id, button, extra)
    if id == nil then return false end
    if kind == "item" then
        if IsModifiedClick() then
            local _, link = C_Item.GetItemInfo(id)
            if link then HandleModifiedItemClick(link) end
            return link ~= nil
        end
        ns.ShowItem(id)
    elseif kind == "quest" then
        if IsShiftKeyDown() then
            local link = GetQuestLink(id)
            -- Into the chat line being typed, else a new one opened with it (as Forever++ does).
            if link and not ChatFrameUtil.InsertLink(link) then ChatFrameUtil.OpenChat(link) end
            return link ~= nil
        end
        -- Ctrl-click: the quest on the world map (Modules/Map/QuestFocus.lua).
        if IsControlKeyDown() then ns.FocusQuest(id) else ns.ShowQuest(id) end
    elseif kind == "creature" then
        ns.ShowCreature(id)
    elseif kind == "place" then
        if extra then ns.FocusCreature(extra) end
        OpenWorldMap(id)
    else
        return false
    end
    if button then ns.Sound("click") end
    return true
end

---------------------------------------------------------------------------
-- Lines: a scrolling column of headers and text lines (icons, clicks and tooltips optional)
---------------------------------------------------------------------------

local Lines = {}
Lines.__index = Lines
J.Lines = Lines -- for JournalSpells.lua's Lines:Entries

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
    self.y, self.usedHeads, self.usedLines, self.usedGrids, self.usedCells = 0, 0, 0, 0, 0
    local width = self.scroll:GetWidth()
    if width and width > 1 then
        self.width = width
        self.content:SetWidth(width)
    end
end

function Lines:Gap(height) self.y = self.y + (height or 10) end

-- A heading (`count`: how many under it, "- 3" beside it in the softer ink; `ink`: J.COLOR's key
-- for its colour, the headings' dark gold by default).
function Lines:Head(text, count, ink)
    if self.y > 0 then self:Gap(8) end
    self.usedHeads = self.usedHeads + 1
    local head = self.heads[self.usedHeads]
    if not head then
        head = J.Header(self.content, "", "GameFontNormal")
        self.heads[self.usedHeads] = head
    end
    head.text:SetText(text)
    J.InkFont(head.text, ink or "heading")
    head.count:SetText(count and ("\194\183 " .. count) or "")
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
    b.mask = b:CreateMaskTexture()
    b.mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    b.mask:SetAllPoints(b.icon)
    b.tag = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.tag:SetPoint("TOPRIGHT", -2, -3)
    b.tag:SetJustifyH("RIGHT")
    J.InkFont(b.tag, "inkSoft")
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.text:SetJustifyH("LEFT")
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(C.ink[1], C.ink[2], C.ink[3], 0.1)
    b:SetScript("OnClick", function(self, button)
        local o = self.opts
        if o.onClick then return o.onClick(self, button) end
        if o.link then J.Link(o.link[1], o.link[2], button, o.link[3]) end
    end)
    b:SetScript("OnEnter", function(self) if self.opts.onEnter then self.opts.onEnter(self) end end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end

-- A line of text. opts: icon (file, ID or "atlas:Name") or display (a creature look: its
-- round portrait), tag (a short dimmed text at the right: a rate, a role), indent, font,
-- link = { kind, id[, extra] } (J.Link: what a click opens) or onClick(line, button),
-- onEnter(line) (a tooltip), data (kept on the line for those), width (narrower than the column).
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
    local width = math.min(self.width - indent, opts.width or self.width)
    b.text:SetFontObject(opts.font or "GameFontHighlight")
    J.InkFont(b.text)
    b.text:ClearAllPoints()
    b.icon:RemoveMaskTexture(b.mask)
    local hasIcon = opts.icon ~= nil or opts.display ~= nil
    if opts.display then
        SetPortraitTextureFromCreatureDisplayID(b.icon, opts.display)
        b.icon:AddMaskTexture(b.mask)
    elseif opts.icon then
        J.SetIcon(b.icon, opts.icon)
    end
    b.icon:SetShown(hasIcon)
    b.text:SetPoint("TOPLEFT", hasIcon and 20 or 0, hasIcon and -2 or -1)
    b.tag:SetText(J.Ink(opts.tag) or "")
    local tagWidth = opts.tag and (b.tag:GetStringWidth() + 8) or 0
    b.text:SetWidth(width - (hasIcon and 20 or 0) - tagWidth)
    b.text:SetText(J.Ink(text))
    local height = math.max(hasIcon and 18 or 0, b.text:GetStringHeight() + 3)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", indent, -self.y)
    b:SetSize(width, height)
    local clicks = opts.onClick ~= nil or opts.link ~= nil
    b:EnableMouse(clicks or opts.onEnter ~= nil)
    b.hl:SetShown(clicks)
    b:Show()
    self.y = self.y + height + 1
    return b
end

-- A quest's line: its state's icon (JournalText.STATE_ICONS), "[level] title" and `tag` at the right
-- (what the creature does for it); a click opens it on the Quests page, Shift-click links it,
-- Ctrl-click shows it on the world map.
function Lines:Quest(questID, tag, opts)
    local Text = ns.JournalText
    opts = opts or {}
    opts.icon = Text.STATE_ICONS[Text.QuestState(questID)]
    opts.tag, opts.link = tag, { "quest", questID }
    return self:Line(Text.QuestTitleLine(questID), opts)
end

-- A grid of item slots (J.Grid, 36 across) under the lines so far: set(slot, entry) fills one
-- slot per entry; onEnter(slot) adds to an item's tooltip. A click opens the item's page.
function Lines:Slots(entries, set, onEnter)
    self.usedGrids = self.usedGrids + 1
    self.grids = self.grids or {}
    local holder = self.grids[self.usedGrids]
    if not holder then
        holder = CreateFrame("Frame", nil, self.content)
        holder.grid = J.Grid(holder, 36, 6, function(slot) if holder.onEnter then holder.onEnter(slot) end end,
            function(slot) J.Link("item", slot.itemID, "LeftButton") end)
        self.grids[self.usedGrids] = holder
    end
    holder.onEnter = onEnter
    holder:ClearAllPoints()
    holder:SetPoint("TOPLEFT", 2, -self.y - 2)
    holder:SetWidth(self.width - 4)
    local height = holder.grid:Fill(entries, set, self.width - 4)
    holder:SetHeight(math.max(height, 1))
    holder:Show()
    self.y = self.y + height + 4
end

function Lines:End()
    for i = self.usedCells + 1, #(self.cellSets or {}) do self.cellSets[i]:Hide() end
    for i = self.usedGrids + 1, #(self.grids or {}) do self.grids[i]:Hide() end
    for i = self.usedHeads + 1, #self.heads do self.heads[i]:Hide() end
    for i = self.usedLines + 1, #self.lines do self.lines[i]:Hide() end
    self.content:SetHeight(math.max(self.y, 1))
end
