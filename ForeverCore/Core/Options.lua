--[[
    Forever Core - Core/Options.lua
    Changing modules and their options: turning a module on or off, setting, saving and
    resetting an option, what option values mean (shared by the Settings page and /forever set), and
    telling listeners (the Settings page, the public API) what changed. The Settings page and
    the slash commands change things only through here.
]]

local _, ns = ...

local ipairs, tostring, tonumber, type, assert, math = ipairs, tostring, tonumber, type, assert, math
local format, strlower = string.format, string.lower
local L = ns.L

-- fn(owner, name, key) when a module turns on or off (key "enabled") or one of its settings
-- changes. Only settings go through here: a module's other news has its own channel. Listeners
-- run like event handlers (ns.ChargedHandler): isolated, and charged to owner by the Profiler.
local changeListeners = {} -- { owner, fn }
function ns:OnChanged(owner, fn)
    changeListeners[#changeListeners + 1] = { owner, fn }
end
function ns:NotifyChanged(name, key)
    for i = 1, #changeListeners do
        local listener = changeListeners[i]
        ns.ChargedHandler(listener[1], "OnChanged", listener[2], name, key)
    end
end

local anyFeature, store -- below

-- Module `name`, or an error naming the caller: a typo in a module name fails where it's made.
local function moduleNamed(name, caller)
    return (assert(ns.modules[name], caller .. ": no module " .. tostring(name)))
end

-- A features module (ns:NewModule, features) is switched through its features: turned off, all of
-- them are unticked; turned on with none ticked, those on by default are ticked again.
local function switchFeatures(mod, on)
    local changed = {}
    for _, key in ipairs(mod.features) do
        -- Off: untick every feature. On: tick those on by default, and leave the rest as they are.
        local want = on and mod.defaults[key] == true
        if (want or not on) and store(mod, key, want) then changed[#changed + 1] = key end
    end
    return changed
end

function ns:SetEnabled(name, on)
    local mod = moduleNamed(name, "SetEnabled")
    on = on and true or false
    local changed = {}
    if mod.features and (not on or not anyFeature(mod)) then changed = switchFeatures(mod, on) end
    if mod.db.enabled == on then
        for _, key in ipairs(changed) do mod:ApplySetting(key) self:NotifyChanged(name, key) end
        return
    end
    mod.db.enabled = on
    mod:SetActive(on) -- turning on applies every setting, so the changed features need only telling
    for _, key in ipairs(changed) do self:NotifyChanged(name, key) end
    self:NotifyChanged(name, "enabled")
end

-- Whether any of a features module's features is ticked.
function anyFeature(mod)
    for _, key in ipairs(mod.features) do
        if mod.db[key] then return true end
    end
    return false
end

local function optionChanged(mod, key)
    mod:ApplySetting(key)
    ns:NotifyChanged(mod.name, key)
    -- A features module runs while one of its features is ticked.
    if mod.features and mod.featureSet[key] then ns:SetEnabled(mod.name, anyFeature(mod)) end
end

-- Saves a setting; false if it already had that value.
function store(mod, key, value)
    if mod.db[key] == value then return false end
    mod.db[key] = value
    mod:Debug(key, "=", tostring(value))
    return true
end

function ns:SetOption(name, key, value)
    local mod = moduleNamed(name, "SetOption")
    if store(mod, key, value) then optionChanged(mod, key) end
end

-- Saves a setting that's already in effect (a frame dragged into place)
-- and tells the listeners, without applying it again the way ns:SetOption does.
function ns:StoreOption(name, key, value)
    if store(moduleNamed(name, "StoreOption"), key, value) then self:NotifyChanged(name, key) end
end

-- What option values mean, shared by the Settings page and /forever set so both accept the same values.
local Options = {}
ns.Options = Options

-- How many decimals a slider value keeps: option.precision, else as many as its step has.
function Options.Precision(option)
    if option.precision then return option.precision end
    local decimals = tostring(option.step or 1):match("%.(%d+)$")
    return decimals and #decimals or 0
end

-- A number typed for a slider, kept to its precision and in its range (it may fall between
-- steps). Returns the value and whether it had to be changed to fit.
function Options.FitSlider(option, number)
    local scale = 10 ^ Options.Precision(option)
    local value = math.floor(number * scale + 0.5) / scale
    local fitted = math.min(math.max(value, option.min), option.max)
    return fitted, fitted ~= number
end

-- A dropdown value's label, or the value itself as text when it isn't one of the choices.
function Options.ChoiceLabel(option, value)
    for _, choice in ipairs(option.choices) do
        if choice[1] == value then return choice[2] end
    end
    return tostring(value)
end

-- Whether `value` is one of the option's values: a dropdown's choice, a slider's number in range.
-- (Its type is checked separately.) Store drops a saved value that isn't.
function Options.Fits(option, value)
    if option.type == "dropdown" then
        for _, choice in ipairs(option.choices) do
            if choice[1] == value then return true end
        end
        return false
    end
    if option.type == "slider" then return value >= option.min and value <= option.max end
    return true
end

-- A typed number for a slider: the first number in the text ("1,5" and "1.5 s" are 1.5), kept in
-- range and to its precision. Returns the value and whether it had to be changed to fit, or nil
-- for no number. The Settings box and /forever set both read numbers this way.
function Options.ParseNumber(option, text)
    local number = tonumber((tostring(text or ""):gsub(",", ".")):match("%-?%d+%.?%d*") or "")
    if not number then return nil end
    return Options.FitSlider(option, number)
end

-- A slider value as its label shows it: option.format (a format string or a function).
function Options.SliderText(option, value)
    if type(option.format) == "function" then return option.format(value) end
    return format(option.format or "%s", value)
end

-- A value as text, as /forever shows it: On or Off, the slider's label, or the choice's label.
-- `onOff` ({ on text, off text }, optional) words a checkbox's instead (the Settings page says
-- Checked or Unchecked, as Blizzard's own undo arrows do).
function Options.ValueText(option, value, onOff)
    if option.type == "checkbox" then
        if onOff then return value and onOff[1] or onOff[2] end
        return ns:StateText(value)
    end
    if option.type == "slider" then return Options.SliderText(option, value) end
    return Options.ChoiceLabel(option, value)
end

local ON = { on = true, ["1"] = true, ["true"] = true, yes = true }
local OFF = { off = true, ["0"] = true, ["false"] = true, no = true }

-- A typed value for an option (/forever set), or nil and why not. A checkbox takes on/off (nothing
-- flips it), a slider a number as the Settings box does, a dropdown a choice's key or label.
function Options.Parse(option, text, current)
    text = strlower(text or "")
    if option.type == "checkbox" then
        if text == "" then return not current end
        if ON[text] then return true end
        if OFF[text] then return false end
        return nil, L.CMD_WANT_ONOFF
    elseif option.type == "slider" then
        local value = Options.ParseNumber(option, text)
        if value == nil then return nil, format(L.CMD_WANT_NUMBER, option.min, option.max) end
        return value
    end
    local wanted = text:gsub("%s", "")
    local names = {}
    for _, choice in ipairs(option.choices) do
        if strlower(choice[1]) == text or strlower(choice[2]):gsub("%s", "") == wanted then return choice[1] end
        names[#names + 1] = choice[2]
    end
    return nil, format(L.CMD_WANT_CHOICE, table.concat(names, ", "))
end

-- What each option type's default must be, and what else it needs. A mistake is an error when the
-- module's file loads, so the tests catch it rather than a player.
local OPTION_SHAPES = {
    checkbox = { default = "boolean" },
    slider = { default = "number", check = function(o) return type(o.min) == "number" and type(o.max) == "number" end,
        need = "numeric min and max" },
    -- Choice values are strings: what /forever set matches typed text against (Options.Parse).
    dropdown = { default = "string", need = "choices with string values", check = function(o)
        if type(o.choices) ~= "table" or o.choices[1] == nil then return false end
        for _, choice in ipairs(o.choices) do
            if type(choice[1]) ~= "string" then return false end
        end
        return true
    end },
}

-- What an option's `requires`, `slider` and `conflicts` name must be: an option of the module,
-- of the right type, with no loop of requires.
local function checkReferences(mod, byKey)
    for _, option in ipairs(mod.options) do
        local where = mod.name .. "." .. tostring(option.key)
        local seen, up = { [option] = true }, option.requires
        while up ~= nil do
            local needed = byKey[up]
            assert(needed and needed.type == "checkbox", "NewModule: " .. where .. " requires " .. tostring(up)
                .. ", which isn't a checkbox option")
            assert(not seen[needed], "NewModule: " .. where .. "'s requires go round in a loop")
            seen[needed] = true
            up = needed.requires
        end
        if option.slider ~= nil then
            local pair = byKey[option.slider]
            assert(option.type == "checkbox" and pair and pair.type == "slider", "NewModule: " .. where
                .. "'s slider must name a slider option, on a checkbox")
        end
        for _, conflict in ipairs(option.conflicts or {}) do
            assert(byKey[conflict.key] and type(conflict.when) == "function", "NewModule: " .. where
                .. " has a conflict that needs an option key and a when(db) function")
        end
    end
end

-- Checks a module's options against OPTION_SHAPES and each other, and its category (ns:NewModule
-- calls this).
function Options.Check(mod)
    assert(mod.category == nil or mod.member.ranks[mod.category], "NewModule: " .. mod.name
        .. " has an unknown category " .. tostring(mod.category))
    local byKey = {}
    for _, option in ipairs(mod.options) do byKey[option.key] = option end
    checkReferences(mod, byKey)
    for _, option in ipairs(mod.options) do
        local where = mod.name .. "." .. tostring(option.key)
        local shape = OPTION_SHAPES[option.type]
        assert(shape, "NewModule: " .. where .. " has an unknown type " .. tostring(option.type))
        assert(not shape.check or shape.check(option), "NewModule: " .. where .. " needs " .. tostring(shape.need))
        local default = mod.defaults[option.key]
        local want = shape.default
        assert(type(default) == want, "NewModule: " .. where .. " needs a " .. want .. " default")
        assert(Options.Fits(option, default), "NewModule: " .. where .. "'s default isn't one of its values")
        assert(not option.group or (option.type == "checkbox" and type(option.group) == "table"),
            "NewModule: " .. where .. " is in a group, which takes checkboxes ({ label, format })")
    end
    for _, key in ipairs(mod.features or {}) do
        assert(byKey[key] and byKey[key].type == "checkbox", "NewModule: feature " .. mod.name .. "." .. tostring(key) .. " needs a checkbox")
    end
end

-- Forgets the player's choice, so the default (now or in a later version) applies.
function ns:ResetOption(name, key)
    local mod = moduleNamed(name, "ResetOption")
    local before = mod.db[key]
    self.Store.Forget(mod, key)
    if mod.db[key] ~= before then optionChanged(mod, key) end
end

-- Every module (or only those named in `names`) and its options back to their defaults (the
-- Defaults buttons, Reset Everything, /forever reset).
function ns:ResetAll(names)
    for _, name in ipairs(names or self.order) do
        local mod = self.modules[name]
        for _, option in ipairs(mod.options) do self:ResetOption(name, option.key) end
        local before = mod.db.enabled
        self.Store.Forget(mod, "enabled")
        if mod.db.enabled ~= before then
            mod:SetActive(mod.db.enabled)
            self:NotifyChanged(name, "enabled")
        end
    end
end

-- How many modules are on, and how many there are: every member's, or only `member`'s.
function ns:CountModules(member)
    local order = member and member.order or self.order
    local on = 0
    for _, name in ipairs(order) do
        if self.modules[name].db.enabled then on = on + 1 end
    end
    return on, #order
end
