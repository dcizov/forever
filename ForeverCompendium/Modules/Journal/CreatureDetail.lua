--[[
    Forever Compendium - Modules/Journal/CreatureDetail.lua
    The top of the Creatures page's right side (CreaturesPage.lua makes it and calls Show), laid
    out as Forever Bestiary does it, in the Mount Journal's look:

      * At the left, the model (ModelWithZoomTemplate: drag or Blizzard's turning buttons to
        turn it, the wheel zooms) on the Mount Journal's backdrop, cropped to fit; from the look
        the Recorder read, else from its creature ID, with arrows through its looks when it has
        several. The favourite star (pinned: shown on the map, first in the list) and, while
        Sharing is on, Share at its top right.
      * At the right, its portrait, name, title, kind and home over the column of what's known
        of it (CreatureOverview.lua).
]]

local _, ns = ...
local L = ns.L

local pairs, format, table, math = pairs, string.format, table, math
local CreateFrame = CreateFrame
local Book, Text, J = ns.Book, ns.JournalText, ns.JournalKit
local Overview = assert(ns.CreatureOverview, "CreatureDetail.lua loads after CreatureOverview.lua")

local STAGE_WIDTH = 330 -- the model's share of the display; what's known of it gets the rest

local Detail = {}
ns.CreatureDetail = Detail


local pane = {}

---------------------------------------------------------------------------
-- The model
---------------------------------------------------------------------------

local function looksOf(rec)
    local list = {}
    for id in pairs(rec.displays or {}) do list[#list + 1] = id end
    table.sort(list)
    if #list == 0 and rec.display then list[1] = rec.display end
    return list
end

local function showLook(rec, npcID)
    local looks = looksOf(rec)
    pane.look = math.max(1, math.min(pane.look or 1, #looks))
    local id = looks[pane.look]
    if id then pane.model:SetDisplayInfo(id) else pane.model:SetCreature(npcID) end
    local several = #looks > 1
    pane.prev:SetShown(several)
    pane.next:SetShown(several)
    pane.lookText:SetShown(several)
    pane.lookText:SetText(format(L.CDETAIL_LOOK, pane.look, #looks))
end

local function stepLook(delta)
    local rec = Book.Creature(pane.npcID)
    if not rec then return end
    local count = #looksOf(rec)
    pane.look = ((pane.look or 1) - 1 + delta) % math.max(count, 1) + 1
    showLook(rec, pane.npcID)
end

-- One of Blizzard's model turning buttons (common-icon-rotateleft/right): turns the model while
-- held, `dir` 1 to the left, -1 to the right.
local function rotateButton(parent, model, dir)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(26, 26)
    b:SetNormalAtlas(dir > 0 and "common-icon-rotateleft" or "common-icon-rotateright")
    b:SetHighlightAtlas(dir > 0 and "common-icon-rotateleft" or "common-icon-rotateright", "ADD")
    b:SetScript("OnMouseDown", function(self)
        self:SetScript("OnUpdate", function(_, elapsed)
            model.rotation = (model.rotation or 0) + dir * elapsed * 2.5
            model:SetRotation(model.rotation)
        end)
    end)
    b:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
    return b
end

-- The Mount Journal's backdrop (MountJournal-BG, its art the left 402 of 512 across, 512 high)
-- cropped to fill `texture` at its size without stretching: the floor kept, the sky cut first.
local ART_W, ART_H, ART_U = 402, 512, 0.78515625
local function fitBackdrop(texture, width, height)
    if not (width and height and width > 0 and height > 0) then return end
    local aspect = width / height
    if aspect >= ART_W / ART_H then
        local h = ART_W / aspect
        local top = (ART_H - h) * 0.7
        texture:SetTexCoord(0, ART_U, top / ART_H, (top + h) / ART_H)
    else
        local w = ART_H * aspect
        local left = (ART_W - w) / 2
        texture:SetTexCoord(left / ART_W * ART_U, (left + w) / ART_W * ART_U, 0, 1)
    end
end

-- The stage at the display's left: the model on the Mount Journal's backdrop, the favourite
-- star and Share at its top right, the turning buttons at its bottom, arrows through its looks.
local function buildStage(box)
    local stage = CreateFrame("Frame", nil, box)
    stage:SetPoint("TOPLEFT", 3, -3)
    stage:SetPoint("BOTTOMLEFT", 3, 3)
    stage:SetWidth(STAGE_WIDTH)
    local art = stage:CreateTexture(nil, "BACKGROUND", nil, 2)
    art:SetTexture("Interface\\PetBattles\\MountJournal-BG")
    art:SetAllPoints()
    fitBackdrop(art, STAGE_WIDTH, box:GetHeight() - 6)
    stage:SetScript("OnSizeChanged", function(_, w, h) fitBackdrop(art, w, h) end)
    local edge = stage:CreateTexture(nil, "ARTWORK")
    edge:SetColorTexture(0, 0, 0, 0.8)
    edge:SetWidth(2)
    edge:SetPoint("TOPLEFT", stage, "TOPRIGHT")
    edge:SetPoint("BOTTOMLEFT", stage, "BOTTOMRIGHT")
    local model = CreateFrame("PlayerModel", nil, stage, "ModelWithZoomTemplate")
    model:SetAllPoints()
    pane.model = model

    local controls = CreateFrame("Frame", nil, stage)
    controls:SetFrameLevel(model:GetFrameLevel() + 5)
    controls:SetAllPoints()
    pane.pin = CreateFrame("Button", nil, controls)
    pane.pin:SetSize(25, 25)
    pane.pin:SetPoint("TOPRIGHT", -10, -10)
    pane.pin.icon = pane.pin:CreateTexture(nil, "ARTWORK")
    pane.pin.icon:SetAtlas("PetJournal-FavoritesIcon")
    pane.pin.icon:SetAllPoints()
    pane.pin:SetHighlightAtlas("PetJournal-FavoritesIcon", "ADD")
    pane.pin:SetScript("OnClick", function() ns.Journal.TogglePin(pane.npcID) end)
    pane.pin:SetScript("OnEnter", function(self) J.Tip(self, self.title, L.CDETAIL_PIN_TIP) end)
    pane.pin:SetScript("OnLeave", GameTooltip_Hide)
    pane.share = J.IconButton(controls, 22, "Interface\\Icons\\INV_Letter_15", L.CDETAIL_SHARE, L.CDETAIL_SHARE_TIP, function()
        if ns.ShareCreature then ns.ShareCreature(pane.npcID) end
    end)
    pane.share:SetPoint("TOP", pane.pin, "BOTTOM", 0, -8)
    local left, right = rotateButton(controls, model, 1), rotateButton(controls, model, -1)
    left:SetPoint("BOTTOMRIGHT", controls, "BOTTOM", -2, 10)
    right:SetPoint("BOTTOMLEFT", controls, "BOTTOM", 2, 10)
    pane.prev = J.IconButton(controls, 26, "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up", L.CDETAIL_LOOK_PREV, nil,
        function() stepLook(-1) end)
    pane.prev:SetPoint("BOTTOMLEFT", 10, 10)
    pane.next = J.IconButton(controls, 26, "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up", L.CDETAIL_LOOK_NEXT, nil,
        function() stepLook(1) end)
    pane.next:SetPoint("LEFT", pane.prev, "RIGHT", 34, 0)
    pane.lookText = controls:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pane.lookText:SetPoint("LEFT", pane.prev, "RIGHT", 2, 0)
    pane.lookText:SetPoint("RIGHT", pane.next, "LEFT", -2, 0)
    pane.sharedMark = controls:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pane.sharedMark:SetPoint("TOPLEFT", 10, -12)
    return stage
end

-- The display: an inset with the stage at its left and, right of it, the creature's portrait,
-- name, what it is and where it lives over the column of what's known (CreatureOverview.lua).
local function buildDisplay(parent, height)
    local box = J.Inset(parent)
    box:SetPoint("TOPLEFT")
    box:SetPoint("TOPRIGHT")
    box:SetHeight(height)
    local stage = buildStage(box)

    local info = CreateFrame("Frame", nil, box)
    info:SetPoint("TOPLEFT", stage, "TOPRIGHT", 16, -12)
    info:SetPoint("BOTTOMRIGHT", -8, 6)
    pane.portrait = J.Portrait(info, 50)
    pane.portrait:SetPoint("TOPLEFT")
    pane.name = info:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    pane.name:SetPoint("TOPLEFT", pane.portrait, "TOPRIGHT", 10, -4)
    pane.name:SetPoint("RIGHT", -8, 0)
    pane.name:SetJustifyH("LEFT")
    pane.name:SetWordWrap(false)
    pane.kind = info:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pane.kind:SetPoint("TOPLEFT", pane.name, "BOTTOMLEFT", 0, -4)
    pane.kind:SetPoint("RIGHT", -8, 0)
    pane.kind:SetJustifyH("LEFT")
    pane.kind:SetSpacing(2)
    pane.where = info:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pane.where:SetPoint("TOPLEFT", pane.kind, "BOTTOMLEFT", 0, -3)
    pane.where:SetPoint("RIGHT", -8, 0)
    pane.where:SetJustifyH("LEFT")
    pane.where:SetWordWrap(false)
    Overview.Build(info)
    Overview.lines.scroll:SetPoint("TOPLEFT", pane.portrait, "BOTTOMLEFT", 0, -14)
    Overview.lines.scroll:SetPoint("BOTTOMRIGHT", -16, 0)
    return box
end

---------------------------------------------------------------------------
-- The pane
---------------------------------------------------------------------------

function Detail.Build(parent, height)
    pane.top = buildDisplay(parent, height)
    pane.empty = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
    pane.empty:SetPoint("CENTER")
    pane.empty:SetText(L.JOURNAL_EMPTY)
    return setmetatable(pane, { __index = Detail })
end

-- Shows creature `npcID`, or the empty page for nil.
function Detail:Show(npcID)
    local rec = npcID and Book.Creature(npcID)
    self.top:SetShown(rec ~= nil)
    self.empty:SetShown(rec == nil)
    if self.npcID ~= npcID then self.look = 1 end
    self.npcID = npcID
    if not rec then return end
    showLook(rec, npcID)
    self.portrait:SetCreature(rec)
    self.name:SetText(rec.name or "?")
    local r, g, b = Text.ReactionColor(rec.reaction)
    local kind = Text.Kind(rec) .. "  " .. Text.Color(r, g, b) .. Text.Reaction(rec.reaction) .. "|r"
    self.kind:SetText(rec.title and ("<" .. rec.title .. ">\n" .. kind) or kind)
    self.where:SetText(Text.Where(rec))
    self.pin.icon:SetDesaturated(not rec.pinned)
    self.pin.icon:SetAlpha(rec.pinned and 1 or 0.45)
    self.pin.title = rec.pinned and L.CDETAIL_UNPIN or L.CDETAIL_PIN
    self.share:SetShown(ns.ShareCreature ~= nil and ns.CanShare())
    self.sharedMark:SetText(rec.shared and format(L.CDETAIL_SHARED_BY, rec.sharedBy or "?") or "")
    Overview.Fill(rec, npcID)
end
