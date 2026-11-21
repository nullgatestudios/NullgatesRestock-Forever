-- Nullgate's Restock: the shopping list window. Drag an item onto it, or Alt-click an item in a
-- vendor's window, to add it; - and + change the amount to keep; ^ moves an item up (items
-- higher on the list are bought first when a spending limit is reached).
local _, ns = ...

local L = ns.L
local Window = {}
ns.Window = Window

local ROWS, ROW_HEIGHT = 10, 26
local frame, rows, offset = nil, {}, 0

-- The step for - and +: small amounts by 1, larger ones in bigger jumps.
function Window.Step(keep)
    if keep >= 1000 then return 200 end
    if keep >= 100 then return 50 end
    if keep >= 20 then return 5 end
    return 1
end

local function AddFromCursor()
    local kind, id = GetCursorInfo()
    if kind == "item" and id then
        ClearCursor()
        local entry = ns.AddItem(id)
        ns.Print(string.format(L["Keeping %d x %s."], entry.keep, ns.Items.Name(id) or ("item " .. id)))
    end
end

local function SmallButton(parent, text, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 22, 20)
    b:SetText(text)
    return b
end

local function CreateRow(i)
    local row = CreateFrame("Frame", nil, frame)
    row:SetSize(360, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -56 - (i - 1) * ROW_HEIGHT)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetWidth(150)
    row.name:SetJustifyH("LEFT")
    row.count = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.count:SetPoint("LEFT", row, "LEFT", 184, 0)
    row.count:SetWidth(70)
    row.count:SetJustifyH("RIGHT")
    row.minus = SmallButton(row, "-")
    row.minus:SetPoint("LEFT", row, "LEFT", 260, 0)
    row.plus = SmallButton(row, "+")
    row.plus:SetPoint("LEFT", row.minus, "RIGHT", 2, 0)
    row.up = SmallButton(row, "^")
    row.up:SetPoint("LEFT", row.plus, "RIGHT", 6, 0)
    row.remove = SmallButton(row, "x")
    row.remove:SetPoint("LEFT", row.up, "RIGHT", 2, 0)
    row.minus:SetScript("OnClick", function()
        local e = row.entry
        if e then e.keep = math.max(1, e.keep - Window.Step(e.keep - 1)); Window.Refresh() end
    end)
    row.plus:SetScript("OnClick", function()
        local e = row.entry
        if e then e.keep = e.keep + Window.Step(e.keep); Window.Refresh() end
    end)
    row.up:SetScript("OnClick", function()
        local i2 = row.entry and ns.FindItem(row.entry.id)
        if i2 and i2 > 1 then
            local items = ns.db.items
            items[i2], items[i2 - 1] = items[i2 - 1], items[i2]
            Window.Refresh()
        end
    end)
    row.remove:SetScript("OnClick", function() if row.entry then ns.RemoveItem(row.entry.id) end end)
    return row
end

local function Build()
    frame = CreateFrame("Frame", "NullgatesRestockWindow", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(400, 56 + ROWS * ROW_HEIGHT + 70)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetScript("OnReceiveDrag", AddFromCursor)
    frame:SetScript("OnMouseUp", AddFromCursor)
    frame:SetScript("OnMouseWheel", function(_, delta)
        offset = math.max(0, math.min(offset - delta, math.max(0, #ns.db.items - ROWS)))
        Window.Refresh()
    end)
    local title = L["Restock: shopping list"]
    if type(frame.SetTitle) == "function" then frame:SetTitle(title)
    elseif type(frame.TitleText) == "table" then frame.TitleText:SetText(title) end
    if UISpecialFrames then table.insert(UISpecialFrames, "NullgatesRestockWindow") end

    local hint = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -32)
    hint:SetWidth(372)
    hint:SetJustifyH("LEFT")
    hint:SetText(L["Drag an item here, or Alt-click it in a vendor's window, to add it. Higher items are bought first."])
    frame.empty = frame:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    frame.empty:SetPoint("TOP", frame, "TOP", 0, -100)
    frame.empty:SetText(L["Your list is empty."])

    for i = 1, ROWS do rows[i] = CreateRow(i) end

    frame.status = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    frame.status:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 40)
    frame.status:SetWidth(372)
    frame.status:SetJustifyH("LEFT")
    local suggest = SmallButton(frame, L["Add suggested items"], 170)
    suggest:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
    suggest:SetScript("OnClick", function()
        ns.Print(string.format(L["Added %d items to your restock list."], ns.AddSuggested()))
    end)
    local settings = SmallButton(frame, L["Settings"], 120)
    settings:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    settings:SetScript("OnClick", function() ns.Options.Open() end)
end

function Window.Refresh()
    if not (frame and frame:IsShown()) then return end
    local items = ns.db.items
    offset = math.max(0, math.min(offset, math.max(0, #items - ROWS)))
    for i, row in ipairs(rows) do
        local entry = items[i + offset]
        row.entry = entry
        if entry then
            local have = ns.Items.Count(entry.id)
            row.icon:SetTexture(ns.Items.Icon(entry.id))
            row.name:SetText(ns.Items.Name(entry.id) or ("item " .. entry.id))
            row.count:SetText(string.format("%s%d|r / %d", have >= entry.keep and "|cff40ff40" or "|cffff6060", have, entry.keep))
            row:Show()
        else
            row:Hide()
        end
    end
    frame.empty:SetShown(#items == 0)
    local db = ns.db
    local parts = {}
    parts[#parts + 1] = ns.Planner.MustAsk(db) and L["Asks before buying."] or L["Buys without asking."]
    if (db.maxSpend or 0) > 0 then parts[#parts + 1] = string.format(L["At most %s per visit."], ns.Planner.Money(db.maxSpend)) end
    if (db.keepMoney or 0) > 0 then parts[#parts + 1] = string.format(L["Keeps at least %s."], ns.Planner.Money(db.keepMoney)) end
    if db.paused then parts[#parts + 1] = L["Paused."] end
    frame.status:SetText(table.concat(parts, " "))
end

function Window.Show()
    if not frame then Build() end
    frame:Show()
    Window.Refresh()
end

function Window.Toggle()
    if frame and frame:IsShown() then frame:Hide() else Window.Show() end
end

-- Alt-click an item in a vendor's window to add it to the list.
function Window.HookMerchant()
    if Window.hooked or not (hooksecurefunc and MerchantItemButton_OnModifiedClick) then return end
    hooksecurefunc("MerchantItemButton_OnModifiedClick", function(self)
        if not IsAltKeyDown() then return end
        local id = GetMerchantItemID(self:GetID())
        if id then
            local entry = ns.AddItem(id)
            ns.Print(string.format(L["Keeping %d x %s."], entry.keep, ns.Items.Name(id) or ("item " .. id)))
        end
    end)
    Window.hooked = true
end
