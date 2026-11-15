--[[
    Forever Tweaks - Modules/Merchant/VendorButton.lua
    Vendor's Restock button
    A round button in the merchant window's bottom row, right of Blizzard's Sell All Junk, made
    like it (Blizzard_UIPanels_Game/Mainline/MerchantFrame.xml: the empty slot behind a 36 px
    icon, the quick-slot pushed texture, the square highlight). Click buys what the Autobuy list is
    short of; right-click opens the Autobuy window. Grayed out while there's nothing to buy, the way
    Sell All Junk is without junk. Shown on the merchant's own tab only, while Vendor and its
    Restock Button option are on.

    A part of the Vendor module (module:AddPart), so it follows the module on and off; Vendor
    reaches it as M.button when the list changes.
]]

local _, ns = ...
local L = ns.L

local M = assert(ns.modules.Vendor, "VendorButton.lua loads after Vendor.lua")

local ICON = "Interface\\Icons\\INV_Misc_Bag_08"

local Button = {}
M.button = Button

local frame -- made the first time the module turns on

local function onEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.VENDOR_RESTOCK)
    GameTooltip:AddLine(self:IsEnabled() and L.VENDOR_RESTOCK_TIP or L.VENDOR_RESTOCK_NOTHING, 1, 1, 1, true)
    GameTooltip:AddLine(L.VENDOR_RESTOCK_RIGHT, 0.1, 1, 0.1)
    GameTooltip:Show()
end

local function onClick(self, mouse)
    if mouse == "RightButton" then
        M.ToggleWindow()
        return
    end
    M:Restock(false)
    Button:Update()
end

-- The Restock button, made the first time the merchant window opens with it on.
local function newButton()
    local b = CreateFrame("Button", "ForeverTweaksRestockButton", MerchantFrame)
    b:SetSize(36, 36)
    local slot = b:CreateTexture(nil, "BACKGROUND")
    slot:SetTexture("Interface\\Buttons\\UI-EmptySlot")
    slot:SetSize(64, 64)
    slot:SetPoint("TOPLEFT", -13, 14)
    b.Icon = b:CreateTexture(nil, "BORDER")
    b.Icon:SetTexture(ICON)
    b.Icon:SetAllPoints()
    b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetMotionScriptsWhileDisabled(true) -- its tooltip says why it's gray
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetPoint("LEFT", MerchantSellAllJunkButton, "RIGHT", 8, 0)
    b:SetScript("OnEnter", onEnter)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnClick", onClick)
    return b
end

-- The bottom row, as MerchantFrame_UpdateRepairButtons (Blizzard_UIPanels_Game/Mainline/
-- MerchantFrame.lua) lays it out, with room for Restock right of Sell All Junk and clear of the
-- buyback item (206 px in):
--   * no repairs: Sell All Junk alone at BOTTOMRIGHT -148; it moves 34 px left.
--   * repairs: Repair Item, Repair All (BOTTOMLEFT 118) and Sell All Junk (80 past Repair All's
--     left edge); the group moves 14 px left.
--   * repairs from the guild bank too: four buttons fill the row, so Restock isn't shown there.
-- Blizzard re-anchors Sell All Junk without clearing it (a BOTTOMRIGHT left from one merchant,
-- a RIGHT added at the next), so here it's cleared first.
local NO_REPAIR_SHIFT, REPAIR_SHIFT = 34, 14

local function roomForRestock() return not (CanMerchantRepair() and CanGuildBankRepair()) end

local function placeRow(shown)
    local junk, all = MerchantSellAllJunkButton, MerchantRepairAllButton
    if not CanMerchantRepair() then
        junk:ClearAllPoints()
        junk:SetPoint("BOTTOMRIGHT", MerchantFrame, "BOTTOMRIGHT", -148 - (shown and NO_REPAIR_SHIFT or 0), 33)
    elseif not CanGuildBankRepair() then
        all:SetPoint("BOTTOMRIGHT", MerchantFrame, "BOTTOMLEFT", 118 - (shown and REPAIR_SHIFT or 0), 33)
        junk:ClearAllPoints()
        junk:SetPoint("RIGHT", all, "LEFT", 80, 0)
    end
end

-- Shown on the merchant's own tab while wanted, gray while there's nothing to buy.
function Button:Update()
    if not frame then return end
    local onTab = MerchantFrame:IsShown() and MerchantFrame.selectedTab == 1
    local shown = M.active and M.db.button and onTab and roomForRestock()
    frame:SetShown(shown)
    if onTab then placeRow(shown) end
    if not shown then return end
    local due = #M:Plan() > 0
    frame:SetEnabled(due)
    frame.Icon:SetDesaturated(not due)
end

local function update() Button:Update() end

function Button:Enable()
    frame = frame or newButton()
    -- The merchant tab draws its items as it opens and on each tab click, the buyback tab its own
    -- (which hides the bottom row). Vendor tells it when the bags or the list change (an owner
    -- has one handler per event, and Vendor's are on MERCHANT_SHOW and BAG_UPDATE_DELAYED).
    M:Hook("MerchantFrame_UpdateMerchantInfo", update)
    M:Hook("MerchantFrame_UpdateBuybackInfo", update)
    M:RegisterEvent("PLAYER_MONEY", update)
    update()
end

function Button:Disable()
    if frame then frame:Hide() end
    if MerchantFrame:IsShown() and MerchantFrame.selectedTab == 1 then placeRow(false) end
end

function Button:Changed(key)
    if key == "button" then update() end
end

M:AddPart(Button)
