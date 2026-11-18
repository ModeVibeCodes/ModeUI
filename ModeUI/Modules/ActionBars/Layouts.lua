local _, addon = ...
local M = addon.ActionBars
if not M or not addon.Layouts then return end

-- Action Bars' part of the built-in Mode-Default layout (DPS / Tank,
-- Shared/Runtime/Layouts.lua): Action Bars 1-4 a 2 x 2 grid centered on the
-- bottom edge, 36 x 30 buttons 2px apart, 12 in a row; the pet bar over the
-- left column and the stance bar over the right one, filling from its right
-- end; the micro menu in two rows of 8 in the top-left corner with the bag
-- bar beside it. Action Bar 5 is off (6-8 stay off). The same at 1080 and
-- 1440. See docs/ACTION_BARS.md, "Mode-Default layout".
-- A bar's element holds its buttons' `frame` edges (3px each side; Layout.lua,
-- M.Geometry), as the owner's layout editor drew them: Action Bars 1-4 are
-- 12 x (36 + 6) + 11 x 2 = 526 wide and 36 tall, so 4 either side of the
-- middle centers the grid.
local ID = M.elementIds

local function Set(style, values) for key, value in pairs(values) do style[key] = value end end

addon.Layouts:Contribute("mode-default", "actionBars", function(db, ctx)
    db.enabled = true
    for _, bar in ipairs({ "bar1", "bar2", "bar3", "bar4" }) do
        Set(db[bar], { show = true, width = 36, height = 30, spacing = 2, buttons = 12, perLine = 12, orientation = "horizontal" })
    end
    db.bar5.show = false
    for _, bar in ipairs({ "pet", "stance" }) do
        Set(db[bar], { width = 30, height = 24, spacing = 2, perLine = 10, orientation = "horizontal" })
    end
    -- Stance buttons start at the bar's right end, so the bar (as wide as
    -- the character's stances) grows left from the right column's edge.
    db.stance.start = "TOPRIGHT"
    -- Two rows of 8; the second goes below the first (First Button: Top Left).
    Set(db.micro, { perLine = 8, orientation = "horizontal", start = "TOPLEFT" })

    ctx.Place(ID.bar1, "screen", "BOTTOMRIGHT", "BOTTOM", -4, 8)
    ctx.Place(ID.bar2, ID.bar1, "LEFT", "RIGHT", 8, 0)
    ctx.Place(ID.bar3, ID.bar1, "BOTTOM", "TOP", 0, 4)
    ctx.Place(ID.bar4, ID.bar2, "BOTTOM", "TOP", 0, 4)
    ctx.Place(ID.pet, ID.bar3, "BOTTOMLEFT", "TOPLEFT", 0, 4)
    ctx.Place(ID.stance, ID.bar4, "BOTTOMRIGHT", "TOPRIGHT", 0, 4)
    ctx.Place(ID.micro, "screen", "TOPLEFT", "TOPLEFT", 8, -8)
    ctx.Place(ID.bags, ID.micro, "TOPLEFT", "TOPRIGHT", 8, 0)
end)
