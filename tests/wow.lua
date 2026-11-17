--[[
    Forever suite - tests/wow.lua
    A small stand-in for the game, enough to load the addon in plain Lua 5.1 and drive it with
    events. Frames answer methods named like the game's (Get*/Is* return plain defaults,
    everything else records what it was given); under W.Strict() a name not in W.METHODS is
    reported, as an unknown global is. It checks wiring and logic, not looks; the game is still
    the real test.
]]

local W = {}
_G.W = W

-- Files of the stand-in game next to this one, in tests/stubs/.
local HERE = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"
local function stub(name) dofile(HERE .. "stubs/" .. name .. ".lua") end

-- Frames, CreateFrame and W.NewFrame (tests/stubs/frames.lua).
stub("frames")

-- Fires an event at every frame registered for it.
function W.Fire(event, ...)
    local list = {}
    for f in pairs(W.events[event] or {}) do list[#list + 1] = f end
    for _, f in ipairs(list) do f:Fire("OnEvent", event, ...) end
end

---------------------------------------------------------------------------
-- Events, timers, errors
---------------------------------------------------------------------------

W.EVENTS = {}
for _, e in ipairs({ "UPDATE_MACROS", "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "CVAR_UPDATE", "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_UPDATE_RESTING",
    "ADDON_ACTION_BLOCKED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT",
    "NAME_PLATE_UNIT_ADDED", "ZONE_CHANGED_NEW_AREA", "GROUP_ROSTER_UPDATE", "ZONE_CHANGED", "LOOT_OPENED",
    "LOOT_SLOT_CLEARED", "LOOT_CLOSED", "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED", "QUEST_LOG_UPDATE",
    "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "MERCHANT_SHOW", "MERCHANT_CLOSED", "PLAYER_MONEY", "CHAT_MSG_SKILL",
    "PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED", "SKILL_LINES_CHANGED", "UNIT_SPELLCAST_CHANNEL_START",
    "EQUIPMENT_SETS_CHANGED", "CHAT_MSG_ADDON", "GROUP_JOINED", "UPDATE_INVENTORY_DURABILITY", "MINIMAP_UPDATE_TRACKING",
    "PLAYER_ALIVE", "PLAYER_UNGHOST", "ADDON_ACTION_FORBIDDEN", "NAME_PLATE_UNIT_REMOVED", "UNIT_QUEST_LOG_CHANGED",
    "QUEST_WATCH_UPDATE", "PLAYER_SOFT_INTERACT_CHANGED", "GLOBAL_MOUSE_DOWN", "GLOBAL_MOUSE_UP", "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_CHANNEL_STOP", "SPELLS_CHANGED", "SPELL_RANGE_CHECK_UPDATE", "UNIT_HEALTH", "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_DISPLAYPOWER", "UNIT_SPELLCAST_SENT", "PARTY_KILL", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE",
    "QUEST_GREETING", "GOSSIP_SHOW", "UNIT_COMBAT", "PLAYER_DEAD", "CHAT_MSG_COMBAT_FACTION_CHANGE", "QUEST_DATA_LOAD_RESULT", "UPDATE_CHAT_WINDOWS", "UPDATE_FLOATING_CHAT_WINDOWS", "PLAYER_LOGOUT",
    "GUILD_ROSTER_UPDATE", "FRIENDLIST_UPDATE", "WHO_LIST_UPDATE", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED",
    "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
    "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "LOOT_READY", "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING", "MODIFIER_STATE_CHANGED", "ZONE_CHANGED_INDOORS", "GOSSIP_CLOSED", "QUEST_FINISHED", "TRAINER_SHOW",
    "TRAINER_CLOSED", "TAXIMAP_OPENED", "TAXIMAP_CLOSED", "PLAYER_LEVEL_UP", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "QUEST_WATCH_LIST_CHANGED", "PLAYER_STOPPED_MOVING" }) do
    W.EVENTS[e] = true
end
function W.validEvent(e) return W.EVENTS[e] or false end
C_EventUtils = { IsEventValid = function(e) return W.validEvent(e) end }

-- The stand-in clock: GetTime() and timers read W.now, which only W.Advance moves.
W.now = 1000
W.timers = {}
local function newTimer(seconds, fn, repeating)
    local t = { seconds = seconds, fn = fn, repeating = repeating, due = W.now + seconds }
    function t:Cancel() self.cancelled = true end
    function t:IsCancelled() return self.cancelled end
    W.timers[#W.timers + 1] = t
    return t
end
C_Timer = {
    After = function(s, fn) newTimer(s, fn) end,
    NewTimer = function(s, fn) return newTimer(s, fn) end,
    NewTicker = function(s, fn) return newTimer(s, fn, true) end,
}
-- Moves the clock on by `seconds`, running each timer as it falls due, in order (a ticker again
-- every interval; a timer made by one runs too if it's due within the time).
function W.Advance(seconds)
    local target = W.now + seconds
    while true do
        local next
        for _, t in ipairs(W.timers) do
            if not t.cancelled and t.due <= target and (not next or t.due < next.due) then next = t end
        end
        if not next then break end
        W.now = math.max(W.now, next.due)
        if next.repeating then next.due = next.due + math.max(next.seconds, 0.001) else next.cancelled = true end
        next.fn(next)
    end
    W.now = target
    local live = {}
    for _, t in ipairs(W.timers) do if not t.cancelled then live[#live + 1] = t end end
    W.timers = live
end

-- Runs every pending timer once, however long its delay (one-shot ones go away), without moving
-- the clock: for a scenario that only cares that it ran. W.Advance checks delays.
function W.RunTimers()
    local list = W.timers
    W.timers = {}
    for _, t in ipairs(list) do
        if not t.cancelled then
            t.fn(t)
            if t.repeating and not t.cancelled then W.timers[#W.timers + 1] = t end
        end
    end
end

W.errors = {}
local errorHandler = function(message) W.errors[#W.errors + 1] = tostring(message) end
function geterrorhandler() return errorHandler end
function seterrorhandler(fn) errorHandler = fn end
function securecallfunction(fn, ...)
    local result = { pcall(fn, ...) }
    if not result[1] then errorHandler(result[2]) return end
    return unpack(result, 2, table.maxn(result))
end
function debugstack() return "[stack]" end
function debugprofilestop() return os.clock() * 1000 end
function hooksecurefunc(t, name, fn)
    if type(t) == "string" then t, name, fn = _G, t, name end
    local old = t[name]
    assert(type(old) == "function", "hooksecurefunc: no function " .. tostring(name))
    t[name] = function(...)
        local r = { old(...) }
        fn(...)
        return unpack(r)
    end
end

---------------------------------------------------------------------------
-- Game API
---------------------------------------------------------------------------

W.cvars = { statusText = "0", nameplateShowFriendlyNpcs = "0", nameplateMaxDistance = "45" }
local function realName(n)
    for k in pairs(W.cvars) do if k:lower() == tostring(n):lower() then return k end end
end
C_CVar = {
    GetCVar = function(n) local r = realName(n) return r and W.cvars[r] end,
    SetCVar = function(n, v)
        local r = realName(n)
        if not r then return false end
        W.cvars[r] = type(v) == "boolean" and (v and "1" or "0") or tostring(v)
        return true
    end,
    -- W.cvarDefaults[name], else what it is now.
    GetCVarDefault = function(n) local r = realName(n) return r and (W.cvarDefaults[r] or W.cvars[r]) end,
}
W.cvarDefaults = { nameplateMaxDistance = "45" }
-- The game's clock: W.gameTime = { hours, minutes }.
W.gameTime = { 12, 0 }
function GetGameTime() return W.gameTime[1], W.gameTime[2] end
function GetZoneText() return W.zoneText or "" end

W.metadata = { Version = "1.0.0", Author = "wtFAQ", Title = "Forever Gearbox" }
W.loaded = {}
W.addonMeta = {} -- addon name -> { key = value }: another addon's TOC fields
-- Addons the game knows but hasn't loaded: name -> { onDemand, disabled, onLoad }. QuestieDB is
-- installed and loads on demand, as it does in Forever; loaded, it answers nothing unless a test
-- put its own LibQuestieDB in place.
W.addonInfo = { QuestieDB = { onDemand = true, onLoad = function()
    if _G.LibQuestieDB == nil then
        local none = { Get = function() return nil end }
        _G.LibQuestieDB = { Quest = none, Item = none }
    end
end } }
C_AddOns = {
    GetAddOnMetadata = function(name, key)
        local own = W.addonMeta[name]
        if own and own[key] ~= nil then return own[key] end
        return W.metadata[key]
    end,
    IsAddOnLoaded = function(name) return W.loaded[name] or false end,
    -- name, title, notes, loadable, reason
    GetAddOnInfo = function(name)
        local info = W.addonInfo[name]
        if W.loaded[name] then return name, name, "", true, nil end
        if not info then return name, nil, nil, false, "MISSING" end
        if info.disabled then return name, name, "", false, "DISABLED" end
        return name, name, "", true, info.onDemand and "DEMAND_LOADED" or nil
    end,
    IsAddOnLoadOnDemand = function(name)
        local info = W.addonInfo[name]
        return info and info.onDemand or false
    end,
    LoadAddOn = function(name)
        local info = W.addonInfo[name]
        if not info or info.disabled then return false, "MISSING" end
        if not W.loaded[name] then
            W.loaded[name] = true
            if info.onLoad then info.onLoad() end
            W.Fire("ADDON_LOADED", name)
        end
        return true
    end,
}
Enum = {
    AddOnProfilerMetric = { SessionAverageTime = 0, RecentAverageTime = 1, EncounterAverageTime = 2, PeakTime = 3 },
    LootSlotType = { None = 0, Item = 1, Money = 2, Currency = 3 },
    ItemQuality = { Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4 },
    ItemClass = { Consumable = 0, Container = 1, Weapon = 2, Armor = 4, Reagent = 5, Tradegoods = 7, Recipe = 9,
        Questitem = 12, Miscellaneous = 15, Profession = 19, Projectile = 6 },
    ItemWeaponSubclass = { Fishingpole = 20 },
    ItemMiscellaneousSubclass = { Reagent = 1 },
    BagIndex = { Backpack = 0 },
    WeaponSlot = { MainHand = 0, OffHand = 1, Ranged = 2 },
}
C_AddOnProfiler = {
    IsEnabled = function() return true end,
    GetAddOnMetric = function() return 0.01 end,
    GetOverallMetric = function() return 2 end,
    GetApplicationMetric = function() return 10 end,
    GetTopKAddOnsForMetric = function() return { { addOnName = "Questie", metricValue = 1.2 } } end,
}

-- Blizzard's Settings, menus and popups (tests/stubs/settings.lua).
stub("settings")

SlashCmdList, hash_SlashCmdList = {}, {}
function W.Slash(text)
    local cmd, rest = text:match("^(%S+)%s*(.-)$")
    for key, fn in pairs(SlashCmdList) do
        local i = 1
        while _G["SLASH_" .. key .. i] do
            if _G["SLASH_" .. key .. i] == cmd then return fn(rest) end
            i = i + 1
        end
    end
    error("no slash command " .. cmd)
end

W.chat = {}
function print(...)
    local t = {}
    for i = 1, select("#", ...) do t[#t + 1] = tostring(select(i, ...)) end
    W.chat[#W.chat + 1] = table.concat(t, " ")
end
function W.LastChat() return W.chat[#W.chat] or "" end
function W.ChatHas(pattern)
    for _, line in ipairs(W.chat) do if line:find(pattern, 1, true) then return true end end
    return false
end

W.combat = false
function InCombatLockdown() return W.combat end
function GetTime() return W.now end
function GetBuildInfo() return "1.60.1", "70862", "Nov 1 2026", 16001 end
function GetLocale() return "enUS" end
W.framerate, W.netStats = 58.4, { 1.5, 0.8, 42, 71 } -- what the game measures; a scenario may change them
function GetFramerate() return W.framerate end
function GetNetStats() return unpack(W.netStats) end
W.cursor = { 0, 0 }
function GetCursorPosition() return W.cursor[1], W.cursor[2] end
-- What the mouse holds: W.held = { "item", itemID, link } (an item picked up from the bags), or nil.
function GetCursorInfo() if W.held then return unpack(W.held) end end
function ClearCursor() W.held = nil end
function IsControlKeyDown() return W.ctrl or false end
W.shift = false
function IsShiftKeyDown() return W.shift end
function IsPlayerMoving() return W.moving or false end
W.alt = false
function IsAltKeyDown() return W.alt end
W.instance = false
function IsInInstance() return W.instance, W.instance and "party" or "none" end
W.speed, W.resting, W.taxi = 0, false, false
function GetUnitSpeed() return W.speed end
function IsResting() return W.resting end
function UnitOnTaxi() return W.taxi end
W.dead, W.casting = false, nil
function UnitIsDeadOrGhost() return W.dead end
W.unitExists = {}
function UnitExists(unit) return W.unitExists[unit] or false end
function UnitCastingInfo() return W.casting end
function UnitChannelInfo() return nil end
W.realm = "Kazran"
function GetRealmName() return W.realm end
-- Sounds played, in order: { id = kit ID or file ID, file = true for PlaySoundFile, channel }.
W.sounds = {}
function PlaySound(id, channel) W.sounds[#W.sounds + 1] = { id = id, channel = channel } end
function PlaySoundFile(id, channel) W.sounds[#W.sounds + 1] = { id = id, file = true, channel = channel } end
function ReloadUI() W.reloaded = true end
function Screenshot() end
date, time = os.date, os.time
function GameTooltip_Hide() end
W.units = { target = "Creature-0-4618-0-3041-3296-0000ABCDEF" }
function UnitGUID(u) return W.units[u] end
function UnitIsPlayer() return false end
function UnitName() return "Orgrimmar Grunt" end
-- Forbidden tables (Blizzard's protected frames): canaccesstable says no, and reading any key
-- from one is an error, as in the game.
W.forbidden = setmetatable({}, { __mode = "k" })
function canaccesstable(t) return not W.forbidden[t] end
function W.Forbid(t)
    W.forbidden[t] = true
    local mt = getmetatable(t)
    setmetatable(t, { __index = function(_, key)
        error("attempted to index a table that cannot be accessed while tainted (" .. tostring(key) .. ")")
    end, __newindex = mt and mt.__newindex })
end
-- A forbidden object: readable, but its methods error (only IsForbidden answers), as in the game.
function W.ForbidObject(frame)
    function frame:IsForbidden() return true end
    function frame:GetChildren() error("Attempt to access forbidden object from code tainted by an AddOn") end
end
W.secrets = {} -- values that are secret
function issecretvalue(v) return W.secrets[v] or false end
ChatFrameUtil = { GetTimestampFormat = function() return nil end }
TimeUtil = { BetterDate = function(fmt, t) return os.date(fmt, t) end }
function LibStub() end

SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 1, IG_MAINMENU_OPTION_CHECKBOX_OFF = 2, RAID_WARNING = 8959 }
YES, NO, ACCEPT, CANCEL, CLOSE, SETTINGS_DEFAULTS = "Yes", "No", "Accept", "Cancel", "Close", "Defaults"
NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0, GetRGB = function() return 1, 0.82, 0 end }
function CreateColor(r, g, b, a)
    return { r = r, g = g, b = b, a = a or 1, GetRGB = function(self) return self.r, self.g, self.b end }
end
UISpecialFrames = {}
UIPanelWindows = {} -- the panel manager's windows: name -> { area, pushable }
-- Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua: a ButtonFrameTemplate window without its portrait.
function ButtonFrameTemplate_HidePortrait() end
-- Blizzard_Colors/Shared/MaterialColors.lua: a material's text and title colours.
function GetMaterialTextColors() return { 0.18, 0.12, 0.06 }, { 0.2, 0.1, 0 } end

UIParent = W.NewFrame("Frame", "UIParent")
function UIParent:GetWidth() return 1920 end
function UIParent:GetHeight() return 1080 end
function UIParent:GetEffectiveScale() return 1 end
-- In the game every frame's metatable has a table of methods as __index (the Button Bag calls
-- them directly): UIParent's is the stub's own method table.
setmetatable(UIParent, { __index = W.FrameMethods })
GameTooltip = W.NewFrame("GameTooltip", "GameTooltip")
GameFontHighlight = W.NewFrame("Font", "GameFontHighlight")
GameFontDisable = W.NewFrame("Font", "GameFontDisable")
ChatFontNormal = W.NewFrame("Font", "ChatFontNormal")
Minimap = W.NewFrame("Frame", "Minimap")
ObjectiveTrackerFrame = W.NewFrame("Frame", "ObjectiveTrackerFrame")
AddonCompartmentFrame = W.NewFrame("Frame", "AddonCompartmentFrame")
AddonCompartmentFrame.registeredAddons = {}
function AddonCompartmentFrame:RegisterAddon(entry) table.insert(self.registeredAddons, entry) end
EditModeManagerFrame = W.NewFrame("Frame", "EditModeManagerFrame")
EditModeManagerFrame._shown = false
function EditModeManagerFrame:EnterEditMode() self._shown = true end
function EditModeManagerFrame:ExitEditMode() self._shown = false end
function EditModeManagerFrame:SelectSystem() end
function EditModeManagerFrame:ClearSelectedSystem() end

-- Items, bags and the loot window.
stub("loot")
-- Professions, worn gear, equipment sets and error text.
stub("professions")
-- The world map's window and Blizzard's scroll container (W.worldMapID, W.canvasScale, the zoom).
stub("worldmap")
-- The chat window.
stub("chat")
-- The quest log and item tooltips.
stub("quests")
-- The merchant window, money and repairs.
stub("merchant")
-- Units, the player's place and the quest giver windows (after the others: it adds to them).
stub("units")
-- Tooltip processing, colors, items, professions and the auction house (the Tooltips category).
stub("tooltips")
-- Forever Codex's own (tests/stubs/compendium.lua).
stub("compendium")
-- Macros, cooldowns, mounts and restricted snippets (Drawer).
stub("macros")

-- Lua 5.1 stand-ins for the game's string and table helpers.
format, strlower, strupper, strsub, strfind, strlen, gsub = string.format, string.lower, string.upper, string.sub, string.find, string.len, string.gsub
tinsert, tremove, sort = table.insert, table.remove, table.sort
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function strtrim(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end
function strjoin(sep, ...) local t = {} for i = 1, select("#", ...) do t[i] = select(i, ...) end return table.concat(t, sep) end
function tostringall(...)
    local n, t = select("#", ...), {}
    for i = 1, n do t[i] = tostring((select(i, ...))) end
    return unpack(t, 1, n)
end
function strsplit(delims, s, limit)
    local parts, current = {}, ""
    for i = 1, #s do
        local c = s:sub(i, i)
        if delims:find(c, 1, true) and not (limit and #parts == limit - 1) then
            parts[#parts + 1], current = current, ""
        else
            current = current .. c
        end
    end
    parts[#parts + 1] = current
    return unpack(parts)
end

---------------------------------------------------------------------------
-- Reading a global the game doesn't have is a bug, unless the addon checks for it on purpose.
---------------------------------------------------------------------------

-- Widget methods the addon calls that the stub answers generically (by verb). Under W.Strict()
-- any other verb-like name is reported, so a misspelled or made-up method fails the run. Add a
-- name only once it's a real method on this client (docs/forever-api.md).
W.METHODS = {
    SetOrientation = true, GetValue = true, GetAlpha = true, UpdateScrollChildRect = true, SetNormalFontObject = true,
    SetThumbTexture = true, SetHighlightFontObject = true, SetValueStep = true,
    AddMaskTexture = true, SetHorizTile = true, SetVertTile = true, SetNormalAtlas = true, SetPushedAtlas = true,
    SetSpacing = true, SetRotation = true, SetPortraitZoom = true, RefreshCamera = true, SetPosition = true, GetNumLines = true, EnableGamePadButton = true, SetLooping = true, IsUserPlaced = true, SetUserPlaced = true, IsMovable = true,
    SetMaxLines = true, SetJustifyV = true, IsTruncated = true, SetDrawEdge = true, Clear = true, SetChecked = true, GetChecked = true, SetCustomOnMouseUpHandler = true,
    SetTabSelectedCallback = true, AddTab = true, SetTabVisuallySelected = true, GetTabButton = true,
    UpdateTabText = true, UpdateTabWidth = true, MarkDirty = true, SetTab = true,
    AddDoubleLine = true, AddLine = true, HighlightText = true, SetFocus = true, SetOwner = true, GetOwner = true,
    NumLines = true, GetPrimaryTooltipData = true, RefreshData = true, GetUnit = true,
    UpdateDisplay = true, EnableKeyboard = true, GetEffectiveScale = true, GetFrameStrata = true,
    SetAlpha = true, SetDrawLayer = true, SetFixedFrameLevel = true, SetFixedFrameStrata = true,
    ClearFocus = true, EnableMouse = true, EnableMouseWheel = true, GenerateMenu = true, GetFrameLevel = true,
    GetHeight = true, GetHighlightTexture = true, GetStringHeight = true, GetTop = true, GetBottom = true,
    GetUnboundedStringWidth = true, GetVerticalScrollRange = true, GetWidth = true, HasFocus = true,
    Init = true, RegisterCallback = true, RegisterForClicks = true, RegisterForDrag = true,
    SetAllPoints = true, SetAtlas = true, SetAutoFocus = true, SetCheckedTexture = true,
    SetClampedToScreen = true, SetColorTexture = true, SetCursorPosition = true, SetDesaturated = true,
    SetDisabledCheckedTexture = true, SetFont = true, SetFontObject = true, SetFrameLevel = true,
    SetFrameStrata = true, SetHeight = true, SetHighlightAtlas = true, SetHighlightTexture = true,
    SetHitRectInsets = true, SetJustifyH = true, SetMaxLetters = true, SetMotionScriptsWhileDisabled = true,
    SetMovable = true, SetMultiLine = true, SetNormalAtlas = true, SetPushedAtlas = true,
    SetScrollChild = true, SetShadowOffset = true, SetSize = true, SetTexCoord = true, SetTextColor = true,
    SetTexture = true, SetVertexColor = true, SetVerticalScroll = true, SetWidth = true, SetWordWrap = true,
    StartMoving = true, StopMovingOrSizing = true, SetItemByID = true, SetHyperlink = true, SetScale = true, SetNumeric = true,
    IsMouseOver = true, SetPushedTexture = true, SetHorizTile = true, SetVertTile = true, SetIgnoreParentAlpha = true, SetTitle = true, GetScale = true,
    SetIgnoreParentScale = true, SetStatusBarTexture = true, GetStatusBarTexture = true, SetMinMaxValues = true,
    SetBlendMode = true, CreateMaskTexture = true, AddMaskTexture = true, RemoveMaskTexture = true, GetDrawLayer = true,
    GetThumbTexture = true, SetPortraitToAsset = true, SetToplevel = true, SetID = true, GetID = true, GetObjectType = true,
    SetSelectionText = true, SetIsDefaultCallback = true, SetDefaultCallback = true, ValidateResetState = true, SetStatusBarColor = true,
    GetFontObject = true, GetFontString = true,
    SetSpellByID = true, SetDisplayInfo = true, SetCreature = true, HasFocus = true, IsForbidden = true, SetFontHeight = true, GetStringWidth = true, CreateAnimationGroup = true, CreateAnimation = true, SetFromAlpha = true, SetToAlpha = true, SetToFinalAlpha = true, Play = true, Stop = true, SetDuration = true, SetOffset = true, IsPlaying = true, SetSpacing = true, GetVerticalScroll = true,
}
-- Methods the addon checks for before using (Blizzard's may lack them): absent here, so the
-- path without them is what runs.
W.PROBED = { GetBagID = true }
W.missing = {}
W.OPTIONAL = { ForeverPlusPlusAPI = true, ForeverPlusPlusCharDB = true, GetAttackPowerForStat = true, GetRangedAttackPowerForStat = true,
    GetCritChanceFromStat = true, GetDodgeChanceFromAttribute = true, GetSpellCritChanceFromStat = true, UnitHPPerStamina = true,
    MANA_PER_INTELLECT = true, BLOCK_VALUE_PER_STRENGTH = true, QuickJoinToastButton = true, ForeverPlusPlusDB = true, PlumberDB = true, WilduToolsDB = true, Auctionator = true, Baganator = true, ForeverGearboxDB = true, ForeverGearboxCharDB = true, ForeverTweaksDB = true, ForeverTweaksCharDB = true, ForeverCompendiumDB = true, ForeverCompendiumCharDB = true,
    ForeverCoreDB = true, ForeverCoreCharDB = true, ForeverCodexDB = true, ForeverCodexCharDB = true, NWB_CurrentLayer = true, LibQuestieDB = true, Spoken = true, SpokenCompendium = true, VoiceOver = true,
    BAGANATOR_CONFIG = true, BAGANATOR_CURRENT_PROFILE = true,
    QuestScrollFrame = true, QuestLogQuests_Update = true, GossipFrame = true, QuestFrameGreetingPanel = true,
    QuestFrameGreetingPanel_OnShow = true, QuestInfo_Display = true, QuestFrameProgressPanel_OnShow = true, QuestInfoFrame = true,
    QuestInfoTitleHeader = true, QuestProgressTitleText = true, QuestObjectiveTracker = true, CampaignQuestObjectiveTracker = true,
    GOSSIP_BUTTON_TYPE_ACTIVE_QUEST = true, GOSSIP_BUTTON_TYPE_AVAILABLE_QUEST = true, GOSSIP_BUTTON_TYPE_OPTION = true,
    QuestFrameAcceptButton = true, QuestFrameCompleteButton = true, QuestFrameCompleteQuestButton = true, QuestInfoItem_OnClick = true,
    MinimapBackdrop = true, GetMinimapShape = true, OpenMapAPI = true, PlayerFrame = true, TargetFrame = true, FocusFrame = true, PartyFrame = true, ForeverBestiaryDB = true, ForeverBestiaryCharDB = true, WorldMapFrame = true, GMChatFrame = true, CommunitiesFrame = true, AuctionHouseFrame = true }
function W.Strict()
    W.strict = true
    setmetatable(_G, { __index = function(_, key)
        if not W.OPTIONAL[key] and not tostring(key):match("^SLASH_") then W.missing[key] = true end
    end })
end

-- Loads addon `name` (the folder root/name) as the game would: its TOC's dependencies first (each
-- once), then its files in TOC order, each addon with a namespace of its own. Returns its
-- namespace. W.addons lists every addon loaded, in order: login fires ADDON_LOADED for each.
W.addons, W.namespaces = {}, {}
-- Addons the stand-in game has a stand-in for (tests/stubs/), loaded instead of a folder.
local STUB_ADDONS = { ForeverPlusPlus = "foreverplusplus" }

function W.LoadAddon(root, name)
    if W.namespaces[name] then return W.namespaces[name] end
    if STUB_ADDONS[name] then
        stub(STUB_ADDONS[name])
        W.namespaces[name] = {}
        W.addons[#W.addons + 1] = name
        W.loaded[name] = true
        return W.namespaces[name]
    end
    local toc = assert(io.open(root .. "/" .. name .. "/" .. name .. ".toc")):read("*a")
    for dependency in (toc:match("## Dependencies: ([^\r\n]+)") or ""):gmatch("[^,%s]+") do
        W.LoadAddon(root, dependency)
    end
    -- Forever++ is an optional dependency of Forever Gearbox: loaded first, as the game does when
    -- it's installed, unless a test plays without it (W.withoutForeverPlusPlus).
    for dependency in (toc:match("## OptionalDeps: ([^\r\n]+)") or ""):gmatch("[^,%s]+") do
        if dependency == "ForeverPlusPlus" and not W.withoutForeverPlusPlus then W.LoadAddon(root, dependency) end
    end
    local ns = {}
    W.namespaces[name] = ns
    for key, value in toc:gmatch("## ([%w-]+): ([^\r\n]+)") do W.metadata[key] = value end
    W.files = W.files or {}
    for line in toc:gmatch("[^\r\n]+") do
        if line:match("%.lua%s*$") then
            local path = root .. "/" .. name .. "/" .. line:gsub("\\", "/"):gsub("%s+$", "")
            local chunk = assert(loadfile(path))
            W.files[#W.files + 1] = path
            chunk(name, ns)
        end
    end
    W.addons[#W.addons + 1] = name
    W.loaded[name] = true
    return ns
end

return W
