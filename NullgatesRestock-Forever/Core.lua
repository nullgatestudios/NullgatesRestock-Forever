-- Nullgate's Restock: saved data, the shopping list, events and slash commands.
local addonName, ns = ...

local L = ns.L

ns.DEFAULTS = {
    items = {},          -- { { id = itemID, keep = amount }, ... } in priority order
    confirm = true,      -- ask before every purchase (can only be off with a limit set)
    maxSpend = 0,        -- copper per vendor visit, 0 = no limit
    keepMoney = 0,       -- copper to always keep, 0 = no limit
    countBank = false,   -- count items in the bank (as of the last visit)
    summary = true,      -- chat line after buying
    paused = false,
    suggestedOffered = false,
    language = "auto",
}

local function Merge(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            if next(value) then Merge(target[key], value) end
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function ns.Print(text)
    print("|cff00c0ffRestock:|r " .. tostring(text))
end

-- --- The shopping list ---------------------------------------------------------------

local function Find(id)
    for i, entry in ipairs(ns.db.items) do
        if entry.id == id then return i, entry end
    end
end
ns.FindItem = Find

-- Adds an item (or changes its amount when it's already listed). Returns the entry.
function ns.AddItem(id, keep)
    local _, entry = Find(id)
    if entry then
        if keep then entry.keep = keep end
    else
        entry = { id = id, keep = keep or ns.Items.DefaultKeep(id) }
        table.insert(ns.db.items, entry)
    end
    if ns.Window then ns.Window.Refresh() end
    return entry
end

function ns.RemoveItem(id)
    local i = Find(id)
    if i then table.remove(ns.db.items, i) end
    if ns.Window then ns.Window.Refresh() end
end

-- The suggested list for this character right now.
function ns.SuggestedList()
    local _, class = UnitClass("player")
    local diets = GetPetFoodTypes and UnitExists("pet") and { GetPetFoodTypes() } or nil
    return ns.Planner.Suggested(class, UnitLevel("player"), ns.Items.RangedAmmoKind(), diets,
        UnitExists("pet") and UnitLevel("pet") or nil)
end

-- Adds every suggested item that isn't listed yet; returns how many were added.
function ns.AddSuggested()
    local added = 0
    for _, entry in ipairs(ns.SuggestedList()) do
        if not Find(entry.id) then
            ns.AddItem(entry.id, entry.keep)
            added = added + 1
        end
    end
    return added
end

-- Once per character: offer the suggested list when the shopping list is empty.
local function OfferSuggested()
    local db = ns.db
    if db.suggestedOffered or #db.items > 0 then return end
    local count = #ns.SuggestedList()
    if count == 0 then return end
    StaticPopupDialogs.NULLGATES_RESTOCK_SUGGEST = {
        text = L["Nullgate's Restock: add the suggested restock list for your class (%d items)? You can change it any time with /nrestock."],
        button1 = YES or L["Yes"],
        button2 = NO or L["No"],
        OnAccept = function()
            db.suggestedOffered = true
            ns.Print(string.format(L["Added %d items to your restock list."], ns.AddSuggested()))
        end,
        OnCancel = function() db.suggestedOffered = true end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopup_Show("NULLGATES_RESTOCK_SUGGEST", count)
end

-- --- Events -----------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            if type(NullgatesRestockDB) ~= "table" then NullgatesRestockDB = {} end
            Merge(NullgatesRestockDB, ns.DEFAULTS)
            ns.db = NullgatesRestockDB
            ns.Planner.Normalize(ns.db)
            ns.SetLanguage(ns.db.language)
            ns.Window.HookMerchant()
        end
        if arg1 == addonName or arg1 == "NullgatesAddonConfig-Forever" then ns.Options.RegisterHub() end
    elseif event == "PLAYER_LOGIN" then
        C_Timer.After(5, OfferSuggested)
    elseif event == "MERCHANT_SHOW" then
        C_Timer.After(0.3, function()
            if MerchantFrame and MerchantFrame.IsShown and not MerchantFrame:IsShown() then return end
            ns.Restock.OnMerchantShow()
        end)
    elseif event == "MERCHANT_CLOSED" then
        ns.Restock.OnMerchantClosed()
    elseif event == "BAG_UPDATE_DELAYED" then
        ns.Window.Refresh()
    end
end)
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "MERCHANT_SHOW", "MERCHANT_CLOSED", "BAG_UPDATE_DELAYED" }) do
    events:RegisterEvent(event)
end

-- --- Slash commands ---------------------------------------------------------------------

-- "<item link> 20" or "17031 20" -> itemID, 20 (the amount is optional).
function ns.ParseAdd(text)
    text = text or ""
    local id = ns.Items.IDFrom(text:match("item:%d+") or "")
    local after = text
    if id then
        after = text:gsub("|c%x+|H.-|h.-|h|r", ""):gsub("|H.-|h.-|h", ""):gsub("item:[%d:%-]+", "")
    else
        local first
        first, after = text:match("^%s*(%d+)%s*(.-)$")
        id = tonumber(first or "")
    end
    return id, tonumber((after or ""):match("^%s*(%d+)%s*$") or "")
end

local function Help()
    ns.Print(L["commands:"])
    print("  /nrestock - " .. L["open the shopping list"])
    print("  /nrestock add <" .. L["item link"] .. "> <" .. L["amount"] .. "> - " .. L["add an item to the list"])
    print("  /nrestock remove <" .. L["item link"] .. "> - " .. L["remove an item from the list"])
    print("  /nrestock suggest - " .. L["add the suggested items for your class"])
    print("  /nrestock pause - " .. L["stop or start offering purchases"])
    print("  /nrestock config - " .. L["open the settings"])
    print("  /nrestock check - " .. L["test what the addon needs in this client (results are saved)"])
end

SLASH_NULLGATESRESTOCK1 = "/nrestock"
SLASH_NULLGATESRESTOCK2 = "/restock"
SlashCmdList["NULLGATESRESTOCK"] = function(msg)
    msg = msg or ""
    local command, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
    command = string.lower(command or "")
    if command == "" or command == "list" then
        ns.Window.Toggle()
    elseif command == "add" then
        local id, amount = ns.ParseAdd(rest)
        if not id then
            ns.Print(L["Shift-click an item into the chat box after /nrestock add, then add the amount."])
            return
        end
        local entry = ns.AddItem(id, amount)
        ns.Print(string.format(L["Keeping %d x %s."], entry.keep, ns.Items.Name(id) or ("item " .. id)))
    elseif command == "remove" then
        local id = ns.Items.IDFrom(rest)
        if id then ns.RemoveItem(id) end
    elseif command == "suggest" then
        ns.Print(string.format(L["Added %d items to your restock list."], ns.AddSuggested()))
    elseif command == "pause" then
        ns.db.paused = not ns.db.paused
        ns.Print(ns.db.paused and L["Paused: no purchases will be offered."] or L["Resumed: purchases will be offered at vendors."])
    elseif command == "config" or command == "options" then
        ns.Options.Open()
    elseif command == "check" then
        ns.Check.Run()
    else
        Help()
    end
end
