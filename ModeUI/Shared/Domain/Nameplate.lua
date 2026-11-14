local _, addon = ...
local Q = addon.Domain.Query

-- The game's nameplate frames. Forbidden nameplates (friendly units inside
-- instances) are never returned to addon code, so they keep Blizzard's look.
local Nameplate = {}
addon.Domain.Nameplate = Nameplate
Nameplate.MAX_UNITS = 40 -- nameplate1 .. nameplate40

-- The nameplate frame for a nameplate unit token, or nil.
function Nameplate.ForUnit(unit)
    if not C_NamePlate then return end
    local ok, frame = Q.Call(C_NamePlate.GetNamePlateForUnit, unit, false)
    if ok and type(frame) == "table" then return frame end
end

-- The personal resource display: the player's own nameplate.
function Nameplate.IsPlayerPlate(frame)
    return frame ~= nil and Nameplate.ForUnit("player") == frame
end

-- Whether the player can attack the unit: an enemy plate, else a friendly one.
function Nameplate.IsEnemy(unit) return Q.Truthy(UnitCanAttack, "player", unit) end

-- Units whose nameplate shows only UI widgets (objects, some quest units).
function Nameplate.WidgetsOnly(unit) return Q.Truthy(UnitNameplateShowsWidgetsOnly, unit) end

-- Every nameplate unit token that has a nameplate right now.
function Nameplate.ActiveUnits()
    local units = {}
    for index = 1, Nameplate.MAX_UNITS do
        local unit = "nameplate" .. index
        if Nameplate.ForUnit(unit) then units[#units + 1] = unit end
    end
    return units
end
