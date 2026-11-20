local _, addon = ...
local M = addon.Tooltip
if not M then return end

-- Tooltip's part of the Mode-Obsidian theme (docs/DESIGN_LANGUAGE.md,
-- "Mode-Obsidian theme"; Shared/Runtime/Themes.lua): the background still at
-- Graphite panel takes Mode-Obsidian's.
addon.Themes:Contribute("obsidian", "tooltip", function(db)
    addon.Themes.SwapColor(db, "backgroundColor", "graphite", "panel")
    addon.Themes.DefaultMetal(db)
end)
