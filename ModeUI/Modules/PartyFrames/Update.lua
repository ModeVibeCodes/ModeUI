local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- Live data on each member: name, health, power, heals and absorbs, dead and
-- offline, range and your target. Unit values can be secret: they go only to
-- StatusBar SetMinMaxValues/SetValue, FontString SetText/SetFormattedText and
-- Region SetAlphaFromBoolean, never compared or used in arithmetic here.
local Kit, Domain = addon.Kit, addon.Domain
local Health, Power, Name, UnitColor, Group = Domain.Health, Domain.Power, Domain.Name, Domain.UnitColor, Domain.Group
local Q = Domain.Query

-- A member's unit changed (the header sorts and hands out units, in combat
-- too): its unit events follow it, then everything is redrawn.
function M:SetMemberUnit(f, unit)
    unit = (addon.IsPublic(unit) and type(unit) == "string" and unit ~= "") and unit or nil
    f.unit = unit
    f.events:UnregisterAllEvents()
    if unit and self.active then
        for event in pairs(self.UNIT_EVENTS) do pcall(f.events.RegisterUnitEvent, f.events, event, unit) end
    end
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
    else self:UpdateMember(f) end
end

function M:Live(f) return self.active and f.unit ~= nil and Q.Truthy(UnitExists, f.unit) end

function M:UpdateMember(f)
    if not self:Live(f) or not f.geometry then return end
    -- A role or power type change can add or remove the power bar.
    self:UpdatePowerShown(f)
    self:UpdateName(f); self:UpdateHealth(f); self:UpdatePower(f); self:UpdatePrediction(f)
    self:UpdateStatus(f); self:UpdateIcons(f); self:UpdateTarget(f); self:UpdateAuras(f)
end
function M:UpdateAll() for _, f in ipairs(self.members or {}) do self:UpdateMember(f) end end
function M:UpdateAllIcons() for _, f in ipairs(self.members or {}) do if self:Live(f) then self:UpdateIcons(f) end end end
function M:UpdateAllTargets() for _, f in ipairs(self.members or {}) do self:UpdateTarget(f) end end

-- The class color of a player (custom Class Colors included), else nil.
function M:ClassColor(unit)
    local color = UnitColor.PlayerClass(unit)
    if color then return { color.r, color.g, color.b } end
end
function M:HealthColor(unit, class)
    local db = self.db
    if db.healthColorMode == "custom" then return db.healthColor end
    if db.healthColorMode == "class" then return class or (unit and self:ClassColor(unit)) or Kit.onyx.health end
    return Kit.onyx.health
end
function M:NameColor(unit, class)
    local db = self.db
    if db.nameColorMode == "custom" then return db.nameColor end
    if db.nameColorMode == "class" then return class or (unit and self:ClassColor(unit)) or db.textColor end
    return db.textColor
end

function M:UpdateName(f)
    if not self:Live(f) then return end
    local text, color = f.texts.name, self:NameColor(f.unit)
    Kit.Write(text, Name.Get(f.unit))
    text:SetTextColor(color[1], color[2], color[3], 1)
end

function M:UpdateHealth(f)
    if not self:Live(f) then return end
    local okMax, max, okValue, value = Health.Read(f.unit)
    if okMax then pcall(f.health.SetMinMaxValues, f.health, 0, max) end
    if okValue then pcall(f.health.SetValue, f.health, value) end
    local color = self:HealthColor(f.unit)
    f.health:SetStatusBarColor(color[1], color[2], color[3], self.db.healthOpacity / 100)
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
    local _, token, okMax, max, okValue, value = Power.Read(f.unit)
    if okMax then pcall(f.power.SetMinMaxValues, f.power, 0, max) end
    if okValue then pcall(f.power.SetValue, f.power, value) end
    local color = self.db.powerColorMode == "custom" and self.db.powerColor or Power.Color(token)
    f.power:SetStatusBarColor(color[1], color[2], color[3], self.db.healthOpacity / 100)
end

-- Heals and shields ride on the health fill with the health range, so the
-- secret amounts draw at the right length straight from SetValue. The
-- overshield fills back from full health with the whole shield, shown only
-- while the shield is bigger than the missing health (SetAlphaFromBoolean).
function M:UpdatePrediction(f)
    if not self:Live(f) then return end
    local db = self.db
    if f.calculator == nil then f.calculator = Group.NewCalculator() or false end
    local p = Group.Prediction(f.unit, f.calculator or nil)
    for _, part in ipairs({ { f.healPrediction, db.showHealPrediction, p.heals }, { f.absorb, db.showAbsorbs, p.shield },
        { f.overshield, db.showOvershields, p.total } }) do
        -- Amounts may be secret: never compared, only handed to the bar (a
        -- missing one makes the call fail, and the bar empties).
        local bar, shown, amount = part[1], part[2], part[3]
        pcall(bar.SetMinMaxValues, bar, 0, p.max)
        if not (shown and pcall(bar.SetValue, bar, amount)) then bar:SetValue(0) end
        bar:SetShown(shown and true or false)
    end
    local over = f.overshield
    if db.showOvershields and p.calculated then
        if addon.IsPublic(p.overflow) then over:SetAlpha(p.overflow and 1 or 0)
        elseif not pcall(over.SetAlphaFromBoolean, over, p.overflow, 1, 0) then over:SetAlpha(0) end
    else over:SetAlpha(0) end
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

-- Your target: its border in the highlight color, or a tint over its bars.
function M:UpdateTarget(f)
    f.isTarget = self:Live(f) and Q.Truthy(UnitIsUnit, f.unit, "target") or false
    self:PaintTarget(f)
end
function M:PaintTarget(f)
    local style = self.db.targetHighlight
    local on = f.isTarget == true
    self.ShowBorder(f.targetRing, on and style == "border")
    f.targetFill:SetShown(on and style == "fill")
end
