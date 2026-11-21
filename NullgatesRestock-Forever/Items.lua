-- Nullgate's Restock: item helpers (the only file that reads item info or bag counts).
local _, ns = ...

local Items = {}
ns.Items = Items

-- How many the player has: bags, plus the bank (as of the last bank visit) when countBank is on.
function Items.Count(itemID)
    local count = (C_Item and C_Item.GetItemCount) or GetItemCount
    if not count then return 0 end
    return count(itemID, ns.db and ns.db.countBank or false) or 0
end

function Items.Name(itemID)
    local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    return info and (info(itemID)) or nil
end

function Items.Icon(itemID)
    local icon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
    return icon and icon(itemID) or nil
end

-- A sensible amount to keep for a newly added item: one stack, at most 20.
function Items.DefaultKeep(itemID)
    local stack = C_Item and C_Item.GetItemMaxStackSizeByID and C_Item.GetItemMaxStackSizeByID(itemID)
    if not stack then
        local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
        stack = info and select(8, info(itemID))
    end
    return math.max(1, math.min(tonumber(stack) or 20, 20))
end

-- The item ID in an item link or "item:123" string, or a plain number.
function Items.IDFrom(text)
    if type(text) == "number" then return text end
    local id = tostring(text or ""):match("item:(%d+)") or tostring(text or ""):match("^%s*(%d+)%s*$")
    return id and tonumber(id) or nil
end

-- "arrow", "bullet" or nil for the ranged weapon the player has equipped.
function Items.RangedAmmoKind()
    local id = GetInventoryItemID and GetInventoryItemID("player", 18)
    if not id then return nil end
    local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not instant then return nil end
    local _, _, _, _, _, classID, subclassID = instant(id)
    if classID ~= 2 then return nil end
    if subclassID == 2 or subclassID == 18 then return "arrow" end -- bows, crossbows
    if subclassID == 3 then return "bullet" end                    -- guns
    return nil
end
