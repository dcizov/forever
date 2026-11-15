--[[
    Forever Tweaks - Modules/Tooltips/AuctionScan.lua
    Item Tooltips: the auction house scan
    Scans the auction house when it opens (every SCAN_INTERVAL at most; /ft scan any time),
    keeping the lowest buyout of each item for Auction Prices (AuctionPrices.lua), with a line of
    text in the auction house's title bar while it runs. Any browse (the player's own searches too)
    updates the prices. The scan is an empty browse search paged to the end, the same one
    Auctionator's default scan uses on Forever; it shares the server's query throttle with
    everything the player does there, so it keeps one request out at a time, gives way for a
    moment after each of Blizzard's own queries, pauses while an item sits in the sell box, asks
    again when the server doesn't answer, and ends with what it has after a few tries. Another
    search replaces its results, so that stops it, keeping the prices seen. Not with Auctionator's
    prices in use. Adapted from Forever++'s Item Tooltips by xIGBClutchIx (MIT License).
]]

local _, ns = ...
local L = ns.L

local ipairs, pairs, format, time, floor = ipairs, pairs, string.format, time, math.floor
local GetTime, CreateFrame = GetTime, CreateFrame
local Shared = assert(ns.ItemTooltipsShared, "AuctionScan.lua loads after ItemTooltips.lua")
local M = assert(ns.modules.ItemTooltips, "AuctionScan.lua loads after ItemTooltips.lua")
local Prices = assert(ns.AuctionPrices, "AuctionScan.lua loads after AuctionPrices.lua")
local packPrice, unpackPrice = Prices.Pack, Prices.Unpack

local SCAN_INTERVAL = 15 * 60 -- seconds between automatic scans, as Auctionator waits

-- Indicator ----------------------------------------------------------------------------------
-- A spinner and a line of text in the auction house's title bar while a scan runs, then
-- "Prices updated" for a few seconds. Our own frame, parented to Blizzard's window.

local indicator
local hideTimer -- the module's timer hiding the indicator

local function getIndicator()
    local parent = AuctionHouseFrame
    if not parent then
        return nil -- Blizzard_AuctionHouseUI loads on demand
    end
    if not indicator then
        indicator = CreateFrame("Frame", nil, parent)
        indicator:SetSize(1, 20)
        indicator:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -30, -1)
        -- Above the window's border and title art, which are child frames with fixed levels well
        -- above the window's. A level over the title bar, as Coordinates does on the map, not a
        -- strata, so it stays with the window instead of floating over others.
        indicator:SetFrameLevel(parent.TitleContainer:GetFrameLevel() + 1)
        indicator.text = indicator:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        indicator.text:SetPoint("RIGHT")
    end
    return indicator
end

-- busy shows the spinner; stay keeps the text up instead of hiding it after a few seconds.
local function showIndicator(text, busy, stay)
    local frame = getIndicator()
    if not frame then
        if not busy and not stay then
            M:Print(text) -- no auction house window to show it on
        end
        return
    end
    M:CancelTimer(hideTimer)
    frame.text:SetText(text)
    frame:Show()
    if not busy and not stay then
        hideTimer = M:After(4, function() frame:Hide() end)
    end
end

local function hideIndicator()
    M:CancelTimer(hideTimer)
    if indicator then
        indicator:Hide()
    end
end

-- Scanning -----------------------------------------------------------------------------------

local scanning = false
local seen, seenCount -- itemIDs priced in this scan, and how many
local listed = {} -- itemIDs priced in the browse results shown now (any browse, not just a scan)

-- Keeps the lowest price from browse results. Any browse (the player's own searches too) updates
-- the prices, so they stay fresh between full scans.
local function addResults(results)
    local items = Prices.House().items
    local now = time()
    for _, result in ipairs(results or {}) do
        local itemID = result.itemKey and result.itemKey.itemID
        local price = result.minPrice
        if itemID and result.totalQuantity and result.totalQuantity > 0 and price
            and price > 0 then
            local old = unpackPrice(items[itemID])
            if listed[itemID] and old then -- no price when the prices were reset since
                -- One item can come back once per item level or suffix: keep the lowest.
                if price < old then items[itemID] = packPrice(price, now) end
            else
                -- The first price in these results replaces the old one.
                listed[itemID] = true
                items[itemID] = packPrice(price, now)
            end
            if scanning and not seen[itemID] then
                seen[itemID] = true
                seenCount = seenCount + 1
            end
        end
    end
end

local open = false -- the auction house is open

-- The scan shares the server's query throttle with everything the player does in the auction
-- house. Paging nonstop starves Blizzard's own queries, so the Sell tab's list never loads and
-- posts can fail. So it keeps one request out at a time, sends only when the throttle is ready,
-- gives way for a moment after each of Blizzard's own queries, and pauses while an item sits in
-- the sell box, so the list and the post go through first. Browsing tabs with nothing
-- to sell doesn't stop it.
local YIELD = 2 -- seconds the scan waits after one of Blizzard's own queries

local sent = false -- the scan's browse query has gone out
local waiting -- what the next step waits on: "server", "throttle", or "blocked"
local ownQuery = false -- set while sending the scan's own browse query
local lastQuery = 0 -- GetTime() of Blizzard's last query of its own
local blockTimer -- the module's timer while a scan is held back
local onThrottleReady

-- The server doesn't always answer: a page request can be dropped by the throttle, or the last
-- page can come back with no event at all, and the throttle's ready event can fail to come. So a
-- step that waits on the server or the throttle asks again after a while, and after a few tries
-- with no answer the scan ends with the prices it has, instead of spinning forever.
local STALL = 8 -- seconds without an answer before asking again
local RETRIES = 2 -- times it asks again before it ends the scan
local stallTimer -- the module's timer while waiting on the server
local retries = 0
local answered = false -- a browse answer came since the scan's query went out

local function stopScan()
    scanning, sent, waiting = false, false, nil
    seen, seenCount = nil, nil
    retries, answered = 0, false
    M:UnregisterEvent("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
    M:CancelTimer(blockTimer)
    M:CancelTimer(stallTimer)
end

-- Ends the scan, keeping every price seen. The scan counts as done, so it waits the usual
-- interval before scanning again on its own.
local function finishScan(text)
    local count = seenCount
    Prices.House().scannedAt = time()
    stopScan()
    showIndicator(format(text, count), false)
end

-- An item is in the sell box on the Sell tab, so a post is coming.
local function selling()
    local frame, modes = AuctionHouseFrame, AuctionHouseFrameDisplayMode
    local mode = frame:GetDisplayMode()
    local sellFrame = (mode == modes.ItemSell and frame.ItemSellFrame)
        or (mode == modes.CommoditiesSell and frame.CommoditiesSellFrame)
    return sellFrame and sellFrame:GetItem() ~= nil or false
end

local step, onStall

-- Waits on the server or the throttle: asks again if nothing comes in STALL seconds. One stall
-- timer at a time, so a timer left from an earlier wait can't send a second request.
local function waitForAnswer(kind)
    waiting = kind
    M:CancelTimer(stallTimer)
    stallTimer = M:After(STALL, onStall)
end

-- No answer in time: ask again, or end the scan with what it has.
function onStall()
    if not scanning or (waiting ~= "server" and waiting ~= "throttle") then
        return
    end
    retries = retries + 1
    if retries > RETRIES then
        finishScan(L.AUCTIONPRICES_NO_ANSWER)
        return
    end
    if waiting == "server" and not answered then
        sent = false -- the first query got no answer: send it again
    end
    M:UnregisterEvent("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
    waiting = nil
    step()
end

-- Paused for the sell box or giving way: look again shortly. The timer runs only while a scan
-- is held back.
local function onBlockTimer()
    if waiting == "blocked" then
        step()
    end
end

-- Sends the scan's query, asks for the next page, or finishes once the server has sent
-- everything. Runs once per answer, so there's never more than one request out.
function step()
    if not scanning then
        return
    end
    local sell = selling()
    local wait = lastQuery + YIELD - GetTime()
    if sell or wait > 0 then
        waiting = "blocked"
        M:CancelTimer(stallTimer) -- held back on purpose, not waiting on anyone
        if sell then
            showIndicator(format(L.AUCTIONPRICES_PAUSED, seenCount), false, true)
        end
        if not M:IsPending(blockTimer) then
            blockTimer = M:After(sell and 1 or wait, onBlockTimer)
        end
        return
    end
    showIndicator(format(L.AUCTIONPRICES_SCANNING, seenCount), true)
    if not C_AuctionHouse.IsThrottledMessageSystemReady() then
        if waiting ~= "throttle" then
            M:RegisterEvent("AUCTION_HOUSE_THROTTLED_SYSTEM_READY", onThrottleReady)
            waitForAnswer("throttle")
        end
        return
    end
    if not sent then
        sent, ownQuery, answered = true, true, false
        C_AuctionHouse.SendBrowseQuery({
            searchString = "", sorts = {}, filters = {}, itemClassFilters = {},
        })
        ownQuery = false
        waitForAnswer("server")
    elseif not C_AuctionHouse.HasFullBrowseResults() then
        C_AuctionHouse.RequestMoreBrowseResults()
        waitForAnswer("server")
    else
        finishScan(L.AUCTIONPRICES_SCANNED)
    end
end

function onThrottleReady()
    M:UnregisterEvent("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
    if waiting == "throttle" then
        step()
    end
end

local function onResults()
    if scanning and sent and waiting == "server" then
        retries, answered = 0, true
        M:CancelTimer(stallTimer)
        step()
    end
end

-- The whole list again: a new search, or more pages of the same one.
local function onResultsUpdated()
    wipe(listed)
    addResults(C_AuctionHouse.GetBrowseResults())
    onResults()
end

local function onResultsAdded(_, _, added)
    addResults(added)
    onResults()
end

-- Blizzard sent a query of its own (the sell list, an item's listings, your auctions, a post,
-- a purchase): hold the next page back for a moment so those go first.
local function onBlizzardQuery()
    if scanning then
        lastQuery = GetTime()
    end
end

-- Another search (the player's, favorites, another addon's) replaces the browse results the scan
-- was paging through, so stop, keeping the prices seen so far. Also stops a scan still waiting
-- to start, which would otherwise replace the player's results.
local function onOtherSearch()
    if scanning and not ownQuery then
        local count = seenCount
        stopScan()
        showIndicator(format(L.AUCTIONPRICES_STOPPED, count), false)
    end
end

local SEARCHES = { "SendBrowseQuery", "SearchForFavorites", "SearchForItemKeys" }
local QUERIES = {
    "SendSearchQuery", "SendSellSearchQuery", "RequestMoreItemSearchResults",
    "RequestMoreCommoditySearchResults", "RefreshItemSearchResults",
    "RefreshCommoditySearchResults", "QueryOwnedAuctions", "QueryBids", "PostItem",
    "PostCommodity", "PlaceBid", "CancelAuction", "StartCommoditiesPurchase",
    "ConfirmCommoditiesPurchase",
}

-- With Auctionator's prices in use, ours aren't scanned; the saved ones stay for when it's off.
local function startScan()
    if scanning or not open or Prices.UsingAuctionator() then
        return
    end
    scanning, sent, waiting = true, false, nil
    seen, seenCount = {}, 0
    step()
end

-- A moment after opening, so Blizzard's window has set itself up first: scan when it's due, or
-- say how old the prices are.
local function afterShow()
    if not open or scanning or Prices.UsingAuctionator() then
        return
    end
    local age = time() - Prices.House().scannedAt
    if M.db.scanOnOpen and age >= SCAN_INTERVAL then
        startScan()
    elseif Prices.House().scannedAt > 0 then
        showIndicator(format(L.AUCTIONPRICES_AGE, floor(age / 60)), false)
    end
end

local function onShow()
    open = true
    M:After(0.5, afterShow)
end

-- /ft scan: scan now, whenever the last one was.
local function scanCommand()
    if not Shared.IsShown("auction") then
        M:Reply(L.AUCTIONPRICES_IS_OFF)
    elseif Prices.UsingAuctionator() then
        M:Reply(L.AUCTIONPRICES_USING_AUCTIONATOR)
    elseif not open then
        M:Reply(L.AUCTIONPRICES_NOT_OPEN)
    else
        startScan()
    end
end
M:AddCommand("scan", nil, L.AUCTIONPRICES_COMMAND, scanCommand)

local function onClosed()
    open = false
    stopScan() -- prices seen so far are kept; the next visit scans again
    hideIndicator()
end

-- On and off with the auction lines ------------------------------------------------------------

local events = {
    AUCTION_HOUSE_SHOW = onShow,
    AUCTION_HOUSE_CLOSED = onClosed,
    AUCTION_HOUSE_BROWSE_RESULTS_UPDATED = onResultsUpdated,
    AUCTION_HOUSE_BROWSE_RESULTS_ADDED = onResultsAdded,
}

-- Listens to the auction house only while the auction lines are on and use our own scans; the
-- hooks do nothing unless a scan runs.
local function update()
    local on = Shared.IsShown("auction") and not Prices.UsingAuctionator()
    for event, fn in pairs(events) do
        if on then M:RegisterEvent(event, fn) else M:UnregisterEvent(event) end
    end
    if on then
        for _, name in ipairs(SEARCHES) do M:Hook(C_AuctionHouse, name, onOtherSearch) end
        for _, name in ipairs(QUERIES) do M:Hook(C_AuctionHouse, name, onBlizzardQuery) end
        open = AuctionHouseFrame and AuctionHouseFrame:IsShown() or false -- turned on there
    else
        stopScan()
        hideIndicator()
        open = false
    end
end

M:AddPart({
    Enable = update,
    Disable = function()
        stopScan()
        hideIndicator()
        open = false
    end,
    Changed = function(_, key) if key == "auction" or key == "auctionator" then update() end end,
})
