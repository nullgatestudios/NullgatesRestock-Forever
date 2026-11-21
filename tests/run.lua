-- Nullgate's Restock: tests for the planner, the buying rules and the suggested lists.
-- Run from the repository root:  lua tests/run.lua   (Lua 5.1 or newer)

local source = debug.getinfo(1, "S").source or ""
local script = source:match("^@(.*)$") or "tests/run.lua"
local scriptDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local root = (scriptDir:match("^(.*)[/\\][^/\\]*$") or ".") .. "/NullgatesRestock-Forever/"

local ns = {}
local function Load(file) assert(loadfile(root .. file), "cannot load " .. file)("NullgatesRestock-Forever", ns) end
Load("Data/StarterLists.lua")
Load("Planner.lua")
local P = ns.Planner

local checks, failures = 0, 0
local function EQ(got, want, name)
    checks = checks + 1
    if got ~= want then
        failures = failures + 1
        print(string.format("FAIL %s: expected %s, got %s", name, tostring(want), tostring(got)))
    end
end

-- --- Rules ---------------------------------------------------------------------------
local db = { confirm = true, maxSpend = 0, keepMoney = 0 }
EQ(P.MustAsk(db), true, "asks by default")
EQ(P.SetConfirm(db, false), false, "can't stop asking with no limit")
EQ(db.confirm, true, "the refused change leaves asking on")
db.maxSpend = 50000
EQ(P.SetConfirm(db, false), true, "with a maximum per visit, asking can be turned off")
EQ(P.MustAsk(db), false, "and then it doesn't ask")
db.maxSpend, db.keepMoney = 0, 100000
EQ(P.MustAsk(db), false, "a minimum gold to keep alone is enough")
db.keepMoney = 0
EQ(P.MustAsk(db), true, "clearing both limits makes it ask again, even before Normalize")
P.Normalize(db)
EQ(db.confirm, true, "Normalize turns asking back on with no limit")
EQ(P.SetConfirm(db, true), true, "turning asking on always works")

-- --- Planning ------------------------------------------------------------------------
local ARROW, RUNE, CANDLE = 11285, 17031, 17028
local offers = {
    [ARROW] = { index = 1, name = "Jagged Arrow", price = 1000, bundle = 200, available = -1, maxStack = 1 },
    [RUNE] = { index = 2, name = "Rune of Teleportation", price = 1000, bundle = 1, available = -1, maxStack = 10 },
    [CANDLE] = { index = 3, name = "Holy Candle", price = 700, bundle = 1, available = 5, maxStack = 20 },
}
local bags = {}
local function Have(id) return bags[id] or 0 end
local list = { { id = ARROW, keep = 1000 }, { id = RUNE, keep = 10 }, { id = CANDLE, keep = 20 }, { id = 999, keep = 5 } }
local NO_LIMIT = { maxSpend = 0, keepMoney = 0 }

bags = { [ARROW] = 350, [RUNE] = 4 }
local plan = P.Plan(list, offers, Have, 1000000, NO_LIMIT)
EQ(#plan.buys, 3, "three items to buy (the fourth isn't sold here)")
EQ(plan.buys[1].purchases, 4, "650 arrows short: 4 bundles of 200 (rounds up)")
EQ(plan.buys[1].items, 800, "800 arrows")
EQ(plan.buys[2].items, 6, "6 runes")
EQ(plan.buys[3].items, 5, "only 5 candles in stock, so 5")
EQ(plan.total, 4000 + 6000 + 3500, "total cost")
EQ(#plan.extra, 0, "nothing over a limit when there is none")

bags = { [ARROW] = 1000, [RUNE] = 10, [CANDLE] = 25 }
plan = P.Plan(list, offers, Have, 1000000, NO_LIMIT)
EQ(#plan.buys + #plan.extra, 0, "fully stocked: nothing to buy")

-- Maximum per visit: the first items fill the budget, the rest goes to extra.
bags = {}
plan = P.Plan(list, offers, Have, 1000000, { maxSpend = 7500, keepMoney = 0 })
EQ(plan.buys[1].purchases, 5, "75s limit: all 5 arrow bundles (50s)")
EQ(plan.buys[2].items, 2, "then 2 runes (20s), up to 70s")
EQ(plan.total, 7000, "never above the limit")
EQ(#plan.extra, 2, "the rest of the runes and the candles are over the limit")
EQ(plan.extra[1].items, 8, "8 more runes")
EQ(plan.extra[2].items, 5, "5 candles")
EQ(plan.extraTotal, 8000 + 3500, "extra total")

-- Minimum gold to keep.
plan = P.Plan(list, offers, Have, 12000, { maxSpend = 0, keepMoney = 10000 })
EQ(plan.total, 2000, "1g 20s with 1g to keep: spends at most 20s")
EQ(plan.buys[1].purchases, 2, "2 arrow bundles")

-- Both limits: the smaller one wins.
plan = P.Plan(list, offers, Have, 1000000, { maxSpend = 3000, keepMoney = 990000 })
EQ(plan.total, 3000, "30s max and 1g to keep of 100g: 30s")
plan = P.Plan(list, offers, Have, 1000000, { maxSpend = 50000, keepMoney = 998000 })
EQ(plan.total, 2000, "500s max but only 20s above the gold to keep: 20s")

-- Not enough gold at all: extra only holds what can still be afforded.
plan = P.Plan(list, offers, Have, 2500, NO_LIMIT)
EQ(plan.total, 2000, "25s: 2 arrow bundles")
EQ(#plan.extra, 0, "nothing listed as extra that can't be afforded")

-- Free items and unknown stock.
plan = P.Plan({ { id = 1, keep = 3 } }, { [1] = { index = 9, name = "Free", price = 0, bundle = 1, maxStack = 1 } }, Have, 0, NO_LIMIT)
EQ(plan.buys[1] and plan.buys[1].items, 3, "free items are bought even with no gold")

-- --- Calls ---------------------------------------------------------------------------
local calls = P.Calls({
    { index = 1, id = ARROW, purchases = 3, items = 600, bundle = 200, maxStack = 1 },
    { index = 2, id = RUNE, purchases = 25, items = 25, bundle = 1, maxStack = 10 },
})
EQ(#calls, 6, "3 bundle calls and 3 stack calls")
EQ(calls[1].quantity, nil, "bundles are bought with no quantity (the vendor's own amount)")
EQ(calls[4].quantity, 10, "single items: a full stack per call")
EQ(calls[6].quantity, 5, "then the remainder")

-- --- Money ---------------------------------------------------------------------------
EQ(P.Money(0), "0c", "0 copper")
EQ(P.Money(12345), "1g 23s 45c", "gold, silver and copper")
EQ(P.Money(10000), "1g", "whole gold")
EQ(P.Money(150), "1s 50c", "silver and copper")

-- --- Suggested lists -----------------------------------------------------------------
local function Ids(l) local t = {}; for _, e in ipairs(l) do t[#t + 1] = e.id end; return table.concat(t, ",") end
EQ(Ids(P.Suggested("MAGE", 10, nil)), "", "level 10 mage: nothing yet")
EQ(Ids(P.Suggested("MAGE", 40, nil)), "17056,17031,17032", "level 40 mage: feathers, teleport and portal runes")
EQ(Ids(P.Suggested("DRUID", 35, nil)), "17035", "level 35 druid: Stranglethorn Seed only")
EQ(Ids(P.Suggested("DRUID", 60, nil)), "17026,17038", "level 60 druid: Wild Thornroot and Ironwood Seed, no older seeds or berries")
EQ(Ids(P.Suggested("PRIEST", 60, nil)), "17056,17029", "level 60 priest: Holy Candle replaced by Sacred Candle")
EQ(Ids(P.Suggested("WARRIOR", 60, nil)), "", "warriors use no reagents")
EQ(Ids(P.Suggested("HUNTER", 45, "arrow", { "Meat", "Fish" }, 45)), "11285,4599", "level 45 hunter with a level 45 pet: Jagged Arrows and Cured Ham Steak")
EQ(Ids(P.Suggested("HUNTER", 30, "bullet", nil)), "3033", "hunter with a gun and no pet: Solid Shot")
EQ(Ids(P.Suggested("HUNTER", 45, "arrow", { "Meat" }, 44)), "11285,3771", "a level 44 pet gets the best meat at or below its level")
EQ(P.Suggested("HUNTER", 45, "arrow")[1].keep, 1000, "ammo keeps 1000")
local seeds = P.Suggested("DRUID", 20, nil)
EQ(seeds[1] and seeds[1].keep, 5, "seeds keep 5")

print(string.format("%d checks, %d failure(s)", checks, failures))
if failures > 0 then os.exit(1) end
