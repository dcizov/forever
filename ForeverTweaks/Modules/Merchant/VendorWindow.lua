--[[
    Forever Tweaks - Modules/Merchant/VendorWindow.lua
    Vendor's Autobuy window: the Autobuy list in a window of its own (Kit.NewStackWindow), the
    same list its Settings pane has (M:BuildPage), to fill without opening the settings; a
    Settings button goes to the module's other options. Right-click the Restock button, or type
    /ft autobuy window. Moves and stays where you leave it; Escape closes it.
    A part of the Vendor module: it closes when the module turns off.
]]

local _, ns = ...
local L = ns.L
local Kit = ns.Kit

local M = assert(ns.modules.Vendor, "VendorWindow.lua loads after Vendor.lua")

local WIDTH, HEIGHT = 480, 520
local window

local function buildWindow()
    local stack
    window, stack = Kit.NewStackWindow("ForeverTweaksAutobuyWindow", L.VENDOR_WINDOW_TITLE, WIDTH, HEIGHT)
    M:BuildPage(stack)
    local settings = Kit.NewButton(window, L.SETTINGS, 110, function()
        window:Hide()
        ns:OpenSettings(M.name)
    end)
    settings:SetPoint("BOTTOMRIGHT", -8, 6)
    window:HookScript("OnShow", function()
        M:ListChanged()
        Kit.Layout(stack)
    end)
end

-- Opens the Autobuy window (or closes it when it's open).
function M.ToggleWindow()
    if not M.active then return end
    if not window then buildWindow() end
    window:SetShown(not window:IsShown())
end

function M.WindowShown() return window ~= nil and window:IsShown() end

M:AddPart({ Disable = function() if window then window:Hide() end end })
