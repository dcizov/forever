--[[
    Forever Tweaks - Modules/Gathering/GatherWindow.lua
    Gathering Session's window: the session in full (time, nodes, fish, items, what they're
    worth and make an hour, skill-ups), your Fishing (skill and bonus, what the zone's water
    needs, the lure's time left), and every item gathered with how many, with Pause and Start
    Over. Opens from the session line's right-click menu, /ft session window or its key binding;
    moves and stays where you leave it; Escape closes it. Kept up to date while it shows (the
    session's own updates, and each second for the clock and the lure).
    A part of the Gathering Session module: it closes when the module turns off.
]]

local _, ns = ...
local L = ns.L
local Kit = ns.Kit

local format, ipairs, concat = string.format, ipairs, table.concat
local M = assert(ns.modules.GatherSession, "GatherWindow.lua loads after GatherSession.lua")
local Shared = assert(ns.GatherSessionShared, "GatherWindow.lua loads after GatherSession.lua")
local State = assert(ns.FishingState, "GatherWindow.lua loads after FishingState.lua")
local money = ns.MoneyText

local WIDTH, HEIGHT = 420, 480
local MAX_ITEMS = 40

local window, stack, rows, pauseButton, ticker
local Window = {}
M.window = Window

local function setRow(row, text)
    row.text:SetText(text)
    row:SetHeight(row.text:GetStringHeight() + 2)
end

local function sessionText()
    if not Shared.Started() then return L.GATHERSESSION_NONE end
    local s = Shared.Session()
    local lines = {
        format(L.GATHERWINDOW_TIME, Shared.ClockText(Shared.Elapsed())) .. (Shared.Paused() and L.GATHERSESSION_PAUSED or ""),
        format(L.GATHERWINDOW_COUNTS, s.nodes, s.fish, s.items),
        format(L.GATHERWINDOW_WORTH, money(s.value)),
    }
    local rate = Shared.PerHour()
    if rate then lines[#lines + 1] = format(L.GATHERWINDOW_RATE, money(rate)) end
    if s.skillups > 0 then lines[#lines + 1] = format(L.GATHERWINDOW_SKILLUPS, s.skillups) end
    return concat(lines, "\n")
end

local function fishingText()
    local rank, _, bonus, name = State.Skill()
    if not rank then return L.GATHERWINDOW_NO_FISHING end
    local lines = { format(L.FISHING_SKILL_BONUS, name, rank, bonus, rank + bonus) }
    local low, high = State.ZoneSkill()
    if low then
        lines[#lines + 1] = format(L.FISHING_ZONE_NEEDS, low == high and low or (low .. "/" .. high))
    end
    local left = State.LureLeft()
    if left and left ~= State.LURE_TIME_UNKNOWN then
        lines[#lines + 1] = format(L.FISHING_LURE, format("%d:%02d", left / 60, left % 60))
    elseif left then
        lines[#lines + 1] = format(L.FISHING_LURE, "?")
    else
        lines[#lines + 1] = L.GATHERWINDOW_NO_LURE
    end
    return concat(lines, "\n")
end

local function itemsText()
    local s = Shared.Session()
    local lines = {}
    for i, link in ipairs(Shared.ItemsByCount()) do
        if i > MAX_ITEMS then break end
        local itemID = C_Item.GetItemInfoInstant(link)
        local icon = itemID and C_Item.GetItemIconByID(itemID)
        lines[#lines + 1] = (icon and format("|T%s:16|t ", icon) or "") .. link .. "  x" .. s.byItem[link]
    end
    return #lines > 0 and concat(lines, "\n") or L.GATHERWINDOW_NO_ITEMS
end

function Window.Refresh()
    if not (window and window:IsShown()) then return end
    setRow(rows.session, sessionText())
    setRow(rows.fishing, fishingText())
    setRow(rows.items, itemsText())
    pauseButton:SetText(Shared.Paused() and L.GATHERSESSION_RESUME or L.GATHERSESSION_PAUSE)
    pauseButton:SetEnabled(Shared.Started())
    Kit.Layout(stack)
end

local function buildWindow()
    window, stack = Kit.NewStackWindow("ForeverTweaksGatherWindow", L.GATHERWINDOW_TITLE, WIDTH, HEIGHT)
    rows = {}
    Kit.AddHeaderRow(stack, L.GATHERWINDOW_SESSION)
    rows.session = Kit.AddTextRow(stack, "")
    Kit.AddHeaderRow(stack, L.GATHERWINDOW_FISHING)
    rows.fishing = Kit.AddTextRow(stack, "")
    Kit.AddHeaderRow(stack, L.GATHERWINDOW_ITEMS)
    rows.items = Kit.AddTextRow(stack, "")
    pauseButton = Kit.NewButton(window, L.GATHERSESSION_PAUSE, 100, function()
        Shared.TogglePause()
        Window.Refresh()
    end)
    pauseButton:SetPoint("BOTTOMLEFT", 8, 6)
    Kit.NewButton(window, L.GATHERSESSION_RESET, 110, function()
        Shared.StartAgain()
        Window.Refresh()
    end):SetPoint("LEFT", pauseButton, "RIGHT", 4, 0)
    window:HookScript("OnShow", function()
        if not M:IsPending(ticker) then ticker = M:NewTicker(1, Window.Refresh) end
        Window.Refresh()
    end)
    window:HookScript("OnHide", function() M:CancelTimer(ticker) end)
end

function Window.Toggle()
    if not M.active then return end
    if not window then buildWindow() end
    window:SetShown(not window:IsShown())
end

function Window.Shown() return window ~= nil and window:IsShown() end

ns:AddBinding(M, "FOREVERTWEAKS_GATHER_WINDOW", Window.Toggle)

M:AddPart({ Disable = function() if window then window:Hide() end end })
