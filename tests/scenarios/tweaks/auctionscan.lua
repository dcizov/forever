--[[
    Forever Tweaks - tests/scenarios/tweaks/auctionscan.lua
    The auction house scan's paging: opening the auction house starts one browse query; each
    page that comes back asks for the next only while the server's throttle is ready (waiting for
    it otherwise); a page the server never answers is asked for again, and after a few tries the
    scan ends with what it has; a stall timer from waiting on the throttle never sends a second
    request once the page has been asked for; reopening soon after doesn't scan again; another
    search stops the scan, keeping the prices seen.
    Run by tests/run.lua (lua5.1 tests/run.lua auctionscan), which passes its helpers in.
]]

local T = ...
local check, eq, login, finish, root = T.check, T.eq, T.login, T.finish, T.root

W.Strict()
-- Blizzard_AuctionHouseUI's window, which loads on demand: on its Buy tab, nothing to sell.
AuctionHouseFrameDisplayMode = { Buy = 1, ItemSell = 2, CommoditiesSell = 3 }
AuctionHouseFrame = W.NewFrame("Frame", "AuctionHouseFrame", UIParent)
function AuctionHouseFrame:GetDisplayMode() return AuctionHouseFrameDisplayMode.Buy end
local ns = W.LoadAddon(root, "ForeverTweaks")
login()
local House = ns.ItemTooltipParts.House

local function page(itemID, price) return { { itemKey = { itemID = itemID }, minPrice = price, totalQuantity = 1 } } end

-- Opening: one browse query, then a page at a time.
W.ah.full = false
W.Fire("AUCTION_HOUSE_SHOW")
W.Advance(1)
eq(W.ah.queries, 1, "opening the auction house sends one browse query")
W.Fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
eq(W.ah.more, 1, "its answer asks for the next page")

-- The throttle isn't ready: wait for it, then ask. The stall timer from that wait must not fire
-- a second request for the same page.
W.ah.ready = false
W.Fire("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", page(2589, 40))
eq(W.ah.more, 1, "nothing asked while the throttle isn't ready")
W.Advance(5)
W.ah.ready = true
W.Fire("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
eq(W.ah.more, 2, "asked once the throttle is ready")
W.Advance(4) -- 9 s after the throttle wait began: past its stall time, not the new one's
eq(W.ah.more, 2, "the throttle wait's stall timer doesn't ask a second time")

-- No answer: ask again, a couple of times, then end with what it has.
W.Advance(8)
eq(W.ah.more, 3, "no answer: asked again")
W.Advance(8)
eq(W.ah.more, 4, "and once more")
W.Advance(8)
eq(W.ah.more, 4, "then it gives up")
check(House().scannedAt > 0, "and the scan counts as done")
eq(ns.ItemTooltipParts.AuctionPrice(2589), 40, "with the prices it saw")

-- Back soon after: no scan.
W.Fire("AUCTION_HOUSE_CLOSED")
W.Fire("AUCTION_HOUSE_SHOW")
W.Advance(1)
eq(W.ah.queries, 1, "reopening soon after doesn't scan again")

-- /ft scan scans now; the player's own search stops it, keeping the prices.
W.Slash("/ft scan")
eq(W.ah.queries, 2, "/ft scan starts a scan")
C_AuctionHouse.SearchForFavorites()
W.Fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
eq(W.ah.more, 4, "another search stops it: no more pages asked")
eq(ns.ItemTooltipParts.AuctionPrice(2589), 40, "the prices seen are kept")
finish()
