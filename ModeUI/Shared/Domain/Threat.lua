local _, addon = ...
local Q, Number = addon.Domain.Query, addon.IsNumber

-- The player's threat on a unit. UnitThreatSituation is secret while the game
-- restricts threat (SecretWhenUnitThreatStateRestricted); then it's unknown.
local Threat = {}
addon.Domain.Threat = Threat

-- 0 no threat, 1 high threat, 2 has aggro but not the highest threat,
-- 3 securely tanking; nil when unknown, secret or not in the threat list.
function Threat.Status(unit)
    local status = Q.Plain(UnitThreatSituation, "player", unit)
    if Number(status, 0, 3) then return status end
end

-- A unit's own threat on whatever it is fighting (UnitThreatSituation with no
-- mob): 2 or 3 means some mob is attacking it. Same scale and secrecy as
-- Status; nil when unknown.
function Threat.Aggro(unit)
    local status = Q.Plain(UnitThreatSituation, unit)
    if Number(status, 0, 3) then return status end
end
