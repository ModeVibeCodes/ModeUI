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
function M:ResetFrame(unit)
    if not self:CanConfigure() or not self.labels[unit] then return false end
    local frame = Copy(self.frameDefaults[unit])
    for key in pairs(self.identityKeys) do frame[key] = self.db[unit][key] end
    return Commit(self, unit, frame)
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
    self.nativeHidden, self.nativeAlpha, self.nativeHooks, self.nativeMouse = {}, {}, {}, {}
    self.events = CreateFrame("Frame")
    self.events:SetScript("OnEvent", function(_, event, unit) self:OnEvent(event, unit) end)
    self.events:RegisterEvent("PLAYER_REGEN_ENABLED")
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
-- Player's look and text layout, keeping its own identity keys (side,
-- visibility, the toggles); one cached proxy, so per-event updates allocate
-- nothing. With Mirror Player Text on and the portrait on the other side, text
-- alignment and horizontal offsets mirror, and `mirrored` tells the layout to
-- read the grouped level/health text in mirror order.
local FLIP = { LEFT = "RIGHT", RIGHT = "LEFT" }
M.mirrorAlign = { nameAlign = true, healthTextPosition = true, powerTextPosition = true }
M.mirrorOffset = { nameOffsetX = true, levelOffsetX = true, healthTextOffsetX = true, powerTextOffsetX = true }
function M:FrameDB(unit)
    local fdb = self.db[unit]
    if unit ~= "target" or not fdb.matchPlayer then return fdb end
    if not self.matchedTarget then
        local identity, align, offset = self.identityKeys, self.mirrorAlign, self.mirrorOffset
        self.matchedTarget = setmetatable({}, { __index = function(_, key)
            local target, player = self.db.target, self.db.player
            if identity[key] then return target[key] end
            local mirror = target.mirrorText == true and target.portraitSide ~= player.portraitSide
            if key == "mirrored" then return mirror end
            local value = player[key]
            if mirror then
                if align[key] then return FLIP[value] or value end
                if offset[key] then return -value end
            end
            return value
        end })
    end
    return self.matchedTarget
end

local UNIT_EVENTS = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
    "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_FACTION", "UNIT_CONNECTION", "UNIT_CLASSIFICATION_CHANGED",
    "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED" }
function M:SetEvents(on)
    if (self.eventsOn or false) == on then return end
    self.eventsOn = on
    local f = self.events
    for _, event in ipairs(UNIT_EVENTS) do
        if on then f:RegisterUnitEvent(event, "player", "target") else f:UnregisterEvent(event) end
    end
    -- Scale/resolution changes re-snap the pixel-perfect borders (registered by
    -- Blizzard's own Forever UI in SharedUIPanelTemplates.lua).
    for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD", "PORTRAITS_UPDATED",
        "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
        if on then f:RegisterEvent(event) else f:UnregisterEvent(event) end
    end
end

-- Secure frames can only be shown, hidden, moved or resized outside combat;
-- requests made in combat are kept and applied when combat ends.
function M:Refresh()
    if not self.frames then return end
    if InCombatLockdown() then self.pending = true; self:UpdateAll(); return end
    self.pending = false
    -- Secure buttons are created on first enable, never in combat.
    if self.active then self:CreateDisplay() end
    local any = false
    for _, unit in ipairs(self.units) do
        local on = self:FrameOn(unit)
        any = any or on
        local f = self.frames[unit]
        if self.ghosts[unit] then self:ApplyLayout(self.ghosts[unit], unit) end
        if f then
            self:ApplyLayout(f, unit)
            self:SyncPosition(unit)
            if on and not self.watched[unit] then RegisterUnitWatch(f); self.watched[unit] = true
            elseif not on and self.watched[unit] then UnregisterUnitWatch(f); self.watched[unit] = nil; f:Hide() end
        end
    end
    self:SyncNative()
    self:SetEvents(any)
    self:RenderGhosts()
    self:UpdateAll()
    if addon.EditMode then addon.EditMode:RefreshElements() end
end

function M:OnEvent(event, unit)
    if event == "PLAYER_REGEN_ENABLED" then
        if self.pending then self:Refresh() end
    elseif event == "PLAYER_TARGET_CHANGED" then self:Update("target")
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PORTRAITS_UPDATED" then self:UpdateAll()
    elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then self:Refresh()
    elseif unit == "player" or unit == "target" then
        if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_CONNECTION" then self:UpdateHealth(unit)
        elseif event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then self:UpdatePower(unit)
        elseif event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" then self:UpdatePortrait(unit)
        else self:Update(unit) end
    end
end

function M:Status()
    if not self.active then return "Disabled. Blizzard's frames are restored outside combat." end
    if self.pending then return "Changes are waiting until you leave combat." end
    return "Active. Use Edit Mode to move the frames; left-click targets, right-click opens the unit menu."
end
