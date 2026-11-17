--[[
    Forever Codex - Minimap Button
    The suite's one button on the minimap, in the addon menu under it (the addon compartment), or
    both. Click opens what the first member addon that has one opens (Forever Codex's
    journal: Core/Members.lua, member.open), else Settings; right-click opens Settings. Drag it
    around the minimap's edge. While Forever Gearbox' Button Bag is on, it takes this button like
    any other addon's (it watches this module's settings to know when the button comes and goes).
    The button keeps the name it had in Forever Gearbox, so the Button Bag and saved places still
    know it.
]]

local _, ns = ...
local L = ns.L

local format, type, ipairs = string.format, type, ipairs

local M = ns:NewModule("MinimapButton", {
    title = L.MMB_TITLE,
    category = "settings",
    description = format(L.MMB_DESC, ns.member.title),
    added = "0.4.0",
    defaults = {
        enabled = true,
        where = "minimap",
        angle = 200, -- its place around the minimap, in degrees
    },
    options = {
        { key = "where", type = "dropdown", label = L.MMB_WHERE, tooltip = L.MMB_WHERE_TIP,
          choices = {
              { "minimap", L.MMB_MINIMAP },
              { "compartment", L.MMB_COMPARTMENT },
              { "both", L.MMB_BOTH },
          } },
    },
})

local button      -- the minimap button
local compartment -- our entry in the addon menu, while it's there

-- The first member with something to open, or nil.
local function opener()
    for _, member in ipairs(ns.members) do
        if member.open then return member end
    end
end

local function onClick(_, mouse)
    local member = opener()
    if mouse == "RightButton" or not member then return ns:OpenSettings() end
    member.open()
end

-- Fills the tooltip; the caller shows it.
local function fillButtonTooltip(owner, drag)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:AddDoubleLine(ns.title, ns.version, 1, 0.82, 0, 0.6, 0.6, 0.6)
    local on, total = ns:CountModules()
    GameTooltip:AddLine(format(L.MODULES_ON, on, total), 1, 1, 1)
    local updates = ns.modules.Updates
    local newer = updates.active and updates:NewerVersion()
    if newer then GameTooltip:AddLine(format(L.UPDATES_TOOLTIP, newer), 0.1, 1, 0.1) end
    GameTooltip:AddLine(" ")
    local member = opener()
    if member then
        GameTooltip:AddLine(format(L.MMB_HINT_OPEN, member.openLabel and L[member.openLabel] or member.short), 0.1, 1, 0.1)
        GameTooltip:AddLine(L.MMB_HINT_RIGHT, 0.1, 1, 0.1)
    else
        GameTooltip:AddLine(L.MMB_HINT_CLICK, 0.1, 1, 0.1)
    end
    if drag then GameTooltip:AddLine(L.MMB_HINT_DRAG, 0.1, 1, 0.1) end
end

---------------------------------------------------------------------------
-- The addon menu (compartment). Registered here instead of in the TOC so it can come and go.
-- Blizzard has no way to unregister, so ours comes out of its list, as LibDBIcon does.
---------------------------------------------------------------------------

local function addCompartment()
    if compartment then return end
    compartment = {
        text = ns.title,
        icon = ns.icon,
        notCheckable = true,
        registerForAnyClick = true,
        func = function() onClick() end,
        -- Blizzard's addon menu has passed the hovered row as a frame or not at all, across
        -- versions. Which one Forever's uses isn't confirmed (docs/forever-api.md), so both are taken.
        funcOnEnter = function(owner)
            fillButtonTooltip(type(owner) == "table" and owner.IsObjectType and owner or AddonCompartmentFrame, false)
            GameTooltip:Show()
        end,
        funcOnLeave = GameTooltip_Hide,
    }
    AddonCompartmentFrame:RegisterAddon(compartment)
end

local function removeCompartment()
    local entries = AddonCompartmentFrame.registeredAddons
    if compartment and entries then
        for i = #entries, 1, -1 do
            if entries[i] == compartment then table.remove(entries, i) end
        end
        AddonCompartmentFrame:UpdateDisplay()
    end
    compartment = nil
end

local function update()
    local where = M.active and M.db.where or "none"
    if where == "minimap" or where == "both" then
        button = button or ns.Widgets.MinimapButton(M, {
            name = "ForeverCodexMinimapButton",
            icon = ns.icon,
            angleKey = "angle",
            onClick = onClick,
            onEnter = function(self) fillButtonTooltip(self, true) end,
        })
        button:Show()
    elseif button then
        button:Hide()
    end
    if where == "compartment" or where == "both" then addCompartment() else removeCompartment() end
end

-- Whether the button is on the minimap (the Button Bag's notice asks).
function M:IsOnMinimap()
    return self.active and (self.db.where == "minimap" or self.db.where == "both")
end

-- For the Button Bag: whether `frame` is this button, and showing it on the minimap again.
function M:IsOurButton(frame) return frame ~= nil and frame == button end

function M:ShowOnMinimap()
    ns:SetEnabled(self.name, true)
    ns:SetOption(self.name, "where", "both")
end

function M:OnEnable() update() end
function M:OnDisable() update() end
function M:OnSettingChanged(key)
    if key == "where" then update() end
end
