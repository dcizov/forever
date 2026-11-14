--[[
    Forever Tweaks - tests/scenarios/core/store.lua
    A failing migration step, and saved settings that don't fit their option.
    Run by tests/run.lua (lua5.1 tests/run.lua store), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root
local ns

-- A step that fails stops the ones after it and is tried again next time; settings that
-- don't fit their option are dropped as they load.
ForeverTweaksDB = {
    version = 4,
    settings = {
        StatusText = { enabled = true },
        Performance = { latency = "nonsense", size = "big", fps = false, future = 1, x = 99999, y = 30 },
    },
    data = {},
}
-- A 1.8.0 character wearing Profession Outfits' Mining outfit (skill line 186): not Fishing's.
ForeverTweaksCharDB = { data = { ProfessionOutfits = { state = { wearing = 186 } } } }
W.Strict()
ns = W.LoadAddon(root, "ForeverTweaks")
ns:Migrate(4.5, function() error("step 4.5 broke") end)
login()
local db = ForeverTweaksDB
eq(db.version, 4, "layout stays at the last step that worked")
check(db.settings.StatusText ~= nil, "later steps didn't run")
check(W.errors[1] and W.errors[1]:find("step 4.5 broke", 1, true) ~= nil, "the failure was reported")
W.errors = {}
eq(ns.modules.Fishing.db.state.wearing, nil, "another profession's outfit isn't taken for Fishing's")
local perf = ns.modules.Performance
eq(perf.db.latency, "world", "a dropdown value that isn't a choice is dropped")
eq(perf.db.size, 12, "a setting of the wrong type is dropped")
eq(perf.db.fps, false, "a setting that fits is kept")
eq(perf.settings.x, nil, "a slider value outside its range is dropped")
eq(perf.db.y, 30, "one inside it is kept")
eq(perf.settings.future, 1, "a key this version doesn't know is left alone")
finish()
