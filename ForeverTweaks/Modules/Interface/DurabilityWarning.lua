--[[
    Forever Tweaks - Durability Warning
    Says once when your most worn piece of gear drops below the durability you pick, and once more
    when something breaks, so you repair in time: red text where the game says "Inventory is full",
    and a chat line naming the item. It warns only when it gets worse (low, then broken);
    repairing or taking the item off brings it back up, and the next drop warns again.
    Durability changes come in bursts (every hit in a fight), so it looks once they settle. Gear
    already low at login gets one warning once the world has loaded; a /reload says nothing new.
    Left to Forever++'s Durability Warning while that's on (Lib/OtherAddons.lua, CoveredBy).
    Adapted from Forever++'s Durability Warning by xIGBClutchIx (MIT License).
]]

local _, ns = ...
local L = ns.L

local format, floor = string.format, math.floor
local Plain = ns.Plain
local OtherAddons = ns.OtherAddons

local COVERS = { { "ForeverPlusPlus", "DurabilityWarning" } }
local FIRST_SLOT, LAST_SLOT = 1, 19 -- the equipped slots (INVSLOT_HEAD to INVSLOT_TABARD)
local SETTLE, FIRST_LOOK = 1, 5 -- seconds
local RANK = { ok = 0, low = 1, broken = 2 }

local M = ns:NewModule("DurabilityWarning", {
    title = L.DURABILITY_TITLE,
    category = "interface",
    description = L.DURABILITY_DESC,
    added = "1.9.0",
    defaults = { threshold = 25, broken = true, alert = true, chat = true },
    options = {
        { key = "threshold", type = "slider", label = L.DURABILITY_THRESHOLD, tooltip = L.DURABILITY_THRESHOLD_TIP,
          min = 5, max = 50, step = 5, format = "%d%%" },
        { key = "broken", type = "checkbox", label = L.DURABILITY_BROKEN, tooltip = L.DURABILITY_BROKEN_TIP },
        { key = "alert", type = "checkbox", label = L.DURABILITY_ALERT, tooltip = L.DURABILITY_ALERT_TIP },
        ns.ChatOption(),
    },
})

M.notice = OtherAddons.CoveredNotices(M, COVERS, L.DURABILITY_WHAT)

-- The most worn equipped item: its fraction (0 to 1) and slot, or nil when nothing worn has any.
local function lowest()
    local low, lowSlot
    for slot = FIRST_SLOT, LAST_SLOT do
        local current, maximum = GetInventoryItemDurability(slot)
        current, maximum = Plain(current), Plain(maximum)
        if current and maximum and maximum > 0 then
            local fraction = current / maximum
            if not low or fraction < low then low, lowSlot = fraction, slot end
        end
    end
    return low, lowSlot
end

-- "broken" at 0 (with Warn When Broken), "low" below the threshold, else "ok".
function M.Level(fraction, threshold, broken)
    if not fraction then return "ok" end
    if fraction <= 0 and broken then return "broken" end
    if fraction < threshold or fraction <= 0 then return "low" end
    return "ok"
end

local function current()
    local fraction, slot = lowest()
    return M.Level(fraction, M.db.threshold / 100, M.db.broken), fraction, slot
end

local function warn(level, fraction, slot, quiet)
    local link = slot and Plain(GetInventoryItemLink("player", slot))
    local percent = floor((fraction or 0) * 100)
    local line, alert
    if level == "broken" then
        line = link and format(L.DURABILITY_BROKEN_ITEM, link) or L.DURABILITY_BROKEN_GEAR
        alert = L.DURABILITY_ALERT_BROKEN
    else
        line = link and format(L.DURABILITY_LOW_ITEM, link, percent) or format(L.DURABILITY_LOW_GEAR, percent)
        alert = format(L.DURABILITY_ALERT_LOW, percent)
    end
    M:Print(line)
    -- The quiet first look at login: in chat only, unless chat is off.
    if M.db.alert and not (quiet and M.db.chat) then UIErrorsFrame:AddMessage(alert, 1, 0.1, 0.1) end
end

local last -- the level last seen; nil until the first look
local reloading

local function look()
    if last == nil then return end
    local level, fraction, slot = current()
    if (RANK[level] or 0) > (RANK[last] or 0) and not OtherAddons.CoveredBy(M, COVERS) then
        warn(level, fraction, slot)
    end
    last = level
end

local function firstLook()
    local level, fraction, slot = current()
    if not reloading and level ~= "ok" and not OtherAddons.CoveredBy(M, COVERS) then
        warn(level, fraction, slot, true)
    end
    last = level
end

-- Each change starts the wait again: one look once a burst has settled.
local settle
local function requestLook()
    M:CancelTimer(settle)
    settle = M:After(SETTLE, look)
end

function M:OnEnable()
    last, reloading = nil, false
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function(_, _, isLogin, isReload)
        if last == nil then reloading = isReload and not isLogin end
    end)
    self:RegisterEvent("UPDATE_INVENTORY_DURABILITY", requestLook)
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", requestLook)
    self:After(FIRST_LOOK, firstLook)
end

function M:OnDisable() last = nil end

-- A new threshold or Warn When Broken takes the level as it is now, without warning.
function M:OnSettingChanged(key)
    if (key == "threshold" or key == "broken") and last ~= nil then last = current() end
end

function M:DebugLine()
    local fraction = lowest()
    return fraction and format(L.DURABILITY_DEBUG, floor(fraction * 100)) or L.DURABILITY_DEBUG_NONE
end
