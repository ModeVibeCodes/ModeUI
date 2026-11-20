local _, addon = ...
local M = addon.ActionBars
if not M then return end

-- Action Bars' part of the Mode-Obsidian theme (docs/DESIGN_LANGUAGE.md,
-- "Mode-Obsidian theme"; Shared/Runtime/Themes.lua): button faces still at
-- Mono panel take Mode-Obsidian's. Borders follow the theme in Style.
addon.Themes:Contribute("obsidian", "actionBars", function(db)
    for _, bar in ipairs(M.bars) do addon.Themes.SwapColor(db[bar], "backgroundColor", "mono", "panel") end
end)
