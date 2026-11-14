local _, addon = ...
local Q, Number = addon.Domain.Query, addon.IsNumber

-- The player's class resource: points a class builds and spends, shown one
-- socket per point. Each class that has one is an entry in CLASSES; a class
-- without one has no resource, and nothing shows for it.
--
-- WoW Forever runs Camelot (classic) unit frames: its Blizzard_UnitFrame.toc
-- loads only the Rogue and Druid combo point bars for Camelot
-- (RogueComboPointBar, DruidComboPointBar, TargetBoundComboPointBar) and
-- excludes Holy Power, Soul Shards, Chi, Runes, Arcane Charges and Essence. So
-- on Forever: Rogues, and Druids in Cat Form, have combo points; other classes
-- have none. Combo points live on the target, as in the Camelot ComboFrame
-- (GetComboPoints("player", "target")). The count may be secret
-- (SecretWhenUnitPowerRestricted): pass it only to StatusBar SetValue, never
-- compare it.
local ClassResource = {}
addon.Domain.ClassResource = ClassResource
ClassResource.MAX = 10
-- Camelot's ComboFrame shows at most five (MAX_COMBO_POINTS); used when the
-- client can't report the player's maximum.
ClassResource.DEFAULT_MAX = 5

local function ComboPowerType() return Enum and Enum.PowerType and Enum.PowerType.ComboPoints end
local function ReadCombo()
    local ok, count = Q.Call(GetComboPoints, "player", "target")
    if ok and count ~= nil then return true, count end
    local powerType = ComboPowerType()
    if powerType == nil then return false end
    ok, count = Q.Call(UnitPower, "player", powerType)
    return ok and count ~= nil, count
end
local function ComboMax()
    local powerType = ComboPowerType()
    local max = powerType ~= nil and Q.Plain(UnitPowerMax, "player", powerType) or nil
    if Number(max, 1, ClassResource.MAX) then return math.floor(max) end
    return ClassResource.DEFAULT_MAX
end

-- name: what the resource is called. active(): whether the player builds it
-- right now. read(): ok, count (may be secret). max(): public point count.
local COMBO = { name = "Combo Points", read = ReadCombo, max = ComboMax, active = function() return true end }
-- Druids build combo points in Cat Form, the only form whose power is Energy.
local FERAL = { name = "Combo Points", read = ReadCombo, max = ComboMax, active = function()
    local _, token = Q.Plain(UnitPowerType, "player")
    return token == "ENERGY"
end, when = "in Cat Form" }
ClassResource.CLASSES = { ROGUE = COMBO, DRUID = FERAL }

local function Class()
    local _, class = Q.Plain(UnitClass, "player")
    return type(class) == "string" and class or nil
end
-- The player's class resource, or nil for a class without one.
function ClassResource.Spec() local class = Class(); return class and ClassResource.CLASSES[class] or nil end
-- The player's class name as the game shows it, or "".
function ClassResource.ClassName()
    local name = Q.Plain(UnitClass, "player")
    return type(name) == "string" and name or ""
end

-- ok, count (may be secret).
function ClassResource.Read()
    local spec = ClassResource.Spec()
    if not spec then return false end
    return spec.read()
end
-- How many points the player can hold (public), 0 for a class without a resource.
function ClassResource.Max()
    local spec = ClassResource.Spec()
    return spec and spec.max() or 0
end
-- True while the player builds the resource.
function ClassResource.Active()
    local spec = ClassResource.Spec()
    return spec ~= nil and spec.active() and ClassResource.Max() > 0
end
