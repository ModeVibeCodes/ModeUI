local _, addon = ...
local Q = addon.Domain.Query

-- Unit power. Values may be secret; pass them only to StatusBar and FontString
-- methods documented as accepting secret values.
local Power = {}
addon.Domain.Power = Power

local function RGB(r, g, b) return { r / 255, g / 255, b / 255 } end
-- Mode-toned power colors; no dependency on Blizzard's PowerBarColor table.
Power.colors = { MANA = RGB(64, 150, 255), RAGE = { 0.86, 0.30, 0.30 }, ENERGY = { 0.95, 0.82, 0.35 },
    FOCUS = { 0.95, 0.58, 0.30 }, HAPPINESS = { 0.35, 0.80, 0.70 } }
Power.defaultColor = { 0.55, 0.55, 0.60 }

-- powerType, token (public or nil), okMax, max, okValue, value.
function Power.Read(unit)
    local powerType, token = Q.Plain(UnitPowerType, unit)
    local okMax, max = Q.Call(UnitPowerMax, unit, powerType)
    local okValue, value = Q.Call(UnitPower, unit, powerType)
    return powerType, token, okMax, max, okValue, value
end

-- ok, percent through a 0-100 curve; may be secret.
function Power.Percent(unit, powerType, curve) return Q.Call(UnitPowerPercent, unit, powerType, false, curve) end

function Power.Color(token)
    return (type(token) == "string" and Power.colors[token]) or Power.defaultColor
end

-- The mana power type (Enum.PowerType.Mana; 0 on every client).
function Power.ManaType() return Enum and Enum.PowerType and Enum.PowerType.Mana or 0 end

-- One power type's okMax, max, okValue, value (each value may be secret).
function Power.ReadType(unit, powerType)
    local okMax, max = Q.Call(UnitPowerMax, unit, powerType)
    local okValue, value = Q.Call(UnitPower, unit, powerType)
    return okMax, max, okValue, value
end

-- Classes whose mana runs on under another power in some forms. On Forever
-- that is the Druid in Bear Form (Rage) and Cat Form (Energy). Blizzard's
-- AlternatePowerBar, which Forever loads, pairs a Druid's mana only with
-- Lunar Power, which Camelot Druids never have, so the game shows no mana
-- bar in those forms.
Power.ALTERNATE_MANA = { DRUID = true }
-- True for such a class.
function Power.HasAlternateMana(unit)
    local _, class = Q.Plain(UnitClass, unit)
    return type(class) == "string" and Power.ALTERNATE_MANA[class] == true
end
-- True while the unit is such a class and its shown power isn't mana.
function Power.AlternateManaActive(unit)
    if not Power.HasAlternateMana(unit) then return false end
    local _, token = Q.Plain(UnitPowerType, unit)
    return type(token) == "string" and token ~= "MANA"
end
