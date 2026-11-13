local _, addon = ...
local Q, Number = addon.Domain.Query, addon.IsNumber

local Level = {}
addon.Domain.Level = Level

local ELITE = { elite = true, rareelite = true, worldboss = true }

-- The level as a plain number (-1 for a skull level), or nil when unknown
-- or secret.
function Level.Number(unit)
    local level = Q.Plain(UnitLevel, unit)
    if Number(level, -1, 1000) and level ~= 0 then return level end
end

-- "normal", "elite", "rareelite", "rare", "worldboss", "trivial", "minus", or
-- nil when unknown or secret.
function Level.Classification(unit)
    local classification = Q.Plain(UnitClassification, unit)
    if type(classification) == "string" then return classification end
end

-- The game's difficulty color for a level ({ r, g, b }), or nil.
function Level.DifficultyColor(level)
    if type(GetCreatureDifficultyColor) ~= "function" or not Number(level, 1, 1000) then return nil end
    local ok, color = pcall(GetCreatureDifficultyColor, level)
    if ok and type(color) == "table" and Number(color.r, 0, 1) then return { color.r, color.g, color.b } end
end

-- "60", "60+" for elites and bosses, "??" for a skull level, "" if unknown.
function Level.Text(unit)
    local level = Q.Plain(UnitLevel, unit)
    local classification = Q.Plain(UnitClassification, unit)
    local text = Number(level, 1, 1000) and tostring(level) or (Number(level, -1, -1) and "??" or "")
    if ELITE[classification] then text = text .. "+" end
    return text
end
