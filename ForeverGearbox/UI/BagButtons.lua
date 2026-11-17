--[[
    Forever Gearbox - UI/BagButtons.lua
    What modules that mark bag items share (Full Bags, Quest Items, Upgrade Arrows in Baganator):

      * Blizzard's bag windows: BagButtons.HookBlizzard(mod, paint) calls paint(button, bag,
        slot) for every item button of a shown window as it shows and after it draws its items
        (UpdateItems: its buttons come from a pool and can show another slot afterwards), through
        the module's own hooks, so it goes quiet when the module turns off.
        BagButtons.PaintBlizzard(paint) does it now.
      * Baganator, which replaces the bag windows: BagButtons.Baganator() is its API or nil;
        BagButtons.RegisterWidget adds a corner widget (Baganator.API.RegisterCornerWidget), once
        per id, quiet while the module is off, and with our callbacks run through ns.ChargedCall
        (charged to the module), so an error of ours is reported and never breaks Baganator's loop;
        BagButtons.RegisterUpgradePlugin makes the module Baganator's judge of upgrades
        (Baganator.API.RegisterUpgradePlugin), the same way;
        BagButtons.RefreshBaganator(mod) has Baganator draw its widgets again (on the next frame);
        BagButtons.ShowBags(mod, show) opens or closes Baganator's bags (else the game's). Calls
        into Baganator go through ns.OtherAddons.Call, which logs their errors to the module.
]]

local _, ns = ...

local ipairs, type = ipairs, type

local BagButtons = {}
ns.BagButtons = BagButtons

---------------------------------------------------------------------------
-- Blizzard's bag windows
---------------------------------------------------------------------------

local frames -- the combined bags and one window per bag, made by FrameXML at load

local function blizzardFrames()
    if not frames then
        frames = { ContainerFrameCombinedBags }
        for i = 1, NUM_CONTAINER_FRAMES do frames[#frames + 1] = _G["ContainerFrame" .. i] end
    end
    return frames
end

-- paint(button, bag, slot) for each item button of one window, while it's shown.
function BagButtons.PaintFrame(container, paint)
    if not container:IsShown() then return end
    for _, button in container:EnumerateValidItems() do paint(button, button:GetBagID(), button:GetID()) end
end

-- paint(button, bag, slot) for each item button of every shown window.
function BagButtons.PaintBlizzard(paint)
    for _, container in ContainerFrameUtil_EnumerateContainerFrames() do BagButtons.PaintFrame(container, paint) end
end

-- Whether one of Blizzard's bag windows is shown.
function BagButtons.BlizzardShown()
    for _, container in ContainerFrameUtil_EnumerateContainerFrames() do
        if container:IsShown() then return true end
    end
    return false
end

-- Paints the windows as they show and after they draw their items, while `mod` is on. Safe to
-- call each OnEnable: a module's hooks are installed once.
function BagButtons.HookBlizzard(mod, paint)
    local function paintContainer(_, container) BagButtons.PaintFrame(container, paint) end
    for _, frame in ipairs(blizzardFrames()) do
        mod:HookScript(frame, "OnShow", paintContainer)
        mod:Hook(frame, "UpdateItems", paintContainer)
    end
end

---------------------------------------------------------------------------
-- Baganator (docs/forever-api.md, Other addons)
---------------------------------------------------------------------------

function BagButtons.Baganator()
    local api = _G.Baganator and Baganator.API
    if type(api) == "table" and type(api.RegisterCornerWidget) == "function" then return api end
end

local CORNERS = { "icon_top_left_corner_array", "icon_top_right_corner_array", "icon_bottom_left_corner_array",
    "icon_bottom_right_corner_array" }

-- Whether one of the widgets `ids` sits in a corner of Baganator's profile in use: Baganator
-- shows a widget only from a corner (Icons > Icon Corners), and puts a new one in only the first
-- time a profile sees it. Read from its saved settings (BAGANATOR_CONFIG.Profiles, the profile
-- named BAGANATOR_CURRENT_PROFILE; its Config.Get isn't public). Nil without Baganator or when
-- they can't be read.
function BagButtons.WidgetPlaced(ids)
    if not BagButtons.Baganator() then return nil end
    local config, current = _G.BAGANATOR_CONFIG, _G.BAGANATOR_CURRENT_PROFILE
    local profile = type(config) == "table" and type(config.Profiles) == "table" and config.Profiles[current]
    if type(profile) ~= "table" then return nil end
    for _, key in ipairs(CORNERS) do
        for _, placed in ipairs(type(profile[key]) == "table" and profile[key] or {}) do
            for _, id in ipairs(ids) do
                if placed == id then return true end
            end
        end
    end
    return false
end

-- One of our callbacks for Baganator, run as the module's code (reported and profiled); when it
-- errors, `fallback` instead (Baganator takes nil as "not loaded yet, ask again").
local function callOr(fallback, mod, source, fn, ...)
    local ok, result = ns.ChargedCall(mod, source, ns.Succeeded, fn, ...)
    if not ok then return fallback end
    return result
end

local registered = {} -- widget id -> true once Baganator took it (it can't take one back)

-- Registers with Baganator once per id: register(api) makes the call. True when it's
-- registered (now or before); false when Baganator isn't there or refused it (then a later call
-- tries again).
local function registerOnce(mod, id, register)
    if registered[id] then return true end
    local api = BagButtons.Baganator()
    if not api then return false end
    local ok = ns.OtherAddons.Call(mod, "Baganator", register, api)
    if ok then registered[id] = true end
    return ok
end

-- A corner widget (call it from OnEnable).
--   opts: label, id, onUpdate(frame, details) says whether it shows (true, false, or nil while the
--   item isn't loaded: Baganator asks again), onInit(button) makes its frame or texture, position
--   = { corner = "top_left" | "top_right" | "bottom_left" | "bottom_right", priority }.
-- While the module is off it never shows.
function BagButtons.RegisterWidget(mod, opts)
    local onUpdate, onInit = opts.onUpdate, opts.onInit
    return registerOnce(mod, opts.id, function(api)
        api.RegisterCornerWidget(opts.label, opts.id,
            function(frame, details)
                if not mod.active then return false end
                return callOr(false, mod, "Baganator widget", onUpdate, frame, details)
            end,
            function(button) return callOr(nil, mod, "Baganator widget", onInit, button) end,
            opts.position, true)
    end)
end

-- An upgrade plugin (Baganator.API.RegisterUpgradePlugin): what Baganator's "upgrade" search
-- and Upgrades category go by, once the player picks it in Baganator's settings (Baganator picks
-- the first one registered while none is). opts: label, id, isUpgrade(itemLink) (true, false,
-- or nil while the item isn't loaded: Baganator asks again). Nil while the module is off.
function BagButtons.RegisterUpgradePlugin(mod, opts)
    local isUpgrade = opts.isUpgrade
    return registerOnce(mod, "upgrade:" .. opts.id, function(api)
        api.RegisterUpgradePlugin(opts.label, opts.id, function(link)
            if not mod.active then return nil end
            return callOr(nil, mod, "Baganator upgrade plugin", isUpgrade, link)
        end)
    end)
end

-- Has Baganator draw its item buttons' widgets again, on the next frame (for module `mod`).
function BagButtons.RefreshBaganator(mod)
    local api = BagButtons.Baganator()
    if not (api and type(api.RequestItemButtonsRefresh) == "function") then return end
    ns.OtherAddons.Call(mod, "Baganator", api.RequestItemButtonsRefresh)
end

-- Opens (or closes) the bags: Baganator's own way (what its loot toast does), else the game's.
-- True when it went through; an error in Baganator's is logged to `mod` and counts as not.
function BagButtons.ShowBags(mod, show)
    local registry = BagButtons.Baganator() and Baganator.CallbackRegistry
    if registry and type(registry.TriggerEvent) == "function" then
        return (ns.OtherAddons.Call(mod, "Baganator", registry.TriggerEvent, registry, show and "BagShow" or "BagHide"))
    end
    if show then OpenAllBags() else CloseAllBags() end
    return true
end
