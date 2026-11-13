local _, addon = ...
local Q = addon.Domain.Query

-- Unit health. UnitHealth is always secret on Forever and the maximum can be:
-- callers pass these values only to StatusBar SetMinMaxValues/SetValue and to
-- FontString SetText/SetFormattedText (see docs/API_COMPATIBILITY.md).
local Health = {}
addon.Domain.Health = Health

-- okMax, max, okValue, value: each value may be secret.
function Health.Read(unit)
    local okMax, max = Q.Call(UnitHealthMax, unit)
    local okValue, value = Q.Call(UnitHealth, unit)
    return okMax, max, okValue, value
end

-- ok, percent through a 0-100 curve (CurveConstants.ScaleTo100); may be secret.
function Health.Percent(unit, curve) return Q.Call(UnitHealthPercent, unit, true, curve) end

-- "Offline", "Ghost", "Dead" or nil while the unit is alive and connected.
function Health.State(unit)
    if not Q.Truthy(UnitIsConnected, unit) then return "Offline" end
    if Q.Truthy(UnitIsGhost, unit) then return "Ghost" end
    if Q.Truthy(UnitIsDeadOrGhost, unit) then return "Dead" end
end
