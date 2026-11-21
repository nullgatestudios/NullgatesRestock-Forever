-- Nullgate's Restock: what happens at a vendor. Plans the purchase, asks first (unless the
-- player turned asking off and set a spending limit), and asks about anything over the limit.
local _, ns = ...

local L = ns.L
local Restock = {}
ns.Restock = Restock

local CONFIRM, OVER = "NULLGATES_RESTOCK_CONFIRM", "NULLGATES_RESTOCK_OVER_LIMIT"
local pending -- the plan a popup is asking about
local SHOWN_ITEMS = 6

-- "200 x Jagged Arrow, 10 x Symbol of Kings" (the first few, then "and N more").
function Restock.Describe(entries)
    local parts = {}
    for i, e in ipairs(entries) do
        if i > SHOWN_ITEMS then
            parts[#parts + 1] = string.format(L["and %d more"], #entries - SHOWN_ITEMS)
            break
        end
        parts[#parts + 1] = e.items .. " x " .. e.name
    end
    return table.concat(parts, ", ")
end

local function ConfirmText(plan)
    local text = string.format(L["Buy %s for %s?"], Restock.Describe(plan.buys), ns.Planner.Money(plan.total))
    if #plan.extra > 0 then
        text = text .. "\n\n" .. string.format(L["Over your spending limit: %s (%s)."],
            Restock.Describe(plan.extra), ns.Planner.Money(plan.extraTotal))
    end
    return text
end

local function AskAboutExtra(extra, total)
    pending = { extra = extra }
    StaticPopup_Show(OVER, string.format(L["Over your spending limit: %s for %s. Buy anyway?"],
        Restock.Describe(extra), ns.Planner.Money(total)))
end

local function Define()
    StaticPopupDialogs[CONFIRM] = {
        text = "%s",
        button1 = L["Buy"],
        button2 = L["Cancel"],
        button3 = L["Buy all"],
        OnAccept = function() if pending then ns.Merchant.Buy(pending.buys) end; pending = nil end,
        OnAlt = function()
            if pending then
                local all = {}
                for _, b in ipairs(pending.buys) do all[#all + 1] = b end
                for _, b in ipairs(pending.extra) do all[#all + 1] = b end
                ns.Merchant.Buy(all)
            end
            pending = nil
        end,
        OnCancel = function() pending = nil end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopupDialogs[OVER] = {
        text = "%s",
        button1 = L["Buy"],
        button2 = L["Skip"],
        OnAccept = function() if pending then ns.Merchant.Buy(pending.extra) end; pending = nil end,
        OnCancel = function() pending = nil end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
end

-- The plan for the vendor that's open.
function Restock.PlanHere()
    local db = ns.db
    return ns.Planner.Plan(db.items, ns.Merchant.ReadOffers(), ns.Items.Count, GetMoney(),
        { maxSpend = db.maxSpend, keepMoney = db.keepMoney })
end

function Restock.OnMerchantShow()
    local db = ns.db
    if db.paused or #db.items == 0 then return end
    if not StaticPopupDialogs[CONFIRM] then Define() end
    local plan = Restock.PlanHere()
    if #plan.buys == 0 and #plan.extra == 0 then return end
    if ns.Planner.MustAsk(db) and #plan.buys == 0 then
        AskAboutExtra(plan.extra, plan.extraTotal) -- everything is over the limit
    elseif ns.Planner.MustAsk(db) then
        pending = plan
        StaticPopupDialogs[CONFIRM].button3 = #plan.extra > 0 and L["Buy all"] or nil
        StaticPopup_Show(CONFIRM, ConfirmText(plan))
    elseif #plan.buys == 0 then
        AskAboutExtra(plan.extra, plan.extraTotal)
    else
        ns.Merchant.Buy(plan.buys, function()
            if #plan.extra > 0 then AskAboutExtra(plan.extra, plan.extraTotal) end
        end)
    end
end

function Restock.OnMerchantClosed()
    pending = nil
    if StaticPopup_Hide then
        StaticPopup_Hide(CONFIRM)
        StaticPopup_Hide(OVER)
    end
    ns.Merchant.Closed()
end
