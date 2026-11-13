local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- Filling a plate from live unit data: health, name, colors, raid marker and
-- the target highlight. Secret values go straight to widgets that accept them.
local Kit, Domain = addon.Kit, addon.Domain
local P, ONYX = Kit.palette, Kit.onyx
local Health, Name, UnitColor, Threat = Domain.Health, Domain.Name, Domain.UnitColor, Domain.Threat
local REACTION = { hostile = P.hostile, neutral = P.neutral, friendly = P.green, tapped = P.tapped }

function M:UpdatePlate(plate)
    if not plate.unit then return end
    self:UpdateName(plate)
    self:UpdateHealth(plate)
    self:UpdateHealthColor(plate)
    self:UpdateRaidIcon(plate)
    self:UpdateTarget(plate)
    self:UpdateCast(plate)
end

function M:UpdateAll()
    if not self.byUnit then return end
    for _, plate in pairs(self.byUnit) do self:UpdatePlate(plate) end
end

function M:UpdateName(plate)
    if not self.db.showName or not plate.unit then return end
    Kit.Write(plate.name, Name.Get(plate.unit))
end

function M:UpdateHealth(plate)
    local unit, bar = plate.unit, plate.health
    if not unit then return end
    local okMax, max, okValue, value = Health.Read(unit)
    if okMax then pcall(bar.SetMinMaxValues, bar, 0, max) end
    if okValue then pcall(bar.SetValue, bar, value) end
    local mode = self.db.healthText
    if mode == "none" then return end
    local state = Health.State(unit)
    if state then Kit.Write(plate.healthText, state)
    else Kit.ValueText(plate.healthText, mode, Health.Percent, unit, okValue, value) end
end

local function Soften(color, softness)
    if not color or softness <= 0 then return color end
    return Kit.Lighten(color, softness / 100)
end

-- Threat (when on and known) wins, then the chosen color mode.
function M:HealthColor(unit)
    local db = self.db
    if db.threatColors then
        local status = Threat.Status(unit)
        if status == 3 then return self.threatPalette.aggro end
        if status == 1 or status == 2 then return self.threatPalette.warning end
    end
    local mode = db.healthColorMode
    if mode == "custom" then return db.healthColor end
    if mode == "onyx" then return ONYX.health end
    if mode == "reaction" then
        local class = UnitColor.PlayerClass(unit)
        if class then return Soften({ class.r, class.g, class.b }, db.softness) end
    end
    local reaction = UnitColor.Reaction(unit)
    if reaction == "tapped" then return REACTION.tapped end
    return Soften(REACTION[reaction] or ONYX.health, db.softness)
end

function M:UpdateHealthColor(plate)
    if not plate.unit then return end
    local color = self:HealthColor(plate.unit)
    plate.health:SetStatusBarColor(color[1], color[2], color[3])
end

function M:UpdateRaidIcon(plate)
    if not self.db.showRaidIcon or not plate.unit then plate.raidIcon:Hide(); return end
    Domain.RaidIcon.Apply(plate.raidIcon, plate.unit)
end

-- The target's nameplate frame is compared directly, so no secret unit
-- comparison is needed.
function M:UpdateTarget(plate, targetPlate)
    if targetPlate == nil then targetPlate = Domain.Nameplate.ForUnit("target") or false end
    local targeted = self.db.targetHighlight and plate.unit ~= nil and plate.nameplate == targetPlate
    local rim = targeted and P.accent or ONYX.border
    Kit.Tint(plate.healthBox.rim, rim, 1)
    Kit.Tint(plate.castBox.rim, rim, 1)
    plate.targeted = targeted
end

function M:UpdateTargets()
    local targetPlate = Domain.Nameplate.ForUnit("target") or false
    for _, plate in pairs(self.byUnit) do self:UpdateTarget(plate, targetPlate) end
end
