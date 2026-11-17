--[[
    Forever Codex - UI/List.lua
    A long scrolling list that stays cheap: a scroll frame (Kit.NewScroll: Blizzard's thin
    scroll bar and the mouse wheel) over a tall empty frame, with only as many row frames as fit,
    redrawn with the items in view whenever it scrolls or its items change.

      local list = ns.List.New(parent, rowHeight, makeRow, fillRow, heightOf)
        makeRow(parent) -> a row frame (made as more fit); fillRow(row, item, index);
        heightOf(item) -> its row's height (optional: every row rowHeight high without it)
      list:SetItems(items)  -- an array; keeps the scroll place when it can
      list:Refresh()        -- draws the rows in view again (items changed in place)
      list.scroll           -- the scroll frame, for the caller to place
]]

local _, ns = ...

local math, ipairs = math, ipairs
local CreateFrame = CreateFrame

local List = {}
ns.List = List

local Methods = {}
Methods.__index = Methods

-- Each item's top, and the height of all of them (rows of one height, or heightOf's).
local function layout(self)
    local tops, y = {}, 0
    for i, item in ipairs(self.items) do
        tops[i] = y
        y = y + (self.heightOf and self.heightOf(item) or self.rowHeight)
    end
    self.tops, self.total = tops, y
end

local function heightAt(self, index)
    local item = self.items[index]
    return item ~= nil and self.heightOf and self.heightOf(item) or self.rowHeight
end

function Methods:Refresh()
    local items, tops = self.items, self.tops
    self.content:SetHeight(math.max(self.total, 1))
    local offset = self.scroll:GetVerticalScroll() or 0
    local height = self.scroll:GetHeight()
    if not height or height <= 0 then height = self.rowHeight * 20 end
    local first = 1
    while tops[first + 1] and tops[first + 1] <= offset do first = first + 1 end
    local used = 0
    local index = first
    while items[index] ~= nil and tops[index] < offset + height do
        used = used + 1
        local row = self.rows[used]
        if not row then
            row = self.makeRow(self.content)
            self.rows[used] = row
        end
        row:SetHeight(heightAt(self, index))
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -tops[index])
        row:SetPoint("RIGHT", self.content, "RIGHT")
        self.fillRow(row, items[index], index)
        row:Show()
        index = index + 1
    end
    for i = used + 1, #self.rows do self.rows[i]:Hide() end
end

function Methods:SetItems(items)
    self.items = items
    layout(self)
    local range = math.max(self.total - (self.scroll:GetHeight() or 0), 0)
    if (self.scroll:GetVerticalScroll() or 0) > range then self.scroll:SetVerticalScroll(range) end
    self:Refresh()
end

-- Scrolls so item `index` is in view.
function Methods:ShowIndex(index)
    local top = self.tops[index]
    if not top then return end
    local h = heightAt(self, index)
    local now = self.scroll:GetVerticalScroll() or 0
    local height = self.scroll:GetHeight() or 0
    if top < now then
        self.scroll:SetVerticalScroll(top)
    elseif height > 0 and top + h > now + height then
        self.scroll:SetVerticalScroll(top + h - height)
    end
    self:Refresh()
end

-- heightOf(item) (optional): each item's own height; rows are rowHeight high without it.
function List.New(parent, rowHeight, makeRow, fillRow, heightOf)
    local self = setmetatable({ rowHeight = rowHeight, makeRow = makeRow, fillRow = fillRow, heightOf = heightOf,
        rows = {}, items = {}, tops = {}, total = 0 }, Methods)
    local scroll = ns.Kit.NewScroll(parent)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll:HookScript("OnVerticalScroll", function() self:Refresh() end)
    scroll:HookScript("OnSizeChanged", function(_, width)
        content:SetWidth(width)
        self:Refresh()
    end)
    self.scroll, self.content = scroll, content
    return self
end

-- For tests and debugging: the rows that show now, in order, each with what it shows.
function Methods:ShownRows()
    local shown = {}
    for _, row in ipairs(self.rows) do
        if row:IsShown() then shown[#shown + 1] = row end
    end
    return shown
end
