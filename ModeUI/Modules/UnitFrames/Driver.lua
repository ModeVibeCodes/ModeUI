local _, addon = ...
local M = addon.UnitFrames
if not M then return end

-- Lifecycle, settings changes, events and the secure refresh. Frames are
-- built in Build.lua, laid out in Layout.lua and filled in Update.lua;
-- Blizzard's own frames are faded in Native.lua.
local function Copy(value) return addon.ProfileCodec.Copy(value) end

function M:CanConfigure() return not InCombatLockdown() and not UnitAffectingCombat("player") end
function M:GetFonts() return addon.Media:GetFonts() end

-- Values are written in place so config widgets keep their table references.
local function Commit(self, unit, frame)
    local copy = Copy(self.db); copy[unit] = frame
    if not pcall(self.Initialize, copy) then return false end
    local target = self.db[unit]
    for key in pairs(target) do target[key] = nil end
    for key, value in pairs(copy[unit]) do target[key] = value end
    self:Refresh()
    if self.page then self.page:Refresh(); self.page:Layout() end
    return true
end
function M:SetFrameOption(unit, key, value)
    if not self:CanConfigure() or not self.labels[unit] or self.frameDefaults[unit][key] == nil then return false end
    local frame = Copy(self.db[unit]); frame[key] = Copy(value)
    return Commit(self, unit, frame)
end
-- Nested settings: `path` leads from the module's settings to a table, such as
-- { "comboPoints" }; the table is updated in place, like a frame's.
function M:SetNestedOption(path, key, value)
    if not self:CanConfigure() then return false end
    local function Walk(root)
        local t = root
        for _, k in ipairs(path) do t = type(t) == "table" and t[k] or nil end
        return type(t) == "table" and t or nil
    end
    local live = Walk(self.db)
    if not live or live[key] == nil then return false end
    local copy = Copy(self.db)
    Walk(copy)[key] = Copy(value)
    if not pcall(self.Initialize, copy) then return false end
    local fresh = Walk(copy)
    for k in pairs(live) do live[k] = nil end
    for k, v in pairs(fresh) do live[k] = v end
    self:Refresh()
    if self.page then self.page:Refresh(); self.page:Layout() end
    return true
end
function M:SetComboOption(key, value) return self:SetNestedOption({ "comboPoints" }, key, value) end
function M:SetStatusOption(unit, key, value) return self.labels[unit] ~= nil and self:SetNestedOption({ unit, "status" }, key, value) end
function M:UpdateAllStatus()
    if not self.frames then return end
    for _, unit in ipairs(self.units) do self:UpdateStatus(unit) end
end
-- Settings of one text slot (content, size, colorMode, color, x, y, align),
-- changed together. Each text shows once per frame (owner, November 13,
-- 2026): showing a text in a slot clears it from any other slot.
function M:SetTextOptions(unit, slot, changes)
    if not self:CanConfigure() or not self.labels[unit] or not self.slotPlaces[slot] then return false end
    local copy = Copy(self.db)
    local texts = copy[unit].texts
    for key, value in pairs(changes) do
        if texts[slot][key] == nil then return false end
        texts[slot][key] = Copy(value)
    end
    local content = changes.content
    if content ~= nil and content ~= "none" then
        for other, s in pairs(texts) do if other ~= slot and s.content == content then s.content = "none" end end
    end
    if not pcall(self.Initialize, copy) then return false end
    local live = self.db[unit].texts
    for name, fresh in pairs(copy[unit].texts) do
        local target = live[name]
        for k in pairs(target) do target[k] = nil end
        for k, v in pairs(fresh) do target[k] = v end
    end
    self:Refresh()
    if self.page then self.page:Refresh(); self.page:Layout() end
    return true
end
function M:SetTextOption(unit, slot, key, value) return self:SetTextOptions(unit, slot, { [key] = value }) end
function M:SetCastOption(unit, key, value) return self.labels[unit] ~= nil and self:SetNestedOption({ unit, "castBar" }, key, value) end
function M:SetAuraOption(unit, group, key, value)
    return self.labels[unit] ~= nil and self.auraGroupLabels[group] ~= nil and self:SetNestedOption({ unit, group }, key, value)
end
function M:ResetFrame(unit)
    if not self:CanConfigure() or not self.labels[unit] then return false end
    local frame = Copy(self.frameDefaults[unit])
    for key in pairs(self.identityKeys) do frame[key] = self.db[unit][key] end
    return Commit(self, unit, frame)
end
-- Every frame, with its cast bar, auras, status and texts, and the class
-- resource back to the defaults (the settings footer's Reset). Positions stay
-- with Edit Mode.
function M:ResetToDefaults()
    if not self:CanConfigure() then return false end
    local copy = Copy(self.db)
    for _, unit in ipairs(self.units) do copy[unit] = Copy(self.frameDefaults[unit]) end
    copy.comboPoints = Copy(self.comboDefaults)
    if not pcall(self.Initialize, copy) then return false end
    for _, unit in ipairs(self.units) do self.db[unit] = copy[unit] end
    self.db.comboPoints = copy.comboPoints
    self:Refresh()
    if self.page then self.page:Refresh(); self.page:Layout() end
    return true
end
function M:CopyStyle(from, to)
    if not self:CanConfigure() or not self.labels[from] or not self.labels[to] or from == to then return false end
    local frame = Copy(self.db[from])
    for key in pairs(self.identityKeys) do frame[key] = self.db[to][key] end
    return Commit(self, to, frame)
end
-- Per-frame appearance owner for the shared font/color widgets. `unit` may be
-- a function so one settings page can switch which frame it edits.
function M:AppearanceOwner(unit)
    local function Unit() return type(unit) == "function" and unit() or unit end
    local appearance = setmetatable({}, { __index = function(_, key) return M.db[Unit()][key] end })
    local owner = { db = { appearance = appearance } }
    function owner.CanConfigure() return M:CanConfigure() end
    function owner.GetFonts() return M:GetFonts() end
    function owner.SetAppearance(_, key, value) return M:SetFrameOption(Unit(), key, value) end
    return owner
end

function M:OnInitialize()
    self.Initialize(self.db)
    self.frames, self.ghosts, self.watched = {}, {}, {}
    self.nativeHidden, self.nativeAlpha, self.nativeHooks, self.nativeMouse, self.nativeAnims = {}, {}, {}, {}, {}
    local function OnEvent(_, event, unit) self:OnEvent(event, unit) end
    self.events = CreateFrame("Frame")
    self.events:SetScript("OnEvent", OnEvent)
    self.events:RegisterEvent("PLAYER_REGEN_ENABLED")
    -- A frame's unit events filter to at most two units, so the focus has its own.
    self.focusEvents = CreateFrame("Frame")
    self.focusEvents:SetScript("OnEvent", OnEvent)
    -- The game sends no unit events for "targettarget" or "focustarget", so
    -- their frames refresh on a short timer while shown, as Blizzard's own
    -- Target of Target does (TargetOfTargetMixin, OnUpdate).
    self.poller = CreateFrame("Frame")
    self.poller:Hide()
    local waited = 0
    self.poller:SetScript("OnUpdate", function(_, elapsed)
        waited = waited + (M.Number(elapsed, 0, 60) and elapsed or 0)
        if waited < self.POLL_SECONDS then return end
        waited = 0
        for unit in pairs(self.polledUnits) do self:Update(unit) end
    end)
    addon.RegisterMessage(self, addon.Messages.CLASS_COLORS_CHANGED, function() self:OnClassColorsChanged() end)
end
function M:OnEnable()
    self.active = true
    self:Refresh()
end
function M:OnDisable()
    self.active = false
    self:Refresh()
end
function M:SetEditMode(enabled) self.editing = enabled and self.active or false; self:RenderGhosts() end
function M:SetPreviewMode(enabled) self.previewing = enabled and self.active or false; self:RenderGhosts() end
-- Global > Class Colors changed: recolor names, health and portrait rings now.
function M:OnClassColorsChanged()
    if not self.frames then return end
    self:UpdateAll()
    -- Preview stand-ins are re-laid out only outside combat, as everywhere else.
    if not InCombatLockdown() then self:RenderGhosts() end
end

function M:FrameOn(unit) return self.active == true and self.db[unit].enabled == true end

-- Settings a frame renders with. A Target set to Match Player Frame reads the
-- Player's look and text slots, keeping its own identity keys (side,
-- visibility, the toggles); one cached proxy, so per-event updates allocate
-- nothing. With Mirror Player Text on and the portrait on the other side,
-- `mirrored` tells the layout to show each text slot on the other side
-- (Texts.lua).
function M:FrameDB(unit)
    local fdb = self.db[unit]
    if unit ~= "target" or not fdb.matchPlayer then return fdb end
    if not self.matchedTarget then
        local identity = self.identityKeys
        self.matchedTarget = setmetatable({}, { __index = function(_, key)
            local target, player = self.db.target, self.db.player
            if identity[key] or self.ownKeys[key] then return target[key] end
            if key == "mirrored" then return target.mirrorText == true and target.portraitSide ~= player.portraitSide end
            return player[key]
        end })
    end
    return self.matchedTarget
end

M.POLL_SECONDS = 0.1
-- UNIT_TARGET: the target or focus picked a new target, so its Target of
-- Target (or Target of Focus) changes at once.
local UNIT_EVENTS = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
    "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_FACTION", "UNIT_CONNECTION", "UNIT_CLASSIFICATION_CHANGED",
    "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED", "UNIT_TARGET",
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "UNIT_AURA", "UNIT_FLAGS",
    -- Shields (Combined, Style.Shield).
    "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_PREDICTION" }
function M:SetEvents(on)
    if (self.eventsOn or false) == on then return end
    self.eventsOn = on
    local f, focus = self.events, self.focusEvents
    for _, event in ipairs(UNIT_EVENTS) do
        if on then f:RegisterUnitEvent(event, "player", "target"); focus:RegisterUnitEvent(event, "focus")
        else f:UnregisterEvent(event); focus:UnregisterEvent(event) end
    end
    -- Scale/resolution changes re-snap the pixel-perfect borders (registered by
    -- Blizzard's own Forever UI in SharedUIPanelTemplates.lua).
    -- Rest and combat for the status badges, red ring and pull pulse.
    for _, event in ipairs({ "PLAYER_UPDATE_RESTING", "PLAYER_REGEN_DISABLED" }) do
        if on then f:RegisterEvent(event) else f:UnregisterEvent(event) end
    end
    for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "PLAYER_ENTERING_WORLD", "PORTRAITS_UPDATED",
        "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
        if on then f:RegisterEvent(event) else f:UnregisterEvent(event) end
    end
    -- Forever moves combo points with the target (Camelot TargetBoundComboPointBar);
    -- guarded, since RegisterEvent errors on an event a client lacks.
    if on then pcall(f.RegisterEvent, f, "COMBO_TARGET_CHANGED") else pcall(f.UnregisterEvent, f, "COMBO_TARGET_CHANGED") end
end

-- Secure frames can only be shown, hidden, moved or resized outside combat;
-- requests made in combat are kept and applied when combat ends.
function M:Refresh()
    if not self.frames then return end
    if InCombatLockdown() then self.pending = true; self:UpdateAll(); return end
    self.pending = false
    -- Secure buttons are created on first enable, never in combat.
    if self.active then self:CreateDisplay() end
    local any, polled = false, false
    for _, unit in ipairs(self.units) do
        local on = self:FrameOn(unit)
        any = any or on
        polled = polled or (on and self.polledUnits[unit] == true)
        local f = self.frames[unit]
        if self.ghosts[unit] then self:ApplyLayout(self.ghosts[unit], unit) end
        if f then
            self:ApplyLayout(f, unit)
            self:SyncPlacement(unit); self:SyncPosition(unit)
            if on and not self.watched[unit] then RegisterUnitWatch(f); self.watched[unit] = true
            elseif not on and self.watched[unit] then UnregisterUnitWatch(f); self.watched[unit] = nil; f:Hide() end
        end
    end
    self:SyncNative()
    self:SetEvents(any)
    self.poller:SetShown(polled)
    self:RenderGhosts()
    self:UpdateAll()
    if addon.EditMode then addon.EditMode:RefreshElements() end
end

function M:OnEvent(event, unit)
    if event == "PLAYER_REGEN_ENABLED" then
        if self.pending then self:Refresh() end
        self:UpdateAllStatus()
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_UPDATE_RESTING" then self:UpdateAllStatus()
    elseif event == "PLAYER_TARGET_CHANGED" then
        self:Update("target"); self:Update("targettarget"); self:UpdateStatus("player")
    elseif event == "UNIT_FLAGS" then
        -- Combat state changed; your target's also decides the Player's pull pulse.
        if unit == "player" or unit == "target" or unit == "focus" then self:UpdateStatus(unit) end
        if unit == "target" then self:UpdateStatus("player") end
    elseif event == "PLAYER_FOCUS_CHANGED" then self:Update("focus"); self:Update("focustarget")
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PORTRAITS_UPDATED" then self:UpdateAll()
    elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then self:Refresh()
    elseif event == "COMBO_TARGET_CHANGED" then self:UpdateCombo()
    elseif event == "UNIT_TARGET" then
        if unit == "target" or unit == "focus" then self:Update(unit .. "target") end
    elseif unit == "player" or unit == "target" or unit == "focus" then
        if event:find("^UNIT_SPELLCAST") then self:UpdateCast(unit)
        elseif event == "UNIT_AURA" then self:UpdateAuras(unit)
        elseif event == "UNIT_ABSORB_AMOUNT_CHANGED" or event == "UNIT_HEAL_PREDICTION" then self:UpdateShield(unit)
        elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_CONNECTION" then self:UpdateHealth(unit)
        elseif event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
            self:UpdatePower(unit)
            -- Combo points are the player's power (Cat Form changes it too).
            if unit == "player" then self:UpdateCombo() end
        elseif event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" then self:UpdatePortrait(unit)
        else self:Update(unit) end
    end
end

function M:Status()
    if not self.active then return "Disabled. Blizzard's frames are restored outside combat." end
    if self.pending then return "Changes are waiting until you leave combat." end
    return "Active. Use Edit Mode to move the frames; left-click targets, right-click opens the unit menu."
end
