--[[
    Forever suite - tests/scenarios/core/store.lua
    The runtime's saved variables (Shared/Core/Store.lua), in Forever Codex: a failing
    migration step, and saved settings that don't fit their option. (Forever Gearbox' settings are
    Forever++'s: the plugin scenario.)
    Run by tests/run.lua (lua5.1 tests/run.lua store), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

-- A step that fails stops the ones after it and is tried again next time; settings that
-- don't fit their option are dropped as they load.
ForeverCodexDB = {
    version = 1, quiet = true,
    settings = {
        TestStore = { latency = "nonsense", size = "big", fps = false, future = 1, x = 99999, y = 30 },
    },
    data = {},
}
W.Strict()
local ns = W.LoadAddon(root, "ForeverCodex")
ns:NewModule("TestStore", {
    category = "journal",
    defaults = { latency = "world", size = 12, fps = true, x = 0, y = 0 },
    options = {
        { key = "latency", type = "dropdown", label = "Latency", choices = { { "world", "World" }, { "home", "Home" } } },
        { key = "size", type = "slider", label = "Size", min = 8, max = 30, step = 1 },
        { key = "fps", type = "checkbox", label = "FPS" },
        { key = "x", type = "slider", label = "X", min = -500, max = 500, step = 1 },
        { key = "y", type = "slider", label = "Y", min = -500, max = 500, step = 1 },
    },
})
ns:Migrate(1.5, function() error("step 1.5 broke") end)
login()
local db = ForeverCodexDB
eq(db.version, 1, "layout stays at the last step that worked")
eq(db.quiet, true, "later steps didn't run")
check(W.errors[1] and W.errors[1]:find("step 1.5 broke", 1, true) ~= nil, "the failure was reported")
W.errors = {}
local mod = ns.modules.TestStore
eq(mod.db.latency, "world", "a dropdown value that isn't a choice is dropped")
eq(mod.db.size, 12, "a setting of the wrong type is dropped")
eq(mod.db.fps, false, "a setting that fits is kept")
eq(mod.settings.x, nil, "a slider value outside its range is dropped")
eq(mod.db.y, 30, "one inside it is kept")
eq(mod.settings.future, 1, "a key this version doesn't know is left alone")
finish()
