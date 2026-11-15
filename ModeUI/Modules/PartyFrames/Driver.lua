local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- Lifecycle, settings changes, events and the out-of-combat refresh. The
-- secure header is in Header.lua, Blizzard's frames in Native.lua; members
-- are laid out in Layout.lua and filled in Update.lua and Icons.lua; auras
-- run in Auras.lua and AuraContainers.lua.
local Events, Defer = addon.Events, addon.Defer
local function Copy(value) return addon.ProfileCodec.Copy(value) end

-- Unit events, registered on each member's own frame for its unit
-- (RegisterUnitEvent), and the part of the member each one refreshes.
M.UNIT_EVENTS = {
    UNIT_HEALTH = "Health", UNIT_MAXHEALTH = "Health", UNIT_CONNECTION = "Member", UNIT_FLAGS = "Status",
    UNIT_POWER_FREQUENT = "Power", UNIT_MAXPOWER = "Power", UNIT_DISPLAYPOWER = "Power",
    UNIT_NAME_UPDATE = "Name", UNIT_AURA = "Auras", UNIT_HEAL_PREDICTION = "Prediction",
    UNIT_ABSORB_AMOUNT_CHANGED = "Prediction", UNIT_IN_RANGE_UPDATE = "Range", UNIT_PHASE = "Icons",
    UNIT_OTHER_PARTY_CHANGED = "Icons", INCOMING_RESURRECT_CHANGED = "Icons", INCOMING_SUMMON_CHANGED = "Icons",
    UNIT_THREAT_SITUATION_UPDATE = "Threat",
}
-- Range has an event, but it can miss changes; while in a group the members
-- are also checked on a short timer.
M.RANGE_SECONDS = 0.5

function M:OnInitialize()
    self.Initialize(self.db)
    self.members = {}
    -- Bumped by each refresh: the aura containers configure again (AuraContainers.lua).
    self.auraRevision = 0
    addon.RegisterMessage(self, addon.Messages.CLASS_COLORS_CHANGED, function() self:UpdateAll() end)
    addon.Media:RegisterStatusBarListener(self, function() if self.active then self:Refresh() end end)
    self.ticker = CreateFrame("Frame")
    self.ticker:Hide()
    local waited = 0
    self.ticker:SetScript("OnUpdate", function(_, elapsed)
        waited = waited + (addon.IsNumber(elapsed, 0, 60) and elapsed or 0)
        if waited < self.RANGE_SECONDS then return end
        waited = 0
        for _, f in ipairs(self.members) do self:UpdateRange(f) end
    end)
end

local GLOBAL_EVENTS = {
    -- Roster events come in bursts: members redraw once, on the next frame.
    GROUP_ROSTER_UPDATE = "QueueAll", PLAYER_ROLES_ASSIGNED = "QueueAll", PLAYER_ENTERING_WORLD = "OnWorld",
    PARTY_LEADER_CHANGED = "UpdateAllIcons", READY_CHECK = "UpdateAllIcons", READY_CHECK_CONFIRM = "UpdateAllIcons",
    READY_CHECK_FINISHED = "OnReadyCheckFinished", RAID_TARGET_UPDATE = "UpdateAllIcons",
    PLAYER_TARGET_CHANGED = "UpdateAllTargets", UI_SCALE_CHANGED = "Refresh", DISPLAY_SIZE_CHANGED = "Refresh",
}

-- Runtime sets self.enabled after these return, so they keep their own state.
function M:OnEnable()
    self.active = true
    for event, method in pairs(GLOBAL_EVENTS) do Events:On(self, event, function() self[method](self) end) end
    self:Refresh()
end
function M:OnDisable()
    self.active = false
    Events:OffAll(self)
    for _, f in ipairs(self.members) do f.events:UnregisterAllEvents(); f.boundUnit = nil end
    self:Refresh()
end

function M:OnWorld()
    addon.Defer:Run("partyFrames:native", function() self:SyncNative() end)
    self:QueueAll()
end

-- Blizzard leaves ready check marks up a few seconds after it ends.
M.READY_CHECK_STAY = 6
function M:OnReadyCheckFinished()
    self:UpdateAllIcons()
    if C_Timer and C_Timer.After then
        self.readyCheckToken = (self.readyCheckToken or 0) + 1
        local token = self.readyCheckToken
        C_Timer.After(self.READY_CHECK_STAY, function()
            if self.readyCheckToken == token then self.readyCheckDone = true; self:UpdateAllIcons(); self.readyCheckDone = nil end
        end)
    end
end

function M:SetEditMode(enabled) self.editing = enabled and self.active or false; self:RenderGhost() end
function M:SetPreviewMode(enabled) self.previewing = enabled and self.active or false; self:RenderGhost() end
-- Test on Screen: the sample party at the frames' place, for trying settings alone.
function M:CanTestDisplay() return self.active == true and not addon.InCombat() and not addon.editMode end
function M:SetTestDisplay(on)
    if on and not self:CanTestDisplay() then return false end
    self.testing = on == true
    self:RenderGhost()
    return true
end

-- Everything protected (building, sizing, attributes, the header's place and
-- Blizzard's frames) runs now, or once combat ends.
function M:Refresh()
    if not self.members then return end
    Defer:Run("partyFrames:refresh", function()
        self.auraRevision = self.auraRevision + 1
        if self.active then self:CreateGhost(); self:CreateHeader() end
        self:RenderGhost()
        if self.header then self:ConfigureHeader(); self:SyncHeaderShown() end
        self:SyncNative()
        self.pending = false
        self.ticker:SetShown(self.active and self.db.rangeFade and self.header ~= nil)
        for _, f in ipairs(self.members) do f.unit = self.MemberUnit(f:GetAttribute("unit")); self:BindMember(f) end
        if addon.EditMode then addon.EditMode:RefreshElements() end
    end)
    if addon.InCombat() then self.pending = true; self:UpdateAll() end
end

function M:CanConfigure() return not addon.InCombat() end

local function Changed(self)
    self:Refresh()
    if self.page then self.page:Refresh(); self.page:Layout() end
    return true
end

-- One setting, checked by Initialize on a copy before it's kept. With
-- `group`, a setting of that aura group.
function M:SetOption(key, value, group)
    if not self:CanConfigure() then return false end
    local defaults = group and self.auraDefaults[group] or self.defaults
    if not defaults or defaults[key] == nil or (not group and key == "auras") then return false end
    local candidate = Copy(self.db)
    local holder = group and candidate.auras[group] or candidate
    holder[key] = Copy(value)
    if not pcall(self.Initialize, candidate) then return false end
    local live = group and self.db.auras[group] or self.db
    live[key] = holder[key]
    return Changed(self)
end
-- An element's setting: show, anchor, place, x, y or size.
function M:SetElementOption(element, key, value)
    if not self.elementDefaults[element] then return false end
    return self:SetOption(element .. key:sub(1, 1):upper() .. key:sub(2), value)
end
function M:SetAuraOption(group, key, value) return self.auraDefaults[group] ~= nil and self:SetOption(key, value, group) end
-- One debuff effect of one dispel type: border, health or gradient on or off.
function M:SetDispelEffect(kind, key, value)
    if not self:CanConfigure() or not self.defaults.dispel[kind] or self.defaults.dispel[kind][key] == nil then return false end
    local candidate = Copy(self.db)
    candidate.dispel[kind][key] = value
    if not pcall(self.Initialize, candidate) then return false end
    self.db.dispel[kind][key] = value
    return Changed(self)
end

-- Back to defaults: everything, or one aura group.
function M:ResetSettings(group)
    if not self:CanConfigure() then return false end
    if group then
        if not self.auraDefaults[group] then return false end
        local live = self.db.auras[group]
        -- A tracked group keeps its buffs.
        local spells = live.spells
        for key in pairs(live) do live[key] = nil end
        for key, value in pairs(Copy(self.auraDefaults[group])) do live[key] = value end
        if spells then live.spells = spells end
        return Changed(self)
    end
    local version = self.db.version
    for key in pairs(self.defaults) do self.db[key] = nil end
    self.db.version = version
    self.Initialize(self.db)
    return Changed(self)
end

-- One aura group's place and look copied onto another; which auras each
-- group shows stays its own.
function M:CopyAuraGroup(from, to)
    if not self:CanConfigure() or not self.auraDefaults[from] or not self.auraDefaults[to] or from == to then return false end
    local source, target = Copy(self.db.auras[from]), self.db.auras[to]
    -- Which auras it shows, and a tracked group's buffs, stay its own.
    source.filter, source.show, source.spells = target.filter, target.show, target.spells
    for key in pairs(target) do target[key] = nil end
    for key, value in pairs(source) do target[key] = value end
    return Changed(self)
end

-- Owner for the shared font and color widgets.
function M:AppearanceOwner()
    local owner = { db = { appearance = setmetatable({}, { __index = function(_, key) return M.db[key] end }) } }
    function owner.CanConfigure() return M:CanConfigure() end
    function owner.GetFonts() return addon.Media:GetFonts() end
    function owner.SetAppearance(_, key, value) return M:SetOption(key, value) end
    return owner
end

function M:Status()
    if not self.active then return "Disabled. Blizzard's party frames are back." end
    if self.pending then return "Changes are waiting until you leave combat." end
    return "Active. Use Edit Mode to move the group; left-click targets, right-click opens the unit menu."
end
