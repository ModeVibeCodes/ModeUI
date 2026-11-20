local _, addon = ...
local M = addon.BuffsDebuffs
if not M then return end

-- Buffs & Debuffs' part of the Mode-Obsidian theme (docs/DESIGN_LANGUAGE.md,
-- "Mode-Obsidian theme"; Shared/Runtime/Themes.lua): every bar's icon border
-- in the style's own metal, so it draws Mode-Obsidian's (the styles follow
-- the theme in Style). Runs once per profile.
addon.Themes:Contribute("obsidian", "buffsDebuffs", function(db)
    for _, bar in pairs(type(db.bars) == "table" and db.bars or {}) do addon.Themes.DefaultMetal(bar) end
    for _, bar in pairs(type(db.customBars) == "table" and db.customBars or {}) do addon.Themes.DefaultMetal(bar) end
end)
