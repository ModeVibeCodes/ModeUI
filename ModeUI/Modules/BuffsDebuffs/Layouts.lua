local _, addon = ...
local M = addon.BuffsDebuffs
if not M or not addon.Layouts then return end

-- Buffs & Debuffs' part of the built-in Mode-Default layout (DPS / Tank,
-- Shared/Runtime/Layouts.lua): Buffs and Debuffs left of the minimap, two
-- rows of 12 each, Buffs from its top, Debuffs ending on its bottom; Player
-- Buffs 30 x 24 under the Player frame's bottom border, right edges lined up
-- (owner's tuning, November 18, 2026); Defensives left of center. The same
-- at 1080 and 1440. See docs/BUFFS_DEBUFFS.md, "Mode-Default layout".
--
-- The owner's layout editor drew each icon as its size plus 2px of edge on
-- every side (3 for a 2px border) and the minimap as what shows of it. In
-- game an icon's border is inside its Width x Height and only its 1px shadow
-- ring shows past it; a bar's Edit Mode element is its cells exactly (each
-- the icon and, with the time below, Time Size + 2 under it; Placement.lua).
-- The Minimap element is the map alone, its `frame` edge 3px past it
-- (Modules/Minimap/Layouts.lua). The places below put what shows where the
-- editor drew it: outer edges on outer edges.
local SHADOW = 1 -- an aura icon's shadow ring, past its Width x Height
local MAP_EDGE = addon.Style.EdgeReach("frame") -- the minimap's edge past the map: 3
local MAP = "modeMinimap" -- the Minimap's Edit Mode element (Modules/Minimap/Init.lua)
local GAP = 6 -- between the bars' icons and the minimap's edge
-- Player Buffs hang from the Player frame's bar block (unitFramesPlayerBars,
-- its band on the block's edge), so Portrait Size, Health Height and Frame
-- Width never move them into the frame: icons 1 under the block share the
-- band's shadow pixel. Five to a row stay clear of the portrait ring (the
-- layout test checks every size); Spacing 1 leaves one pixel for both icons'
-- shadows, as the Cooldown Manager's icons share theirs.
local PLAYER_BARS = "unitFramesPlayerBars"

local function Bar(bar, values) for key, value in pairs(values) do bar[key] = value end end

-- What both layouts share: the bars' sizes and look, Player Buffs off, Buffs
-- and Debuffs by the minimap. Returns the Defensives bar's id.
local function Common(db, ctx)
    db.enabled = true
    local bars = db.bars
    local row = { width = 30, height = 24, perRow = 12, grow = "left", wrap = "down", timer = "below" }
    Bar(bars.buffs, row); bars.buffs.max = 24
    Bar(bars.debuffs, row); bars.debuffs.max = 16
    -- Player Buffs off (owner, November 18, 2026): Buffs by the minimap show
    -- them; the bar keeps its size and place for whoever turns it on.
    Bar(bars.playerBuffs, { show = false, width = 30, height = 24, perRow = 5 })
    local defensives
    for _, entry in ipairs(db.customBars) do
        if entry.preset == "defensives" and not defensives then defensives = entry.id end
    end
    assert(defensives, "no Defensives bar")
    Bar(bars[defensives], { width = 40, height = 34, max = 4 })
    -- Every bar uniform (owner, November 18, 2026): Mode-Thin in its own metal,
    -- icons 1px apart so neighbours share one shadow pixel, as the Cooldown
    -- Manager's do. Border sizes stay each bar's own.
    for _, bar in pairs(bars) do bar.edgeStyle, bar.edgeMetal, bar.spacing = "thin", "default", 1 end

    local x = -(GAP + MAP_EDGE + SHADOW)
    -- Buffs: the icons' tops on the minimap's top.
    ctx.Place(M.ElementId("buffs"), MAP, "TOPRIGHT", "TOPLEFT", x, MAP_EDGE - SHADOW)
    -- Debuffs: two rows that end on the minimap's bottom (the time text
    -- under the second row reaches the element's bottom).
    local _, height = M:BarSize(bars.debuffs, 1)
    ctx.Place(M.ElementId("debuffs"), MAP, "TOPRIGHT", "BOTTOMLEFT", x, height - MAP_EDGE)
    ctx.Place(M.ElementId("playerBuffs"), PLAYER_BARS, "TOPRIGHT", "BOTTOMRIGHT", 0, -SHADOW)
    return defensives
end

addon.Layouts:Contribute("mode-default", "buffsDebuffs", function(db, ctx)
    local defensives = Common(db, ctx)
    ctx.Place(M.ElementId(defensives), "screen", "RIGHT", "CENTER", -123 - SHADOW, 166)
end)

-- The Healer layout (owner, November 19, 2026; design/healer-layout/): Player
-- Debuffs on the right of the screen, 6px right of ModeCDM's Right Buffs bar,
-- growing right, six to a row, the first row centered on that column's middle;
-- Boss & Important over it (6 up, its default gap), left edges lined up,
-- growing right; Defensives in the top half, centered at (0, 170), growing
-- right. Right Buffs sits on the screen at (138, -16), 34 wide with its edges
-- (ModeCDM's healer part), so its right edge is at 155 and this place needs
-- no anchor to it (ModeCDM is optional, and a ModeUI bar can't anchor to a
-- companion's yet). Centered growth doesn't exist (Blizzard's aura flow
-- layout has none, and the count is secret), so Defensives' four icons (163
-- wide) are centered as a full row: x -82.
local HEALER = { rightBuffsEdge = 155, gap = 6, middle = -16, defensives = { x = -82, y = 170 } }

addon.Layouts:Contribute("healer", "buffsDebuffs", function(db, ctx)
    local defensives = Common(db, ctx)
    local bars = db.bars
    bars.playerDebuffs.grow, bars.playerDebuffs.perRow, bars.playerDebuffs.wrap = "right", 6, "down"
    bars.playerImportant.grow, bars.playerImportant.wrap = "right", "down"
    bars[defensives].grow = "right"
    local _, rowHeight = M:CellSize(bars.playerDebuffs, 1)
    ctx.Place(M.ElementId("playerDebuffs"), "screen", "TOPLEFT", "CENTER", HEALER.rightBuffsEdge + HEALER.gap + SHADOW,
        HEALER.middle + rowHeight / 2)
    ctx.Place(M.ElementId("playerImportant"), M.ElementId("playerDebuffs"), "BOTTOMLEFT", "TOPLEFT", 0, 6)
    ctx.Place(M.ElementId(defensives), "screen", "LEFT", "CENTER", HEALER.defensives.x, HEALER.defensives.y)
end)
