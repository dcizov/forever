--[[
    Forever Codex - Modules/Journal/Npcs/NpcDetail.lua
    The right side of the NPCs page (NpcsPage.lua makes it and calls Show): one NPC. A card with
    its model standing on the page (by its look, else by its ID as the game knows it), name, title and
    level and what you dealt with it for; below, when you met it, last saw it and how often you
    dealt with it, where you found it (each zone, a click shows it on the map, with the places in
    it), what it sells as its window shows it (a slot each: a click opens the item, Shift-click
    links it, its price on its tooltip) and its quests (one icon for where each stands with you, what it does for it in words).
]]

local _, ns = ...
local L = ns.L

local ipairs, pairs, next, format, table = ipairs, pairs, next, string.format, table
local CreateFrame = CreateFrame
local Book = ns.Book
local Text = assert(ns.JournalText, "NpcDetail.lua loads after JournalText.lua")
local J = assert(ns.JournalKit, "NpcDetail.lua loads after JournalKit.lua")

local Detail = {}
ns.NpcDetail = Detail

local card, lines

-- What you can deal with an NPC for (Book's services), each with its icon and name.
Detail.SERVICES = {
    { "quest", "Interface\\Icons\\INV_Misc_Note_02", L.NPCS_QUEST }, { "vendor", "Interface\\Icons\\INV_Misc_Coin_02", L.NPCS_VENDOR },
    { "trainer", "Interface\\Icons\\INV_Misc_Book_09", L.NPCS_TRAINER }, { "flight", "Interface\\Icons\\Ability_Mount_Wyvern_01", L.NPCS_FLIGHT },
    { "bank", "Interface\\Icons\\INV_Misc_Bag_10", L.NPCS_BANK }, { "gossip", "Interface\\Icons\\INV_Letter_15", L.NPCS_GOSSIP },
}

-- The icons of what you dealt with NPC `rec` for, inline, `size` across.
function Detail.ServiceIcons(rec, size)
    local out = {}
    for _, s in ipairs(Detail.SERVICES) do
        if rec.services and rec.services[s[1]] then out[#out + 1] = Text.Icon(s[2], size) end
    end
    return table.concat(out, " ")
end

local STAGE_W, CARD_H = 170, 210 -- the NPC's model at the card's left, the card's height

function Detail.Build(parent)
    card = J.Panel(parent)
    card:SetPoint("TOPLEFT")
    card:SetPoint("TOPRIGHT")
    card:SetHeight(CARD_H)
    -- Its model, standing on the page.
    card.model = CreateFrame("PlayerModel", nil, card, "ModelWithZoomTemplate")
    card.model:SetPoint("TOPLEFT", 8, -8)
    card.model:SetSize(STAGE_W, CARD_H - 16)
    card.name = card:CreateFontString(nil, "OVERLAY", J.TITLE_FONT)
    J.InkFont(card.name)
    card.name:SetPoint("TOPLEFT", card.model, "TOPRIGHT", 12, -14)
    card.name:SetPoint("RIGHT", -16, 0)
    card.name:SetJustifyH("LEFT")
    card.title = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    card.title:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -6)
    J.InkFont(card.title, "inkSoft")
    card.kind = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.kind:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -4)
    J.InkFont(card.kind, "inkSoft")
    -- What you dealt with it for: its services, one a line, under its name.
    card.services = J.NewLines(card, 260)
    card.services.scroll:SetPoint("TOPLEFT", card.kind, "BOTTOMLEFT", 0, -12)
    card.services.scroll:SetPoint("BOTTOMRIGHT", -16, 12)
    local divider = J.Divider(card)
    divider:SetPoint("BOTTOMLEFT", 10, 0)
    divider:SetPoint("BOTTOMRIGHT", -10, 0)
    local body = J.Panel(parent)
    body:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, -6)
    body:SetPoint("BOTTOMRIGHT")
    lines = J.NewLines(body, 400)
    lines.scroll:SetPoint("TOPLEFT", 16, -6)
    lines.scroll:SetPoint("BOTTOMRIGHT", -24, 10)
end

-- Shows NPC `npcID` (nil: none).
function Detail.Show(npcID)
    local rec = npcID and Book.Creature(npcID)
    card:SetShown(rec ~= nil)
    lines:Begin()
    if not rec then
        lines:Line(Text.GRAY .. L.NPCS_EMPTY .. "|r")
        return lines:End()
    end
    -- By its look when one was read, else by its ID (the game's own model of it, as the
    -- creature page does): an NPC met only by its window has no look read.
    local display = rec.display or next(rec.displays or {})
    if display then card.model:SetDisplayInfo(display) else card.model:SetCreature(npcID) end
    J.FitModel(card.model)
    card.name:SetText(rec.name or "?")
    card.title:SetText(rec.title and ("<" .. rec.title .. ">") or "")
    card.kind:SetText(Text.LevelText(rec))
    local services = card.services
    services:Begin()
    for _, s in ipairs(Detail.SERVICES) do
        if rec.services and rec.services[s[1]] then services:Line(s[3], { icon = s[2] }) end
    end
    services:End()
    -- When you met it, last saw it, and how often you dealt with it.
    lines:Head(L.NPCS_ENCOUNTERS)
    lines:Line(Text.GOLD .. L.NPCS_FIRST .. "|r  " .. Text.Date(rec.first))
    lines:Line(Text.GOLD .. L.NPCS_LAST .. "|r  " .. Text.Date(rec.last))
    if rec.dealt then lines:Line(Text.GOLD .. L.NPCS_DEALT .. "|r  " .. format(L.NPCS_TIMES, rec.dealt)) end
    -- Where: each zone (a click shows it on the map), the places in it under it.
    local places = Text.Places(rec)
    if #places > 0 then
        lines:Head(L.NPCS_FOUND)
        for _, place in ipairs(places) do
            lines:Line(place.name, { icon = "atlas:Waypoint-MapPin-Untracked", link = { "place", place.mapID, npcID } })
            for _, sub in ipairs(place.subs) do lines:Line(Text.GRAY .. sub .. "|r", { indent = 20, font = "GameFontHighlightSmall" }) end
        end
    end
    -- What it sells, as its window shows it: a slot each (its price on the slot's tooltip).
    if rec.wares and next(rec.wares) then
        local wares = {}
        for itemID, ware in pairs(rec.wares) do wares[#wares + 1] = { itemID = itemID, ware = ware } end
        table.sort(wares, function(a, b) return Text.ItemName(a.itemID) < Text.ItemName(b.itemID) end)
        lines:Head(L.NPCS_SELLS, #wares)
        lines:Slots(wares, function(slot, w)
            slot.price = w.ware.price
            J.SetSlot(slot, w.itemID, (w.ware.stack or 1) > 1 and w.ware.stack or nil, w.ware.limited and "Interface\\Common\\Indicator-Yellow" or nil)
        end, function(slot)
            if slot.price then GameTooltip:AddLine(" ") GameTooltip:AddLine(ns.MoneyText(slot.price), 1, 1, 1) end
        end)
    end
    local quests = Text.CreatureQuests(rec)
    if #quests > 0 then
        lines:Head(L.CTABS_QUESTS, #quests)
        for _, entry in ipairs(quests) do lines:Quest(entry.questID, Text.RoleTags(entry.roles)) end
    end
    lines:End()
    lines.scroll:SetVerticalScroll(0)
end
