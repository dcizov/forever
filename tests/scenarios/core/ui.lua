--[[
    Forever Tweaks - tests/scenarios/core/ui.lua
    Slash commands another addon has, popups, and the minimap button.
    Run by tests/run.lua (lua5.1 tests/run.lua ui), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root
local ns

-- Another addon already answers to /ft.
_G.SLASH_OTHERADDON1 = "/ft"
SlashCmdList.OTHERADDON = function() end
ForeverTweaksDB = { version = 6, settings = {}, data = {} }
W.Strict()
ns = W.LoadAddon(root, "ForeverTweaks")
login()
local L = ns.L
eq(_G.SLASH_FOREVERTWEAKS1, "/forevertweaks", "a taken slash is left to the other addon")
check(W.ChatHas(L.SLASH_TAKEN:format("/ft")), "and the player is told")
W.Slash("/forevertweaks list")
check(W.ChatHas("ButtonBag"), "the other slash works")
ns.Slash.Remove("FOREVERTWEAKS")
eq(SlashCmdList.FOREVERTWEAKS, nil, "a command can be taken away")
eq(_G.SLASH_FOREVERTWEAKS1, nil, "with its slashes")

-- Popups: a line to type, and a line to copy.
local typed
local owner = { name = "Test" }
ns:Prompt(owner, "TEST", "Name?", function(text) typed = text end, "  start  ")
local popup = W.popups[#W.popups]
eq(popup.EditBox:GetText(), "  start  ", "starts from the text given")
W.Accept()
eq(typed, "start", "Accept hands over the text, trimmed")
ns:Prompt(owner, "TEST", "Name?", function(text) typed = text end)
popup = W.popups[#W.popups]
popup.EditBox:SetText("typed")
StaticPopupDialogs.FOREVERTWEAKS_TEST_PROMPT.EditBoxOnEnterPressed(popup.EditBox, popup.data)
eq(typed, "typed", "Enter hands it over too")
ns:ShowCopyText("TEST", "Copy:", "the value")
popup = W.popups[#W.popups]
eq(popup.EditBox:GetText(), "the value", "the text to copy")
popup.EditBox:SetText("changed")
StaticPopupDialogs.FOREVERTWEAKS_TEST_COPY.EditBoxOnTextChanged(popup.EditBox, popup.data)
eq(popup.EditBox:GetText(), "the value", "typing into it changes nothing")
W.Fire("PLAYER_TARGET_CHANGED")
ForeverTweaksLayer:Fire("OnMouseUp", "RightButton")
W.menu:Find(L.LAYER_COPY).fn()
eq(W.popups[#W.popups].EditBox:GetText(), "3041", "Layer Info's menu copies the zone UID")

-- The minimap button, the addon menu (compartment), or both.
local button = ForeverTweaksMinimapButton
local function inCompartment()
    for _, entry in ipairs(AddonCompartmentFrame.registeredAddons) do
        if entry.text == ns.title then return true end
    end
    return false
end
check(button:IsShown() and not inCompartment(), "on the minimap only, by default")
button:Fire("OnEnter")
button:Fire("OnClick", "LeftButton")
eq(ForeverCore.SettingsWindow.Current(), ns.title, "a click opens Settings")
ns:SetOption("MinimapButton", "where", "compartment")
check(not button:IsShown() and inCompartment(), "in the addon menu instead")
ns:SetOption("MinimapButton", "where", "both")
check(button:IsShown() and inCompartment(), "both")
ns:SetEnabled("MinimapButton", false)
check(not button:IsShown() and not inCompartment(), "neither while off")
check(not ns.modules.MinimapButton:IsOnMinimap(), "and not on the minimap")
finish()
