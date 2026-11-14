--[[
    Forever Tweaks - tests/scenarios/core/editmode.lua
    Edit Mode moves, nudges and snapping.
    Run by tests/run.lua (lua5.1 tests/run.lua editmode), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root
local ns

W.Strict()
ns = W.LoadAddon(root, "ForeverTweaks")
login()
local perf, display = ns.modules.Performance, ForeverTweaksPerformance
local function selections()
    local list = {}
    for _, f in ipairs(W.frames) do
        if f:GetParent() == display and rawget(f, "info") then list[#list + 1] = f end
    end
    return list
end
local selection = selections()[1]
check(selection ~= nil, "selection box made")
local changed = {}
ForeverTweaksAPI.v1.RegisterCallback("OPTION_CHANGED", function(_, name, key) changed[name .. "." .. key] = true end)
-- Stand-in sizes: the display 100x20 and the quest tracker 100x20, both centered at (50, 10).
-- The display hangs by its BOTTOMRIGHT from the tracker's TOP (50, 20).
selection.info.moveTo(500.4, 300)
eq(perf.db.x, 500, "x: from the display's corner to the anchor, rounded")
eq(perf.db.y, 270, "y")
check(changed["Performance.x"] and changed["Performance.y"], "both coordinates reported")

EditModeManagerFrame:EnterEditMode()
check(selection:IsShown(), "selection shows in Edit Mode")
selection:Fire("OnMouseDown", "LeftButton")
local dialog = ForeverCoreEditModeDialog
check(dialog and dialog:IsShown(), "picking it opens the dialog")
dialog:Fire("OnKeyDown", "RIGHT")
eq(perf.db.x, 51, "arrow key nudges a pixel")
eq(perf.db.y, -20, "from where it is")
dialog:Fire("OnKeyDown", "LSHIFT")
dialog:Fire("OnKeyDown", "UP")
dialog:Fire("OnKeyUp", "LSHIFT")
eq(perf.db.y, -10, "Shift nudges ten")

-- Dragging snaps to the screen's edges and our other frames (Layer Info's spans 0 to 100).
W.cursor = { 0, 0 }
selection:Fire("OnDragStart")
W.cursor = { 7, 0 }
selection:Fire("OnUpdate", 0.01)
eq(perf.db.x, 50, "within ten pixels of a line: snapped")
W.cursor = { 30, 0 }
selection:Fire("OnUpdate", 0.01)
eq(perf.db.x, 80, "further away: where the mouse put it")
selection:Fire("OnDragStop")
eq(selection:GetScript("OnUpdate"), nil, "drag over")
dialog:Fire("OnKeyDown", "ESCAPE")
check(not dialog:IsShown(), "Escape lets go")
EditModeManagerFrame:ExitEditMode()
check(not selection:IsShown(), "selection hides with Edit Mode")

-- Turning the module off and on keeps the one selection box.
ns:SetEnabled("Performance", false)
ns:SetEnabled("Performance", true)
eq(#selections(), 1, "selection box reused")
finish()
