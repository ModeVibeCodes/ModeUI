local _, addon = ...
local M = addon.UnitFrames
if not M then return end

-- Colors and live unit data: health, power and portraits; the text slots
-- (names, levels, values) are filled by Texts.lua.
local P, ONYX = M.palette, M.onyx
local Domain = addon.Domain
local UnitColor, Portrait = Domain.UnitColor, Domain.Portrait
local Style = addon.Style

-- Class and reaction colors are their true colors: Class Color Softness (a
-- pastel blend toward white) was retired at layout version 24 (owner).
local REACTION_COLORS = { hostile = P.hostile, neutral = P.neutral, friendly = P.green }
-- How much of a character portrait is cropped from each side (PaintPortrait).
M.PORTRAIT_CROP = 0.16
-- Class color for players (or Mode reaction colors when allowed), else nil.
function M:IdentityColor(unit, reactionOnly)
    if not reactionOnly then
        local color = UnitColor.PlayerClass(unit)
        if color then return { color.r, color.g, color.b } end
    end
    local reaction = UnitColor.Reaction(unit)
    if reaction == "tapped" then return P.tapped end
    if reaction then return REACTION_COLORS[reaction] end
end
-- Edit Mode/preview stand-ins show the player's own class, and an enemy for others.
function M:SampleIdentity(unit)
    return unit == "player" and self:IdentityColor("player") or P.hostile
end

function M:HealthColor(unit, identity)
    local fdb = self:FrameDB(unit)
    local mode = fdb.healthColorMode
    if mode == "custom" then return fdb.healthColor end
    if mode == "class" then return identity or self:IdentityColor(unit) or Style.Tone.darkFill end
    return Style.Tone.darkFill
end
function M:NameColor(unit, identity)
    local fdb = self:FrameDB(unit)
    local mode = fdb.nameColorMode
    if mode == "custom" then return fdb.nameColor end
    if mode == "class" then return identity or self:IdentityColor(unit) or self.ACCENT end
    -- Gradient (docs/DESIGN_LANGUAGE.md, "Text"): the class or reaction color;
    -- WriteNames runs it toward white letter by letter.
    if mode == "gradient" then return self:IdentityColor(unit) or self.ACCENT end
    return self.nameAccents[mode] or self.ACCENT
end

-- Portrait ring (Style.Ring): its Ring Style (Mode-Border by default) in its
-- Ring Finish: a metal, Class Color (the default; the reaction color for NPCs)
-- or Custom. A color, and the combat red, is the style's lighting in tones
-- made from it (Style.ColorTones).
function M:PaintRing(f, unit)
    local fdb = self:FrameDB(unit)
    local ring, mode = f.portrait.ring, fdb.portraitRing
    -- In combat, with Combat Ring on, the ring turns red (Status.lua).
    local color = f.redRing and self.db[unit].status.ringColor or mode == "custom" and fdb.portraitRingColor
        or mode == "class" and (f.ghost and self:SampleIdentity(unit) or self:IdentityColor(unit)) or nil
    Style.SetRingStyle(ring, fdb.portraitRingStyle)
    Style.PaintRing(ring, color, fdb.portraitRingMetal)
    self:PaintGlow(f, unit)
end

-- The Prism glow round the bar block (docs/DESIGN_LANGUAGE.md, "Mode-Obsidian
-- theme"): Always, or while the mouse is over the frame (Mouseover), in the
-- unit's class or reaction color.
function M:PaintGlow(f, unit)
    local glow = f.prism
    if not glow then return end
    local mode = self:FrameDB(unit).prismGlow
    local shown = mode == "always" or (mode == "hover" and f.hovered == true)
    if shown then glow:SetColor(f.ghost and self:SampleIdentity(unit) or self:IdentityColor(unit) or self.ACCENT) end
    glow:SetShown(shown)
    -- The frame border's soft drop would darken the glow: it steps aside.
    f.panel.edge:SetDrop(self:MatchedFrame(unit, self:FrameDB(unit)).dropShadow and not shown)
end
-- Ring Finish as one choice: a Ring Metal id while Portrait Ring is Metal
-- ("border"), else "class" or "custom".
function M.RingFinish(fdb) return fdb.portraitRing == "border" and fdb.portraitRingMetal or fdb.portraitRing end
function M:SetRingFinish(unit, id)
    if id == "class" or id == "custom" then return self:SetFrameOption(unit, "portraitRing", id) end
    return self:SetFrameOption(unit, "portraitRingMetal", id) and self:SetFrameOption(unit, "portraitRing", "border")
end

-- The health fill's color, and the shield's tint that follows it.
local function PaintHealth(bar, color, alpha)
    bar:SetStatusBarColor(color[1], color[2], color[3], alpha)
    bar.fillColor = color
    if bar.shield then bar.shield:Paint() end
end

-- A mana frame (Bar Shows: Mana): the health bar shows the unit's mana.
function M.ShowsMana(fdb) return fdb.barShows == "mana" end
-- Shields ride on health, so a mana frame has none.
function M.ShowsShields(fdb) return fdb.showShields and not M.ShowsMana(fdb) end

-- Combined shields from Blizzard's heal prediction calculator; amounts may be
-- secret and only reach the shield's bars (Style.Shield).
function M:UpdateShield(unit)
    local f = self.frames and self.frames[unit]
    if not f or not self:FrameOn(unit) then return end
    local shield = f.health.shield
    if not M.ShowsShields(self:FrameDB(unit)) then shield:SetShown(false); return end
    if f.calculator == nil then f.calculator = Domain.Group.NewCalculator() or false end
    shield:SetShown(true)
    shield:Update(unit, Domain.Group.Prediction(unit, f.calculator or nil))
end

function M:PaintPortrait(f, unit, sampleUnit)
    local fdb = self:FrameDB(unit)
    if not fdb.showPortrait then return end
    -- Character portraits: centered and cropped 16% on every side, so the
    -- face fills most of the ring (owner, November 18, 2026).
    if Portrait.Apply(f.portrait.icon, sampleUnit or unit, fdb.portraitStyle) == "portrait" then
        f.portrait.icon:SetTexCoord(M.PORTRAIT_CROP, 1 - M.PORTRAIT_CROP, M.PORTRAIT_CROP, 1 - M.PORTRAIT_CROP)
    end
end

function M:PaintSample(g, unit)
    local fdb = self:FrameDB(unit)
    local identity = self:SampleIdentity(unit)
    local mana = M.ShowsMana(fdb)
    local color = mana and Domain.Power.Color("MANA") or self:HealthColor(unit, identity)
    local alpha = fdb.barForegroundOpacity / 100
    PaintHealth(g.health, color, alpha)
    g.health:SetMinMaxValues(0, 100); g.health:SetValue(mana and 60 or 75)
    -- A sample shield that fits in the missing health.
    local shields = M.ShowsShields(fdb)
    g.health.shield:SetShown(shields)
    if shields then g.health.shield:Update(nil, { max = 100, shield = 15, total = 15 }) end
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
    -- A mana frame's bar is UpdatePower's; its health texts still show health.
    if not M.ShowsMana(self:FrameDB(unit)) then
        if okMax then pcall(f.health.SetMinMaxValues, f.health, 0, max) end
        if okValue then pcall(f.health.SetValue, f.health, value) end
        local color = self:HealthColor(unit)
        PaintHealth(f.health, color, self:FrameDB(unit).barForegroundOpacity / 100)
    end
    self:UpdateHealthTexts(f, unit, okValue, value)
    self:UpdateShield(unit)
end

-- A mana frame's bar: the unit's mana, whatever power it shows now (a Druid
-- in a form keeps mana under Rage or Energy), in the mana color. Values may be
-- secret and only reach the StatusBar.
function M:UpdateManaBar(f, unit)
    local manaType = Power.ManaType()
    local okMax, max, okValue, value = Power.ReadType(unit, manaType)
    if okMax then pcall(f.health.SetMinMaxValues, f.health, 0, max) end
    if okValue then pcall(f.health.SetValue, f.health, value) end
    PaintHealth(f.health, Power.Color("MANA"), self:FrameDB(unit).barForegroundOpacity / 100)
    return manaType, okValue, value
end

function M:UpdatePower(unit)
    local f = self.frames and self.frames[unit]
    local fdb = self:FrameDB(unit)
    if not f or not self:FrameOn(unit) then return end
    local mana = M.ShowsMana(fdb)
    -- Power texts can sit on the health bar, so they update without a power bar.
    if not fdb.showPower and not mana and #f.textKinds.power == 0 then return end
    local powerType, token, okMax, max, okValue, value = Power.Read(unit)
    -- On a mana frame, power texts show the mana its bar shows.
    local textType, okText, textValue = powerType, okValue, value
    if mana then textType, okText, textValue = self:UpdateManaBar(f, unit) end
    if fdb.showPower then
        if okMax then pcall(f.power.SetMinMaxValues, f.power, 0, max) end
        if okValue then pcall(f.power.SetValue, f.power, value) end
        local color = fdb.powerColorMode == "custom" and fdb.powerColor or Power.Color(token)
        f.power:SetStatusBarColor(color[1], color[2], color[3], fdb.powerForegroundOpacity / 100)
    end
    self:UpdatePowerTexts(f, unit, textType, okText, textValue)
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
