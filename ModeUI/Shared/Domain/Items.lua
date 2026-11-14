local _, addon = ...

-- Items by ID (C_Item, C_Container): whether one exists, its name, icon and
-- count, its cooldown, whether it can be used now, and the items in your
-- bags that you can use (those with a "Use:" spell: potions, healthstones,
-- food, trinkets you carry). Every call is guarded and only public values
-- come back; the item APIs here aren't marked secret on mainline or on the
-- Forever branch. Names and icons can need the item's data loaded first
-- (RequestLoadItemDataByID; ITEM_DATA_LOAD_RESULT says when it has).
local Query, Public, Number = addon.Domain.Query, addon.IsPublic, addon.IsNumber
local Items = {}
addon.Domain.Items = Items
local Call = Query.Call

local GCD = 1.5 -- an item cooldown this short or shorter is the global cooldown

local function ID(itemID) return Number(itemID, 1, 99999999) and itemID == math.floor(itemID) end
local function API(group, name) return type(_G[group]) == "table" and _G[group][name] or nil end

-- Whether an item ID names an item at all.
function Items.Exists(itemID)
    if not ID(itemID) then return false end
    local ok, exists = Call(API("C_Item", "DoesItemExistByID"), itemID)
    return ok and Public(exists) and exists == true
end

-- Asks the client to load an item's name and icon (once is enough).
function Items.Load(itemID)
    if ID(itemID) then Call(API("C_Item", "RequestLoadItemDataByID"), itemID) end
end

function Items.Name(itemID)
    local ok, name = Call(API("C_Item", "GetItemNameByID"), itemID)
    if ok and Public(name) and type(name) == "string" and name ~= "" then return name end
end

function Items.Icon(itemID)
    local ok, icon = Call(API("C_Item", "GetItemIconByID"), itemID)
    if ok and Public(icon) and (type(icon) == "number" or type(icon) == "string") then return icon end
end

-- How many you carry (charges counted, the bank left out), or nil.
function Items.Count(itemID)
    local ok, count = Call(API("C_Item", "GetItemCount"), itemID, false, true)
    if ok and Number(count, 0) then return math.floor(count) end
end

-- The item's cooldown: start and duration (seconds) while one runs, and
-- whether it's a real cooldown (longer than the global cooldown); nil when
-- the client can't say.
function Items.Cooldown(itemID)
    local ok, start, duration, enable = Call(API("C_Container", "GetItemCooldown"), itemID)
    if not ok or not Number(start, 0) or not Number(duration, 0) then return nil end
    local running = duration > 0 and start > 0 and enable ~= 0 and enable ~= false
    return running and start or 0, running and duration or 0, running and duration > GCD
end

-- Whether it can be used now, and whether only power is short; nil when
-- the client won't say.
function Items.Usable(itemID)
    local ok, usable, noPower = Call(API("C_Item", "IsUsableItem"), itemID)
    if not ok or not Public(usable) then return nil end
    return usable == true, Public(noPower) and noPower == true
end

-- The spell an item casts when used (its "Use:"), or nil.
function Items.Spell(itemID)
    local ok, _, spellID = Call(API("C_Item", "GetItemSpell"), itemID)
    if ok and Number(spellID, 1) then return spellID end
end

-- The items in your held bags that you can use, each once, in bag order:
-- { id, icon, name }.
function Items.UsableInBags()
    local list, seen = {}, {}
    local Containers = addon.Domain.Containers
    for _, bag in ipairs(Containers.HeldBags()) do
        for slot = 1, Containers.NumSlots(bag) do
            local item = Containers.Item(bag, slot)
            local id = item and item.id
            if id and not seen[id] and ID(id) and Items.Spell(id) then
                seen[id] = true
                list[#list + 1] = { id = id, icon = item.icon or Items.Icon(id), name = item.name or Items.Name(id) }
            end
        end
    end
    return list
end
