local _, addon = ...
local M = addon.BuffsDebuffs
if not M then return end

-- Lifecycle and settings changes. Nothing is built until the module is first
-- switched on; frames and containers change outside combat only (Defer).
local Defer, Events, L = addon.Defer, addon.Events, addon.L
local function Copy(value) return addon.ProfileCodec.Copy(value) end

function M:OnInitialize()
    self.Initialize(self.db)
    self.movers, self.holders, self.containers, self.samples = {}, {}, {}, {}
    for _, entry in ipairs(self.db.customBars) do
        addon.Positioning:AddTarget(self.ElementId(entry.id), entry.name, self.FrameName(entry.id))
    end
    addon.RegisterMessage(self, addon.Messages.PROFILES_CHANGED, function() self:Refresh() end)
end

function M:OnEnable()
    self.active = true
    Events:On(self, "PLAYER_ENTERING_WORLD", function() self:Refresh() end)
    self:Refresh()
end
function M:OnDisable()
    self.active = false
    Events:OffAll(self)
    self:Refresh()
    -- Blizzard's frames come back with a reload (they were switched off).
    if self.blizzardParked then
        addon.ReloadManager:Request("buffsDebuffs", L["Buffs & Debuffs: reload to give Blizzard's buffs and debuffs back."])
    end
end

function M:CanConfigure() return not addon.InCombat() end

-- Every bar's ID, the four fixed ones first.
function M:BarIds()
    local ids = {}
    for _, id in ipairs(self.FIXED) do ids[#ids + 1] = id end
    for _, entry in ipairs(self.db.customBars) do ids[#ids + 1] = entry.id end
    return ids
end
function M:Custom(id)
    for index, entry in ipairs(self.db.customBars) do if entry.id == id then return entry, index end end
end
function M:HasBar(id) return self.db.bars[id] ~= nil and (self.FIXED_KIND[id] ~= nil or self:Custom(id) ~= nil) end
-- A preset bar (Defensives): a custom bar that keeps its kind.
function M:Preset(id)
    local custom = self:Custom(id)
    return custom and custom.preset and self.PRESETS[custom.preset] or nil
end
-- Whether the bar's kind can change (custom bars that aren't presets).
function M:KindChangeable(id) return self:Custom(id) ~= nil and self:Preset(id) == nil end
function M:BarLabel(id)
    local custom = self:Custom(id)
    return custom and custom.name or L[self.FIXED_LABELS[id] or id]
end

-- Applies everything now, or after combat.
function M:Refresh()
    Defer:Run("buffsDebuffs:refresh", function() self:Apply() end)
end
function M:Apply()
    self:SyncMovers()
    self:StandIn()
    for _, id in ipairs(self:BarIds()) do self:ApplyBar(id) end
    self:RenderMovers()
    if self.page then self.page:Refresh() end
    if self.RefreshPreview then self:RefreshPreview() end
end

-- A validated copy replaces the settings (the switch is kept).
function M:Commit(candidate)
    candidate.enabled = self.db.enabled
    if not pcall(self.Initialize, candidate) then return false end
    local db = self.db
    for key in pairs(db) do db[key] = nil end
    for key, value in pairs(candidate) do db[key] = value end
    self:Refresh()
    return true
end

-- One setting of one bar. Switching a bar between buffs and debuffs keeps
-- the kinds it had picked for each (owner, November 18, 2026: an accidental
-- switch shouldn't lose them); a kind never picked starts on All. Changing
-- the way it grows keeps its rows across.
local LISTS = { cats = true, otherCats = true, spells = true }
function M:SetBarOption(id, key, value)
    if not self:CanConfigure() or not self:HasBar(id) or LISTS[key] then return false end
    if key == "kind" and not self:KindChangeable(id) then return false end
    local preset = self:Preset(id)
    if preset and preset[key] ~= nil then return false end
    local candidate = Copy(self.db)
    local bar = candidate.bars[id]
    if bar[key] == nil then return false end
    -- A height still at its width's default offset follows the width.
    if key == "width" and addon.IsNumber(value) and bar.height == addon.Style.IconHeight(bar.width) then
        bar.height = addon.Style.IconHeight(value)
    end
    bar[key] = value
    if key == "kind" and value ~= self.db.bars[id].kind then
        bar.cats, bar.otherCats = bar.otherCats or { all = true }, bar.cats
        bar.byType = value == "debuffs"; bar.cancel = value == "buffs"
    end
    if key == "grow" and self.HORIZONTAL[value] == self.HORIZONTAL[bar.wrap] then
        bar.wrap = self.HORIZONTAL[value] and "down" or "right"
    end
    return self:Commit(candidate)
end

-- The module's text: font, outline and shadow (every bar's time and stacks).
M.TEXT_KEYS = { font = true, fontMedia = true, outline = true, shadow = true }
function M:SetOption(key, value)
    if not self:CanConfigure() or not self.TEXT_KEYS[key] then return false end
    local candidate = Copy(self.db)
    candidate[key] = value
    return self:Commit(candidate)
end
-- The font picker and color rows read and write through an owner.
function M:TextOwner()
    local owner = { db = { appearance = setmetatable({}, { __index = function(_, key) return M.db[key] end }) } }
    function owner.CanConfigure() return M:CanConfigure() end
    function owner.GetFonts() return addon.Media:GetFonts() end
    function owner.SetAppearance(_, key, value) return M:SetOption(key, value) end
    return owner
end

-- Turns one kind of aura on or off for a bar. All stands alone (it already
-- shows the rest); picking another kind takes All off. Weapon Enchants go
-- with anything.
function M:SetCategory(id, category, on)
    if not self:CanConfigure() or not self:HasBar(id) then return false end
    local candidate = Copy(self.db)
    local bar = candidate.bars[id]
    if not self.categoryById[bar.kind][category] then return false end
    if on then
        if category == "all" then
            for other in pairs(bar.cats) do if other ~= "enchant" then bar.cats[other] = nil end end
        elseif category ~= "enchant" then bar.cats.all = nil end
        bar.cats[category] = true
    else bar.cats[category] = nil end
    return self:Commit(candidate)
end

-- Custom bars: added with the default look, named "Bar N"; deleting one
-- moves what hangs from it to where it is and forgets its place.
function M:AddCustomBar()
    if not self:CanConfigure() or #self.db.customBars >= self.MAX_CUSTOM then return nil end
    local candidate = Copy(self.db)
    local id = "custom" .. candidate.nextCustom
    candidate.nextCustom = candidate.nextCustom + 1
    local name = string.format(L["Bar %d"], #candidate.customBars + 1)
    candidate.customBars[#candidate.customBars + 1] = { id = id, name = name }
    candidate.bars[id] = Copy(self.customDefaults)
    addon.Positioning:AddTarget(self.ElementId(id), name, self.FrameName(id))
    if not self:Commit(candidate) then addon.Positioning:RemoveTarget(self.ElementId(id)); return nil end
    self:AllowBarTarget(id)
    return id
end
function M:DeleteCustomBar(id)
    local _, index = self:Custom(id)
    if not self:CanConfigure() or not index then return false end
    addon.Positioning:RemoveTarget(self.ElementId(id))
    local candidate = Copy(self.db)
    table.remove(candidate.customBars, index)
    candidate.bars[id] = nil
    if not self:Commit(candidate) then return false end
    local positions = addon.db and addon.db.positions
    if type(positions) == "table" then positions[self.ElementId(id)] = nil end
    return true
end
function M:RenameCustomBar(id, name)
    local _, index = self:Custom(id)
    if not self:CanConfigure() or not index or type(name) ~= "string" then return false end
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" or #name > 40 then return false end
    local candidate = Copy(self.db)
    candidate.customBars[index].name = name
    if not self:Commit(candidate) then return false end
    if self.movers[id] then addon.PositionManager:SetLabel(self.ElementId(id), name) end
    addon.Positioning:SetTargetLabel(self.ElementId(id), name)
    return true
end

-- The blacklist: spells every bar leaves out (excludeSpellIDs).
function M:IsBlacklisted(spellID)
    for _, held in ipairs(self.db.blacklist) do if held == spellID then return true end end
    return false
end
function M:AddBlacklist(spellID)
    if not self:CanConfigure() or not addon.IsNumber(spellID, 1, 10000000) or spellID ~= math.floor(spellID) then return false end
    if self:IsBlacklisted(spellID) or #self.db.blacklist >= self.MAX_BLACKLIST then return false end
    local candidate = Copy(self.db)
    candidate.blacklist[#candidate.blacklist + 1] = spellID
    return self:Commit(candidate)
end
function M:RemoveBlacklist(spellID)
    if not self:CanConfigure() or not self:IsBlacklisted(spellID) then return false end
    local candidate = Copy(self.db)
    local kept = {}
    for _, held in ipairs(candidate.blacklist) do if held ~= spellID then kept[#kept + 1] = held end end
    candidate.blacklist = kept
    return self:Commit(candidate)
end

-- Spells You Add: a bar's own buffs (includeSpellIDs).
function M:HasBarSpell(id, spellID)
    for _, held in ipairs(self.db.bars[id] and self.db.bars[id].spells or {}) do if held == spellID then return true end end
    return false
end
function M:AddBarSpell(id, spellID)
    if not self:CanConfigure() or not self:HasBar(id) or not addon.IsNumber(spellID, 1, 10000000)
        or spellID ~= math.floor(spellID) then return false end
    if self:HasBarSpell(id, spellID) or #self.db.bars[id].spells >= self.MAX_SPELLS then return false end
    local candidate = Copy(self.db)
    local spells = candidate.bars[id].spells
    spells[#spells + 1] = spellID
    return self:Commit(candidate)
end
function M:RemoveBarSpell(id, spellID)
    if not self:CanConfigure() or not self:HasBarSpell(id, spellID) then return false end
    local candidate = Copy(self.db)
    local kept = {}
    for _, held in ipairs(candidate.bars[id].spells) do if held ~= spellID then kept[#kept + 1] = held end end
    candidate.bars[id].spells = kept
    return self:Commit(candidate)
end

-- Reset puts every bar, the blacklist and the text back (places stay).
function M:ResetSettings()
    if not self:CanConfigure() then return false end
    for _, entry in ipairs(self.db.customBars) do addon.Positioning:RemoveTarget(self.ElementId(entry.id)) end
    local candidate = { enabled = self.db.enabled }
    if not self:Commit(candidate) then return false end
    for _, entry in ipairs(self.db.customBars) do
        addon.Positioning:AddTarget(self.ElementId(entry.id), entry.name, self.FrameName(entry.id))
        self:AllowBarTarget(entry.id)
    end
    return true
end

-- Edit Mode shows each bar's stand-in and sample icons; the containers wait.
function M:SetEditMode(on)
    self.editing = on and true or false
    if self.built then self:Refresh() end
end
