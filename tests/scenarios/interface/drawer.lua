--[[
    Forever Gearbox - tests/scenarios/interface/drawer.lua
    Drawer (Modules/Interface/Drawer.lua, DrawerFlyout.lua, DrawerEditor.lua): a #drawer macro gets
    its /click line and its first action's icon, other macros are left alone, its handler holds
    its actions (closing after a click), the secure snippet opens and closes the flyout (in combat
    too, with nothing blocked), a macro changed in combat is read once it ends, Hide Unusable leaves
    out what you don't have, nothing is written twice, the panel on Blizzard's macro window makes
    a drawer and takes a drop, and turned off, the /click lines come out.
    Run by tests/run.lua (lua5.1 tests/run.lua drawer), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
W.spells[18960] = "Teleport: Moonglade"
W.knownSpells[18960] = true
W.owned[6948] = 1
W.macros[1] = { name = "Travel", icon = 134400, body = "#drawer\n#/cast Teleport: Moonglade\n#/use item:6948" }
W.macros[2] = { name = "Plain", icon = 1, body = "/say hello" }
W.macros[121] = { name = "Mine", icon = 7, body = "#drawer\n#/use item:6948" }
local ns = W.LoadAddon(root, "ForeverGearbox")
login()
W.RunTimers()
check(ns.modules.Drawer.active, "on by default")

-- The macros: a /click line each, the first action's icon for a question mark; others alone.
eq(W.macros[1].body, "#drawer\n#/cast Teleport: Moonglade\n#/use item:6948\n/click ForeverGearboxDrawer1", "a drawer opens its handler")
eq(W.macros[1].icon, 100000 + 18960, "a question mark becomes its first action's icon")
eq(W.macros[121].body, "#drawer\n#/use item:6948\n/click ForeverGearboxDrawer2", "a character macro too, the next handler")
eq(W.macros[121].icon, 7, "an icon of your own stays")
eq(W.macros[2].body, "/say hello", "a macro that isn't a drawer is left alone")
local edits = #W.macroEdits
W.Fire("UPDATE_MACROS")
W.RunTimers()
eq(#W.macroEdits, edits, "read again: nothing written twice")

-- Its handler: the actions, each closing the drawer after it.
local handler = ForeverGearboxDrawer1
eq(handler:GetAttribute("count"), 2, "two actions")
eq(handler:GetAttribute("action1"), "/cast Teleport: Moonglade\n/click ForeverGearboxDrawerRoot", "closing after it")
eq(handler:GetAttribute("action2"), "/use item:6948\n/click ForeverGearboxDrawerRoot", "an item by its ID")

-- Opening it, as /click does: the look from Lua first (PreClick), then the snippet; in combat too.
W.combat = true
handler:Fire("PreClick")
W.RunSecure(handler, "_onclick", "LeftButton", false)
local flyoutRoot = ForeverGearboxDrawerRoot
check(flyoutRoot:IsShown(), "the drawer opens")
local first, third = ForeverGearboxDrawerButton1, ForeverGearboxDrawerButton3
eq(first:GetAttribute("type"), "macro", "its first button runs a macro")
eq(first:GetAttribute("macrotext"), handler:GetAttribute("action1"), "its first action")
check(first:IsShown() and ForeverGearboxDrawerButton2:IsShown() and not third:IsShown(), "two buttons, the rest hidden")
eq(first.icon:GetTexture(), 100000 + 18960, "the spell's icon on it")
eq(#W.blocked, 0, "nothing blocked in combat")
W.RunSecure(handler, "_onclick", "LeftButton", false)
check(not flyoutRoot:IsShown(), "clicked again: closed")

-- A macro changed in combat is read once combat ends.
W.macros[1].body = "#drawer\n#/cast Teleport: Moonglade\n/click ForeverGearboxDrawer1"
W.Fire("UPDATE_MACROS")
W.RunTimers()
eq(handler:GetAttribute("count"), 2, "in combat: not yet")
W.combat = false
W.Fire("PLAYER_REGEN_ENABLED")
W.RunTimers()
eq(handler:GetAttribute("count"), 1, "after combat: read again")

-- Hide Unusable: an item you don't have is left out.
W.macros[1].body = "#drawer\n#/cast Teleport: Moonglade\n#/use item:6948"
W.owned[6948] = 0
ns:SetOption("Drawer", "hideUnusable", true)
W.RunTimers()
eq(handler:GetAttribute("count"), 1, "Hide Unusable: the missing item left out")
eq(ForeverGearboxDrawer2:GetAttribute("count"), 0, "a drawer of only that: empty")
ns:SetOption("Drawer", "hideUnusable", false)
W.RunTimers()
eq(handler:GetAttribute("count"), 2, "shown again")

-- Opening toward the left: the background turned as Blizzard turns it.
ns:SetOption("Drawer", "direction", "LEFT")
eq(handler:GetAttribute("direction"), "LEFT", "the handler opens left")

-- Blizzard's macro window: the Drawer panel beside it.
local selectedIndex = 2
MacroFrame = W.NewFrame("Frame", "MacroFrame", UIParent)
function MacroFrame:GetSelectedIndex() return selectedIndex end
function MacroFrame:GetMacroDataIndex(index) return index end
function MacroFrame:SaveMacro() end
function MacroFrame:SelectMacro(index) selectedIndex = index end
function MacroFrame:Update() end
MacroFrame:Show()
W.loaded.Blizzard_MacroUI = true
W.Fire("ADDON_LOADED", "Blizzard_MacroUI")
MacroFrame:SelectMacro(2)
local panel = ForeverGearboxDrawerEditor
check(panel and panel:IsShown(), "a Drawer panel beside the macro window")
check(panel.make:IsShown(), "a macro that isn't a drawer: Make Drawer")
panel.make:Click()
eq(W.macros[2].body, "#drawer\n#/say hello", "made a drawer: its lines its actions")
W.held = { "spell", 1, "spell", 18960 }
panel.drop:Fire("OnReceiveDrag")
eq(W.macros[2].body, "#drawer\n#/say hello\n#/cast Teleport: Moonglade", "a spell dropped on it is added")
eq(W.held, nil, "and taken off the cursor")
W.combat = true
W.held = { "item", 6948 }
panel.drop:Fire("OnReceiveDrag")
eq(W.macros[2].body, "#drawer\n#/say hello\n#/cast Teleport: Moonglade", "in combat: not changed")
W.combat = false

-- Off: the /click lines come out of every drawer.
ns:SetEnabled("Drawer", false)
W.RunTimers()
eq(W.macros[1].body, "#drawer\n#/cast Teleport: Moonglade\n#/use item:6948", "off: the macro as you wrote it")
check(not panel:IsShown() or not ns.modules.Drawer.active, "the panel goes")
MacroFrame = nil
eq(#W.errors, 0, "no errors")
finish()
