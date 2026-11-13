local _, addon = ...
local Q, Number = addon.Domain.Query, addon.IsNumber

-- The player's combo points. On Forever they live on the target, as in the
-- Camelot ComboFrame (GetComboPoints("player", "target")). The count may be
-- secret (SecretWhenUnitPowerRestricted): pass it only to StatusBar
-- SetValue, never compare it.
local ComboPoints = {}
addon.Domain.ComboPoints = ComboPoints
ComboPoints.MAX = 10
-- Camelot's ComboFrame shows at most five (MAX_COMBO_POINTS); used when the
-- client can't report the player's maximum.
ComboPoints.DEFAULT_MAX = 5
local HAS_POINTS = { ROGUE = true, DRUID = true }

local function PowerType() return Enum and Enum.PowerType and Enum.PowerType.ComboPoints end

-- ok, count (may be secret).
function ComboPoints.Read()
    local ok, count = Q.Call(GetComboPoints, "player", "target")
    if ok and count ~= nil then return true, count end
    local powerType = PowerType()
    if powerType == nil then return false end
    ok, count = Q.Call(UnitPower, "player", powerType)
    return ok and count ~= nil, count
end

-- How many points the player can hold (public), 0 for a class without them.
function ComboPoints.Max()
    local _, class = Q.Plain(UnitClass, "player")
    if type(class) == "string" and not HAS_POINTS[class] then return 0 end
    local powerType = PowerType()
    local max = powerType ~= nil and Q.Plain(UnitPowerMax, "player", powerType) or nil
    if Number(max, 1, ComboPoints.MAX) then return math.floor(max) end
    return HAS_POINTS[class] and ComboPoints.DEFAULT_MAX or 0
end

-- True while the player builds combo points: a Rogue, or a Druid in Cat Form
-- (the only form whose power is Energy).
function ComboPoints.Active()
    if ComboPoints.Max() == 0 then return false end
    local _, class = Q.Plain(UnitClass, "player")
    if class ~= "DRUID" then return true end
    local _, token = Q.Plain(UnitPowerType, "player")
    return token == "ENERGY"
end
