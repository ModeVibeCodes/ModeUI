local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- Filling a plate from live unit data: health, name, colors and the raid
-- marker, each with the plate's own kind settings. Secret values go straight to
-- widgets that accept them. The target indicator is in Target.lua.
local Kit, Domain = addon.Kit, addon.Domain
local P, ONYX = Kit.palette, Kit.onyx
local Health, Name, UnitColor, Threat = Domain.Health, Domain.Name, Domain.UnitColor, Domain.Threat
M.reactionColors = { hostile = P.hostile, neutral = P.neutral, friendly = P.green, tapped = P.tapped }

function M:UpdatePlate(plate)
    if not plate.unit then return end
    self:UpdateName(plate)
    self:UpdateHealth(plate)
    self:UpdateHealthColor(plate)
    self:UpdateRaidIcon(plate)
    self:UpdateIndicator(plate)
    self:UpdateTarget(plate)
    self:UpdateFocus(plate)
    self:UpdateCombo(plate)
    self:UpdateSoftTarget(plate)
    self:UpdateCast(plate)
    self:UpdateAuras(plate)
end

function M:UpdateAll()
    if not self.byUnit then return end
    for _, plate in pairs(self.byUnit) do self:UpdatePlate(plate) end
end

function M:UpdateName(plate)
    local db = self:Style(plate)
    if not (db.showName or plate.nameOnly) or not plate.unit then return end
    self:WriteName(plate, Name.Get(plate.unit))
end

function M:UpdateHealth(plate)
    local unit, bar = plate.unit, plate.health
    if not unit then return end
    local okMax, max, okValue, value = Health.Read(unit)
    if okMax then pcall(bar.SetMinMaxValues, bar, 0, max) end
    if okValue then pcall(bar.SetValue, bar, value) end
    local mode = self:Style(plate).healthText
    if mode == "none" then return end
    -- Pickups and other objects keep their plate but show no health text.
    if Health.IsObject(unit) then Kit.Write(plate.healthText, ""); return end
    local state = Health.State(unit)
    if state then Kit.Write(plate.healthText, state)
    else Kit.ValueText(plate.healthText, mode, Health.Percent, unit, okValue, value) end
    self:PaintHealthText(plate)
end

-- The color for a style, given what is known about the unit: its class color
-- ({ r, g, b } fields, players only), its reaction ("hostile", "neutral",
-- "friendly", "tapped") and threat status (0-3). Colors are used as they are;
-- Health Opacity fades the bar instead. Shared with the preview.
function M:ColorFor(style, class, reaction, threat)
    local threatKey = style.threatColors and threat and self.threatColorKeys[threat]
    if threatKey then return style[threatKey] end
    local mode = style.healthColorMode
    if mode == "custom" then return style.healthColor end
    if mode == "onyx" then return ONYX.health end
    if mode == "reaction" and class then return { class.r, class.g, class.b } end
    return self.reactionColors[reaction] or ONYX.health
end

-- The class color for players, else the reaction color.
function M:IdentityColor(plate)
    local class = UnitColor.PlayerClass(plate.unit)
    if class then return { class.r, class.g, class.b } end
    return self.reactionColors[UnitColor.Reaction(plate.unit)]
end

-- Health colors go on the bar at the kind's Health Opacity.
function M:PaintHealthColor(plate, color)
    plate.health:SetStatusBarColor(color[1], color[2], color[3], self:Style(plate).healthOpacity / 100)
end

function M:HealthColor(plate)
    local unit, style = plate.unit, self:Style(plate)
    local class = style.healthColorMode == "reaction" and UnitColor.PlayerClass(unit) or nil
    local threat = style.threatColors and Threat.Status(unit) or nil
    return self:ColorFor(style, class, UnitColor.Reaction(unit), threat)
end

function M:UpdateHealthColor(plate)
    if not plate.unit then return end
    self:PaintHealthColor(plate, self:HealthColor(plate))
end

function M:UpdateRaidIcon(plate)
    if not self:Style(plate).showRaidIcon or not plate.unit then plate.raidIcon:Hide(); return end
    Domain.RaidIcon.Apply(plate.raidIcon, plate.unit)
end
