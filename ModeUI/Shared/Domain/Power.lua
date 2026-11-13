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
