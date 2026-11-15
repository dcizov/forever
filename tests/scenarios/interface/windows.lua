--[[
    Forever Tweaks - tests/scenarios/interface/windows.lua
    Movable Windows: Shift+drag moves a Blizzard window, Blizzard placing it again is undone,
    Ctrl+right-click puts it back; nothing while Forever++'s own is on. Keep Windows Open: the
    windows leave the panel manager's list (and Escape still closes them), only out of combat.
    Run by tests/run.lua (lua5.1 tests/run.lua windows), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
CharacterFrame = W.NewFrame("Frame", "CharacterFrame", UIParent)
CharacterFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
UIPanelWindows.CharacterFrame = { area = "left", pushable = 3 }
local ns = W.LoadAddon(root, "ForeverTweaks")
login()

-- Movable Windows.
ns:SetEnabled("MovableWindows", true)
local frame = CharacterFrame
local movedTo = { "CENTER", UIParent, "CENTER", 200, 50 }
frame.StartMoving = function(self) self._moving = true end
frame.StopMovingOrSizing = function(self)
    self._moving = false
    self:ClearAllPoints()
    self:SetPoint(unpack(movedTo))
end
frame:Fire("OnMouseDown", "LeftButton")
check(not frame._moving, "no Shift: no drag")
W.shift = true
frame:Fire("OnMouseDown", "LeftButton")
W.shift = false
check(frame._moving, "Shift+drag moves it")
frame:Fire("OnMouseUp", "LeftButton")
eq(ns.modules.MovableWindows.db.positions.CharacterFrame[4], 50, "where it was left is kept")
frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116) -- the panel manager places it again
local point, _, _, x = frame:GetPoint(1)
check(point == "CENTER" and x == 200, "Blizzard placing it again is undone")
W.ctrl = true
frame:Fire("OnMouseDown", "RightButton")
W.ctrl = false
point = frame:GetPoint(1)
eq(point, "TOPLEFT", "Ctrl+right-click: back to Blizzard's place")
eq(ns.modules.MovableWindows.db.positions.CharacterFrame, nil, "and forgotten")

-- Keep Windows Open.
W.combat = true
ns:SetEnabled("KeepWindowsOpen", true)
check(UIPanelWindows.CharacterFrame ~= nil, "not in combat")
W.combat = false
W.Fire("PLAYER_REGEN_ENABLED")
W.RunTimers()
eq(UIPanelWindows.CharacterFrame, nil, "after combat: out of the panel manager's list")
local escapes = false
for _, name in ipairs(UISpecialFrames) do if name == "CharacterFrame" then escapes = true end end
check(escapes, "Escape still closes it")
eq(#W.errors, 0, "no errors")
finish()
