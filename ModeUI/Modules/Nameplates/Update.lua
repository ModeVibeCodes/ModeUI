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
    self:UpdateTarget(plate)
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
    Kit.Write(plate.name, Name.Get(plate.unit))
    if not plate.targeted then
        local color = self:NameColor(plate)
        plate.name:SetTextColor(color[1], color[2], color[3], 1)
    end
end

function M:UpdateHealth(plate)
    local unit, bar = plate.unit, plate.health
    if not unit then return end
    local okMax, max, okValue, value = Health.Read(unit)
    if okMax then pcall(bar.SetMinMaxValues, bar, 0, max) end
    if okValue then pcall(bar.SetValue, bar, value) end
    local mode = self:Style(plate).healthText
    if mode == "none" then return end
    local state = Health.State(unit)
    if state then Kit.Write(plate.healthText, state)
    else Kit.ValueText(plate.healthText, mode, Health.Percent, unit, okValue, value) end
end

local function Soften(color, softness)
    if not color or softness <= 0 then return color end
    return Kit.Lighten(color, softness / 100)
end

-- The color for a style, given what is known about the unit: its class color
-- ({ r, g, b } fields, players only), its reaction ("hostile", "neutral",
-- "friendly", "tapped") and threat status (0-3). Shared with the preview.
function M:ColorFor(style, class, reaction, threat)
    if style.threatColors then
        if threat == 3 then return self.threatPalette.aggro end
        if threat == 1 or threat == 2 then return self.threatPalette.warning end
    end
    local mode = style.healthColorMode
    if mode == "custom" then return style.healthColor end
    if mode == "onyx" then return ONYX.health end
    if mode == "reaction" and class then return Soften({ class.r, class.g, class.b }, style.softness) end
    if reaction == "tapped" then return self.reactionColors.tapped end
    return Soften(self.reactionColors[reaction] or ONYX.health, style.softness)
end

-- The class color for players, else the reaction color, softened like health.
function M:IdentityColor(plate)
    local style, unit = self:Style(plate), plate.unit
    local class = UnitColor.PlayerClass(unit)
    if class then return Soften({ class.r, class.g, class.b }, style.softness) end
    local reaction = UnitColor.Reaction(unit)
    return Soften(self.reactionColors[reaction], style.softness)
end

function M:HealthColor(plate)
    local unit, style = plate.unit, self:Style(plate)
    local class = style.healthColorMode == "reaction" and UnitColor.PlayerClass(unit) or nil
    local threat = style.threatColors and Threat.Status(unit) or nil
    return self:ColorFor(style, class, UnitColor.Reaction(unit), threat)
end

function M:UpdateHealthColor(plate)
    if not plate.unit then return end
    local color = self:HealthColor(plate)
    plate.health:SetStatusBarColor(color[1], color[2], color[3])
end

function M:UpdateRaidIcon(plate)
    if not self:Style(plate).showRaidIcon or not plate.unit then plate.raidIcon:Hide(); return end
    Domain.RaidIcon.Apply(plate.raidIcon, plate.unit)
end
