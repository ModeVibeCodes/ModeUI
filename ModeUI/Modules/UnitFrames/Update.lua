local _, addon = ...
local M = addon.UnitFrames
if not M then return end

-- Colors and live unit data: health, power and portraits; the text slots
-- (names, levels, values) are filled by Texts.lua.
local P, ONYX = M.palette, M.onyx
local Kit, Domain = addon.Kit, addon.Domain
local UnitColor, Portrait = Domain.UnitColor, Domain.Portrait
local Lighten = Kit.Lighten
local Style = addon.Style

-- Blends a class/reaction color toward white by the frame's Class Color
-- Softness (pastel; 0 keeps the original color).
function M:Soften(color, fdb)
    if not color then return nil end
    local t = fdb.classSoftness / 100
    if t <= 0 then return color end
    return Lighten(color, t)
end
local REACTION_COLORS = { hostile = P.hostile, neutral = P.neutral, friendly = P.green }
-- Class color for players (or Mode reaction colors when allowed), softened by
-- the frame's Class Color Softness, else nil. `fdb` defaults to the unit's frame.
function M:IdentityColor(unit, reactionOnly, fdb)
    fdb = fdb or self:FrameDB(unit)
    if not reactionOnly then
        local color = UnitColor.PlayerClass(unit)
        if color then return self:Soften({ color.r, color.g, color.b }, fdb) end
    end
    local reaction = UnitColor.Reaction(unit)
    if reaction == "tapped" then return P.tapped end
    if reaction then return self:Soften(REACTION_COLORS[reaction], fdb) end
end
-- Edit Mode/preview stand-ins show the player's own class, and an enemy for others.
function M:SampleIdentity(unit, fdb)
    return unit == "player" and self:IdentityColor("player", false, fdb) or self:Soften(P.hostile, fdb)
end

function M:HealthColor(unit, identity)
    local fdb = self:FrameDB(unit)
    local mode = fdb.healthColorMode
    if mode == "custom" then return fdb.healthColor end
    if mode == "class" then return identity or self:IdentityColor(unit) or ONYX.health end
    return ONYX.health
end
function M:NameColor(unit, identity)
    local fdb = self:FrameDB(unit)
    local mode = fdb.nameColorMode
    if mode == "custom" then return fdb.nameColor end
    if mode == "class" then return identity or self:IdentityColor(unit) or self.ACCENT end
    -- Gradient (docs/DESIGN_LANGUAGE.md, "Text"): the class or reaction color
    -- itself, unsoftened; WriteNames runs it toward white letter by letter.
    if mode == "gradient" then return self:IdentityColor(unit, false, { classSoftness = 0 }) or self.ACCENT end
    return self.nameAccents[mode] or self.ACCENT
end

-- Portrait ring (Style.Ring): Steel Sheen by default, or its metal tinted by
-- the class/reaction color or a custom color, keeping its light band.
function M:PaintRing(f, unit)
    local fdb = self:FrameDB(unit)
    local ring, mode = f.portrait.ring, fdb.portraitRing
    -- In combat, with Combat Ring on, the ring turns red (Status.lua).
    if f.redRing then Style.PaintRing(ring, self.db[unit].status.ringColor); return end
    if mode == "custom" then Style.PaintRing(ring, fdb.portraitRingColor); return end
    local color = mode == "class" and (f.ghost and self:SampleIdentity(unit, fdb) or self:IdentityColor(unit))
    Style.PaintRing(ring, color or nil)
end

-- The health fill's color, and the shield's tint that follows it.
local function PaintHealth(bar, color, alpha)
    bar:SetStatusBarColor(color[1], color[2], color[3], alpha)
    bar.fillColor = color
    if bar.shield then bar.shield:Paint() end
end

-- Combined shields from Blizzard's heal prediction calculator; amounts may be
-- secret and only reach the shield's bars (Style.Shield).
function M:UpdateShield(unit)
    local f = self.frames and self.frames[unit]
    if not f or not self:FrameOn(unit) then return end
    local shield = f.health.shield
    if not self:FrameDB(unit).showShields then shield:SetShown(false); return end
    if f.calculator == nil then f.calculator = Domain.Group.NewCalculator() or false end
    shield:SetShown(true)
    shield:Update(unit, Domain.Group.Prediction(unit, f.calculator or nil))
end

function M:PaintPortrait(f, unit, sampleUnit)
    local fdb = self:FrameDB(unit)
    if not fdb.showPortrait then return end
    -- Character portraits: cropped 10% at the sides and bottom, 4% at the top,
    -- so the face fills the ring a little more.
    if Portrait.Apply(f.portrait.icon, sampleUnit or unit, fdb.portraitStyle) == "portrait" then
        f.portrait.icon:SetTexCoord(0.1, 0.9, 0.04, 0.84)
    end
end

function M:PaintSample(g, unit)
    local fdb = self:FrameDB(unit)
    local identity = self:SampleIdentity(unit, fdb)
    local color = self:HealthColor(unit, identity)
    local alpha = fdb.barForegroundOpacity / 100
    PaintHealth(g.health, color, alpha)
    g.health:SetMinMaxValues(0, 100); g.health:SetValue(75)
    -- A sample shield that fits in the missing health.
    g.health.shield:SetShown(fdb.showShields)
    if fdb.showShields then g.health.shield:Update(nil, { max = 100, shield = 15, total = 15 }) end
    local power = fdb.powerColorMode == "custom" and fdb.powerColor or P.mana
    g.power:SetMinMaxValues(0, 100); g.power:SetValue(60)
    g.power:SetStatusBarColor(power[1], power[2], power[3], fdb.powerForegroundOpacity / 100)
    self:PaintTextSample(g, unit, identity)
    if fdb.showPortrait then
        if unit == "player" then self:PaintPortrait(g, unit, "player") else Portrait.SetIcon(g.portrait.icon, Portrait.UNKNOWN_ICON) end
    end
    self:PaintComboSample(g)
    self:PaintCastSample(g, unit)
    self:PaintAuraSample(g, unit)
    self:PaintStatusSample(g, unit)
end

local Health, Power = Domain.Health, Domain.Power

function M:UpdateHealth(unit)
    local f = self.frames and self.frames[unit]
    if not f or not self:FrameOn(unit) then return end
    local okMax, max, okValue, value = Health.Read(unit)
    if okMax then pcall(f.health.SetMinMaxValues, f.health, 0, max) end
    if okValue then pcall(f.health.SetValue, f.health, value) end
    local color = self:HealthColor(unit)
    PaintHealth(f.health, color, self:FrameDB(unit).barForegroundOpacity / 100)
    self:UpdateHealthTexts(f, unit, okValue, value)
    self:UpdateShield(unit)
end

function M:UpdatePower(unit)
    local f = self.frames and self.frames[unit]
    local fdb = self:FrameDB(unit)
    if not f or not self:FrameOn(unit) then return end
    -- Power texts can sit on the health bar, so they update without a power bar.
    if not fdb.showPower and #f.textKinds.power == 0 then return end
    local powerType, token, okMax, max, okValue, value = Power.Read(unit)
    if fdb.showPower then
        if okMax then pcall(f.power.SetMinMaxValues, f.power, 0, max) end
        if okValue then pcall(f.power.SetValue, f.power, value) end
        local color = fdb.powerColorMode == "custom" and fdb.powerColor or Power.Color(token)
        f.power:SetStatusBarColor(color[1], color[2], color[3], fdb.powerForegroundOpacity / 100)
    end
    self:UpdatePowerTexts(f, unit, powerType, okValue, value)
end

function M:UpdatePortrait(unit)
    local f = self.frames and self.frames[unit]
    if not f or not self:FrameOn(unit) then return end
    self:PaintPortrait(f, unit); self:PaintRing(f, unit)
end

function M:UpdateText(unit) self:UpdateNameTexts(self.frames[unit], unit) end

function M:Update(unit)
    local f = self.frames and self.frames[unit]
    if not f or not self:FrameOn(unit) or not Portrait.Exists(unit) then return end
    self:UpdateText(unit); self:UpdateHealth(unit); self:UpdatePower(unit); self:UpdatePortrait(unit)
    if unit == "target" then self:UpdateCombo() end
    self:UpdateCast(unit); self:UpdateAuras(unit); self:UpdateStatus(unit)
end
function M:UpdateAll() for _, unit in ipairs(self.units) do self:Update(unit) end end
