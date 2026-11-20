local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- Live data on each member: name, health, power, heals and absorbs, dead and
-- offline, range and your target. Unit values can be secret: they go only to
-- StatusBar SetMinMaxValues/SetValue, FontString SetText/SetFormattedText and
-- Region SetAlphaFromBoolean, never compared or used in arithmetic here.
local Kit, Domain, Style = addon.Kit, addon.Domain, addon.Style
local Health, Power, Name, UnitColor, Group = Domain.Health, Domain.Power, Domain.Name, Domain.UnitColor, Domain.Group
local Q = Domain.Query

-- The header hands out units (in combat too). It sets every button's unit
-- again on each GROUP_ROSTER_UPDATE and on any unit's UNIT_NAME_UPDATE, which
-- come in bursts while a group forms, and mostly hands back the same unit.
-- So the same unit does nothing, and real changes wait for one pass on the
-- next frame (FlushMembers), however many arrive.
local function UnitOf(unit) return (addon.IsPublic(unit) and type(unit) == "string" and unit ~= "") and unit or nil end
M.MemberUnit = UnitOf
function M:SetMemberUnit(f, unit)
    unit = UnitOf(unit)
    if unit == f.unit then return end
    f.unit = unit
    self:QueueMember(f)
end

function M:QueueMember(f)
    self.queued = self.queued or {}
    self.queued[f] = true
    if self.flushQueued then return end
    self.flushQueued = true
    if C_Timer and C_Timer.After then C_Timer.After(0, function() self:FlushMembers() end) else self:FlushMembers() end
end
function M:QueueAll() for _, f in ipairs(self.members or {}) do self:QueueMember(f) end end
function M:FlushMembers()
    local queued = self.queued or {}
    self.queued, self.flushQueued = {}, false
    for _, f in ipairs(self.members or {}) do if queued[f] then self:SyncMember(f) end end
end

-- Who a unit is: its GUID when readable (it can be secret), else nil.
local function Identity(unit)
    if not unit or not UnitGUID then return nil end
    local ok, guid = pcall(UnitGUID, unit)
    return (ok and addon.IsPublic(guid) and type(guid) == "string") and guid or nil
end

-- A new unit binds the member to it; the same unit (a roster change can put
-- someone else behind it) is redrawn, and its auras read again only when the
-- person changed or can't be told.
function M:SyncMember(f)
    if (self.active and f.unit or nil) ~= f.boundUnit then self:BindMember(f); return end
    local guid = Identity(f.unit)
    if f.unit and (guid == nil or guid ~= f.guid) then self:AttachAuras(f, true) end
    f.guid = guid
    self:UpdateMember(f)
end

-- Unit events follow the unit (re-registered only when it changes), the aura
-- containers point at it, then everything is redrawn. Refresh runs this for
-- every member after a settings change.
function M:BindMember(f)
    local unit = self.active and f.unit or nil
    if unit ~= f.boundUnit then
        f.events:UnregisterAllEvents()
        if unit then
            for event in pairs(self.UNIT_EVENTS) do pcall(f.events.RegisterUnitEvent, f.events, event, unit) end
        end
        f.boundUnit = unit
    end
    f.guid = Identity(f.unit)
    self:AttachAuras(f)
    self:UpdateMember(f)
end

function M:OnMemberEvent(f, event, unit)
    if unit ~= nil and unit ~= f.unit then return end
    local part = self.UNIT_EVENTS[event]
    -- Dying and coming back arrive as health changes.
    if part == "Health" then self:UpdateStatus(f, true); self:UpdateHealth(f); self:UpdatePrediction(f)
    elseif part == "Power" then self:UpdatePower(f)
    elseif part == "Name" then self:UpdateName(f)
    elseif part == "Auras" then self:UpdateAuras(f)
    elseif part == "Prediction" then self:UpdatePrediction(f)
    elseif part == "Range" then self:UpdateRange(f)
    elseif part == "Icons" then self:UpdateIcons(f)
    elseif part == "Status" then self:UpdateStatus(f)
    elseif part == "Threat" then self:UpdateThreat(f)
    else self:UpdateMember(f) end
end

function M:Live(f) return self.active and f.unit ~= nil and Q.Truthy(UnitExists, f.unit) end

function M:UpdateMember(f)
    if not self:Live(f) or not f.geometry then return end
    -- A role or power type change can add or remove the power bar.
    self:UpdatePowerShown(f)
    self:UpdateName(f); self:UpdateHealth(f); self:UpdatePower(f); self:UpdatePrediction(f)
    self:UpdateStatus(f); self:UpdateIcons(f); self:UpdateThreat(f); self:UpdateTarget(f); self:UpdateFocus(f); self:UpdateAuras(f)
end
function M:UpdateAll() for _, f in ipairs(self.members or {}) do self:UpdateMember(f) end end
function M:UpdateAllIcons() for _, f in ipairs(self.members or {}) do if self:Live(f) then self:UpdateIcons(f) end end end
function M:UpdateAllTargets() for _, f in ipairs(self.members or {}) do self:UpdateTarget(f) end end
function M:UpdateAllFocus() for _, f in ipairs(self.members or {}) do self:UpdateFocus(f) end end

-- Your focus (the Prism glow, when Focus Glow is on).
function M:UpdateFocus(f)
    f.isFocus = self:Live(f) and Q.Truthy(UnitIsUnit, f.unit, "focus") or false
    self:PaintGlow(f)
end
-- The Prism glow round a member (docs/DESIGN_LANGUAGE.md, "Mode-Obsidian
-- theme"): while the mouse is over it (Hover Glow) or while it is your focus
-- (Focus Glow), in its class color.
function M:PaintGlow(f)
    local glow, db = f.prism, self.db
    if not glow then return end
    local shown = (db.hoverGlow and f.hovered == true) or (db.focusGlow and f.isFocus == true) or false
    if shown then glow:SetColor(f.unit and self:ClassColor(f.unit) or Style.Tone.ivory) end
    glow:SetShown(shown)
end

-- The class color of a player (custom Class Colors included), else nil.
function M:ClassColor(unit)
    local color = UnitColor.PlayerClass(unit)
    if color then return { color.r, color.g, color.b } end
end
function M:HealthColor(unit, class)
    local db = self.db
    if db.healthColorMode == "custom" then return db.healthColor end
    if db.healthColorMode == "class" then return class or (unit and self:ClassColor(unit)) or Style.Tone.darkFill end
    return Style.Tone.darkFill
end
-- The name's color and its style: Gradient and Soft Class follow the class
-- (a non-player gets the friendly green), the others are one color.
function M:NameColor(unit, class)
    local db = self.db
    if db.nameColorMode == "custom" then return db.nameColor, "white" end
    if db.nameColorMode == "text" then return db.textColor, "white" end
    local color = class or (unit and self:ClassColor(unit)) or Style.Tone.reaction.friendly
    return color, db.nameColorMode == "gradient" and "gradient" or "soft"
end
-- Writes a name (possibly secret) in its style; the lift copy gets it plain.
function M:WriteName(text, name, color, style)
    if style == "white" then
        Kit.Write(text, name)
        text:SetTextColor(color[1], color[2], color[3], 1)
        return
    end
    Style.SetName(text, name, color, style)
    if text.lift then text.lift:SetText(name) end
end

function M:UpdateName(f)
    if not self:Live(f) then return end
    local color, style = self:NameColor(f.unit)
    self:WriteName(f.texts.name, Name.Get(f.unit), color, style)
end

-- The health fill's color; the shield's tint follows it.
function M.PaintHealth(bar, color, alpha)
    bar:SetStatusBarColor(color[1], color[2], color[3], alpha)
    bar.fillColor = color
    if bar.shield then bar.shield:Paint() end
end

function M:UpdateHealth(f)
    if not self:Live(f) then return end
    local okMax, max, okValue, value = Health.Read(f.unit)
    if okMax then pcall(f.health.SetMinMaxValues, f.health, 0, max) end
    if okValue then pcall(f.health.SetValue, f.health, value) end
    self.PaintHealth(f.health, self:HealthColor(f.unit), self.db.healthOpacity / 100)
    self:UpdateHealthText(f, okValue, value)
end

-- Percent, current or missing health; empty while dead or offline (the
-- status text says so).
function M:UpdateHealthText(f, okValue, value)
    local text, db = f.texts.healthText, self.db
    if not db.healthTextShow or Health.State(f.unit) then Kit.Write(text, ""); return end
    if db.healthText == "deficit" then
        local ok, deficit = Health.Deficit(f.unit)
        if not (ok and pcall(Kit.Write, text, deficit)) then Kit.Write(text, "") end
        return
    end
    if db.healthText == "percentPlain" then
        local curve = CurveConstants and CurveConstants.ScaleTo100
        local ok, percent = false, nil
        if curve then ok, percent = Health.Percent(f.unit, curve) end
        if not (ok and pcall(Kit.Formatted, text, "%.0f", percent)) then Kit.Write(text, "") end
    else Kit.ValueText(text, db.healthText, Health.Percent, f.unit, okValue, value) end
    -- By Health: Rosewood at 30% and under, through Ivory, to Celadon (the
    -- client evaluates the curve; the percent is secret).
    if db.healthTextColor == "health" and Style.PaintHealthText(text, f.unit) then return end
    local c = db.textColor
    text:SetTextColor(c[1], c[2], c[3], 1)
end

-- Role and power type decide whether a member shows power (Power Bar For).
function M:UpdatePowerShown(f)
    local role, token = Group.Role(f.unit), select(2, Power.Read(f.unit))
    if role ~= f.role or token ~= f.powerToken then
        f.role, f.powerToken = role, token
        local shown = self:ShowsPower(f)
        if shown ~= f.hasPower then self:LayoutBars(f) end
    end
end

function M:UpdatePower(f)
    if not self:Live(f) then return end
    self:UpdatePowerShown(f)
    if not f.hasPower then return end
    local powerType, token, okMax, max, okValue, value = Power.Read(f.unit)
    if okMax then pcall(f.power.SetMinMaxValues, f.power, 0, max) end
    if okValue then pcall(f.power.SetValue, f.power, value) end
    local color = self.db.powerColorMode == "custom" and self.db.powerColor or Power.Color(token)
    f.power:SetStatusBarColor(color[1], color[2], color[3], self.db.powerOpacity / 100)
    self:UpdatePowerText(f, powerType, okValue, value)
end

-- The power text: percent (with or without the sign) or the current value,
-- all possibly secret, so only SetFormattedText and SetText take them.
function M:UpdatePowerText(f, powerType, okValue, value)
    local db, text = self.db, f.powerText
    if not db.powerTextShow then Kit.Write(text, ""); return end
    local function Percent(unit, curve) return Power.Percent(unit, powerType, curve) end
    if db.powerText == "percentPlain" then
        local curve = CurveConstants and CurveConstants.ScaleTo100
        local ok, percent = false, nil
        if curve then ok, percent = Percent(f.unit, curve) end
        if not (ok and pcall(Kit.Formatted, text, "%.0f", percent)) then Kit.Write(text, "") end
    else Kit.ValueText(text, db.powerText, Percent, f.unit, okValue, value) end
end

-- Heals ride on the health fill with the health range, so the secret
-- amount draws at the right length straight from SetValue. Shields are
-- Combined (Style.Shield): attached to the health's end below full health,
-- the whole shield back from max at full health (Overshields off: never).
function M:UpdatePrediction(f)
    if not self:Live(f) then return end
    local db = self.db
    if f.calculator == nil then f.calculator = Group.NewCalculator() or false end
    local p = Group.Prediction(f.unit, f.calculator or nil)
    local bar = f.healPrediction
    -- Amounts may be secret: never compared, only handed to the bar (a
    -- missing one makes the call fail, and the bar empties).
    pcall(bar.SetMinMaxValues, bar, 0, p.max)
    if not (db.showHealPrediction and pcall(bar.SetValue, bar, p.heals)) then bar:SetValue(0) end
    bar:SetShown(db.showHealPrediction and true or false)
    local shield = f.health.shield
    shield:SetShown(db.showAbsorbs)
    if not db.showAbsorbs then return end
    shield:Update(f.unit, p)
    if not db.showOvershields then shield.full:SetAlpha(0) end
end

-- Aggro: the rim in the hostile red while the member holds a mob's attention
-- (UnitThreatSituation 2 or 3; unknown or secret counts as none).
function M:UpdateThreat(f)
    local status = self:Live(f) and Domain.Threat.Aggro(f.unit)
    f.hasAggro = status ~= nil and status >= 2 or nil
    self:PaintRim(f)
end

-- "Dead", "Ghost" and "Offline" in the status text, and those members fade.
-- `changesOnly`: nothing to do unless the state changed (health events).
function M:UpdateStatus(f, changesOnly)
    if not self:Live(f) then return end
    local state = Health.State(f.unit)
    if changesOnly and state == f.state then return end
    f.state = state
    Kit.Write(f.texts.status, state and addon.L[state] or "")
    local c = self.db.textColor
    f.texts.status:SetTextColor(c[1], c[2], c[3], 1)
    self:UpdateRange(f)
end

-- Alpha: dead and offline members at Dead and Offline Opacity; others out of
-- range at Out of Range Opacity. UnitInRange is secret, so the client picks
-- between the two through SetAlphaFromBoolean. You are always in range.
function M:UpdateRange(f)
    if not self:Live(f) then return end
    local db = self.db
    if f.state then f:SetAlpha(db.deadOpacity / 100); return end
    if not db.rangeFade or f.unit == "player" or Q.Truthy(UnitIsUnit, f.unit, "player") then f:SetAlpha(1); return end
    local ok, inRange = Group.InRange(f.unit)
    if not ok then f:SetAlpha(1); return end
    if addon.IsPublic(inRange) then f:SetAlpha(inRange and 1 or db.rangeOpacity / 100); return end
    if not (f.SetAlphaFromBoolean and pcall(f.SetAlphaFromBoolean, f, inRange, 1, db.rangeOpacity / 100)) then f:SetAlpha(1) end
end

-- Your target: its rim in the highlight color, or a tint over its bars.
function M:UpdateTarget(f)
    f.isTarget = self:Live(f) and Q.Truthy(UnitIsUnit, f.unit, "target") or false
    self:PaintTarget(f)
end
function M:PaintTarget(f)
    local style = self.db.targetHighlight
    local on = f.isTarget == true
    self:PaintRim(f)
    f.targetFill:SetShown(on and style == "fill")
end
