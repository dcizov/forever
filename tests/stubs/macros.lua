--[[
    Forever suite - tests/stubs/macros.lua
    The stand-in game's macros and what Drawer needs around them (loaded by tests/wow.lua):
      W.macros       index -> { name, icon, body }: account macros 1-120, character from 121
      EditMacro      changes one (the game refuses in combat: an error here), and remembers it in
                     W.macroEdits
      cooldowns      C_Spell.GetSpellCooldown, C_Item.GetItemCooldown (W.cooldowns[id] = { start, duration })
      mounts         C_MountJournal.GetMountInfoByID (W.mounts[id] = { name, spellID })
      W.mousePosition { x, y } (0-1) for a frame's GetMousePosition
      W.RunSecure(frame, key, ...) runs the restricted snippet in frame's attribute `key` as the
                     game would (self is the frame; protected frames may be changed in combat there)
]]

W.macros, W.macroEdits, W.cooldowns, W.mounts = {}, {}, {}, {}
W.mousePosition = { 0.5, 0.5 }

function GetNumMacros()
    local account, character = 0, 0
    for index in pairs(W.macros) do
        if index > 120 then character = character + 1 else account = account + 1 end
    end
    return account, character
end

function GetMacroInfo(index)
    local m = W.macros[index]
    if m then return m.name, m.icon, m.body end
end

function EditMacro(index, name, icon, body)
    if W.combat then
        W.errors[#W.errors + 1] = "blocked in combat: EditMacro"
        return
    end
    local m = W.macros[index]
    if not m then return end
    m.name, m.icon, m.body = name or m.name, icon or m.icon, body or m.body
    W.macroEdits[#W.macroEdits + 1] = index
    return index
end

C_Spell.GetSpellCooldown = function(id)
    local c = W.cooldowns[id]
    return { startTime = c and c[1] or 0, duration = c and c[2] or 0, isEnabled = true, modRate = 1 }
end
C_Item.GetItemCooldown = function(id)
    local c = W.cooldowns[id]
    return c and c[1] or 0, c and c[2] or 0, 1
end
C_MountJournal = C_MountJournal or {}
C_MountJournal.GetMountInfoByID = function(id)
    local m = W.mounts[id]
    if m then return m.name, m.spellID end
end

-- Blizzard's FrameXML helper: turns a texture (kept to be read back).
function SetClampedTextureRotation(texture, degrees) texture._rotation = degrees end

local Frame = W.FrameMethods
function Frame:SetFrameRef(key, frame) self._refs = self._refs or {}; self._refs[key] = frame end
function Frame:GetFrameRef(key) return self._refs and self._refs[key] end
function Frame:GetMousePosition() return W.mousePosition[1], W.mousePosition[2] end
function Frame:SetBindingClick(_, key) self._binding = key end
function Frame:ClearBindings() self._binding = nil end

function W.RunSecure(frame, key, ...)
    local snippet = frame:GetAttribute(key)
    assert(type(snippet) == "string", "no snippet " .. tostring(key))
    local fn = assert(loadstring("local self, button, down = ...\n" .. snippet))
    W.restricted = true
    local ok, err = pcall(fn, frame, ...)
    W.restricted = false
    if not ok then error(err, 2) end
end
