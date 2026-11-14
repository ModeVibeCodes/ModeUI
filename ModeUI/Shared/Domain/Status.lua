local _, addon = ...
local Q = addon.Domain.Query

-- Rest and combat state. On Forever UnitAffectingCombat and UnitCanAttack
-- return plain booleans (no secret flags in UnitDocumentation); IsResting is
-- the global Blizzard's PlayerFrame reads. A missing or failed answer is "no".
local Status = {}
addon.Domain.Status = Status

function Status.Resting() return Q.Truthy(IsResting) end
function Status.InCombat(unit) return Q.Truthy(UnitAffectingCombat, unit) end
function Status.CanAttack(unit) return Q.Truthy(UnitCanAttack, "player", unit) end
function Status.Exists(unit) return Q.Truthy(UnitExists, unit) end

-- Something pulled you that you aren't fighting: you're in combat, and you
-- have no enemy targeted, or your target isn't in combat. Threat would be
-- exact but can be secret (SecretWhenUnitThreatStateRestricted), so the
-- target's own combat state stands in for "it is fighting you".
function Status.PulledUnawares()
    if not Status.InCombat("player") then return false end
    local engaged = Status.Exists("target") and Status.CanAttack("target") and Status.InCombat("target")
    return not engaged
end
