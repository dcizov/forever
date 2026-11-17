--[[
    Forever Gearbox - Upgrade Arrows in Baganator (module key BaganatorUpgrades)
    Upgrade arrows in Baganator's bags (UI/BagButtons.lua), while Baganator is loaded:

      * an upgrade plugin: Baganator's "upgrade" search and its Upgrades category go by it
        (Baganator picks the first plugin registered while none is picked; else the player picks
        it in Baganator's settings);
      * a corner widget with Blizzard's green arrow (bags-greenarrow) on an upgrade; with Show
        Downgrades, the same arrow turned over and red on a downgrade; with Percentage, the
        difference under it. Top left, first in its corner.

    The judgement is our own (Lib/Upgrades.lua: stat weights for your class and talent tree,
    against what you wear, Forever++'s defaults), asked again when your gear, level or talents
    change and once an item it waited for has loaded. With Forever++ Integration (Core/Plugin.lua)
    it's Forever++'s Upgrade Arrows' instead (ForeverPlusPlusAPI.v1.GetItemUpgradeInfo while it's on,
    redrawn on its UPGRADES_UPDATED), and this is also a section on Upgrade Arrows' page there.
]]

local _, ns = ...
local L = ns.L

local type, ipairs, format, PI = type, ipairs, string.format, math.pi
local BagButtons, OtherAddons, Upgrades = ns.BagButtons, ns.OtherAddons, ns.Upgrades

local ATLAS = "bags-greenarrow" -- the arrow Blizzard's bag buttons keep hidden, as Forever++ draws it
local SIZE = 14
local GREEN, RED = { 0.1, 1, 0.1 }, { 1, 0.25, 0.25 }
local OWNER = "ForeverGearboxBaganatorUpgrades" -- our Forever++ callback's owner

local M = ns:NewModule("BaganatorUpgrades", {
    attach = "UpgradeArrows", -- a section on Forever++'s UpgradeArrows page (Core/Attach.lua)
    title = L.BAGUP_TITLE,
    category = "bags",
    description = L.BAGUP_DESC,
    added = "3.0.0",
    addon = "Baganator",
    defaults = { enabled = true, downgrades = true, percent = false },
    options = {
        { key = "downgrades", type = "checkbox", label = L.BAGUP_DOWNGRADES, tooltip = L.BAGUP_DOWNGRADES_TIP },
        { key = "percent", type = "checkbox", label = L.BAGUP_SHOW_PERCENT, tooltip = L.BAGUP_SHOW_PERCENT_TIP },
    },
})

-- Forever++'s API while Forever++ Integration is on, else nil.
local function api()
    return ns.Plugin.Integrated() and _G.ForeverPlusPlusAPI.v1 or nil
end

-- The judgement of an item link: its table ({ isUpgrade, isDowngrade, percent }), false for no
-- candidate (or Forever++'s Upgrade Arrows off), or nil while the item isn't loaded. Forever++'s
-- with the integration, else our own.
local function infoOf(link)
    local fpp = api()
    if type(link) ~= "string" then return false end
    if not fpp then return Upgrades.Judge(link) end
    local ok, has = OtherAddons.Call(M, "Forever++ HasUpgradeScores", fpp.HasUpgradeScores)
    if not (ok and has) then return false end
    local got, info = OtherAddons.Call(M, "Forever++ GetItemUpgradeInfo", fpp.GetItemUpgradeInfo, link)
    if not got then return false end
    return type(info) == "table" and info or nil
end

local function isUpgrade(link)
    local info = infoOf(link)
    if info == nil then return nil end
    return info and info.isUpgrade or false
end

-- The arrow and its percentage, made once per item button.
local function newMark(button)
    local mark = CreateFrame("Frame", nil, button)
    mark:SetSize(SIZE, SIZE)
    mark.arrow = mark:CreateTexture(nil, "OVERLAY", nil, 2)
    mark.arrow:SetAtlas(ATLAS)
    mark.arrow:SetAllPoints()
    mark.text = mark:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    mark.text:SetPoint("TOPLEFT", mark, "BOTTOMLEFT", 0, 1)
    return mark
end

-- Shows Forever++'s mark for the item, as its Upgrade Arrows options would draw it.
local function paint(mark, details)
    local info = infoOf(details and details.itemLink)
    if info == nil then return nil end
    if not info then return false end
    local down = not info.isUpgrade and info.isDowngrade and M.db.downgrades
    if not (info.isUpgrade or down) then return false end
    local color = down and RED or GREEN
    mark.arrow:SetDesaturated(down and true or false)
    mark.arrow:SetRotation(down and PI or 0)
    if down then mark.arrow:SetVertexColor(color[1], color[2], color[3]) else mark.arrow:SetVertexColor(1, 1, 1) end
    local percent = type(info.percent) == "number" and M.db.percent
    if percent then
        mark.text:SetText(format(L.BAGUP_PERCENT, info.percent))
        mark.text:SetTextColor(color[1], color[2], color[3])
        mark.text:Show()
    else
        mark.text:Hide()
    end
    return true
end

local function refresh() if M.active then BagButtons.RefreshBaganator(M) end end

-- Our own judgement: what changes it forgets them all; an item it waited for asks again.
local function changed()
    Upgrades.Forget()
    M:Soon(refresh)
end

local CHANGES = { "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED" }

-- Forever++'s scores changing (with the integration) redraw the arrows.
local function followForeverPlusPlus()
    local fpp = api()
    if fpp then
        OtherAddons.Call(M, "Forever++ RegisterCallback", fpp.RegisterCallback, "UPGRADES_UPDATED",
            function() ns.ChargedCall(M, "upgrades updated", refresh) end, OWNER)
    end
end

function M:OnEnable()
    BagButtons.RegisterUpgradePlugin(self, { label = L.BAGUP_PLUGIN, id = "foreverplusplus", isUpgrade = isUpgrade })
    BagButtons.RegisterWidget(self, { label = L.BAGUP_WIDGET, id = "ForeverTweaks_Upgrade", onUpdate = paint,
        onInit = newMark, position = { corner = "top_left", priority = 1 } })
    for _, event in ipairs(CHANGES) do self:RegisterEvent(event, changed) end
    self:RegisterEvent("GET_ITEM_INFO_RECEIVED", function(_, _, itemID)
        if Upgrades.Waiting(itemID) then self:Soon(refresh) end
    end)
    followForeverPlusPlus()
    refresh()
end

-- Forever++ Integration turned on or off: the other judgement.
M:OnChanged(function(_, name)
    if name == "ForeverPlusPlus" then
        followForeverPlusPlus()
        refresh()
    end
end)

function M:OnSettingChanged() refresh() end

function M:OnDisable()
    local fpp = _G.ForeverPlusPlusAPI and _G.ForeverPlusPlusAPI.v1
    if fpp then OtherAddons.Call(self, "Forever++ UnregisterCallback", fpp.UnregisterCallback, "UPGRADES_UPDATED", OWNER) end
    BagButtons.RefreshBaganator(self) -- the arrows come off
end
