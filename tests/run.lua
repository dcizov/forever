--[[
    Forever suite - tests/run.lua
    lua5.1 tests/run.lua            runs every scenario, each in a fresh Lua
    lua5.1 tests/run.lua <name>     runs one

    Each scenario loads addons from their TOCs into the stand-in game (tests/wow.lua: W.LoadAddon
    loads an addon's dependencies first: Forever Gearbox brings the Forever++ stand-in), fires the events the
    game would, and checks what happens. Exits non-zero on any failure.
]]

local root = (arg[0]:match("^(.*)/tests/[^/]*$")) or "."
-- Scenarios by folder in tests/scenarios/, in the order they run: core/ checks the runtime,
-- the two addons (alone and together), saved variables, settings pages and API; tweaks/
-- Forever Gearbox' features, one each, with its on-screen and unit ones in interface/ and its
-- quest ones in quests/; bags/ its bag features (Full Bags, Quest Items, Vendor)
-- and how they share Baganator; compendium/ Forever Codex's.
local GROUPS = {
    { "core", { "suite", "bindings", "alone", "migrate", "upgrade", "removed", "fresh", "settings", "commands", "isolation", "store", "editmode", "ui", "api", "codexapi", "codexintegration",
        "changelog", "hints", "updates", "standalone", "lint" } },
    { "tweaks", { "fpppage", "bag", "djskin", "djcolors", "fishing", "chat", "chatsplit" } },
    { "interface", { "layer", "combathelpers", "performance", "cooldowns", "nameplatedistance", "visuals", "drawer" } },
    { "quests", { "questmarkers" } },
    { "bags", { "fullbags", "questitems", "questiedb", "vendor", "baganator", "bagupgrades" } },
    { "compendium", { "openmap", "recorder", "learning", "import", "journal", "quests", "archive", "social", "pins", "tooltips", "banner" } },
}
local SCENARIOS, folderOf = {}, {}
for _, group in ipairs(GROUPS) do
    for _, name in ipairs(group[2]) do
        SCENARIOS[#SCENARIOS + 1] = name
        folderOf[name] = group[1]
    end
end

-- Every scenario file is listed above, and every listed one exists: a new file left out of
-- GROUPS would otherwise never run.
local function checkListed()
    local problems = {}
    for _, group in ipairs(GROUPS) do
        local folder, listed = group[1], {}
        for _, name in ipairs(group[2]) do listed[name] = true end
        local ls = assert(io.popen('ls "' .. root .. "/tests/scenarios/" .. folder .. '"'))
        for file in ls:lines() do
            local name = file:match("^(.+)%.lua$")
            if name and not listed[name] then
                problems[#problems + 1] = folder .. "/" .. file .. " isn't in tests/run.lua's GROUPS"
            end
            listed[name or file] = nil
        end
        ls:close()
        for name in pairs(listed) do problems[#problems + 1] = folder .. "/" .. name .. ".lua is listed but missing" end
    end
    return problems
end

if not arg[1] then
    local problems = checkListed()
    for _, problem in ipairs(problems) do print(problem) end
    if #problems > 0 then os.exit(1) end
    local lua = arg[-1] or "lua5.1"
    local failed = 0
    for _, name in ipairs(SCENARIOS) do
        local ok = os.execute(lua .. " " .. arg[0] .. " " .. name)
        if ok ~= 0 and ok ~= true then failed = failed + 1 end
    end
    print(failed == 0 and "All scenarios passed." or (failed .. " scenario(s) failed."))
    os.exit(failed == 0 and 0 or 1)
end

local function say(text) io.write(text, "\n") end
local scenario = arg[1]
dofile(root .. "/tests/wow.lua")

local passed, failures = 0, {}
local function check(cond, what)
    if cond then passed = passed + 1 else failures[#failures + 1] = what end
end
local function eq(a, b, what)
    check(a == b, string.format("%s: expected %s, got %s", what, tostring(b), tostring(a)))
end

local function login()
    for _, name in ipairs(W.addons) do W.Fire("ADDON_LOADED", name) end
    W.Fire("PLAYER_LOGIN")
    W.Fire("PLAYER_ENTERING_WORLD", true, false)
    W.RunTimers()
end

local function finish()
    for _, e in ipairs(W.errors) do failures[#failures + 1] = "error: " .. e end
    for key in pairs(W.missing) do failures[#failures + 1] = "used something the game doesn't have: " .. key end
    if #failures > 0 then
        say(string.format("[%s] FAILED (%d passed)", scenario, passed))
        for _, f in ipairs(failures) do say("   " .. f) end
        os.exit(1)
    end
    say(string.format("[%s] ok, %d checks", scenario, passed))
end

-- Every frame under f (at any depth) for which test(frame) is true, in tree order: how scenarios
-- find widgets, by their text or template rather than their position.
local function under(f, test, found)
    found = found or {}
    for _, child in ipairs({ f:GetChildren() }) do
        if test(child) then found[#found + 1] = child end
        under(child, test, found)
    end
    return found
end

-- Checks every page and module pane of Forever Codex's settings window opens without an
-- error: its slash, every module's page, and its own pages.
local function openEverything(ns)
    W.Slash(ns.member.slash[1] .. " settings")
    for _, name in ipairs(ns.order) do ns:OpenSettings(name) end
    for _, page in ipairs({ ns.title, ns.L.DEBUG, ns.L.CHANGELOG, ns.L.ABOUT }) do C_SettingsUtil.OpenSettingsPanel(page) end
    check(W.opened ~= nil, "settings opened")
end

---------------------------------------------------------------------------
-- Each scenario is its own file in tests/scenarios/<folder>/, given these helpers.
---------------------------------------------------------------------------

local folder = folderOf[scenario]
local chunk = folder and loadfile(root .. "/tests/scenarios/" .. folder .. "/" .. scenario .. ".lua")
if not chunk then error("no scenario " .. scenario) end
chunk({ root = root, check = check, eq = eq, login = login, finish = finish, openEverything = openEverything,
    under = under })
