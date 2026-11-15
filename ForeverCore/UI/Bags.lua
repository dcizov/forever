--[[
    Forever Core - UI/Bags.lua
    Finding an item in the bags, for any member (the Compendium's item page): Bags.Has(itemID)
    says whether it's in your bags, and Bags.Find(mod, itemID) opens them on it, out of combat
    only (the one Blizzard window addon code opens: README's rules).
      * Baganator: its bags open (its "BagShow", what its loot toast does) and it flashes the
        item's buttons itself ("HighlightIdenticalItems", what its own item search does:
        ItemViewCommon/Search.lua), a moment later once its view is drawn. Calls into it are
        pcalled and their errors go to the module's log.
      * Blizzard's bags: OpenAllBags, then each of the item's buttons gets a soft white glow
        (the bags' own "bags-glow-white") that pulses for a few seconds.
]]

local _, ns = ...

local pairs, type, tostring, setmetatable, pcall = pairs, type, tostring, setmetatable, pcall
local Plain = ns.Plain

local Bags = {}
ns.Bags = Bags

local SETTLE = 0.2  -- seconds for the bags to draw their items before the item is marked
local GLOW_FOR = 3  -- seconds the glow pulses
local glows = setmetatable({}, { __mode = "k" }) -- item button -> our glow texture

-- Whether `itemID` is in your bags (not the bank).
function Bags.Has(itemID)
    return type(itemID) == "number" and (C_Item.GetItemCount(itemID) or 0) > 0
end

local function glowOn(button)
    local glow = glows[button]
    if not glow then
        glow = button:CreateTexture(nil, "OVERLAY", nil, 7)
        glow:SetAtlas("bags-glow-white")
        glow:SetBlendMode("ADD")
        glow:SetAllPoints()
        local pulse = glow:CreateAnimationGroup()
        pulse:SetLooping("BOUNCE")
        local alpha = pulse:CreateAnimation("Alpha")
        alpha:SetFromAlpha(1)
        alpha:SetToAlpha(0.2)
        alpha:SetDuration(0.5)
        glow.pulse = pulse
        glows[button] = glow
    end
    glow:Show()
    glow.pulse:Play()
    return glow
end

local function glowOff()
    for _, glow in pairs(glows) do
        glow.pulse:Stop()
        glow:Hide()
    end
end

-- Marks every shown button of Blizzard's bags that holds `itemID`. Returns how many.
function Bags.Mark(itemID)
    glowOff()
    local marked = 0
    for _, container in ContainerFrameUtil_EnumerateContainerFrames() do
        if container:IsShown() then
            for _, button in container:EnumerateValidItems() do
                local info = C_Container.GetContainerItemInfo(button:GetBagID(), button:GetID())
                if info and Plain(info.itemID) == itemID then
                    glowOn(button)
                    marked = marked + 1
                end
            end
        end
    end
    return marked
end

local function baganator(mod, event, ...)
    local registry = _G.Baganator and Baganator.CallbackRegistry
    if not (registry and type(registry.TriggerEvent) == "function") then return nil end
    local ok, err = pcall(registry.TriggerEvent, registry, event, ...)
    if not ok then mod:Debug("Baganator:", tostring(err)) end
    return ok
end

-- Opens the bags on `itemID` for `mod` (whose timers it uses). False when it can't: in combat,
-- or the item isn't in your bags.
function Bags.Find(mod, itemID)
    if InCombatLockdown() or not Bags.Has(itemID) then return false end
    if _G.Baganator and Baganator.CallbackRegistry then
        if not baganator(mod, "BagShow") then return false end
        local _, link = C_Item.GetItemInfo(itemID)
        mod:After(SETTLE, function() baganator(mod, "HighlightIdenticalItems", link or ("item:" .. itemID)) end)
        return true
    end
    OpenAllBags()
    mod:After(SETTLE, function()
        if Bags.Mark(itemID) > 0 then mod:After(GLOW_FOR, glowOff) end
    end)
    return true
end
