local _, addon = ...
local Q, Public, Number = addon.Domain.Query, addon.IsPublic, addon.IsNumber

-- Where the player is: the minimap's zone name, the zone's PvP type and the
-- player's position on the current map. Every call is guarded; a missing
-- API or a secret answer counts as unknown.
local Location = {}
addon.Domain.Location = Location

-- ok, text: the minimap's zone name. The text goes straight to SetText, so
-- it may be secret; it's never compared or joined here.
function Location.ZoneText()
    return Q.Call(GetMinimapZoneText)
end

-- The zone's PvP type ("friendly", "contested", "hostile", "sanctuary",
-- "arena", "combat"), or nil.
function Location.PvPType()
    if not (C_PvP and C_PvP.GetZonePVPInfo) then return nil end
    local pvpType = Q.Plain(C_PvP.GetZonePVPInfo)
    if type(pvpType) == "string" then return pvpType end
end

-- The player's position on their current map in percent (0-100), or nil
-- (instances often have no position).
function Location.PlayerPosition()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local mapID = Q.Plain(C_Map.GetBestMapForUnit, "player")
    if not Number(mapID) then return nil end
    local ok, position = Q.Call(C_Map.GetPlayerMapPosition, mapID, "player")
    if not ok or not Public(position) or type(position) ~= "table" or type(position.GetXY) ~= "function" then return nil end
    local x, y = Q.Plain(position.GetXY, position)
    if Number(x, 0, 1) and Number(y, 0, 1) and not (x == 0 and y == 0) then return x * 100, y * 100 end
end
