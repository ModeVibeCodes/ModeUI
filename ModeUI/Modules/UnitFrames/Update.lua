local _, addon = ...
local M = addon.UnitFrames
if not M then return end

-- Colors and live unit data: names, levels, health, power and portraits.
local P, ONYX = M.palette, M.onyx
local Kit, Domain = addon.Kit, addon.Domain
local UnitColor, Portrait = Domain.UnitColor, Domain.Portrait
local Lighten, Scale, Gradient, Write = Kit.Lighten, Kit.Scale, Kit.Gradient, Kit.Write

local function SetName(f, text, color)
    Write(f.nameText, text); f.nameText:SetTextColor(color[1], color[2], color[3], 1)
end

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
    return self.nameAccents[mode] or self.ACCENT
end

-- Portrait ring: Class Gradient (light top, pastel class/reaction color, deeper
-- bottom), Default (the frame's rim color) or Custom.
function M:PaintRing(f, unit)
    local fdb = self:FrameDB(unit)
    local ring, mode = f.portrait.ring, fdb.portraitRing
    -- In combat, with Combat Ring on, the ring turns red (Status.lua).
    if f.redRing then
        local c = self.db[unit].status.ringColor
        Gradient(ring, Lighten(c, 0.35), Scale(c, 0.72)); return
    end
    if mode == "custom" then Gradient(ring, fdb.portraitRingColor, fdb.portraitRingColor); return end
    local color = mode == "class" and (f.ghost and self:SampleIdentity(unit, fdb) or self:IdentityColor(unit))
    if not color then Gradient(ring, M.RIM_COLOR, M.RIM_COLOR); return end
    Gradient(ring, Lighten(color, 0.35), Scale(color, 0.72))
end

function M:PaintPortrait(f, unit, sampleUnit)
    local fdb = self:FrameDB(unit)
    if not fdb.showPortrait then return end
    Portrait.Apply(f.portrait.icon, sampleUnit or unit, fdb.portraitStyle)
end

function M:PaintSample(g, unit)
    local fdb = self:FrameDB(unit)
    local identity = self:SampleIdentity(unit, fdb)
    local color = self:HealthColor(unit, identity)
    local alpha = fdb.barForegroundOpacity / 100
    g.health:SetStatusBarColor(color[1], color[2], color[3], alpha)
    g.health:SetMinMaxValues(0, 100); g.health:SetValue(75)
    local power = fdb.powerColorMode == "custom" and fdb.powerColor or P.mana
    g.power:SetMinMaxValues(0, 100); g.power:SetValue(60); g.power:SetStatusBarColor(power[1], power[2], power[3], alpha)
    SetName(g, self.titles[unit], self:NameColor(unit, identity))
    Write(g.levelText, "60")
    local mode = fdb.healthText
    Write(g.healthText, mode == "current" and "3,450" or mode == "both" and "3,450 · 75%" or "75%")
    local pmode = fdb.powerText
    Write(g.powerText, pmode == "current" and "1,200" or pmode == "both" and "1,200 · 60%" or "60%")
    if fdb.showPortrait then
        if unit == "player" then self:PaintPortrait(g, unit, "player") else Portrait.SetIcon(g.portrait.icon, Portrait.UNKNOWN_ICON) end
    end
    self:PaintComboSample(g)
    self:PaintCastSample(g, unit)
    self:PaintAuraSample(g, unit)
    self:PaintStatusSample(g, unit)
end

local Health, Power, Name, Level = Domain.Health, Domain.Power, Domain.Name, Domain.Level

function M:UpdateHealth(unit)
    local f = self.frames and self.frames[unit]
    if not f or not self:FrameOn(unit) then return end
    local okMax, max, okValue, value = Health.Read(unit)
    if okMax then pcall(f.health.SetMinMaxValues, f.health, 0, max) end
    if okValue then pcall(f.health.SetValue, f.health, value) end
    local color = self:HealthColor(unit)
    f.health:SetStatusBarColor(color[1], color[2], color[3], self:FrameDB(unit).barForegroundOpacity / 100)
    local mode = self:FrameDB(unit).healthText
    if mode == "none" then return end
    -- Objects (pickups, interactables) have no health to show.
    if Health.IsObject(unit) then Write(f.healthText, ""); return end
    local state = Health.State(unit)
    if state then Write(f.healthText, state)
    else Kit.ValueText(f.healthText, mode, Health.Percent, unit, okValue, value) end
end

function M:UpdatePower(unit)
    local f = self.frames and self.frames[unit]
    local fdb = self:FrameDB(unit)
    if not f or not self:FrameOn(unit) or not fdb.showPower then return end
    local powerType, token, okMax, max, okValue, value = Power.Read(unit)
    if okMax then pcall(f.power.SetMinMaxValues, f.power, 0, max) end
    if okValue then pcall(f.power.SetValue, f.power, value) end
    local color = fdb.powerColorMode == "custom" and fdb.powerColor
        or Power.Color(token)
    f.power:SetStatusBarColor(color[1], color[2], color[3], fdb.barForegroundOpacity / 100)
    Kit.ValueText(f.powerText, fdb.powerText, function(u, curve) return Power.Percent(u, powerType, curve) end,
        unit, okValue, value)
end

function M:UpdatePortrait(unit)
    local f = self.frames and self.frames[unit]
    if not f or not self:FrameOn(unit) then return end
    self:PaintPortrait(f, unit); self:PaintRing(f, unit)
end

function M:UpdateText(unit)
    local f, fdb = self.frames[unit], self:FrameDB(unit)
    if fdb.showName then
        SetName(f, Name.Get(unit), self:NameColor(unit))
    end
    if fdb.levelStyle ~= "none" then
        Write(f.levelText, Level.Text(unit))
    end
end

function M:Update(unit)
    local f = self.frames and self.frames[unit]
    if not f or not self:FrameOn(unit) or not Portrait.Exists(unit) then return end
    self:UpdateText(unit); self:UpdateHealth(unit); self:UpdatePower(unit); self:UpdatePortrait(unit)
    if unit == "target" then self:UpdateCombo() end
    self:UpdateCast(unit); self:UpdateAuras(unit); self:UpdateStatus(unit)
end
function M:UpdateAll() for _, unit in ipairs(self.units) do self:Update(unit) end end
