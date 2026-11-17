--[[
    Forever Codex - Modules/Journal/JournalSpells.lua
    More of JournalKit (ns.JournalKit): a page laid out as the spellbook lays out what you can
    learn ("What's Training?"): the Trophies and Badges pages.

      * J.SpellPage(frame): the whole page on the parchment under the strip: its title (.title)
        with a total at its right (.total), the spellbook's divider under them, the lines below
        (.lines, J.NewLines) and a hint at its foot (.hint).
      * Lines:Entries(entries, o): under the lines so far, a cell per entry in `o.columns` columns
        (as many as fit when nil): a picture (a square icon in its frame, or a creature's round
        face), a name and a softer line under it. o.fill(cell, entry) fills one (cell:Icon(file,
        r, g, b), cell:Face(rec), cell:Dim(on), cell.name, cell.sub, cell.mark); o.onClick(cell,
        button) and o.onEnter(cell) act on cell.entry.
]]

local _, ns = ...

local ipairs, pairs, math = ipairs, pairs, math
local CreateFrame = CreateFrame
local J = assert(ns.JournalKit, "JournalSpells.lua loads after JournalLines.lua")
local Lines = assert(J.Lines, "JournalSpells.lua loads after JournalLines.lua")
local C = J.COLOR

local CELL_H, CELL_MIN_W, ICON = 46, 250, 36
local STAR = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------

function J.SpellPage(frame)
    local inset, holder = J.Page(frame)
    inset:SetPoint("TOPLEFT", 0, -J.STRIP)
    inset:SetPoint("BOTTOMRIGHT")
    local p = { inset = inset }
    p.title = holder:CreateFontString(nil, "OVERLAY", J.TITLE_FONT)
    p.title:SetPoint("TOPLEFT", 36, -22)
    J.InkFont(p.title)
    p.total = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    p.total:SetPoint("BOTTOMRIGHT", p.title, "BOTTOMRIGHT", 0, 0)
    p.total:SetPoint("RIGHT", holder, "RIGHT", -48, 0)
    J.InkFont(p.total, "inkSoft")
    local line = J.Divider(holder)
    line:SetPoint("TOPLEFT", p.title, "BOTTOMLEFT", -8, -6)
    line:SetPoint("RIGHT", holder, "RIGHT", -36, 0)
    p.hint = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.hint:SetPoint("BOTTOMLEFT", 36, 12)
    p.hint:SetPoint("RIGHT", -36, 0)
    p.hint:SetJustifyH("LEFT")
    J.InkFont(p.hint, "inkSoft")
    p.lines = J.NewLines(holder, 600)
    p.lines.scroll:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 8, -10)
    p.lines.scroll:SetPoint("BOTTOMRIGHT", -44, 34)
    return p
end

---------------------------------------------------------------------------
-- Cells
---------------------------------------------------------------------------

local Cell = {}

-- A square icon in its frame, the frame tinted r, g, b (the ink's dark edge when nil).
function Cell:Icon(file, r, g, b)
    self.face:Hide()
    self.icon:Show()
    self.icon:SetTexture(file)
    self.border:Show()
    self.border:SetVertexColor(r or 0.3, g or 0.24, b or 0.16)
end

-- A creature's round face (J.Portrait).
function Cell:Face(rec)
    self.icon:Hide()
    self.border:Hide()
    self.face:Show()
    self.face:SetCreature(rec)
end

-- Greyed: what isn't yours yet (its picture without colour, its name in the softer ink).
function Cell:Dim(on)
    self.icon:SetDesaturated(on)
    self.face:SetDesaturated(on)
    J.InkFont(self.name, on and "inkSoft" or "ink")
end

local function newCell(holder)
    local cell = CreateFrame("Button", nil, holder)
    cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    cell:SetHeight(CELL_H)
    cell.icon = cell:CreateTexture(nil, "ARTWORK")
    cell.icon:SetSize(ICON, ICON)
    cell.icon:SetPoint("LEFT", 4, 0)
    cell.border = cell:CreateTexture(nil, "OVERLAY")
    cell.border:SetTexture("Interface\\Common\\WhiteIconFrame")
    cell.border:SetAllPoints(cell.icon)
    cell.face = J.Portrait(cell, ICON + 6)
    cell.face:SetPoint("CENTER", cell.icon, "CENTER")
    cell.mark = cell:CreateTexture(nil, "OVERLAY", nil, 2)
    cell.mark:SetTexture(STAR)
    cell.mark:SetSize(14, 14)
    cell.mark:SetPoint("TOPLEFT", cell.icon, "TOPLEFT", -6, 6)
    cell.name = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    cell.name:SetPoint("TOPLEFT", cell.icon, "TOPRIGHT", 10, -1)
    cell.name:SetPoint("RIGHT", -4, 0)
    cell.name:SetJustifyH("LEFT")
    cell.name:SetWordWrap(false)
    cell.sub = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cell.sub:SetPoint("TOPLEFT", cell.name, "BOTTOMLEFT", 0, -3)
    cell.sub:SetPoint("RIGHT", -4, 0)
    cell.sub:SetJustifyH("LEFT")
    cell.sub:SetWordWrap(false)
    J.InkFont(cell.sub, "inkSoft")
    local hl = cell:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(C.ink[1], C.ink[2], C.ink[3], 0.08)
    cell:SetScript("OnClick", function(self, button) if holder.o.onClick then holder.o.onClick(self, button) end end)
    cell:SetScript("OnEnter", function(self) if holder.o.onEnter then holder.o.onEnter(self) end end)
    cell:SetScript("OnLeave", GameTooltip_Hide)
    for k, fn in pairs(Cell) do cell[k] = fn end
    return cell
end

function Lines:Entries(entries, o)
    self.usedCells = (self.usedCells or 0) + 1
    self.cellSets = self.cellSets or {}
    local holder = self.cellSets[self.usedCells]
    if not holder then
        holder = CreateFrame("Frame", nil, self.content)
        holder.cells = {}
        self.cellSets[self.usedCells] = holder
    end
    holder.o = o
    local columns = o.columns or math.max(1, math.floor(self.width / CELL_MIN_W))
    local width = math.floor(self.width / columns)
    for i, entry in ipairs(entries) do
        local cell = holder.cells[i] or newCell(holder)
        holder.cells[i] = cell
        cell.entry = entry
        cell.mark:Hide()
        cell:Dim(false)
        o.fill(cell, entry)
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", ((i - 1) % columns) * width, -math.floor((i - 1) / columns) * (CELL_H + 4))
        cell:SetWidth(width - 8)
        cell:Show()
    end
    for i = #entries + 1, #holder.cells do holder.cells[i]:Hide() end
    local height = math.ceil(#entries / columns) * (CELL_H + 4)
    holder:ClearAllPoints()
    holder:SetPoint("TOPLEFT", 0, -self.y - 2)
    holder:SetSize(self.width, math.max(height, 1))
    holder:Show()
    self.y = self.y + height + 6
end
