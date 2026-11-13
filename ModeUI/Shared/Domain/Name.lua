local _, addon = ...
local Q = addon.Domain.Query

-- Unit names can be secret: the result goes to FontString SetText only.
local Name = {}
addon.Domain.Name = Name

-- The unit's name (possibly secret), or "" when the client can't give one.
function Name.Get(unit)
    local ok, name = Q.Call(UnitName, unit)
    if not ok then return "" end
    return name
end
