local _, addon = ...
local M = addon.DamageMeters
if not M then return end

-- Pixel-perfect window geometry. Sizes in the settings are interface units,
-- snapped to whole physical pixels; Border Size is in physical pixels. The
-- window is exactly as tall as its rows, and an even number of pixels each
-- way, so a centered window stays on the pixel grid.
--
--   rim (Border Size) | header (Header Height) | 1px divider in the rim color
--   | Padding | rows (Row Height, Spacing apart) | Padding | rim
--
-- Each row is an optional square class icon, a gap, then the bar; the name
-- and value sit on the bar, Text Inset in from its ends.

-- style: a window's settings; px: one physical pixel; rows: how many rows to
-- fit (the window's Rows by default; the breakdown passes its own).
function M.Geometry(style, px, rows)
    px = px or 1
    local function Snap(v) return math.max(px, math.floor(v / px + 0.5) * px) end
    local function Round(v) return math.floor(v / px + 0.5) * px end
    local function Odd(v) return math.floor(v / px + 0.5) % 2 == 1 end
    local g = { px = px, rows = rows or style.rows }
    g.border = style.border == "none" and 0 or style.borderSize * px
    g.cut = style.border == "rounded" and px or 0
    g.pad = Round(style.padding)
    g.header = style.header and Snap(style.headerHeight) or 0
    g.divider = (style.header and g.border > 0) and px or 0
    g.rowH, g.gap = Snap(style.rowHeight), Round(style.spacing)
    g.icon = style.icon ~= "none" and g.rowH or 0
    g.iconGap = g.icon > 0 and math.max(px, g.gap) or 0
    g.inset = Round(style.textInset)
    g.width = Snap(style.width)
    if Odd(g.width) then g.width = g.width + px end
    g.left = g.border + g.pad
    g.rowW = math.max(px, g.width - 2 * g.left)
    g.rowsTop = g.border + g.header + g.divider + g.pad
    local count = math.max(1, g.rows)
    g.height = g.rowsTop + count * g.rowH + (count - 1) * g.gap + g.pad + g.border
    if Odd(g.height) then g.height = g.height + px end
    return g
end

-- Top offset of row `index` (1-based) from the window's top edge.
function M.RowTop(g, index) return g.rowsTop + (index - 1) * (g.rowH + g.gap) end
