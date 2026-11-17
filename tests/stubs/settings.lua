--[[
    Forever suite - tests/stubs/settings.lua
    The stand-in game's Settings, menus and popups (loaded by tests/wow.lua):
      Settings.RegisterCanvasLayoutCategory / Subcategory (W.categories[name]; a subcategory is
      listed in its parent's GetSubcategories, as the sidebar shows it), SettingsPanel,
      C_SettingsUtil.OpenSettingsPanel (W.opened), the stepper slider's mixin, MenuUtil's context
      menus (W.menu, nodes with Find), and StaticPopup_Show (W.popups; W.Accept presses the newest's
      first button).
]]
W.categories = {}
local function category(frame, name)
    local c = { frame = frame, name = name, subs = {} }
    function c:GetID() return name end
    function c:GetName() return name end
    function c:GetSubcategories() return self.subs end
    W.categories[name] = c
    return c
end
Settings = {
    RegisterCanvasLayoutCategory = function(frame, name) return category(frame, name) end,
    -- A page under another: listed in its subcategories, as the sidebar shows them.
    RegisterCanvasLayoutSubcategory = function(parent, frame, name)
        local c = category(frame, name)
        if type(parent) == "table" and parent.subs then parent.subs[#parent.subs + 1] = c end
        return c
    end,
    RegisterAddOnCategory = function() end,
    CreateSliderOptions = function() return { SetLabelFormatter = function() end } end,
}
SettingsPanel = W.NewFrame("Frame", "SettingsPanel")
SettingsPanel._shown = false
function HideUIPanel(frame) frame:Hide() end
C_SettingsUtil = {
    OpenSettingsPanel = function(id)
        W.opened = id
        SettingsPanel:Show()
        local c = W.categories[id]
        if c then c.frame:Show() end
    end,
}
MinimalSliderWithSteppersMixin = { Label = { Right = 1, Left = 2, Top = 3 }, Event = { OnValueChanged = 1 } }
function CreateMinimalSliderFormatter(_, fn) return fn end
NineSliceUtil = {
    ApplyLayout = function() end,
    ApplyLayoutByName = function(container, name) container._layout = name end,
}

W.menu = nil
local function menuNode(label)
    local node = { label = label, items = {} }
    function node:CreateTitle(text) self.items[#self.items + 1] = { title = text } end
    function node:CreateDivider() end
    function node:CreateButton(text, fn) local c = menuNode(text); c.fn = fn; self.items[#self.items + 1] = c; return c end
    function node:CreateCheckbox(text, get, set) local c = menuNode(text); c.get, c.set = get, set; self.items[#self.items + 1] = c; return c end
    function node:CreateRadio(text, get, set, data) local c = menuNode(text); c.get, c.set, c.data = get, set, data; self.items[#self.items + 1] = c; return c end
    function node:SetScrollMode() end
    function node:SetTitleAndTextTooltip(title, text) self.tooltip = { title, text } end
    function node:Find(text) for _, i in ipairs(self.items) do if i.label == text then return i end end end
    return node
end
MenuUtil = { CreateContextMenu = function(owner, gen) local root = menuNode("root"); gen(owner, root); W.menu = root end }

StaticPopupDialogs = {}
W.popups = {}
function StaticPopup_Show(which, textArg, _, data)
    local dialog = StaticPopupDialogs[which]
    local popup = W.NewFrame("Frame")
    popup.EditBox = W.NewFrame("EditBox", nil, popup)
    popup.which, popup.data, popup.text = which, data, dialog.text:format(textArg or "")
    if dialog.OnShow then dialog.OnShow(popup, data) end
    W.popups[#W.popups + 1] = popup
    return popup
end
-- Presses the first button of the newest popup.
function W.Accept()
    local popup = table.remove(W.popups)
    local dialog = StaticPopupDialogs[popup.which]
    if dialog.OnAccept then dialog.OnAccept(popup, popup.data) end
end
