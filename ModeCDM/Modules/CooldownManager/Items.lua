local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M then return end

-- Items on custom Cooldown Bars: potions, healthstones, food, anything with
-- a "Use:". Saved in the bar's spells as "i<item ID>" beside the cooldown
-- IDs and custom spells, on an icon of ModeUI's own (Spells.lua makes it):
-- the item's picture, its cooldown (C_Container.GetItemCooldown, public
-- numbers, to Cooldown:SetCooldown) and how many you carry. With none left
-- it stays, gray, showing 0, so the bar keeps its shape. Gray while cooling
-- and the off-cooldown glow work as on spells; procs, active and buff glows
-- don't apply to items.
local L, Items = addon.L, addon.Domain.Items
local NOT_USABLE, NO_POWER = { 0.4, 0.4, 0.4 }, { 0.5, 0.5, 1 }
local function Copy(value) return addon.ProfileCodec.Copy(value) end

function M.IsItemEntry(key) return type(key) == "string" and key:match("^i%d+$") ~= nil end
-- Entries on ModeUI's own icons: custom spells and items.
function M.IsOwnEntry(key) return M.IsSpellEntry(key) or M.IsItemEntry(key) end
function M.ItemOf(key) return M.IsItemEntry(key) and tonumber(key:sub(2)) or nil end

-- Adds an item by its ID (a number, or text as typed) to a custom Cooldown
-- Bar, Essential or Utility. Returns true and the item ID, or false and why.
function M:AddCustomItem(id, text)
    if not self:TakesOwn(id) or not self:TakesEntries(id) then return false, L["Items go on Cooldown Bars, Essential and Utility."] end
    if not self:CanConfigure() then return false, L["Not in combat."] end
    local itemID = type(text) == "number" and text or tonumber(type(text) == "string" and text:match("^%s*(%d+)%s*$") or nil)
    if not itemID or not Items.Exists(itemID) then return false, L["No item has that ID."] end
    if not Items.Spell(itemID) then return false, L["That item has no Use: effect."] end
    local key = "i" .. itemID
    local list = self:Entries(id)
    for _, entry in ipairs(list) do if entry == key then return false, L["That item is on this bar already."] end end
    if #list >= self.MAX_ENTRIES then return false, L["This bar is full."] end
    local candidate = Copy(self.db)
    local entries = self.EntriesIn(candidate, id)
    entries[#entries + 1] = key
    if not self.CommitBars(self, candidate) then return false, L["That item can't be added."] end
    Items.Load(itemID)
    return true, itemID
end

-- Whether an entry is on a real cooldown now: true, false or nil (unknown).
function M:EntryCooling(key)
    local item = self.ItemOf(key)
    if item then
        local _, _, cooling = Items.Cooldown(item)
        return cooling
    end
    return addon.Domain.Cooldowns.Cooling(self:CooldownSpell(key))
end

-- An entry's picture: an item's, else its spell's.
function M:EntryIcon(key)
    local item = self.ItemOf(key)
    if item then return Items.Icon(item) end
    local spell = self:CooldownSpell(key)
    return spell and addon.Domain.Cooldowns.SpellIcon(spell)
end

-- The item's name, else its ID.
function M:ItemLabel(key)
    local item = self.ItemOf(key)
    return Items.Name(item) or string.format(L["Item %s"], tostring(item))
end

-- Brings an item's icon up to date: picture, cooldown, count, the usable
-- tint and the gray.
function M:UpdateItemIcon(icon, style)
    local item = self.ItemOf(self.iconKey[icon])
    icon.Icon:SetTexture(Items.Icon(item) or 134400)
    local start, duration, cooling = Items.Cooldown(item)
    local cooldown = icon.Cooldown
    if start and cooldown.SetCooldown then
        if duration > 0 then cooldown:SetCooldown(start, duration)
        elseif cooldown.Clear then cooldown:Clear() end
    end
    local count = Items.Count(item)
    icon.ChargeCount.Current:SetText(count and string.format("%d", count) or "")
    local usable, noPower = Items.Usable(item)
    local tint = (usable == false and count ~= 0) and (noPower and NO_POWER or NOT_USABLE) or nil
    icon.Icon:SetVertexColor(tint and tint[1] or 1, tint and tint[2] or 1, tint and tint[3] or 1, 1)
    icon.Icon:SetDesaturated(count == 0 or (style.desaturate and cooling == true))
end

-- The usable items in your bags not yet on this bar, for the + slot's list.
function M:ItemCandidates(id)
    if not self:TakesOwn(id) or not self:TakesEntries(id) then return {} end
    local here, list = {}, {}
    for _, key in ipairs(self:Entries(id)) do here[key] = true end
    for _, item in ipairs(Items.UsableInBags()) do
        local key = "i" .. item.id
        if not here[key] then list[#list + 1] = { key = key, id = item.id, icon = item.icon, name = item.name or self:ItemLabel(key) } end
    end
    return list
end
