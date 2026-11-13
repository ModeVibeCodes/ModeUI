local _, addon = ...
local Q, Number = addon.Domain.Query, addon.IsNumber

local Level = {}
addon.Domain.Level = Level

local ELITE = { elite = true, rareelite = true, worldboss = true }

-- "60", "60+" for elites and bosses, "??" for a skull level, "" if unknown.
function Level.Text(unit)
    local level = Q.Plain(UnitLevel, unit)
    local classification = Q.Plain(UnitClassification, unit)
    local text = Number(level, 1, 1000) and tostring(level) or (Number(level, -1, -1) and "??" or "")
    if ELITE[classification] then text = text .. "+" end
    return text
end
