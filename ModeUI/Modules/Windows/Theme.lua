local _, addon = ...
local M = addon.Windows
if not M then return end

-- Windows' part of the Mode-Obsidian theme (docs/DESIGN_LANGUAGE.md,
-- "Mode-Obsidian theme"; Shared/Runtime/Themes.lua): the window color still
-- at Graphite panel takes Mode-Obsidian's.
addon.Themes:Contribute("obsidian", "windows", function(db)
    addon.Themes.SwapColor(db, "backgroundColor", "graphite", "panel")
    addon.Themes.DefaultMetal(db)
end)
