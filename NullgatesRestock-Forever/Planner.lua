-- Nullgate's Restock: what to buy, and the buying rules. No game calls here, so the tests
-- can run every case outside the game.
local _, ns = ...

local Planner = {}
ns.Planner = Planner

-- --- Rules ---------------------------------------------------------------------------
-- Every purchase asks first. Asking can only be turned off while a spending limit is set
-- (a maximum per vendor visit, a minimum amount of gold to keep, or both); clearing both
-- limits turns asking back on.

function Planner.HasLimit(db)
    return (db.maxSpend or 0) > 0 or (db.keepMoney or 0) > 0
end

function Planner.MustAsk(db)
    return db.confirm ~= false or not Planner.HasLimit(db)
end

-- Returns false (and changes nothing) when turning asking off without a limit.
function Planner.SetConfirm(db, value)
    if not value and not Planner.HasLimit(db) then return false end
    db.confirm = value and true or false
    return true
end

-- Call after loading or changing a limit.
function Planner.Normalize(db)
    if not Planner.HasLimit(db) then db.confirm = true end
end

-- --- Planning ------------------------------------------------------------------------
-- list:   { { id = itemID, keep = amount }, ... } in the player's order (first = most important)
-- offers: [itemID] = { index =, name =, price = copper per purchase, bundle = items per purchase,
--                      available = purchases left (-1 = unlimited), maxStack = items per call }
-- have:   function(itemID) -> how many the player has
-- money:  the player's copper
-- limits: { maxSpend = copper (0 = none), keepMoney = copper (0 = none) }
--
-- Returns { buys = {...}, total = copper, extra = {...}, extraTotal = copper }. buys fit the limits;
-- extra is what the limits left out but the player could still afford. Each entry is
-- { id =, index =, name =, purchases =, items =, bundle =, maxStack =, cost = }.
function Planner.Plan(list, offers, have, money, limits)
    local plan = { buys = {}, total = 0, extra = {}, extraTotal = 0 }
    money = math.max(0, money or 0)
    local cap = money
    if (limits.keepMoney or 0) > 0 then cap = math.max(0, money - limits.keepMoney) end
    if (limits.maxSpend or 0) > 0 then cap = math.min(cap, limits.maxSpend) end
    local left, cash = cap, money

    local function Entry(entry, offer, purchases)
        return {
            id = entry.id, index = offer.index, name = offer.name, purchases = purchases,
            items = purchases * offer.bundle, bundle = offer.bundle, maxStack = offer.maxStack or 1,
            cost = purchases * offer.price,
        }
    end

    for _, entry in ipairs(list) do
        local offer = offers[entry.id]
        local need = (entry.keep or 0) - (have(entry.id) or 0)
        if offer and need > 0 and (offer.bundle or 0) > 0 then
            local purchases = math.ceil(need / offer.bundle)
            if offer.available and offer.available >= 0 then purchases = math.min(purchases, offer.available) end
            local price = offer.price or 0
            local take = purchases
            if price > 0 then take = math.min(purchases, math.floor(left / price)) end
            if take > 0 then
                local buy = Entry(entry, offer, take)
                plan.buys[#plan.buys + 1] = buy
                plan.total = plan.total + buy.cost
                left, cash = left - buy.cost, cash - buy.cost
            end
            local rest = purchases - take
            if rest > 0 and price > 0 then rest = math.min(rest, math.floor((cash - plan.extraTotal) / price)) end
            if rest > 0 then
                local extra = Entry(entry, offer, rest)
                plan.extra[#plan.extra + 1] = extra
                plan.extraTotal = plan.extraTotal + extra.cost
            end
        end
    end
    return plan
end

-- The BuyMerchantItem calls for a list of buys: { { index =, id =, quantity = } }. Items sold in
-- bundles (200 arrows) are bought one bundle per call with no quantity (the vendor's own
-- amount); single items are bought up to a full stack per call.
function Planner.Calls(buys)
    local calls = {}
    for _, buy in ipairs(buys) do
        if buy.bundle > 1 then
            for _ = 1, buy.purchases do calls[#calls + 1] = { index = buy.index, id = buy.id } end
        else
            local left, stack = buy.items, math.max(1, buy.maxStack)
            while left > 0 do
                local n = math.min(left, stack)
                calls[#calls + 1] = { index = buy.index, id = buy.id, quantity = n }
                left = left - n
            end
        end
    end
    return calls
end

-- 12345 -> "1g 23s 45c"; 0 -> "0c".
function Planner.Money(copper)
    copper = math.floor(copper or 0)
    local gold, silver, rest = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if gold > 0 then parts[#parts + 1] = gold .. "g" end
    if silver > 0 then parts[#parts + 1] = silver .. "s" end
    if rest > 0 or #parts == 0 then parts[#parts + 1] = rest .. "c" end
    return table.concat(parts, " ")
end

-- --- Suggested lists -----------------------------------------------------------------
-- class: "MAGE" etc.; level: the player's level; ranged: "arrow", "bullet" or nil;
-- diets: the pet's diets (GetPetFoodTypes), or nil; petLevel: the pet's level.
-- Returns { { id =, keep = }, ... }.
function Planner.Suggested(class, level, ranged, diets, petLevel)
    local list = {}
    for _, e in ipairs((ns.STARTER_REAGENTS or {})[class] or {}) do
        if level >= e.level and (not e.untilLevel or level < e.untilLevel) then
            list[#list + 1] = { id = e.item, keep = e.keep }
        end
    end
    local function Best(entries, upTo)
        local best
        for _, e in ipairs(entries or {}) do
            if e.level <= upTo then best = e end
        end
        return best
    end
    if class == "HUNTER" then
        local ammo = ranged and Best((ns.STARTER_AMMO or {})[ranged], level)
        if ammo then list[#list + 1] = { id = ammo.item, keep = 1000 } end
        for _, diet in ipairs(diets or {}) do
            local food = Best((ns.STARTER_PET_FOOD or {})[diet], petLevel or level)
            if food then
                list[#list + 1] = { id = food.item, keep = 20 }
                break
            end
        end
    end
    return list
end
