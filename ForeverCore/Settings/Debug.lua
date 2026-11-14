--[[
    Forever Core - Settings/Debug.lua
    The Debug page: the log, debug info (ns:DebugInfo, Core/DebugReport.lua), the Profiler (CPU per
    module).
    Show Log in Chat is on the Settings page (Settings/General.lua).
]]

local _, ns = ...
local Kit, L = ns.Kit, ns.L

local ipairs, format = ipairs, string.format

function ns.BuildDebugPage(frame)
    local stack = Kit.NewRowPage(frame, L.DEBUG)
    local refreshers = {}

    Kit.AddHeaderRow(stack, L.SECTION_DIAGNOSTICS)
    Kit.AddButtonRow(stack, L.DEBUG_COPY, L.COPY, function()
        Kit.ShowCopyWindow(format(L.DEBUG_COPY_TITLE, ns.title), ns:DebugInfo())
    end, L.DEBUG_COPY_TIP)
    Kit.AddButtonRow(stack, L.DEBUG_RELOAD, L.RELOAD, ReloadUI, L.DEBUG_RELOAD_TIP)

    Kit.AddHeaderRow(stack, L.SECTION_PROFILER)
    local status = Kit.AddTextRow(stack, "", "GameFontHighlight", 4)
    local recordButton
    local function update()
        local recording = ns.Profiler.recording
        status.text:SetText(recording and L.PROFILER_RECORDING or L.PROFILER_IDLE)
        recordButton:SetText(recording and L.STOP or L.START)
    end
    local _
    _, recordButton = Kit.AddButtonRow(stack, L.PROFILER_RECORD, L.START, function()
        if ns.Profiler.recording then ns.Profiler.Stop() else ns.Profiler.Start() end
        update()
    end, L.PROFILER_RECORD_TIP)
    Kit.AddButtonRow(stack, L.PROFILER_REPORT, L.COPY, function()
        Kit.ShowCopyWindow(L.PROFILER_REPORT, ns.Profiler.Report())
    end, L.PROFILER_REPORT_TIP)
    refreshers[#refreshers + 1] = update
    update()

    Kit.Layout(stack)
    frame:HookScript("OnShow", function()
        for _, fn in ipairs(refreshers) do fn() end
    end)
end
