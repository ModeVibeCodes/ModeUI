local _, addon = ...
local M = addon.DamageMeters
if not M or not addon.Layouts then return end

-- Damage Meters' part of the built-in Mode-Default layout (DPS / Tank,
-- Shared/Runtime/Layouts.lua): Damage Done in the bottom-right corner, 6
-- rows, with Healing Done (3 rows) stacked on it, 4 units apart, the same
-- width (Edit Mode's Match Width, picked on Window 1). Window 3 stays off.
-- The window's `window` edge sits inside it (Layout.lua, M.Geometry), so
-- what shows is exactly Width wide: 230, the same as the minimap's outer
-- edge in this layout (Modules/Minimap/Layouts.lua). Heights follow the
-- rows: 3 + 20 + 1 + 1 + 6 x 23 + 5 x 1 + 1 + 3 = 172 and, for 3 rows, 100
-- (both even, so no pixel is added). The same at 1080 and 1440.
-- See docs/DAMAGE_METERS.md, "Mode-Default layout".
local WIDTH = 230
local ROWS = { window1 = 6, window2 = 3 }

addon.Layouts:Contribute("mode-default", "damageMeters", function(db, ctx)
    db.enabled = true
    for window, rows in pairs(ROWS) do
        local style = db[window]
        style.show, style.group = true, "none"
        style.width, style.rows, style.rowHeight, style.spacing, style.padding = WIDTH, rows, 23, 1, 1
        style.header, style.headerHeight = true, 20
    end
    db.window1.meterType, db.window2.meterType = "damageDone", "healingDone"
    db.window2.matchWidth = true
    db.window3.show = false
    ctx.Place(M.elementIds.window1, "screen", "BOTTOMRIGHT", "BOTTOMRIGHT", -8, 8)
    ctx.Place(M.elementIds.window2, M.elementIds.window1, "BOTTOM", "TOP", 0, 4)
    ctx.Match(M.elementIds.window2, "width", M.elementIds.window1)
end)
