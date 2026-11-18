local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M then return end

-- Bars: Blizzard's four viewers, then your custom bars. A custom bar houses
-- spells you track in Blizzard's Cooldown Manager, taken out of their viewer
-- (a Cooldown Bar also takes any spell by its ID, on an icon of ModeUI's own:
-- Spells.lua):
-- Blizzard's own icon moves onto the custom bar, so it keeps updating as
-- before (a Cooldown Bar takes Essential and Utility spells, a Buff Bar
-- Tracked Buffs). A spell sits on at most one custom bar; deleting the bar
-- gives its spells back to their viewers. Saved as
--   db.customBars = { { id = "custom1", name = "Cooldown Bar 1", kind = "cooldown", entries = { "1234", ... } } }
-- with each bar's look in db[id], like a viewer's.
-- Essential and Utility take spells the same way (owner, November 14,
-- 2026): from each other or a custom bar, by Spell ID, or items, saved as
--   db.extras = { essential = { "s1234", "i5512", "201" }, utility = {} }
-- after Blizzard's own spells. A viewer's own spell can't leave it
-- (Blizzard's Cooldown Manager decides what it tracks): removing one hides
-- it there.
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
-- A bar's defaults: a viewer's, a default bar's own (Presets.lua) or its kind's.
function M:Defaults(id)
    if self.styleDefaults[id] then return self.styleDefaults[id] end
    local bar = self:Custom(id)
    return bar and self.BarDefaults(bar)
end
function M:IsBar(id) return self.viewerSpecs[id] ~= nil and self.viewerSpecs[id].bar == true end
function M:IsBuff(id)
    if self.viewerSpecs[id] then return self.viewerSpecs[id].buff == true end
    return self:KindOf(id) == "buff"
end
-- The viewers a bar's icons come from: its own first.
function M:Sources(id)
    if self.entryViewers[id] then return self.entryViewers[id] end
    if self.viewerSpecs[id] then return { id } end
    local kind = self:KindOf(id)
    return kind and self.customKinds[kind].sources or {}
end
function M:Parts(id) return self:IsBar(id) and self.barParts or self.iconParts end
function M:SizeRange(id, key) return self.sizeRanges[self:IsBar(id) and "bar" or "icon"][key] end
function M:Glows(id) return self:IsBar(id) and {} or (self:IsBuff(id) and self.buffGlows or self.cooldownGlows) end

-- A bar's own list of spells in `db`: a custom bar's entries, or what
-- Essential or Utility took (db.extras). Nil for the other viewers.
function M.EntriesIn(db, id)
    if M.entryViewers[id] then return db.extras[id] end
    for _, bar in ipairs(db.customBars) do if bar.id == id then return bar.entries end end
end
local NONE = {} -- read only
-- A bar's list as it shows: on the racials' bar, your racials follow it
-- (Racials.lua). Read only.
function M:Entries(id)
    local stored = self.EntriesIn(self.db, id)
    if not stored then return NONE end
    if self.db.racials == id then return self:WithRacials(id, stored) end
    return stored
end
-- Whether the + slot adds spells to a bar, and whether spells by ID and
-- items too (Cooldown Bars, Essential and Utility).
function M:TakesEntries(id) return self.EntriesIn(self.db, id) ~= nil end
function M:TakesOwn(id) return self.entryViewers[id] ~= nil or self:KindOf(id) == "cooldown" end

-- Which bar took each spell (cooldown ID key), rebuilt on changes.
function M:RebuildAssignments()
    local assigned = {}
    for _, bar in ipairs(self.db.customBars) do
        for _, key in ipairs(bar.entries) do if not assigned[key] then assigned[key] = bar.id end end
    end
    for _, viewer in ipairs(self.viewers) do
        for _, key in ipairs(self.entryViewers[viewer] and self.db.extras[viewer] or NONE) do
            if not assigned[key] then assigned[key] = viewer end
        end
    end
    self.assigned = assigned
end
local function Contains(list, value) for _, v in ipairs(list) do if v == value then return true end end return false end

-- The bar an item shows on: the custom bar holding its spell (when that bar
-- takes spells from the item's viewer), else its own viewer.
function M:Owner(item)
    if self.iconBar[item] then return self.iconBar[item] end
    local source = self.sourceOf[item]
    local key = source and self:SpellKey(item)
    local custom = key and self.assigned and self.assigned[key]
    if custom and Contains(self:Sources(custom), source) then return custom end
    return source
end
-- The other bars that take spells from a viewer: Essential or Utility
-- while it holds spells of its own, and custom bars.
function M:CustomsFrom(viewer)
    local list = {}
    for _, other in ipairs(self.viewers) do
        local sources = self.entryViewers[other]
        if other ~= viewer and sources and Contains(sources, viewer) and #self:Entries(other) > 0 then list[#list + 1] = other end
    end
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
    self:SyncSpellIcons()
    self:Refresh()
    if self.window then self:RefreshWindow() end
    return true
end

M.CommitBars = Commit

-- Version 4: bars still in version 3's default places (4 units off what
-- they hang from: Utility, Tracked Buffs, the resource bars) sit right
-- against it; the 1px gap comes from the placement itself now.
function M:MovePlaces()
    local positions = addon.db and addon.db.positions
    if type(positions) ~= "table" then return end
    local olds = { [self.ElementId("utility")] = { self.ElementId("essential"), -4 }, [self.ElementId("buffIcon")] = { self.ElementId("essential"), 4 } }
    for id, place in pairs(self.resourcePositions or {}) do olds[self.ResourceElementId(id)] = { place.target, -4 } end
    for eid, old in pairs(olds) do
        local place = positions[eid]
        if type(place) == "table" and place.target == old[1] and place.x == 0 and place.y == old[2] and place.point == nil then place.y = 0 end
    end
end

-- Custom bars as anchor targets: each saved one at start, a new one when
-- added; every element of this module may pick it.
function M:AddBarTargets()
    for _, bar in ipairs(self.db.customBars) do addon.Positioning:AddTarget(self.ElementId(bar.id), bar.name, self.FrameName(bar.id)) end
end
function M:AllowBarTarget(id)
    local PM = addon.PositionManager
    for eid, element in pairs(PM.elements) do
        if element.module == self and eid ~= self.ElementId(id) then PM:AllowTarget(eid, self.ElementId(id)) end
    end
end

-- A new custom bar ("cooldown" or "buff"); returns its ID.
function M:AddCustomBar(kind)
    if not self:CanConfigure() or not self.customKinds[kind] or #self.db.customBars >= self.MAX_CUSTOM then return nil end
    local candidate = Copy(self.db)
    local id = "custom" .. candidate.nextCustom
    local count = 1
    -- Numbered among your own bars: the default bars have names of their own.
    for _, bar in ipairs(candidate.customBars) do if bar.kind == kind and not bar.preset then count = count + 1 end end
    candidate.nextCustom = candidate.nextCustom + 1
    candidate.customBars[#candidate.customBars + 1] = { id = id, kind = kind, entries = {},
        name = string.format("%s %d", L[self.customKinds[kind].label], count) }
    candidate[id] = Copy(self.customDefaults[kind])
    -- Other bars can anchor to it, like to the viewers.
    local name = candidate.customBars[#candidate.customBars].name
    addon.Positioning:AddTarget(self.ElementId(id), name, self.FrameName(id))
    if not Commit(self, candidate) then addon.Positioning:RemoveTarget(self.ElementId(id)); return nil end
    self:AllowBarTarget(id)
    return id
end

-- Deleting a bar gives its spells back to their viewers and forgets its place.
function M:DeleteCustomBar(id)
    local _, index = self:Custom(id)
    if not self:CanConfigure() or not index then return false end
    -- The page moves off the bar first, so nothing draws a bar that's gone.
    if self.selectedBar == id then
        self.selectedBar = "essential"
        if self.page then self.page.SetEditing("essential") end
    end
    -- What hangs from it moves to the screen where it is.
    addon.Positioning:RemoveTarget(self.ElementId(id))
    local candidate = Copy(self.db)
    table.remove(candidate.customBars, index)
    candidate[id] = nil
    -- Racials on it go back to Utility.
    if candidate.racials == id then candidate.racials = "utility" end
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
    addon.Positioning:SetTargetLabel(self.ElementId(id), name)
    return true
end

-- Puts a spell on a bar that takes spells (taking it off every other one).
-- Only a spell the bar can take, tracked now (Candidates), is accepted; a
-- viewer's own spell going back to it needs no entry.
function M:AddEntry(id, key)
    if not self:CanConfigure() or not self:TakesEntries(id) or type(key) ~= "string" then return false end
    local found
    for _, candidate in ipairs(self:Candidates(id)) do if candidate.key == key then found = candidate end end
    if not found or found.owner == id then return false end
    local candidate = Copy(self.db)
    local function Drop(entries)
        for i = #entries, 1, -1 do if entries[i] == key then table.remove(entries, i) end end
    end
    for _, bar in ipairs(candidate.customBars) do Drop(bar.entries) end
    for viewer in pairs(self.entryViewers) do Drop(candidate.extras[viewer]) end
    local entries = self.EntriesIn(candidate, id)
    if found.source ~= id then
        if #entries >= self.MAX_ENTRIES then return false end
        entries[#entries + 1] = key
    end
    return Commit(self, candidate)
end

-- Takes a spell off a bar: back to its viewer, or (a viewer's own spell)
-- hidden there.
function M:RemoveEntry(id, key)
    if not self:CanConfigure() or not self:TakesEntries(id) then return false end
    local candidate = Copy(self.db)
    local entries, found = self.EntriesIn(candidate, id), false
    for i = #entries, 1, -1 do if entries[i] == key then table.remove(entries, i); found = true end end
    -- A viewer's own spell, or a racial the bar shows on its own, hides there.
    if not found and (not self:IsCustom(id) or self:IsRacialHere(id, key)) then return self:SetSpellSwitch(id, key, "hide", true) end
    candidate[id].spells[key] = nil
    return Commit(self, candidate)
end

-- The order spells show in on a bar. A custom bar's is its list. A
-- viewer's is Blizzard's (its own spells, then what it took) until you move
-- one (owner, November 14, 2026): then db.order[viewer] ranks the keys, and
-- spells it doesn't name follow in their own order. ModeUI lays the icons
-- out, so Blizzard's own order in its window is untouched.
-- Sorts `list` (items or keys; KeyOf gives each one's key) in place.
function M:Ordered(id, list, KeyOf)
    local order = self.db.order[id]
    if not order or #order == 0 or #list < 2 then return list end
    local rank, last = {}, #order
    for index, key in ipairs(order) do rank[key] = index end
    local scored = {}
    for index, value in ipairs(list) do
        local key = KeyOf(value)
        scored[index] = { value, (key and rank[key]) or (last + index) }
    end
    table.sort(scored, function(a, b) return a[2] < b[2] end)
    for index, pair in ipairs(scored) do list[index] = pair[1] end
    return list
end

-- The keys a bar shows now, in order (the preview's spells, faded ones too).
function M:SpellOrder(id)
    local keys = {}
    for _, entry in ipairs((self:PreviewEntries(id))) do if entry.key then keys[#keys + 1] = entry.key end end
    return keys
end

-- Moves a spell to place `index` on its bar (dragged in the preview, or
-- Earlier and Later in its menu).
function M:MoveSpell(id, key, index)
    if not self:CanConfigure() or not self:HasBar(id) or type(index) ~= "number" then return false end
    local keys, from = self:SpellOrder(id), nil
    for i, other in ipairs(keys) do if other == key then from = i end end
    if not from or index < 1 or index > #keys or index == from then return false end
    table.remove(keys, from)
    table.insert(keys, index, key)
    local candidate = Copy(self.db)
    local custom = self:Custom(id)
    if custom then
        -- The bar's list in the new order; anything not shown keeps its place at the end.
        -- A racial the bar shows on its own joins its list once moved.
        local entries, placed, allowed = self.EntriesIn(candidate, id), {}, {}
        for _, k in ipairs(self:Entries(id)) do allowed[k] = true end
        local list = {}
        for _, k in ipairs(keys) do if allowed[k] and not placed[k] then placed[k] = true; list[#list + 1] = k end end
        for _, e in ipairs(entries) do if not placed[e] then list[#list + 1] = e end end
        for i = #entries, 1, -1 do entries[i] = nil end
        for i, k in ipairs(list) do entries[i] = k end
    else
        while #keys > self.MAX_ORDER do keys[#keys] = nil end
        candidate.order[id] = keys
    end
    return Commit(self, candidate)
end

-- Moves a spell earlier (-1) or later (+1) on its bar.
function M:MoveEntry(id, key, delta)
    for index, other in ipairs(self:SpellOrder(id)) do
        if other == key then return self:MoveSpell(id, key, index + delta) end
    end
    return false
end

-- What a bar can take: every spell tracked now in its source viewers, in
-- Blizzard's order, with the viewer it comes from and the bar it shows on
-- now. { key, icon, name, source, owner }.
function M:Candidates(id)
    local list, seen = {}, {}
    for _, viewer in ipairs(self:Sources(id)) do
        for _, item in ipairs(self:Items(viewer)) do
            local key = self:SpellKey(item)
            if key and not seen[key] then
                seen[key] = true
                local spell = self:SpellOf(key)
                list[#list + 1] = { key = key, icon = spell and Cooldowns.SpellIcon(spell), name = self:SpellLabel(key),
                    source = viewer, owner = self:Owner(item) }
            end
        end
    end
    return list
end
