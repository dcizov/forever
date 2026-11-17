--[[
    Forever Codex - Modules/Journal/CreatureNotes.lua
    Your note on a creature: a button on its model's stage (CreatureDetail.lua places it; lit
    while the creature has a note) opens a panel over the model to write in, kept as you type
    (Book.SetNote). The panel stays open from one creature to the next until closed.
]]

local _, ns = ...
local L = ns.L

local math = math
local CreateFrame = CreateFrame
local Book = ns.Book
local J = assert(ns.JournalKit, "CreatureNotes.lua loads after JournalKit.lua")

local NOTE_ICON = "Interface\\Icons\\INV_Misc_Note_01"

local Notes = {}
ns.CreatureNotes = Notes

local pane = {}

local function fill()
    local rec = Book.Creature(pane.npcID)
    pane.filling = true
    pane.edit:SetText(rec and rec.note or "")
    pane.filling = false
    pane.prompt:SetShown(not (rec and rec.note))
    pane.edit:SetWidth(math.max((pane.scroll:GetWidth() or 0) - 4, 100))
end

local function setShown(on)
    pane.panel:SetShown(on)
    if on then
        fill()
        pane.edit:SetFocus()
    elseif pane.edit:HasFocus() then
        pane.edit:ClearFocus()
    end
end

-- The button on `controls` (the stage's buttons) and the panel over `stage`.
function Notes.Build(controls, stage)
    pane.button = J.IconButton(controls, 22, NOTE_ICON, L.CNOTES_TITLE, L.CNOTES_TIP, function()
        ns.Sound("button")
        setShown(not pane.panel:IsShown())
    end)

    -- A leaf of the book's own parchment laid over the stage, written on in its ink.
    local panel = J.Page(controls)
    panel:SetPoint("TOPLEFT", stage, "TOPLEFT", 8, -8)
    panel:SetPoint("BOTTOMRIGHT", stage, "BOTTOMRIGHT", -40, 8)
    panel:EnableMouse(true)
    panel:Hide()
    pane.panel = panel
    local title = J.Header(panel, L.CNOTES_TITLE, "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -6)
    title:SetPoint("RIGHT", -30, 0)
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() setShown(false) end)

    local scroll = ns.Kit.NewScroll(panel)
    scroll:SetPoint("TOPLEFT", 14, -40)
    scroll:SetPoint("BOTTOMRIGHT", -26, 12)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(GameFontHighlight)
    J.InkFont(edit)
    edit:SetWidth(200)
    -- As wide as the note, whatever the window's size.
    scroll:SetScript("OnSizeChanged", function(_, width) if width > 1 then edit:SetWidth(width - 4) end end)
    edit:SetMaxLetters(4000)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    edit:SetScript("OnTextChanged", function(self)
        if pane.filling then return end
        local text = self:GetText()
        Book.SetNote(pane.npcID, text)
        pane.prompt:SetShown(text == "")
        Notes.Mark()
    end)
    scroll:SetScrollChild(edit)
    scroll:EnableMouse(true)
    scroll:SetScript("OnMouseDown", function() edit:SetFocus() end)
    pane.edit, pane.scroll = edit, scroll
    pane.prompt = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    J.InkFont(pane.prompt, "inkSoft")
    pane.prompt:SetPoint("TOPLEFT", scroll, "TOPLEFT", 2, -2)
    pane.prompt:SetPoint("RIGHT", scroll, "RIGHT", -4, 0)
    pane.prompt:SetJustifyH("LEFT")
    pane.prompt:SetText(L.CNOTES_PROMPT)
    return pane.button
end

-- The button lit while the creature has a note.
function Notes.Mark()
    local rec = Book.Creature(pane.npcID)
    local has = rec ~= nil and rec.note ~= nil
    pane.button.icon:SetDesaturated(not has)
    pane.button.icon:SetAlpha(has and 1 or 0.6)
end

-- Shows creature `npcID`'s note (the panel, if open, follows it).
function Notes.Show(npcID)
    if pane.npcID ~= npcID and pane.edit:HasFocus() then pane.edit:ClearFocus() end
    pane.npcID = npcID
    Notes.Mark()
    if pane.panel:IsShown() then fill() end
end

-- Opens the panel on the creature shown.
function Notes.Open() setShown(true) end
