-- Nullgate's Restock: /nrestock check, the in-game self test (phase 0 of PLAN.md).
-- It writes every result to chat and to NullgatesRestockDB.check, so the log can be copied from
-- WTF\Account\<account>\<realm>\<character>\SavedVariables\NullgatesRestock-Forever.lua.
--
--   1. Which vendor, item and popup calls exist in this client.
--   2. At an open vendor: every item it sells, as the addon reads it (ID, price, bundle,
--      stock, stack), and the plan the addon would make from your list.
--   3. A one-purchase test: buys one purchase of the cheapest item on your list that this
--      vendor sells and reports how many arrived, to confirm how bundled items are bought.
local _, ns = ...

local Check = {}
ns.Check = Check

local LOG_LIMIT = 400
local panel, buyTest

local function Log(text)
    local db = ns.db
    if db then
        db.check = db.check or {}
        if #db.check >= LOG_LIMIT then table.remove(db.check, 1) end
        db.check[#db.check + 1] = text
    end
    print("|cff00c0ffNullgate's Restock check:|r " .. text)
end
Check.Log = Log

local function Exists(path)
    local value = _G
    for part in path:gmatch("[^.]+") do
        if type(value) ~= "table" then return false end
        value = value[part]
    end
    return type(value) == "function"
end

local function StaticChecks()
    local _, class = UnitClass("player")
    Log(string.format("client %s, build %s, interface %s; class %s, level %s; data build %s",
        tostring(GetBuildInfo and select(1, GetBuildInfo())), tostring(GetBuildInfo and select(2, GetBuildInfo())),
        tostring(GetBuildInfo and select(4, GetBuildInfo())), tostring(class), tostring(UnitLevel("player")),
        tostring(ns.STARTER_DATA_BUILD)))
    local calls = {}
    for _, name in ipairs({ "GetMerchantNumItems", "GetMerchantItemID", "GetMerchantItemInfo", "C_MerchantFrame.GetItemInfo",
        "GetMerchantItemMaxStack", "BuyMerchantItem", "C_Item.GetItemCount", "GetItemCount", "C_Item.GetItemMaxStackSizeByID",
        "C_Item.GetItemInfoInstant", "GetPetFoodTypes", "GetCursorInfo", "MerchantItemButton_OnModifiedClick",
        "StaticPopup_Show", "C_Timer.NewTicker" }) do
        calls[#calls + 1] = name .. "=" .. (Exists(name) and "yes" or "no")
    end
    Log("calls: " .. table.concat(calls, " "))
    local suggested = ns.SuggestedList()
    local names = {}
    for _, e in ipairs(suggested) do names[#names + 1] = e.keep .. " x " .. (ns.Items.Name(e.id) or e.id) end
    Log("suggested list: " .. (#names > 0 and table.concat(names, ", ") or "none for this class and level"))
    if GetPetFoodTypes and UnitExists("pet") then Log("pet diets: " .. table.concat({ GetPetFoodTypes() }, ", ")) end
    Log("ranged ammo kind: " .. tostring(ns.Items.RangedAmmoKind()))
    if ns.db.items[1] then
        local id = ns.db.items[1].id
        local count = (C_Item and C_Item.GetItemCount) or GetItemCount
        if count then Log(string.format("first list item %d: bags %s, bags+bank %s", id, tostring(count(id)), tostring(count(id, true)))) end
    end
end

local function VendorChecks()
    local n = GetMerchantNumItems and GetMerchantNumItems() or 0
    if n == 0 then
        Log("no vendor open: talk to a vendor and run /nrestock check again for the vendor tests")
        return
    end
    for index = 1, n do
        local name, price, bundle, available, purchasable, extended = ns.Merchant.ItemInfo(index)
        Log(string.format("vendor %d: id %s %s, price %s, bundle %s, available %s, purchasable %s, extended %s, maxStack %s",
            index, tostring(GetMerchantItemID(index)), tostring(name), tostring(price), tostring(bundle), tostring(available),
            tostring(purchasable), tostring(extended), tostring(GetMerchantItemMaxStack and GetMerchantItemMaxStack(index))))
    end
    local plan = ns.Restock.PlanHere()
    Log(string.format("plan from your list: %d to buy (%s), %d over the limit (%s); must ask: %s",
        #plan.buys, ns.Planner.Money(plan.total), #plan.extra, ns.Planner.Money(plan.extraTotal), tostring(ns.Planner.MustAsk(ns.db))))
end

-- The cheapest item on the list that this vendor sells.
local function CheapestListed()
    local offers, best = ns.Merchant.ReadOffers(), nil
    for _, entry in ipairs(ns.db.items) do
        local offer = offers[entry.id]
        if offer and (not best or offer.price < best.offer.price) then best = { id = entry.id, offer = offer } end
    end
    return best
end

local function BuildPanel()
    panel = CreateFrame("Frame", "NullgatesRestockCheck", UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(300, 130)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetToplevel(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    local title = "Restock check"
    if type(panel.SetTitle) == "function" then panel:SetTitle(title)
    elseif type(panel.TitleText) == "table" then panel.TitleText:SetText(title) end
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(260, 22)
    button:SetPoint("TOP", panel, "TOP", 0, -36)
    button:SetText("Buy one purchase of a list item")
    button:SetScript("OnClick", function()
        local pick = CheapestListed()
        if not pick then
            Log("buy test: this vendor sells nothing on your list")
            return
        end
        buyTest = { id = pick.id, before = ns.Items.Count(pick.id), bundle = pick.offer.bundle }
        Log(string.format("buy test: BuyMerchantItem(%d) for item %d (bundle %d, price %s)", pick.offer.index, pick.id,
            pick.offer.bundle, ns.Planner.Money(pick.offer.price)))
        BuyMerchantItem(pick.offer.index)
    end)
    local note = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("BOTTOM", panel, "BOTTOM", 0, 14)
    note:SetWidth(270)
    note:SetText("Spends a little gold on the cheapest item on your list. Results go to chat and are saved.")
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("BAG_UPDATE_DELAYED")
watcher:RegisterEvent("UI_ERROR_MESSAGE")
watcher:SetScript("OnEvent", function(_, event, a, b)
    if not buyTest then return end
    if event == "UI_ERROR_MESSAGE" then
        Log("buy test: game error " .. tostring(b or a))
        return
    end
    local after = ns.Items.Count(buyTest.id)
    Log(string.format("buy test: %d arrived (bundle %d) -> %s", after - buyTest.before, buyTest.bundle,
        (after - buyTest.before) == buyTest.bundle and "OK, one call buys one bundle" or "DIFFERENT"))
    buyTest = nil
end)

function Check.Run()
    if ns.db then ns.db.check = {} end
    StaticChecks()
    VendorChecks()
    if GetMerchantNumItems and GetMerchantNumItems() > 0 then
        if not panel then BuildPanel() end
        panel:Show()
    end
end
