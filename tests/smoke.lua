-- Nullgate's Restock: smoke test of the whole addon with stand-in game API.
-- Loads the files in .toc order, logs in as a level 40 mage, accepts the suggested list and
-- shops at a vendor: asking first, buying, spending limits, the vendor closing, adding items
-- (slash command, drag, Alt-click), pausing and /nrestock check.
-- Run from the repository root:  lua tests/smoke.lua

local source = debug.getinfo(1, "S").source or ""
local script = source:match("^@(.*)$") or "tests/smoke.lua"
local scriptDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local repo = scriptDir:match("^(.*)[/\\][^/\\]*$") or "."
local folder = "NullgatesRestock-Forever"
local root = repo .. "/" .. folder .. "/"

local checks, failures = 0, 0
local function OK(cond, name)
    checks = checks + 1
    if not cond then failures = failures + 1; io.write("FAIL " .. name .. "\n") end
end

-- --- Stand-in game API ----------------------------------------------------------
local frames, printed = {}, {}
local function NewFrame(kind, name, parent, template)
    local f = { kind = kind, name = name, template = template, scripts = {}, events = {}, shown = false }
    setmetatable(f, { __index = function(_, key) if type(key) == "string" and key:match("^%u") then return function() return nil end end end })
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:GetScript(k) return self.scripts[k] end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetShown(v) self.shown = v and true or false end
    function f:IsShown() return self.shown end
    function f:SetText(t) self.text = t end
    function f:GetText() return self.text end
    function f:SetChecked(v) self.checked = v end
    function f:GetChecked() return self.checked end
    function f:CreateFontString() return NewFrame("FontString") end
    function f:CreateTexture() return NewFrame("Texture") end
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
CreateFrame = NewFrame
SlashCmdList = {}
UIParent = NewFrame("Frame", "UIParent")
MerchantFrame = NewFrame("Frame", "MerchantFrame")
UISpecialFrames = {}
YES, NO = "Yes", "No"
print = function(text) printed[#printed + 1] = tostring(text) end
local function Printed(fragment)
    for _, line in ipairs(printed) do if line:find(fragment, 1, true) then return true end end
    return false
end

-- Popups: remember what was shown; tests click the buttons.
StaticPopupDialogs = {}
local popups = {}
function StaticPopup_Show(name, text) popups[name] = { text = text and string.format(StaticPopupDialogs[name].text, text) or StaticPopupDialogs[name].text } end
function StaticPopup_Hide(name) popups[name] = nil end
local function Click(name, button)
    local d = StaticPopupDialogs[name]
    popups[name] = nil
    if button == 1 then d.OnAccept() elseif button == 3 then d.OnAlt() else d.OnCancel() end
end

-- Timers: After runs at once; tickers are driven by Tick().
local tickers = {}
C_Timer = {
    After = function(_, fn) fn() end,
    NewTicker = function(_, fn)
        local t = { fn = fn, cancelled = false }
        function t:Cancel() self.cancelled = true end
        tickers[#tickers + 1] = t
        return t
    end,
}
local function Tick()
    for _ = 1, 100 do
        local active = false
        for _, t in ipairs(tickers) do if not t.cancelled then active = true; t.fn() end end
        if not active then return end
    end
end

-- The player, bags, bank, money and a vendor.
local player = { class = "MAGE", level = 40 }
function UnitClass() return player.class, player.class end
function UnitLevel(unit) return unit == "player" and player.level or 0 end
function UnitExists(unit) return unit == "player" end
function GetBuildInfo() return "1.60.1", "70532", "Nov 2026", 16001 end
local bags, bank, money = {}, {}, 1000000
function GetMoney() return money end
C_Item = {
    GetItemCount = function(id, includeBank) return (bags[id] or 0) + (includeBank and (bank[id] or 0) or 0) end,
    GetItemInfo = function(id) return "Item" .. id end,
    GetItemIconByID = function(id) return "icon" .. id end,
    GetItemMaxStackSizeByID = function(id) return id == 17031 and 10 or 20 end,
}
local FEATHER, TELEPORT, PORTAL, ARROW = 17056, 17031, 17032, 11285
local vendor = {}
local function OpenVendor(items) vendor = items end
function GetMerchantNumItems() return #vendor end
function GetMerchantItemID(i) return vendor[i] and vendor[i].id end
function GetMerchantItemInfo(i)
    local v = vendor[i]
    return v.name, "tex", v.price, v.bundle, v.available or -1, true, true, nil
end
function GetMerchantItemMaxStack(i) return vendor[i].maxStack or 20 end
local buyCalls = {}
function BuyMerchantItem(i, quantity)
    local v = vendor[i]
    local n = quantity or v.bundle
    buyCalls[#buyCalls + 1] = { id = v.id, quantity = quantity }
    bags[v.id] = (bags[v.id] or 0) + n
    money = money - v.price * (quantity or 1)
end
local STOCK = {
    { id = FEATHER, name = "Light Feather", price = 30, bundle = 1, maxStack = 20 },
    { id = TELEPORT, name = "Rune of Teleportation", price = 1000, bundle = 1, maxStack = 10 },
    { id = PORTAL, name = "Rune of Portals", price = 2000, bundle = 1, maxStack = 10 },
    { id = ARROW, name = "Jagged Arrow", price = 1000, bundle = 200, maxStack = 1 },
}
local hooks = {}
function hooksecurefunc(name, fn) hooks[name] = fn end
function MerchantItemButton_OnModifiedClick() end
local alt = false
function IsAltKeyDown() return alt end
local cursor
function GetCursorInfo() if cursor then return "item", cursor end end
function ClearCursor() cursor = nil end

-- --- Load the files in .toc order -----------------------------------------------
local ns = {}
local toc = assert(io.open(root .. folder .. ".toc", "r")):read("*a")
for line in toc:gmatch("[^\r\n]+") do
    if not line:match("^##") and line:match("%.lua$") then
        assert(loadfile(root .. line:gsub("\\", "/")))(folder, ns)
    end
end
local core
for _, f in ipairs(frames) do if f.events.MERCHANT_SHOW then core = f end end
local function Fire(event, ...) core.scripts.OnEvent(core, event, ...) end
Fire("ADDON_LOADED", folder)
local db = NullgatesRestockDB
OK(type(db) == "table" and db.confirm == true and #db.items == 0, "saved data gets its defaults: asks first, empty list")
OK(SLASH_NULLGATESRESTOCK1 == "/nrestock" and SLASH_NULLGATESRESTOCK2 == "/restock", "slash commands /nrestock and /restock")

-- --- Login: the suggested list is offered once -----------------------------------------
Fire("PLAYER_LOGIN")
OK(popups.NULLGATES_RESTOCK_SUGGEST and popups.NULLGATES_RESTOCK_SUGGEST.text:find("3 items", 1, true), "a level 40 mage is offered 3 suggested items")
Click("NULLGATES_RESTOCK_SUGGEST", 1)
OK(#db.items == 3 and db.items[2].id == TELEPORT and db.items[2].keep == 10, "accepting adds them (10 teleport runes)")
OK(db.suggestedOffered, "and it won't be offered again")

-- --- A vendor: asks first, then buys ---------------------------------------------------
bags = { [FEATHER] = 5 }
OpenVendor(STOCK)
MerchantFrame.shown = true
Fire("MERCHANT_SHOW")
local ask = popups.NULLGATES_RESTOCK_CONFIRM
OK(ask and ask.text:find("15 x Light Feather", 1, true) and ask.text:find("10 x Rune of Teleportation", 1, true), "the popup lists what it will buy")
OK(ask and ask.text:find("Buy ", 1, true) == 1 and ask.text:find("for ", 1, true), "it asks before buying, with the cost")
OK(#buyCalls == 0, "nothing is bought before the player says yes")
Click("NULLGATES_RESTOCK_CONFIRM", 1)
Tick()
OK(bags[FEATHER] == 20 and bags[TELEPORT] == 10 and bags[PORTAL] == 10, "after yes: everything topped up")
OK(Printed("Bought 15 x Light Feather"), "a chat line says what was bought")
OK(money == 1000000 - 15 * 30 - 10 * 1000 - 10 * 2000, "the right amount was spent")

buyCalls = {}
Fire("MERCHANT_SHOW")
OK(not popups.NULLGATES_RESTOCK_CONFIRM and #buyCalls == 0, "fully stocked: no popup, nothing bought")

-- --- Saying no ---------------------------------------------------------------------------
bags = {}
Fire("MERCHANT_SHOW")
Click("NULLGATES_RESTOCK_CONFIRM", 2)
Tick()
OK(#buyCalls == 0, "Cancel buys nothing")

-- --- Buying without asking needs a limit ------------------------------------------------
OK(ns.Planner.SetConfirm(db, false) == false and db.confirm == true, "asking can't be turned off with no limit")
db.maxSpend = 15000 -- 1g 50s per visit
OK(ns.Planner.SetConfirm(db, false) and not ns.Planner.MustAsk(db), "with a maximum per visit it can")
money = 1000000
Fire("MERCHANT_SHOW")
OK(not popups.NULLGATES_RESTOCK_CONFIRM, "no confirmation popup")
Tick()
OK(bags[FEATHER] == 20 and bags[TELEPORT] == 10 and bags[PORTAL] == 2, "it buys what fits in 1g 50s, in list order (feathers, teleport runes, 2 portal runes)")
OK(1000000 - money <= 15000, "and never spends more than the limit")
local over = popups.NULLGATES_RESTOCK_OVER_LIMIT
OK(over and over.text:find("Rune of Portals", 1, true) and over.text:find("Buy anyway", 1, true), "then it asks about what's over the limit")
Click("NULLGATES_RESTOCK_OVER_LIMIT", 1)
Tick()
OK(bags[PORTAL] == 10, "and buys it when the player says yes")

-- With asking on and a limit: one popup, with Buy all for the extra.
db.confirm = true
bags = {}
Fire("MERCHANT_SHOW")
ask = popups.NULLGATES_RESTOCK_CONFIRM
OK(ask and ask.text:find("Over your spending limit", 1, true), "the popup also lists what's over the limit")
OK(StaticPopupDialogs.NULLGATES_RESTOCK_CONFIRM.button3 == "Buy all", "with a Buy all button")
Click("NULLGATES_RESTOCK_CONFIRM", 3)
Tick()
OK(bags[PORTAL] == 10 and bags[TELEPORT] == 10, "Buy all buys everything")

-- Clearing the limit turns asking back on.
db.confirm, db.maxSpend = false, 0
OK(ns.Planner.MustAsk(db), "no limit left: it asks again")

-- --- Bundles: one call per bundle -----------------------------------------------------------
ns.AddItem(ARROW, 600)
bags = { [FEATHER] = 20, [TELEPORT] = 10, [PORTAL] = 10, [ARROW] = 150 }
buyCalls = {}
Fire("MERCHANT_SHOW")
Click("NULLGATES_RESTOCK_CONFIRM", 1)
Tick()
OK(#buyCalls == 3 and buyCalls[1].quantity == nil and bags[ARROW] == 750, "450 arrows short: three bundle purchases of 200")

-- --- The vendor closing stops buying ----------------------------------------------------------
bags = { [FEATHER] = 20, [TELEPORT] = 10, [PORTAL] = 10, [ARROW] = 0 }
buyCalls = {}
Fire("MERCHANT_SHOW")
Click("NULLGATES_RESTOCK_CONFIRM", 1)
Fire("MERCHANT_CLOSED")
Tick()
OK(#buyCalls == 1, "closing the vendor after the first purchase stops the rest")

-- --- The bank counts when asked ---------------------------------------------------------------
bags, bank = { [FEATHER] = 20, [TELEPORT] = 10, [PORTAL] = 10 }, { [ARROW] = 600 }
db.countBank = true
Fire("MERCHANT_SHOW")
OK(not popups.NULLGATES_RESTOCK_CONFIRM, "600 arrows in the bank count when bank counting is on")
db.countBank = false

-- --- Paused ---------------------------------------------------------------------------------
SlashCmdList.NULLGATESRESTOCK("pause")
bags = {}
Fire("MERCHANT_SHOW")
OK(db.paused and not popups.NULLGATES_RESTOCK_CONFIRM, "paused: no purchases offered")
SlashCmdList.NULLGATESRESTOCK("pause")
OK(not db.paused, "pause again resumes")
Fire("MERCHANT_CLOSED")

-- --- Adding and removing items ----------------------------------------------------------------
SlashCmdList.NULLGATESRESTOCK("add |cffffffff|Hitem:17020::::::::40:::::|h[Arcane Powder]|h|r 40")
local _, powder = ns.FindItem(17020)
OK(powder and powder.keep == 40, "/nrestock add <link> 40")
SlashCmdList.NULLGATESRESTOCK("add 17030 5")
local _, ankh = ns.FindItem(17030)
OK(ankh and ankh.keep == 5, "/nrestock add <item ID> 5")
SlashCmdList.NULLGATESRESTOCK("add 17029")
local _, candle = ns.FindItem(17029)
OK(candle and candle.keep == 20, "no amount: one stack")
SlashCmdList.NULLGATESRESTOCK("remove 17030")
OK(not ns.FindItem(17030), "/nrestock remove")
SlashCmdList.NULLGATESRESTOCK("")
OK(NullgatesRestockWindow and NullgatesRestockWindow.shown, "/nrestock opens the shopping list")
cursor = 4599
NullgatesRestockWindow.scripts.OnReceiveDrag()
OK(ns.FindItem(4599) and not cursor, "dragging an item onto the list adds it")
alt = true
hooks.MerchantItemButton_OnModifiedClick({ GetID = function() return 4 end })
OK(ns.FindItem(ARROW), "Alt-click at a vendor adds the item")
OK(ns.Window.Step(10) == 1 and ns.Window.Step(1000) == 200, "the - and + steps grow with the amount")

-- --- Settings and /nrestock check ---------------------------------------------------------------
SlashCmdList.NULLGATESRESTOCK("config")
OK(NullgatesRestockOptions and NullgatesRestockOptions.shown, "/nrestock config opens the settings")
OpenVendor(STOCK)
SlashCmdList.NULLGATESRESTOCK("check")
do -- the report window every Nullgate addon shares
    local w = NullgateReportWindow
    OK(w and w.shown and w.url == "https://nullgatestudios.com/report?addon=restock", "check opens the shared report window with this addon's link")
    OK(w and w.text and w.text:find("Addon: restock\nNullgate's Restock - Forever ", 1, true) == 1, "the report starts with the addon's slug and name")
    OK(w and w.box.text == w.text and w.link.text == w.url, "the report and the link are in the window, ready to copy")
end
local log = table.concat(db.check or {}, "\n")
OK(log:find("BuyMerchantItem=yes", 1, true) and log:find("GetMerchantItemInfo=yes", 1, true), "check reports which calls exist")
OK(log:find("vendor 4: id 11285 Jagged Arrow, price 1000, bundle 200", 1, true), "check lists what the vendor sells")
OK(NullgatesRestockCheck and NullgatesRestockCheck.shown, "at a vendor the check window opens for the buy test")

io.write(string.format("smoke: %d checks, %d failure(s)\n", checks, failures))
if failures > 0 then os.exit(1) end
