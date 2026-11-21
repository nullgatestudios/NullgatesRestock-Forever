-- Nullgate's Restock: reading the open vendor and buying from it.
local _, ns = ...

local L = ns.L
local Merchant = {}
ns.Merchant = Merchant

local queue, ticker, bought

-- One vendor item: name, price per purchase, items per purchase, purchases left (-1 = unlimited),
-- purchasable, and whether it costs something other than money (tokens, honor).
local function ItemInfo(index)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local t = C_MerchantFrame.GetItemInfo(index)
        if not t then return nil end
        return t.name, t.price, t.stackCount, t.numAvailable, t.isPurchasable, t.hasExtendedCost
    end
    if GetMerchantItemInfo then
        local name, _, price, quantity, numAvailable, isPurchasable, _, extendedCost = GetMerchantItemInfo(index)
        return name, price, quantity, numAvailable, isPurchasable, extendedCost
    end
    return nil
end
Merchant.ItemInfo = ItemInfo

-- [itemID] = offer (see Planner.Plan), for the vendor that's open. The first offer of an item wins.
function Merchant.ReadOffers()
    local offers = {}
    local count = GetMerchantNumItems and GetMerchantNumItems() or 0
    for index = 1, count do
        local id = GetMerchantItemID and GetMerchantItemID(index)
        local name, price, bundle, available, purchasable, extended = ItemInfo(index)
        if id and not offers[id] and purchasable ~= false and not extended and price then
            offers[id] = {
                index = index, name = name or ns.Items.Name(id) or ("item " .. id), price = price,
                bundle = math.max(1, bundle or 1), available = available or -1,
                maxStack = (GetMerchantItemMaxStack and GetMerchantItemMaxStack(index)) or 1,
            }
        end
    end
    return offers
end

local function Stop()
    if ticker then ticker:Cancel() end
    ticker, queue = nil, nil
end

local function Finish()
    local summary = bought
    Stop()
    bought = nil
    if summary and #summary.parts > 0 and ns.db.summary then
        ns.Print(string.format(L["Bought %s for %s."], table.concat(summary.parts, ", "), ns.Planner.Money(summary.cost)))
    end
end

-- Buys the planned items, one call every 0.2 seconds, and prints a summary at the end.
-- Stops if the vendor closes, an item moves, or a purchase would break the gold to keep.
function Merchant.Buy(buys, onDone)
    if not buys or #buys == 0 then
        if onDone then onDone() end
        return
    end
    Stop()
    queue = ns.Planner.Calls(buys)
    bought = { parts = {}, cost = 0 }
    for _, buy in ipairs(buys) do
        bought.parts[#bought.parts + 1] = buy.items .. " x " .. buy.name
        bought.cost = bought.cost + buy.cost
    end
    local step = 1
    local function Next()
        local call = queue and queue[step]
        if not call then
            Finish()
            if onDone then onDone() end
            return
        end
        step = step + 1
        if GetMerchantItemID(call.index) ~= call.id then
            ns.Print(L["The vendor's list changed; stopped buying."])
            bought = nil
            Stop()
            return
        end
        if call.quantity then BuyMerchantItem(call.index, call.quantity) else BuyMerchantItem(call.index) end
    end
    Next()
    if queue then ticker = C_Timer.NewTicker(0.2, Next) end
end

function Merchant.Closed()
    if queue then
        ns.Print(L["The vendor closed before everything was bought."])
        bought = nil
    end
    Stop()
end
