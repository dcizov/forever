--[[
    Forever Tweaks - tests/scenarios/tweaks/bag.lua
    The Button Bag taking buttons and giving them back.
    Run by tests/run.lua (lua5.1 tests/run.lua bag), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root
local ns

-- A LibDBIcon button on the minimap, with its own drag script and place.
local button = CreateFrame("Button", "LibDBIcon10_Test", Minimap)
button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 5, -5)
local drag = function() end
button:SetScript("OnDragStart", drag)
local lib = { objects = { Test = button }, callbacks = {} }
-- LibDBIcon's callbacks (CallbackHandler): a function is called with the event's name.
-- The first registration fails, as a broken copy of the library would.
local failNext = true
function lib.RegisterCallback(owner, event, fn)
    if failNext then
        failNext = false
        error("CallbackHandler broke")
    end
    lib.callbacks[event] = fn
end
function LibStub(name) if name == "LibDBIcon-1.0" then return lib end end
W.Strict()
ns = W.LoadAddon(root, "ForeverTweaks")
login()
local bag = ns.modules.ButtonBag
local frame = ForeverTweaksButtonBag
-- A failed LibDBIcon registration is logged, not reported, and tried again next time it turns on.
eq(lib.callbacks.LibDBIcon_IconCreated, nil, "the first registration failed")
eq(#W.errors, 0, "without an error report")
ns:SetEnabled("ButtonBag", false)
ns:SetEnabled("ButtonBag", true)
W.RunTimers()
eq(button:GetParent(), frame, "taken into the bag")
eq(button:GetScript("OnDragStart"), nil, "can't be dragged out while bagged")
button:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
check(button._point[1] ~= "CENTER", "the addon can't move it back while bagged")
eq(bag:Count(), 1, "counted")
check(bag:DebugLine():find("1", 1, true) ~= nil, "Debug line")
check(ns:DebugInfo():find(bag:DebugLine(), 1, true) ~= nil, "on the Debug report")
check(ns.modules.MinimapButton:IsOnMinimap(), "our own button is on the minimap")
W.Slash("/ft bag")
check(frame:IsShown(), "/ft bag opens it")
W.Slash("/ft bag")

-- A layout asked for just before the module turns off doesn't block later ones.
check(not frame.empty:IsShown(), "laid out with one button")
button:Hide()
ns:SetEnabled("ButtonBag", false)
eq(button:GetParent(), Minimap, "put back when the module turns off")
eq(button:GetScript("OnDragStart"), drag, "its drag script back")
eq(button._point and button._point[1], "TOPLEFT", "and its place")
eq(rawget(button, "SetPoint"), nil, "its own methods back")
ns:SetEnabled("ButtonBag", true)
W.RunTimers()
eq(button:GetParent(), frame, "taken again")
check(frame.empty:IsShown(), "empty while its only button is hidden")
button:Show()
W.RunTimers()
check(not frame.empty:IsShown(), "laid out again when the button shows")

-- Left out from the bag button's menu, then put back in.
ForeverTweaksBagButton:Fire("OnClick", "RightButton")
local item = W.menu:Find("Test")
check(item ~= nil, "listed in the menu")
item.set()
eq(bag.db.ignored.Test, true, "left out")
eq(button:GetParent(), Minimap, "back on the minimap")
item.set()
eq(button:GetParent(), frame, "back in the bag")

-- A button LibDBIcon makes later is taken in once it says so (LibDBIcon_IconCreated).
check(lib.callbacks.LibDBIcon_IconCreated ~= nil, "listening for new LibDBIcon buttons")
local late = CreateFrame("Button", "LibDBIcon10_Late", Minimap)
late:SetScript("OnDragStart", function() end)
lib.objects.Late = late
lib.callbacks.LibDBIcon_IconCreated("LibDBIcon_IconCreated", late, "Late")
W.RunTimers()
eq(late:GetParent(), frame, "a late button is taken in")
finish()
