local _, addon = ...
local M = addon.Minimap
if not M then return end

-- The Minimap's part of the Mode-Obsidian theme (docs/DESIGN_LANGUAGE.md,
-- "Mode-Obsidian theme"; Shared/Runtime/Themes.lua): its borders in the
-- style's own metal, so they draw Mode-Obsidian's. Runs once per profile.
addon.Themes:Contribute("obsidian", "minimap", function(db)
    addon.Themes.DefaultMetal(db)
end)
