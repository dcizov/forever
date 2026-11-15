--[[
    Forever Core - Core/Module.lua
    Modules: ns:NewModule, and what every module can do (events, hooks, timers and
    parts), all of it stopped when the module turns off. Builds on the event frame and ns.ChargedHandler in
    Core/Core.lua; loaded right after it, before anything that defines a module.
]]

local _, ns = ...

local pairs, ipairs, type, tostring = pairs, ipairs, type, tostring
local setmetatable, strlower = setmetatable, string.lower
local C_Timer, hooksecurefunc = C_Timer, hooksecurefunc

local L = ns.L
local call, run = ns.SafeCall, ns.ChargedHandler

local Module = {}
Module.__index = Module
ns.Module = Module

-- handler: function(self, event, ...). Only while the module is on; it stops by itself when the
-- module turns off. False if the client doesn't have the event. One handler per event:
-- registering another replaces it; registering the same one again, or unregistering an event
-- it doesn't hear, costs nothing, so a module can call these on every change without a flag.
function Module:RegisterEvent(event, handler)
    assert(type(handler) == "function", "RegisterEvent: handler must be a function")
    if self.events[event] == handler then return true end
    if not ns:On(event, self, handler) then return false end
    self.events[event] = handler
    return true
end

function Module:UnregisterEvent(event)
    if not self.events[event] then return end
    self.events[event] = nil
    ns:Off(event, self)
end

function Module:UnregisterAllEvents()
    for event in pairs(self.events) do ns:Off(event, self) end
    self.events = {}
end

-- Timers that belong to the module: cancelled when it turns off.
function Module:After(seconds, fn)
    local timer
    timer = C_Timer.NewTimer(seconds, function()
        self.timers[timer] = nil
        if self.active then run(self, "timer", fn) end
    end)
    self.timers[timer] = true
    return timer
end

function Module:NewTicker(seconds, fn)
    local ticker = C_Timer.NewTicker(seconds, function() run(self, "ticker", fn) end)
    self.timers[ticker] = true
    return ticker
end

-- fn(self) on the next frame, once however often this is called before then: for redrawing
-- once after a burst of events.
function Module:Soon(fn)
    local soon = self.soon
    if soon[fn] then return end
    soon[fn] = self:After(0, function(mod)
        soon[fn] = nil
        return fn(mod)
    end)
end

-- Whether `timer` (from After or NewTicker) is still running: false once it has fired, been
-- cancelled, or the module turned off.
function Module:IsPending(timer)
    return timer ~= nil and self.timers[timer] ~= nil
end

function Module:CancelTimer(timer)
    if not self:IsPending(timer) then return end
    timer:Cancel()
    self.timers[timer] = nil
end

local function cancelTimers(mod)
    for timer in pairs(mod.timers) do timer:Cancel() end
    mod.timers, mod.soon = {}, {}
end

-- A part is shared behaviour a module is built with (an on-screen display, UI/Widgets.lua): an
-- object with any of part:Enable(), part:Disable() and part:Changed(key). They run before the
-- module's own OnEnable, OnDisable and OnSettingChanged (which stay free for the module), each
-- isolated, and timed and charged to the module by the Profiler.
function Module:AddPart(part)
    self.parts[#self.parts + 1] = part
end

local function runParts(mod, method, ...)
    for _, part in ipairs(mod.parts) do
        if part[method] then ns.ChargedCall(mod, method, part[method], part, ...) end
    end
end

-- Hooks: installed once however often this is called, and doing nothing while the module is
-- off. module:Hook("GlobalFunction", fn) or module:Hook(object, "Method", fn).
local function hookOnce(mod, target, method, fn, install)
    local hooked = mod.hooked[target]
    if not hooked then
        hooked = {}
        mod.hooked[target] = hooked
    end
    if hooked[method] then return true end
    local source = type(method) == "string" and method or "hook"
    local installed = install(function(...)
        if mod.active then return run(mod, source, fn, ...) end
    end)
    -- Marked only once installed: an install that fails (errors, or answers false) is tried
    -- again next time.
    if installed == false then return false end
    hooked[method] = true
    return true
end

-- Both return false (and say so in the log) when there's nothing to hook, like RegisterEvent.
function Module:Hook(target, method, fn)
    if type(target) == "string" then target, method, fn = _G, target, method end
    if type(target) ~= "table" or type(target[method]) ~= "function" then
        self:Debug("nothing to hook:", tostring(method))
        return false
    end
    return hookOnce(self, target, method, fn, function(hook) hooksecurefunc(target, method, hook) end)
end

-- For a hook the game gives no Hook/HookScript for (a tooltip post call, a callback registry):
-- install(hook) adds `hook` wherever it goes, once per target and key; fn(self, ...) runs through
-- it only while the module is on. install answers false when it couldn't (an install calling
-- into another addon pcalls it and logs the error), and then it's tried again the next time.
function Module:HookCallback(target, key, install, fn)
    return hookOnce(self, target, key, fn, install)
end

function Module:HookScript(frame, script, fn)
    if not (frame and frame.HookScript) then
        self:Debug("no frame to hook:", tostring(script))
        return false
    end
    return hookOnce(self, frame, script, fn, function(hook) frame:HookScript(script, hook) end)
end

-- The suite's news (ns:Announce) and setting changes (ns:NotifyChanged), heard only while the
-- module is on, like its events: fn(self, event, ...) and fn(self, name, key). Something that must
-- hear them while the module is off (a cache to throw away) uses ns:OnNews / ns:OnChanged.
function Module:OnNews(fn)
    ns:OnNews(self, function(owner, ...)
        if owner.active then return fn(owner, ...) end
    end)
end

function Module:OnChanged(fn)
    ns:OnChanged(self, function(owner, ...)
        if owner.active then return fn(owner, ...) end
    end)
end

-- Says something in chat by itself: only while its Chat Messages option (ns.ChatOption) is on and
-- Mute All Chat Messages (ns.db.quiet, the Settings page) is off.
function Module:Print(...)
    if self.db.chat == false or (ns.db and ns.db.quiet) then return end
    ns.Print(self, ...) -- under its member's name
end

-- Answers the player (a command's reply, a button's result): always shown, chat muted or not,
-- since they asked. What a module says unprompted goes through Print.
function Module:Reply(...)
    ns.Print(self, ...) -- under its member's name
end

function Module:Debug(...) ns:Debug(self.name .. ":", ...) end

-- Turns the module on or off. A module whose OnEnable errors (the error is reported) is turned
-- off again at once, so it isn't left half on: its events, timers and hooks stop, OnDisable runs.
-- Its saved on/off stays as it was, so the next login tries again.
function Module:SetActive(state)
    state = state and true or false
    if state == self.active then return end
    self.active = state
    self:Debug(state and "on" or "off")
    if state then
        runParts(self, "Enable")
        if self.OnEnable and not ns.ChargedCall(self, "OnEnable", ns.Succeeded, self.OnEnable, self) then
            self:Debug("OnEnable failed: turned off again")
            return self:SetActive(false)
        end
    else
        self:UnregisterAllEvents()
        cancelTimers(self)
        runParts(self, "Disable")
        if self.OnDisable then run(self, "OnDisable", self.OnDisable) end
    end
end

-- Puts a changed setting into effect: its parts and OnSettingChanged. Only while the module is
-- on (turning it on applies everything anyway).
function Module:ApplySetting(key)
    if not self.active then return end
    runParts(self, "Changed", key)
    if self.OnSettingChanged then run(self, "OnSettingChanged", self.OnSettingChanged, key, self.db[key]) end
end

-- The Chat Messages option for a module that speaks unprompted (key "chat", default on).
function ns.ChatOption(tooltip)
    return { key = "chat", type = "checkbox", label = L.CHAT_MESSAGES, section = L.SECTION_CHAT,
        tooltip = tooltip or L.CHAT_MESSAGES_TIP }
end

--[[
    ns:NewModule(name, info)
      title, category (one of its member's categories (Core/Members.lua), "other", or
                    "settings" for one drawn on the Settings page; each module file sits in the
                    folder of its category), description
      defaults      settings with their defaults ("enabled" is true if left out). A table default
                    is data the module keeps: never reset by Defaults.
      perCharacter  { key = true }: data saved for each character on its own
      options       controls on its settings pane (README.md, "Option fields"; drawn by
                    Settings/Section.lua)
      notice        a gray row above its options, or a list of them (a list once defined; drawn
                    by Settings/Section.lua)
      features      option keys of checkboxes that are each a feature of their own, for a module
                    that bundles several: it gets no on/off switch of its own and is on while any
                    of them is ticked (Core/Options.lua keeps "enabled" in step)
      added         the version it first shipped in (newer ones get a NEW label)
      addon         for a Forever Tweaks "addons" module: the folder of the addon it changes;
                    the Tweaks for Addons page shows its section only while that addon is loaded
    The module belongs to the member whose namespace made it (mod.member, Core/Members.lua): its
    settings are saved in that member's saved variables.
    Methods: OnInitialize, OnEnable, OnDisable, OnSettingChanged(key, value), and DebugLine(): one
    line for the debug report (/forever debug, the Debug page) saying what it's doing, asked only while
    it's on. BuildPage(stack, width) adds more to the module's settings pane, under its options
    (Vendor's Autobuy list), and may return a function redrawing that.
]]
function ns:NewModule(name, info)
    assert(type(name) == "string", "NewModule: name must be a string")
    assert(not self.modules[name], "NewModule: duplicate module '" .. name .. "'")
    local mod = setmetatable(info or {}, Module)
    mod.name     = name
    mod.title    = mod.title or name
    mod.defaults = mod.defaults or {}
    mod.options  = mod.options or {}
    -- One notice or a list of them: a list from here on.
    if mod.notice and not mod.notice[1] then mod.notice = { mod.notice } end
    if mod.features then
        -- On while any feature is ticked; featureSet answers "is this key a feature" (Core/Options.lua).
        local any = false
        mod.featureSet = {}
        for _, key in ipairs(mod.features) do
            any = any or mod.defaults[key] == true
            mod.featureSet[key] = true
        end
        mod.defaults.enabled = any
    elseif mod.defaults.enabled == nil then
        mod.defaults.enabled = true
    end
    mod.active, mod.events, mod.timers, mod.hooked = false, {}, {}, {}
    mod.parts, mod.soon = {}, {}
    mod.member = self.member
    ns.Options.Check(mod) -- Core/Options.lua, loaded before any module
    self.modules[name] = mod
    self.order[#self.order + 1] = name
    mod.member.order[#mod.member.order + 1] = name
    return mod
end

function ns:GetModule(query)
    if not query or query == "" then return end
    if self.modules[query] then return self.modules[query] end
    local wanted = strlower(query):gsub("%s", "")
    for _, name in ipairs(self.order) do
        local mod = self.modules[name]
        if strlower(name):find(wanted, 1, true) == 1 or strlower(mod.title):gsub("%s", ""):find(wanted, 1, true) == 1 then
            return mod
        end
    end
end

---------------------------------------------------------------------------
-- Startup (Core/Init.lua calls Start once everything has loaded)
---------------------------------------------------------------------------

local function start(mod)
    if mod.db.enabled then mod:SetActive(true) end
end

-- Each module starts on its own: one that fails to turn on doesn't stop the rest.
function ns:Start()
    for _, name in ipairs(self.order) do call(start, self.modules[name]) end
end
