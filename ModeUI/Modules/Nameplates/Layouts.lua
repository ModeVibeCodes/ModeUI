local _, addon = ...
local M = addon.Nameplates
if not M or not addon.Layouts then return end

-- The nameplates' part of the built-in Mode-Default layout (DPS / Tank,
-- Shared/Runtime/Layouts.lua; owner, November 18, 2026): aura icons 1px
-- apart, so neighbours share one shadow pixel like every icon in the layout
-- (an aura icon's border is inside its size, only its 1px shadow ring past
-- it). Everything else keeps its default. See docs/NAMEPLATES.md,
-- "Mode-Default layout".
addon.Layouts:Contribute("mode-default", "nameplates", function(db)
    db.enabled = true
    for _, kind in ipairs(M.kinds) do db[kind].auraSpacing = 1 end
end)
