--[[
    Forever Core - UI/Popups.lua
    Blizzard's own popups for a yes/no question, a line of text to type, and one to copy. `owner`
    is the module asking (or any table with a name, such as Kit.owner): what the player answers
    runs as its code (ns.ChargedCall). `key` is the caller's name for the popup, kept apart per kind (one key can be both a question and a copy);
    each gets its popup made once; preferredIndex 3 keeps them clear of the game's own popups.

    Adapted from Forever++ by xIGBClutchIx (MIT License).
]]

local _, ns = ...

local StaticPopupDialogs, StaticPopup_Show = StaticPopupDialogs, StaticPopup_Show

local function showPopup(key, text, build, data, textArg)
    local which = "FOREVERTWEAKS_" .. key
    if not StaticPopupDialogs[which] then
        local dialog = build()
        dialog.timeout = 0
        dialog.whileDead = true
        dialog.hideOnEscape = true
        dialog.preferredIndex = 3
        StaticPopupDialogs[which] = dialog
    end
    StaticPopupDialogs[which].text = text
    return StaticPopup_Show(which, textArg, nil, data)
end

-- Asks `text` (with a %s filled by textArg) and runs onAccept on Yes.
function ns:Confirm(owner, key, text, onAccept, textArg)
    showPopup(key .. "_CONFIRM", text, function()
        return {
            button1 = YES,
            button2 = NO,
            OnAccept = function(_, data) ns.ChargedCall(data.owner, "popup", data.onAccept) end,
        }
    end, { owner = owner, onAccept = onAccept }, textArg)
end

-- A line of text to type: onAccept(text) on Accept or Enter, starting from `initial`.
function ns:Prompt(owner, key, text, onAccept, initial)
    showPopup(key .. "_PROMPT", text, function()
        return {
            button1 = ACCEPT,
            button2 = CANCEL,
            hasEditBox = true,
            editBoxWidth = 280,
            OnShow = function(self, data)
                local box = self:GetEditBox()
                box:SetText(data.initial or "")
                box:SetFocus()
                box:HighlightText()
            end,
            OnAccept = function(self, data)
                ns.ChargedCall(data.owner, "popup", data.onAccept, strtrim(self:GetEditBox():GetText() or ""))
            end,
            EditBoxOnEnterPressed = function(box, data)
                ns.ChargedCall(data.owner, "popup", data.onAccept, strtrim(box:GetText() or ""))
                box:GetParent():Hide()
            end,
            EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
        }
    end, { owner = owner, initial = initial, onAccept = onAccept })
end

-- A line of text to copy: `text`, selected, under `label`, with a Close button. Typing into it
-- changes nothing.
function ns:ShowCopyText(key, label, text)
    showPopup(key .. "_COPY", label, function()
        return {
            button1 = CLOSE,
            hasEditBox = true,
            editBoxWidth = 280,
            OnShow = function(self, data)
                local box = self:GetEditBox()
                box:SetText(data)
                box:SetFocus()
                box:HighlightText()
            end,
            EditBoxOnEnterPressed = function(box) box:GetParent():Hide() end,
            EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
            EditBoxOnTextChanged = function(box, data)
                if box:GetText() ~= data then
                    box:SetText(data)
                    box:HighlightText()
                end
            end,
        }
    end, text)
end
