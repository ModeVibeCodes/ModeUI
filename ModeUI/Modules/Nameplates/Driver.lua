local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- Lifecycle, events, settings changes and fading Blizzard's nameplate art.
-- Every plate is an enemy or a friendly plate (plate.kind) and draws with that
-- kind's settings, M:Style(plate).
-- Plates are built and laid out in Plate.lua, filled in Update.lua; cast bars
-- run in CastBar.lua and aura icons in Auras.lua.
local Events, NP = addon.Events, addon.Domain.Nameplate
local function Copy(value) return addon.ProfileCodec.Copy(value) end

local UNIT_EVENTS = {
    UNIT_HEALTH = "Health", UNIT_MAXHEALTH = "Health", UNIT_CONNECTION = "Health",
    UNIT_AURA = "Auras", UNIT_NAME_UPDATE = "Name", UNIT_FACTION = "Faction", UNIT_CLASSIFICATION_CHANGED = "Classification", UNIT_LEVEL = "Indicator", UNIT_TARGET = "CastTarget",
    UNIT_THREAT_SITUATION_UPDATE = "Color", UNIT_THREAT_LIST_UPDATE = "Color",
    UNIT_SPELLCAST_START = "Cast", UNIT_SPELLCAST_STOP = "Cast", UNIT_SPELLCAST_FAILED = "Cast",
    UNIT_SPELLCAST_INTERRUPTED = "Cast", UNIT_SPELLCAST_DELAYED = "Cast", UNIT_SPELLCAST_CHANNEL_START = "Cast",
    UNIT_SPELLCAST_CHANNEL_UPDATE = "Cast", UNIT_SPELLCAST_CHANNEL_STOP = "Cast", UNIT_SPELLCAST_INTERRUPTIBLE = "Cast",
    UNIT_SPELLCAST_NOT_INTERRUPTIBLE = "Cast", UNIT_SPELLCAST_EMPOWER_START = "Cast",
    UNIT_SPELLCAST_EMPOWER_UPDATE = "Cast", UNIT_SPELLCAST_EMPOWER_STOP = "Cast",
}
M.unitEvents = UNIT_EVENTS

function M:OnInitialize()
    self.Initialize(self.db)
    self.plates, self.byUnit, self.faded, self.fadeHooks = {}, {}, {}, {}
    addon.RegisterMessage(self, addon.Messages.CLASS_COLORS_CHANGED, function() self:UpdateAll() end)
    -- SharedMedia textures can register after login; redraw plates using them.
    addon.Media:RegisterStatusBarListener(self, function() if self.active then self:Refresh() end end)
end

-- Runtime sets self.enabled after these return, so they keep their own state.
function M:OnEnable()
    self.active = true
    Events:On(self, "NAME_PLATE_UNIT_ADDED", function(_, unit) self:OnUnitAdded(unit) end)
    Events:On(self, "NAME_PLATE_UNIT_REMOVED", function(_, unit) self:OnUnitRemoved(unit) end)
    Events:On(self, "PLAYER_TARGET_CHANGED", function() self:UpdateTargets() end)
    Events:On(self, "PLAYER_FOCUS_CHANGED", function() self:UpdateFocuses() end)
    Events:On(self, "RAID_TARGET_UPDATE", function() self:ForEachPlate(self.UpdateRaidIcon) end)
    Events:On(self, "QUEST_LOG_UPDATE", function() self:ForEachPlate(self.UpdateIndicator) end)
    for event in pairs({ UI_SCALE_CHANGED = true, DISPLAY_SIZE_CHANGED = true }) do
        Events:On(self, event, function() self:Refresh() end)
    end
    for event, part in pairs(UNIT_EVENTS) do
        Events:On(self, event, function(_, unit) self:OnUnitEvent(part, unit) end)
    end
    for _, unit in ipairs(NP.ActiveUnits()) do self:OnUnitAdded(unit) end
end

function M:OnDisable()
    self.active = false
    Events:OffAll(self)
    for unit in pairs(self.byUnit) do self:OnUnitRemoved(unit) end
end

function M:ForEachPlate(fn)
    for _, plate in pairs(self.byUnit) do fn(self, plate) end
end

function M:Style(plate) return self.db[plate.kind or "enemy"] end
function M:KindOf(unit) return NP.IsEnemy(unit) and "enemy" or "friendly" end

function M:OnUnitAdded(unit)
    if not self.active or type(unit) ~= "string" then return end
    if self.byUnit[unit] then self:OnUnitRemoved(unit) end
    local nameplate = NP.ForUnit(unit)
    -- The personal resource display and widget-only plates stay Blizzard's,
    -- and so does a kind whose ModeUI plates are switched off.
    if not nameplate or NP.IsPlayerPlate(nameplate) or NP.WidgetsOnly(unit) then return end
    local kind = self:KindOf(unit)
    if not self.db[kind].show then return end
    local plate = self:EnsurePlate(nameplate)
    plate.unit, plate.kind = unit, kind
    self.byUnit[unit] = plate
    self:FadeBlizzard(nameplate)
    self:LayoutPlate(plate)
    plate:Show()
    self:UpdatePlate(plate)
end

function M:OnUnitRemoved(unit)
    local plate = type(unit) == "string" and self.byUnit[unit]
    if not plate then return end
    self.byUnit[unit] = nil
    self:StopCast(plate)
    self:HideAuras(plate)
    plate.unit = nil
    plate:Hide()
    self:RestoreBlizzard(plate)
end

function M:OnUnitEvent(part, unit)
    local plate = type(unit) == "string" and self.byUnit[unit]
    if not plate then return end
    if part == "Faction" then
        -- A unit can turn hostile or friendly (duels, mind control).
        if self:KindOf(unit) ~= plate.kind then self:OnUnitAdded(unit) else self:UpdateHealthColor(plate) end
    elseif part == "Health" then self:UpdateHealth(plate)
    elseif part == "Name" then self:UpdateName(plate)
    elseif part == "Color" then self:UpdateHealthColor(plate)
    elseif part == "Indicator" then self:UpdateIndicator(plate)
    elseif part == "CastTarget" then self:UpdateCastTarget(plate)
    elseif part == "Classification" then self:UpdateHealthColor(plate); self:UpdateIndicator(plate)
    elseif part == "Auras" then self:UpdateAuras(plate)
    else self:UpdateCast(plate) end
end

-- Blizzard's own unit frame keeps running (it handles clicks and stacking);
-- only its art is faded, and kept faded if Blizzard resets the alpha.
local function Fade(self, frame)
    if type(frame) ~= "table" or not frame.SetAlpha then return end
    self.faded[frame] = true
    if not self.fadeHooks[frame] and hooksecurefunc then
        self.fadeHooks[frame] = true
        hooksecurefunc(frame, "SetAlpha", function(region)
            if self.faded[region] and not self.fading then
                self.fading = true; pcall(region.SetAlpha, region, 0); self.fading = false
            end
        end)
    end
    self.fading = true; pcall(frame.SetAlpha, frame, 0); self.fading = false
end

function M:FadeBlizzard(nameplate)
    local plate = self.plates[nameplate]
    -- Blizzard may acquire the unit frame after this handler runs; the hook
    -- installed in EnsurePlate fades it then.
    if nameplate.UnitFrame then
        plate.blizzard = nameplate.UnitFrame
        Fade(self, nameplate.UnitFrame)
    end
end

function M:RestoreBlizzard(plate)
    local frame = plate.blizzard
    plate.blizzard = nil
    if not frame or not self.faded[frame] then return end
    self.faded[frame] = nil
    pcall(frame.SetAlpha, frame, 1)
end

function M:OnBlizzardAcquired(nameplate)
    local plate = self.plates[nameplate]
    if plate and plate.unit and self.active then self:FadeBlizzard(nameplate) end
end

-- Re-attaches every game nameplate, so a kind switched on or off takes effect.
function M:Refresh()
    if not self.plates or not self.active then return end
    for unit in pairs(self.byUnit) do self:OnUnitRemoved(unit) end
    for _, unit in ipairs(NP.ActiveUnits()) do self:OnUnitAdded(unit) end
end

local function Changed(self)
    self:Refresh()
    if self.page then self.page:Refresh() end
end

function M:CanConfigure() return not addon.InCombat() end

-- key is a setting of the kind, or of one aura group when `group` is given.
local GROUPS = {}
for _, group in ipairs(M.auraGroups) do GROUPS[group] = true end
function M:SetOption(kind, key, value, group)
    local defaults = self.styleDefaults[kind]
    if not self:CanConfigure() or not defaults or (group and not GROUPS[group]) or (not group and GROUPS[key]) then return false end
    local target = group and defaults[group] or defaults
    if target[key] == nil then return false end
    local candidate = Copy(self.db)
    local holder = group and candidate[kind][group] or candidate[kind]
    holder[key] = Copy(value)
    if not pcall(self.Initialize, candidate) then return false end
    local live = group and self.db[kind][group] or self.db[kind]
    live[key] = holder[key]
    Changed(self)
    return true
end

-- Values are written in place so the settings widgets keep their tables.
local function Replace(self, kind, style)
    local target = self.db[kind]
    for key in pairs(target) do target[key] = nil end
    for key, value in pairs(style) do target[key] = value end
    Changed(self)
    return true
end

function M:ResetSettings(kind)
    if not self:CanConfigure() or not self.styleDefaults[kind] then return false end
    local style = Copy(self.styleDefaults[kind])
    for key in pairs(self.identityKeys) do style[key] = self.db[kind][key] end
    return Replace(self, kind, style)
end

-- Copies one kind's look to the other; whether each kind is shown stays its own.
function M:CopyStyle(from, to)
    if not self:CanConfigure() or not self.styleDefaults[from] or not self.styleDefaults[to] or from == to then return false end
    local style = Copy(self.db[from])
    for key in pairs(self.identityKeys) do style[key] = self.db[to][key] end
    return Replace(self, to, style)
end

-- Owner for the shared font and color widgets; kind() names the kind being edited.
function M:AppearanceOwner(kind)
    local appearance = setmetatable({}, { __index = function(_, key) return M.db[kind()][key] end })
    local owner = { db = { appearance = appearance } }
    function owner.CanConfigure() return M:CanConfigure() end
    function owner.GetFonts() return addon.Media:GetFonts() end
    function owner.SetAppearance(_, key, value) return M:SetOption(kind(), key, value) end
    return owner
end
