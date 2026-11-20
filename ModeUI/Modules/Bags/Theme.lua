local _, addon = ...
local M = addon.Bags
if not M then return end

-- Bags' part of the Mode-Obsidian theme (docs/DESIGN_LANGUAGE.md,
-- "Mode-Obsidian theme"; Shared/Runtime/Themes.lua): the window, header and
-- slot colors still at their Mode-Blizz tokens take Mode-Obsidian's.
addon.Themes:Contribute("obsidian", "bags", function(db)
    local Swap = addon.Themes.SwapColor
    Swap(db, "backgroundColor", "graphite", "panel")
    Swap(db, "headerColor", "graphite", "raised")
    Swap(db, "slotColor", "mono", "panel")
    addon.Themes.DefaultMetal(db)
end)
