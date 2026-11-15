local _, addon = ...
-- Combined shields with the Hairline texture (docs/DESIGN_LANGUAGE.md, "Bars").
-- Below max health the shield is attached to the end of health and stops at the
-- end of the bar: an attached StatusBar fed the shield clamped to missing health
-- by Blizzard's heal prediction calculator. At full health the whole shield fills
-- back from max: a reverse StatusBar fed the total shield, shown only at full
-- health through a step curve on UnitHealthPercent (SetAlpha accepts the secret
-- result). Every amount may be secret and only reaches SetValue.
local Style = addon.Style
local Tone = Style.Tone

local LINE_ALPHA = 0.45
local LIFT_ALPHA = 0.42
local OVERFLOW_LIGHT = 0.09

local fullCurve
-- 0 below full health, 1 at full health.
local function FullHealthCurve()
    if fullCurve ~= nil then return fullCurve or nil end
    fullCurve = false
    local util = C_CurveUtil
    if type(util) == "table" and type(util.CreateCurve) == "function" then
        local ok, curve = pcall(util.CreateCurve)
        if ok and curve then
            if curve.SetType and Enum and Enum.LuaCurveType then pcall(curve.SetType, curve, Enum.LuaCurveType.Step) end
            pcall(curve.AddPoint, curve, 0, 0)
            pcall(curve.AddPoint, curve, 0.9995, 0)
            pcall(curve.AddPoint, curve, 1, 1)
            fullCurve = curve
        end
    end
    return fullCurve or nil
end

local function Layer(bar, frame, sublevel)
    -- The faint lift: the bar's own color added (ADD), so the shield keeps the
    -- bar's hue instead of washing it white; it stretches with the fill.
    local lift = frame:CreateTexture(nil, "ARTWORK", nil, sublevel)
    Style.ApplyAsset(lift, "Solid")
    lift:SetBlendMode("ADD")
    -- The Hairline lines span the whole bar, tiled 1:1, inside a clip that
    -- follows the fill: the pattern stays put on the bar (and lines up between
    -- the attached and full shields) instead of stretching with the amount.
    local clip = CreateFrame("Frame", nil, frame)
    clip:SetClipsChildren(true)
    local lines = clip:CreateTexture(nil, "ARTWORK", nil, sublevel + 1)
    Style.ApplyAsset(lines, "Shield")
    lines:SetBlendMode("ADD")
    lines:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    lines:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    return lift, lines, clip
end

local Shield = {}
Shield.__index = Shield

-- Adds a shield to a Style.Bar. The bar must be the unit's health bar.
function Style.Shield(bar)
    local shield = setmetatable({ bar = bar }, Shield)
    -- Attached: starts at the health fill's edge, as wide as the whole bar,
    -- inside a clip so nothing passes the bar's end.
    shield.clip = CreateFrame("Frame", nil, bar)
    shield.clip:SetAllPoints(bar)
    shield.clip:SetClipsChildren(true)
    shield.attached = CreateFrame("StatusBar", nil, shield.clip)
    shield.attached:SetStatusBarTexture(Style.AssetPath("Solid"))
    shield.attached:GetStatusBarTexture():SetAlpha(0)
    shield.attachedLift, shield.attachedLines, shield.attachedClip = Layer(bar, shield.attached, 4)
    -- From max: right to left, full width.
    shield.full = CreateFrame("StatusBar", nil, bar)
    shield.full:SetAllPoints(bar)
    shield.full:SetReverseFill(bar.reverse ~= true)
    shield.full:SetStatusBarTexture(Style.AssetPath("Solid"))
    shield.full:GetStatusBarTexture():SetAlpha(0)
    shield.fullLift, shield.fullLines, shield.fullClip = Layer(bar, shield.full, 4)
    shield.fullLight = shield.full:CreateTexture(nil, "ARTWORK", nil, 6)
    Style.ApplyAsset(shield.fullLight, "Solid")
    shield.fullLight:SetVertexColor(1, 1, 1, OVERFLOW_LIGHT)
    -- The finish line on the shield's end, and its glow.
    shield.finish = shield.attached:CreateTexture(nil, "OVERLAY", nil, 2)
    Style.ApplyAsset(shield.finish, "Solid")
    shield.finishGlow = shield.attached:CreateTexture(nil, "OVERLAY", nil, 1)
    Style.ApplyAsset(shield.finishGlow, "LineGlow")
    shield.fullFinish = shield.full:CreateTexture(nil, "OVERLAY", nil, 2)
    Style.ApplyAsset(shield.fullFinish, "Solid")
    for _, frame in ipairs({ shield.attached, shield.full }) do
        frame:SetFrameLevel(bar:GetFrameLevel() + 1)
        frame:SetMinMaxValues(0, 1)
        frame:SetValue(0)
    end
    bar.shield = shield
    shield:Layout()
    shield:Paint()
    return shield
end

-- Fits a texture or clip frame to a StatusBar's fill.
local function Fit(texture, fill)
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, 0)
    texture:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0)
end

function Shield:Layout()
    local bar, px = self.bar, Style.Pixel(self.bar)
    -- A bar gets its fill texture when its owner styles it; lay out from then on.
    local healthFill = bar:GetStatusBarTexture()
    if not healthFill then return end
    local side = bar.reverse and "LEFT" or "RIGHT"
    local away = bar.reverse and "RIGHT" or "LEFT"
    self.attached:ClearAllPoints()
    self.attached:SetPoint("TOP" .. away, healthFill, "TOP" .. side)
    self.attached:SetPoint("BOTTOM" .. away, healthFill, "BOTTOM" .. side)
    self.attached:SetWidth(math.max(1, bar:GetWidth()))
    -- SetReverseFill takes a boolean only.
    self.attached:SetReverseFill(bar.reverse == true)
    self.full:SetReverseFill(bar.reverse ~= true)
    local attachedFill, fullFill = self.attached:GetStatusBarTexture(), self.full:GetStatusBarTexture()
    Fit(self.attachedLift, attachedFill); Fit(self.attachedClip, attachedFill)
    Fit(self.fullLift, fullFill); Fit(self.fullClip, fullFill); Fit(self.fullLight, fullFill)
    -- Hairline tiles 1:1 over the whole bar (a line every 8px along it).
    local w, h = bar:GetWidth(), bar:GetHeight()
    Style.TileCoords(self.attachedLines, "Shield", w, h, px)
    Style.TileCoords(self.fullLines, "Shield", w, h, px)
    for _, pair in ipairs({ { self.finish, attachedFill }, { self.fullFinish, fullFill } }) do
        local line, fill = pair[1], pair[2]
        local edge = (line == self.finish) and side or away
        line:ClearAllPoints()
        line:SetPoint("TOP" .. edge, fill, "TOP" .. edge)
        line:SetPoint("BOTTOM" .. edge, fill, "BOTTOM" .. edge)
        line:SetWidth(px)
    end
    self.finishGlow:ClearAllPoints()
    self.finishGlow:SetPoint("CENTER", self.finish, "CENTER")
    self.finishGlow:SetSize(5 * px, math.max(1, h))
end

-- Lift and lines tinted from the bar's own color (lightened), so the shield
-- reads as the same material, a step brighter.
function Shield:Paint()
    local tint = Style.Lighten(self.bar.fillColor or Tone.darkFill, 0.45)
    for _, lift in ipairs({ self.attachedLift, self.fullLift }) do lift:SetVertexColor(tint[1], tint[2], tint[3], LIFT_ALPHA) end
    for _, lines in ipairs({ self.attachedLines, self.fullLines }) do lines:SetVertexColor(1, 1, 1, LINE_ALPHA) end
    for _, line in ipairs({ self.finish, self.fullFinish }) do line:SetVertexColor(0.965, 0.973, 0.984, 1) end
end

-- Feeds the shield from Domain.Group.Prediction(unit, calculator): `shield`
-- (clamped to missing health), `total` and `max`. Values may be secret.
function Shield:Update(unit, prediction)
    local max = prediction.max or 1
    self.attached:SetMinMaxValues(0, max)
    self.full:SetMinMaxValues(0, max)
    self.attached:SetValue(prediction.shield or 0)
    self.full:SetValue(prediction.total or prediction.shield or 0)
    local curve = FullHealthCurve()
    local okFull, full = false, nil
    if curve and unit then okFull, full = pcall(UnitHealthPercent, unit, false, curve) end
    if okFull and full ~= nil then
        self.full:SetAlpha(full)
        if addon.IsPublic(full) then self.attached:SetAlpha(1 - full) end
    else
        -- No curve: attached only (never fills back from max).
        self.full:SetAlpha(0)
    end
    self:Paint()
end

function Shield:SetShown(shown)
    self.clip:SetShown(shown)
    self.full:SetShown(shown)
end
