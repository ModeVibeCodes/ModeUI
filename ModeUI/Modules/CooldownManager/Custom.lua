local _, addon = ...
local M = addon.CooldownManager
if not M then return end

-- Bars: Blizzard's four viewers, then your custom bars. A custom bar houses
-- spells you track in Blizzard's Cooldown Manager, taken out of their viewer:
-- Blizzard's own icon moves onto the custom bar, so it keeps updating as
-- before (a Cooldown Bar takes Essential and Utility spells, a Buff Bar
-- Tracked Buffs). A spell sits on at most one custom bar; deleting the bar
-- gives its spells back to their viewers. Saved as
--   db.customBars = { { id = "custom1", name = "Cooldown Bar 1", kind = "cooldown", entries = { "1234", ... } } }
-- with each bar's look in db[id], like a viewer's.
local L, Cooldowns = addon.L, addon.Domain.Cooldowns
local function Copy(value) return addon.ProfileCodec.Copy(value) end

function M:IsCustom(id) return type(id) == "string" and id:match("^custom%d+$") ~= nil end
function M:Custom(id)
    for index, bar in ipairs(self.db.customBars) do if bar.id == id then return bar, index end end
end
-- Every bar's ID, in list order.
function M:BarIds()
    local list = {}
    for _, viewer in ipairs(self.viewers) do list[#list + 1] = viewer end
    for _, bar in ipairs(self.db.customBars) do list[#list + 1] = bar.id end
    return list
end
function M:HasBar(id) return self.viewerSpecs[id] ~= nil or self:Custom(id) ~= nil end
function M:Label(id)
    if self.viewerSpecs[id] then return L[self.viewerSpecs[id].label] end
    local bar = self:Custom(id)
    return bar and bar.name or tostring(id)
end
function M:KindOf(id) local bar = self:Custom(id); return bar and bar.kind end
function M:Defaults(id)
    if self.styleDefaults[id] then return self.styleDefaults[id] end
    local kind = self:KindOf(id)
    return kind and self.customDefaults[kind]
end
function M:IsBar(id) return self.viewerSpecs[id] ~= nil and self.viewerSpecs[id].bar == true end
function M:IsBuff(id)
    if self.viewerSpecs[id] then return self.viewerSpecs[id].buff == true end
    return self:KindOf(id) == "buff"
end
-- The viewers a bar's icons come from.
function M:Sources(id)
    if self.viewerSpecs[id] then return { id } end
    local kind = self:KindOf(id)
    return kind and self.customKinds[kind].sources or {}
end
function M:Parts(id) return self:IsBar(id) and self.barParts or self.iconParts end
function M:SizeRange(id, key) return self.sizeRanges[self:IsBar(id) and "bar" or "icon"][key] end
function M:Glows(id) return self:IsBar(id) and {} or (self:IsBuff(id) and self.buffGlows or self.cooldownGlows) end

-- Which custom bar holds each spell (cooldown ID key), rebuilt on changes.
function M:RebuildAssignments()
    local assigned = {}
    for _, bar in ipairs(self.db.customBars) do
        for _, key in ipairs(bar.entries) do if not assigned[key] then assigned[key] = bar.id end end
    end
    self.assigned = assigned
end
local function Contains(list, value) for _, v in ipairs(list) do if v == value then return true end end return false end

-- The bar an item shows on: the custom bar holding its spell (when that bar
-- takes spells from the item's viewer), else its own viewer.
function M:Owner(item)
    local source = self.sourceOf[item]
    local key = source and self:SpellKey(item)
    local custom = key and self.assigned and self.assigned[key]
    if custom and Contains(self:Sources(custom), source) then return custom end
    return source
end
-- Custom bars that take spells from a viewer.
function M:CustomsFrom(viewer)
    local list = {}
    for _, bar in ipairs(self.db.customBars) do
        if Contains(self.customKinds[bar.kind].sources, viewer) then list[#list + 1] = bar.id end
    end
    return list
end

-- Changes to the bar list are checked by Initialize on a copy, then kept.
local function Commit(self, candidate)
    if not pcall(self.Initialize, candidate) then return false end
    local db = self.db
    for key in pairs(db) do db[key] = nil end
    for key, value in pairs(candidate) do db[key] = value end
    self:RebuildAssignments()
    self:SyncBarFrames()
    self:Refresh()
    if self.window then self:RefreshWindow() end
    return true
end

-- A new custom bar ("cooldown" or "buff"); returns its ID.
function M:AddCustomBar(kind)
    if not self:CanConfigure() or not self.customKinds[kind] or #self.db.customBars >= self.MAX_CUSTOM then return nil end
    local candidate = Copy(self.db)
    local id = "custom" .. candidate.nextCustom
    local count = 1
    for _, bar in ipairs(candidate.customBars) do if bar.kind == kind then count = count + 1 end end
    candidate.nextCustom = candidate.nextCustom + 1
    candidate.customBars[#candidate.customBars + 1] = { id = id, kind = kind, entries = {},
        name = string.format("%s %d", L[self.customKinds[kind].label], count) }
    candidate[id] = Copy(self.customDefaults[kind])
    return Commit(self, candidate) and id or nil
end

-- Deleting a bar gives its spells back to their viewers and forgets its place.
function M:DeleteCustomBar(id)
    local _, index = self:Custom(id)
    if not self:CanConfigure() or not index then return false end
    local candidate = Copy(self.db)
    table.remove(candidate.customBars, index)
    candidate[id] = nil
    if not Commit(self, candidate) then return false end
    local positions = addon.db and addon.db.positions
    if type(positions) == "table" then positions[self.ElementId(id)] = nil end
    return true
end

function M:RenameCustomBar(id, name)
    local _, index = self:Custom(id)
    if not self:CanConfigure() or not index or type(name) ~= "string" then return false end
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return false end
    local candidate = Copy(self.db)
    candidate.customBars[index].name = name
    if not Commit(self, candidate) then return false end
    -- Edit Mode's handle takes the new name.
    if self.built then addon.PositionManager:SetLabel(self.ElementId(id), name) end
    return true
end

-- Puts a spell on a custom bar (taking it off any other custom bar). Only a
-- spell the bar can take, tracked now (Candidates), is accepted.
function M:AddEntry(id, key)
    local _, index = self:Custom(id)
    if not self:CanConfigure() or not index or type(key) ~= "string" then return false end
    local takes = false
    for _, candidate in ipairs(self:Candidates(id)) do if candidate.key == key then takes = true end end
    if not takes then return false end
    local candidate = Copy(self.db)
    for _, bar in ipairs(candidate.customBars) do
        for i = #bar.entries, 1, -1 do if bar.entries[i] == key then table.remove(bar.entries, i) end end
    end
    local entries = candidate.customBars[index].entries
    entries[#entries + 1] = key
    return Commit(self, candidate)
end

function M:RemoveEntry(id, key)
    local _, index = self:Custom(id)
    if not self:CanConfigure() or not index then return false end
    local candidate = Copy(self.db)
    local entries = candidate.customBars[index].entries
    for i = #entries, 1, -1 do if entries[i] == key then table.remove(entries, i) end end
    candidate[id].spells[key] = nil
    return Commit(self, candidate)
end

-- Moves a spell earlier (-1) or later (+1) on its custom bar.
function M:MoveEntry(id, key, delta)
    local _, index = self:Custom(id)
    if not self:CanConfigure() or not index then return false end
    local candidate = Copy(self.db)
    local entries = candidate.customBars[index].entries
    for i, entry in ipairs(entries) do
        if entry == key then
            local j = i + delta
            if j < 1 or j > #entries then return false end
            entries[i], entries[j] = entries[j], entries[i]
            return Commit(self, candidate)
        end
    end
    return false
end

-- What a custom bar can take: every spell tracked now in its source viewers,
-- in Blizzard's order, with where it shows now. { key, icon, name, owner }.
function M:Candidates(id)
    local list, seen = {}, {}
    for _, viewer in ipairs(self:Sources(id)) do
        for _, item in ipairs(self:Items(viewer)) do
            local key = self:SpellKey(item)
            if key and not seen[key] then
                seen[key] = true
                local spell = Cooldowns.SpellID(tonumber(key))
                list[#list + 1] = { key = key, icon = spell and Cooldowns.SpellIcon(spell), name = self:SpellLabel(key),
                    owner = self.assigned and self.assigned[key] or viewer }
            end
        end
    end
    return list
end
