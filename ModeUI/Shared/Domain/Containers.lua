local _, addon = ...

-- The player's bags (C_Container): which bags exist, their slots and what
-- each slot holds. Every call is guarded: a missing API or a failed call is
-- "unknown", and only public values are returned. Bag IDs: 0 is the
-- backpack, 1-4 the equipped bags, 5 the reagent bag (when the client has
-- one) and -2 the keyring (Forever shows it when C_ActionBar.ShouldShowKeyring
-- says so). See docs/BAGS.md and docs/API_COMPATIBILITY.md.
local Query, Public = addon.Domain.Query, addon.IsPublic
local Containers = {}
addon.Domain.Containers = Containers

Containers.BACKPACK, Containers.KEYRING = 0, -2

local function Count(value) return Public(value) and type(value) == "number" and value == value and value >= 0 and math.floor(value) or 0 end
local function Constant(group, key, fallback)
    local value = type(Constants) == "table" and type(Constants[group]) == "table" and Constants[group][key]
    return Public(value) and type(value) == "number" and value or fallback
end

-- Equipped bags (1-4) and reagent bags (5) the client has.
function Containers.BagCount() return Constant("InventoryConstants", "NumBagSlots", 4) end
function Containers.ReagentCount() return Constant("InventoryConstants", "NumReagentBagSlots", 0) end
function Containers.IsReagent(bag) return bag > Containers.BagCount() and bag <= Containers.BagCount() + Containers.ReagentCount() end

-- The keyring, when the game shows one.
function Containers.HasKeyring()
    return type(C_ActionBar) == "table" and Query.Truthy(C_ActionBar.ShouldShowKeyring) or false
end

-- The held bags in order: the backpack, the equipped bags, then reagent
-- bags. The keyring is asked for separately (it has its own section).
function Containers.HeldBags()
    local list = {}
    for bag = 0, Containers.BagCount() + Containers.ReagentCount() do list[#list + 1] = bag end
    return list
end

-- Whether a bag ID belongs to the player's held bags (or the keyring).
function Containers.IsHeld(bag)
    if not (Public(bag) and type(bag) == "number") then return false end
    if bag == Containers.KEYRING then return true end
    return bag >= 0 and bag <= Containers.BagCount() + Containers.ReagentCount() and bag == math.floor(bag)
end

local function API(name) return type(C_Container) == "table" and C_Container[name] or nil end

function Containers.NumSlots(bag)
    if bag == Containers.KEYRING then
        local ok, size = Query.Call(GetKeyRingSize)
        return ok and Count(size) or 0
    end
    local ok, size = Query.Call(API("GetContainerNumSlots"), bag)
    return ok and Count(size) or 0
end

function Containers.FreeSlots(bag)
    local ok, free = Query.Call(API("GetContainerNumFreeSlots"), bag)
    return ok and Count(free) or 0
end

-- What a slot holds, or nil when it's empty: { icon, count, quality,
-- locked, link, id, name, filtered, noValue, readable, bound }. Fields the
-- game keeps secret stay nil.
local FIELDS = { iconFileID = "icon", stackCount = "count", quality = "quality", isLocked = "locked", hyperlink = "link",
    itemID = "id", itemName = "name", isFiltered = "filtered", hasNoValue = "noValue", isReadable = "readable", isBound = "bound" }
function Containers.Item(bag, slot)
    local ok, info = Query.Call(API("GetContainerItemInfo"), bag, slot)
    if not ok or not Public(info) or type(info) ~= "table" then return nil end
    local item = {}
    for key, name in pairs(FIELDS) do
        local value = info[key]
        if Public(value) then item[name] = value end
    end
    if item.icon == nil and item.id == nil then return nil end
    item.count = Count(item.count)
    return item
end

-- A quest item: isQuestItem, questID, isActive (from the game's quest info).
function Containers.Quest(bag, slot)
    local ok, info = Query.Call(API("GetContainerItemQuestInfo"), bag, slot)
    if not ok or not Public(info) or type(info) ~= "table" then return false, nil, false end
    local questItem, questID, active = info.isQuestItem, info.questID, info.isActive
    return Public(questItem) and questItem == true, Public(questID) and questID or nil, Public(active) and active == true
end

function Containers.IsNew(bag, slot)
    return type(C_NewItems) == "table" and Query.Truthy(C_NewItems.IsNewItem, bag, slot) or false
end

-- start, duration, enabled of the slot's cooldown, all public, or nil.
function Containers.Cooldown(bag, slot)
    local start, duration, enabled = Query.Plain(API("GetContainerItemCooldown"), bag, slot)
    if type(start) ~= "number" or type(duration) ~= "number" then return nil end
    return start, duration, enabled == 1 or enabled == true
end

-- The item's class and subclass IDs (instant, from the client's item data).
function Containers.ItemClass(link)
    if type(link) ~= "string" or type(C_Item) ~= "table" then return nil end
    local _, _, _, equipLoc, _, classID, subClassID = Query.Read(C_Item.GetItemInfoInstant, link)
    return classID, subClassID, equipLoc
end

-- The item level of equipment (weapons and armor), or nil until the game
-- has the item's data (GET_ITEM_INFO_RECEIVED follows).
Containers.WEAPON, Containers.ARMOR = 2, 4
function Containers.ItemLevel(link)
    local classID, _, equipLoc = Containers.ItemClass(link)
    if classID ~= Containers.WEAPON and classID ~= Containers.ARMOR then return nil end
    if equipLoc == "INVTYPE_NON_EQUIP_IGNORE" or equipLoc == "" then return nil end
    local level = Query.Read(C_Item.GetDetailedItemLevelInfo, link)
    return type(level) == "number" and level > 0 and math.floor(level) or nil
end

function Containers.QualityColor(quality)
    if type(quality) ~= "number" or type(C_Item) ~= "table" then return nil end
    local r, g, b = Query.Read(C_Item.GetItemQualityColor, quality)
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return nil end
    return { r, g, b }
end

function Containers.Money()
    local ok, money = Query.Call(GetMoney)
    return ok and Count(money) or 0
end

-- The game's own bag search (the same one Blizzard's bag search box sets):
-- slots that don't match come back with isFiltered, and
-- INVENTORY_SEARCH_UPDATE fires. False when the client has none.
function Containers.SetSearch(text)
    local fn = API("SetItemSearch")
    if type(fn) ~= "function" then return false end
    return (pcall(fn, type(text) == "string" and text or ""))
end
function Containers.HasSearch() return type(API("SetItemSearch")) == "function" end

-- Blizzard's Clean Up Bags: the game sorts the items in the bags.
function Containers.CleanUp()
    local fn = API("SortBags")
    if type(fn) ~= "function" then return false end
    return (pcall(fn))
end
function Containers.CanCleanUp() return type(API("SortBags")) == "function" end
