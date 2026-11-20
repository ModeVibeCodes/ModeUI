local _, addon = ...
local M = addon.DamageMeters
if not M then return end

-- Damage Meters' part of the Mode-Obsidian theme (docs/DESIGN_LANGUAGE.md,
-- "Mode-Obsidian theme"; Shared/Runtime/Themes.lua): each window's and
-- header's colors still at their Mode-Blizz tokens take Mode-Obsidian's.
addon.Themes:Contribute("obsidian", "damageMeters", function(db)
    local Swap = addon.Themes.SwapColor
    for _, window in ipairs(M.windows) do
        Swap(db[window], "backgroundColor", "graphite", "panel")
        Swap(db[window], "headerColor", "graphite", "raised")
        Swap(db[window], "titleColor", "graphite", "text")
        Swap(db[window], "timerColor", "graphite", "muted")
    end
end)
