-- Nullgate's Restock: settings. Options.Build(container) lays out every setting and is used both
-- by the addon's own window and by Nullgate's Addon Config when installed.
local addonName, ns = ...

local L = ns.L
local Options = {}
ns.Options = Options

local FULL_TITLE = "Nullgate's Restock - Forever"
local window
local refreshers = {}

local function RefreshAll()
    for _, fn in ipairs(refreshers) do fn() end
    ns.Window.Refresh()
end

local function Header(parent, text, y)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y)
    label:SetText(text)
    return y - 28
end

-- set returns false to refuse the change (the box goes back).
local function Check(parent, text, get, set, y)
    local box = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    box:SetSize(24, 24)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y)
    box:SetChecked(get())
    box:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        RefreshAll()
    end)
    refreshers[#refreshers + 1] = function() box:SetChecked(get()) end
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", box, "RIGHT", 4, 0)
    label:SetText(text)
    return y - 28
end

-- An amount of gold with - and + buttons (0 = no limit). Steps grow with the amount.
local function GoldStep(gold)
    if gold >= 1000 then return 100 end
    if gold >= 100 then return 10 end
    if gold >= 10 then return 5 end
    return 1
end
Options.GoldStep = GoldStep

local function GoldStepper(parent, text, key, y)
    local db = ns.db
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, y - 4)
    label:SetText(text)
    local value = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    value:SetPoint("TOPLEFT", parent, "TOPLEFT", 252, y - 4)
    value:SetWidth(60)
    local function Show()
        local gold = math.floor((db[key] or 0) / 10000)
        value:SetText(gold > 0 and (gold .. "g") or L["none"])
    end
    local function Change(up)
        local gold = math.floor((db[key] or 0) / 10000)
        gold = up and gold + GoldStep(gold) or math.max(0, gold - GoldStep(math.max(0, gold - 1)))
        db[key] = gold * 10000
        if not ns.Planner.HasLimit(db) and db.confirm == false then
            db.confirm = true
            ns.Print(L["No spending limit is set, so Restock asks before buying again."])
        end
        Show()
        RefreshAll()
    end
    local minus = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    minus:SetSize(24, 20)
    minus:SetPoint("TOPLEFT", parent, "TOPLEFT", 224, y)
    minus:SetText("-")
    minus:SetScript("OnClick", function() Change(false) end)
    local plus = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    plus:SetSize(24, 20)
    plus:SetPoint("TOPLEFT", parent, "TOPLEFT", 312, y)
    plus:SetText("+")
    plus:SetScript("OnClick", function() Change(true) end)
    refreshers[#refreshers + 1] = Show
    Show()
    return y - 28
end

local function Button(parent, text, x, y, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 150, 22)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function Note(parent, text, y)
    local note = parent:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, y)
    note:SetWidth(330)
    note:SetJustifyH("LEFT")
    note:SetText(text)
    return y - (note:GetStringHeight() or 24) - 8
end

-- Lays out every setting inside container; returns the height used.
function Options.Build(container)
    local db = ns.db
    local y = -12
    y = Header(container, L["Buying"], y)
    y = Check(container, L["Ask before buying"], function() return ns.Planner.MustAsk(db) end, function(v)
        if not ns.Planner.SetConfirm(db, v) then
            ns.Print(L["Set a maximum per visit or a minimum gold to keep first; then Restock can buy without asking."])
        end
    end, y)
    y = Note(container, L["To buy without asking, set at least one limit below."], y + 4)
    y = GoldStepper(container, L["Spend at most per visit"], "maxSpend", y)
    y = GoldStepper(container, L["Always keep at least"], "keepMoney", y)
    y = Check(container, L["Count items in my bank"], function() return db.countBank end, function(v) db.countBank = v end, y)
    y = Check(container, L["Show what was bought in chat"], function() return db.summary end, function(v) db.summary = v end, y)
    y = Check(container, L["Pause (offer no purchases)"], function() return db.paused end, function(v) db.paused = v end, y)
    y = y - 4

    y = Header(container, L["Shopping list"], y)
    Button(container, L["Open shopping list"], 16, y, 160, function() ns.Window.Show() end)
    Button(container, L["Add suggested items"], 186, y, 160, function()
        ns.Print(string.format(L["Added %d items to your restock list."], ns.AddSuggested()))
    end)
    y = y - 36

    y = Header(container, L["Language"], y)
    local function LanguageName()
        if db.language == "auto" then return L["Automatic (game language)"] end
        for _, entry in ipairs(ns.LANGUAGES) do
            if entry.code == db.language then return entry.name end
        end
        return db.language
    end
    local picker = Button(container, LanguageName(), 16, y, 230, nil)
    picker:SetScript("OnClick", function(self)
        local nextCode = ns.LANGUAGES[1].code
        if db.language ~= "auto" then
            nextCode = "auto"
            for i, entry in ipairs(ns.LANGUAGES) do
                if entry.code == db.language and ns.LANGUAGES[i + 1] then nextCode = ns.LANGUAGES[i + 1].code end
            end
        end
        db.language = nextCode
        self:SetText(LanguageName())
        ns.Print(L["The language changes after you type /reload."])
    end)
    y = y - 32
    y = Note(container, L["Commands: /nrestock (shopping list), /nrestock add, /nrestock suggest, /nrestock pause, /nrestock check."], y - 4)
    return -y + 16
end

local function OwnWindow()
    if not window then
        window = CreateFrame("Frame", "NullgatesRestockOptions", UIParent, "BasicFrameTemplateWithInset")
        window:SetSize(380, 520)
        window:SetPoint("CENTER")
        window:SetMovable(true)
        window:EnableMouse(true)
        window:SetClampedToScreen(true)
        window:RegisterForDrag("LeftButton")
        window:SetScript("OnDragStart", window.StartMoving)
        window:SetScript("OnDragStop", window.StopMovingOrSizing)
        if type(window.SetTitle) == "function" then window:SetTitle(FULL_TITLE)
        elseif type(window.TitleText) == "table" then window.TitleText:SetText(FULL_TITLE) end
        local content = CreateFrame("Frame", nil, window)
        content:SetPoint("TOPLEFT", window, "TOPLEFT", 4, -26)
        content:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -4, 4)
        window:SetHeight(Options.Build(content) + 30)
        if UISpecialFrames then table.insert(UISpecialFrames, "NullgatesRestockOptions") end
    end
    RefreshAll()
    window:Show()
end

-- Opens the settings inside Nullgate's Addon Config when it's installed, otherwise in our own window.
function Options.Open(standalone)
    local hub = NullgatesAddonConfigForever
    if not standalone and hub and hub.ShowUI and hub.SelectModule and Options.registered then
        hub:ShowUI()
        hub:SelectModule(addonName)
    else
        OwnWindow()
    end
end

function Options.RegisterHub()
    local hub = NullgatesAddonConfigForever
    if Options.registered or not (hub and hub.RegisterModule and ns.db) then return end
    hub:RegisterModule(addonName, {
        name = FULL_TITLE,
        sidebarName = "Restock",
        author = "Nullgate Studios",
        isNullgate = true,
        description = L["Keep reagents, ammo and supplies topped up at vendors."],
        db = ns.db,
        buildUI = function(container) Options.Build(container) end,
    })
    Options.registered = true
end
