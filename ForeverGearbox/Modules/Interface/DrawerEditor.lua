--[[
    Forever Gearbox - Modules/Interface/DrawerEditor.lua
    Drawer's panel on Blizzard's macro window (Blizzard_MacroUI, loaded on demand): a window in
    Blizzard's own chrome (ButtonFrameTemplate, its portrait hidden) beside MacroFrame, following
    the macro selected there (MacroFrame:SelectMacro, hooked):

      * Not a drawer: Make Drawer, which writes #drawer first and turns the macro's own lines
        into the drawer's actions (#/...).
      * A drawer: its actions as action buttons (icon and tooltip; right-click takes one out), and
        an empty slot to drop a spell, an item or a mount on (from the spellbook, the bags or the
        mount journal), written as /cast <spell> or /use item:<id>.
    Edits go through EditMacro after Blizzard's own unsaved text is saved (MacroFrame:SaveMacro),
    then the selection is drawn again; Drawer.lua then adds its /click line (UPDATE_MACROS). The
    game won't change macros in combat, so the panel says so and waits.
]]

local addonName, ns = ...
local L = ns.L

local ipairs, type, math, strtrim = ipairs, type, math, strtrim
local Drawer = ns.Drawer
local M = ns.modules.Drawer

local WIDTH = 210
local SIZE, GAP, PER_ROW = 36, 6, 4
local ROOM = 225 -- of a macro's 255 characters: the rest is for Drawer's /click line

local panel
local slots = {} -- the action buttons shown

-- The selected macro: its index (account or character) and text, or nil.
local function selected()
    local index = MacroFrame:GetSelectedIndex()
    if not index then return nil end
    local actual = MacroFrame:GetMacroDataIndex(index)
    local name, _, body = GetMacroInfo(actual)
    if not name then return nil end
    return actual, body, index
end

local refresh -- below

-- Writes `body` to the selected macro, after Blizzard's own unsaved text.
local function write(change)
    if InCombatLockdown() then return M:Print(L.DRAWER_EDIT_COMBAT) end
    MacroFrame:SaveMacro()
    local actual, body, index = selected()
    if not actual then return end
    local new = change(body)
    if not new then return end
    if #Drawer.WithoutClick(new) > ROOM then return M:Print(L.DRAWER_FULL) end
    EditMacro(actual, nil, nil, new)
    MacroFrame:SelectMacro(index)
    refresh()
end

-- Make Drawer: #drawer first, the macro's own lines its actions.
local function makeDrawer()
    write(function(body)
        local lines = { Drawer.MARK }
        for line in ((body or "") .. "\n"):gmatch("([^\n]*)\n") do
            line = strtrim(line)
            if line:sub(1, 1) == "/" then lines[#lines + 1] = "#" .. line end
        end
        return table.concat(lines, "\n")
    end)
end

-- The macro line for what's on the cursor, or nil.
local function cursorLine()
    local kind, a, _, d = GetCursorInfo()
    if kind == "spell" then
        local info = C_Spell.GetSpellInfo(d or a)
        return info and info.name and "/cast " .. info.name
    elseif kind == "item" and type(a) == "number" then
        return "/use item:" .. a
    elseif kind == "mount" then
        local name = C_MountJournal.GetMountInfoByID(a)
        return name and "/cast " .. name
    end
end

-- Drops what's on the cursor into the drawer.
local function receive()
    local line = cursorLine()
    if not line then return end
    ClearCursor()
    write(function(body) return Drawer.WithoutClick(body) .. "\n#" .. line end)
end

-- Takes the n-th action out.
local function remove(n)
    write(function(body)
        local lines, seen = {}, 0
        for line in (Drawer.WithoutClick(body) .. "\n"):gmatch("([^\n]*)\n") do
            if line:match("^#/") then
                seen = seen + 1
                if seen ~= n then lines[#lines + 1] = line end
            else
                lines[#lines + 1] = line
            end
        end
        return table.concat(lines, "\n")
    end)
end

-- An action button of the panel (n-th), in ActionButtonTemplate's art.
local function newSlot(n)
    local slot = CreateFrame("Button", nil, panel.Inset)
    slot:SetSize(SIZE, SIZE)
    slot.icon = slot:CreateTexture(nil, "BACKGROUND")
    slot.icon:SetAllPoints()
    slot:SetNormalAtlas("UI-HUD-ActionBar-IconFrame")
    slot:SetHighlightAtlas("UI-HUD-ActionBar-IconFrame-Mouseover", "ADD")
    slot:RegisterForClicks("RightButtonUp", "LeftButtonUp")
    slot:SetScript("OnClick", function(self, mouse)
        if mouse == "RightButton" and self.n then remove(self.n) end
    end)
    slot:SetScript("OnReceiveDrag", receive)
    slot:SetScript("OnEnter", function(self)
        local action = self.action
        if not action then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if action.spellID then
            GameTooltip:SetSpellByID(action.spellID)
        elseif action.itemID then
            GameTooltip:SetItemByID(action.itemID)
        else
            GameTooltip:SetText(action.text, 1, 1, 1)
        end
        GameTooltip:AddLine(L.DRAWER_REMOVE_HINT, 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
    slots[n] = slot
    return slot
end

local function place(frame, i)
    local column, row = (i - 1) % PER_ROW, math.floor((i - 1) / PER_ROW)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", panel.Inset, "TOPLEFT", 14 + column * (SIZE + GAP), -86 - row * (SIZE + GAP))
end

function refresh()
    if not panel then return end
    panel:SetShown(M.active and MacroFrame:IsShown())
    if not panel:IsShown() then return end
    local actual, body = selected()
    local drawer = actual and Drawer.IsDrawer(body)
    panel.make:SetShown(actual ~= nil and not drawer)
    panel.drop:SetShown(drawer and true or false)
    panel.text:SetText(not actual and L.DRAWER_EDIT_NONE or drawer and L.DRAWER_EDIT_HELP or L.DRAWER_EDIT_MAKE)
    local actions = drawer and Drawer.Actions(body, false) or {}
    for i, action in ipairs(actions) do
        local slot = slots[i] or newSlot(i)
        slot.n, slot.action = i, action
        slot.icon:SetTexture(action.icon or 134400)
        place(slot, i)
        slot:Show()
    end
    for i = #actions + 1, #slots do slots[i]:Hide() end
    if drawer then place(panel.drop, #actions + 1) end
end

local function build()
    panel = CreateFrame("Frame", addonName .. "DrawerEditor", MacroFrame, "ButtonFrameTemplate")
    ButtonFrameTemplate_HidePortrait(panel)
    panel:SetSize(WIDTH, MacroFrame:GetHeight())
    panel:SetPoint("TOPLEFT", MacroFrame, "TOPRIGHT", 2, 0)
    panel:SetTitle(L.DRAWER_TITLE)
    panel.CloseButton:Hide()
    panel.text = panel.Inset:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.text:SetPoint("TOPLEFT", 10, -10)
    panel.text:SetPoint("TOPRIGHT", -10, -10)
    panel.text:SetJustifyH("LEFT")
    panel.make = ns.Kit.NewButton(panel.Inset, L.DRAWER_MAKE, 140, makeDrawer)
    panel.make:SetPoint("TOP", panel.text, "BOTTOM", 0, -12)
    -- The empty slot things are dropped on: Blizzard's empty action slot.
    local drop = CreateFrame("Button", nil, panel.Inset)
    drop:SetSize(SIZE, SIZE)
    local art = drop:CreateTexture(nil, "BACKGROUND")
    art:SetAtlas("ui-hud-actionbar-iconframe-slot")
    art:SetAllPoints()
    drop:SetHighlightAtlas("UI-HUD-ActionBar-IconFrame-Mouseover", "ADD")
    drop:SetScript("OnReceiveDrag", receive)
    drop:SetScript("OnClick", receive)
    drop:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.DRAWER_DROP, 1, 1, 1)
        GameTooltip:AddLine(L.DRAWER_DROP_TIP, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    drop:SetScript("OnLeave", function() GameTooltip:Hide() end)
    panel.drop = drop
end

-- Blizzard's macro window, once it's loaded: our panel on it.
local function attach()
    if panel or not MacroFrame then return refresh() end
    build()
    M:Hook(MacroFrame, "SelectMacro", refresh)
    M:Hook(MacroFrame, "Update", refresh)
    M:HookScript(MacroFrame, "OnShow", refresh)
    refresh()
end

M:AddPart({
    Enable = function()
        if C_AddOns.IsAddOnLoaded("Blizzard_MacroUI") then
            attach()
        else
            M:RegisterEvent("ADDON_LOADED", function(_, _, name)
                if name == "Blizzard_MacroUI" then attach() end
            end)
        end
    end,
    Disable = function() if panel then panel:Hide() end end,
})
