local _, addon = ...
local M = addon.UnitFrames
if not M or not addon.Layouts then return end

-- The unit frames' part of the built-in Mode-Default layout (DPS / Tank,
-- Shared/Runtime/Layouts.lua), from the owner's layout editor (November 18,
-- 2026). Player and Target sit either side of the screen's bottom centre
-- (each 246 x 70: the 70px ring and a 184px bar block), the Player's name on
-- the left of its top border; the Target mirrors it, its name on the right,
-- its buffs at the top left growing right. A small Focus (120 wide, 20px
-- health, 3px power, no portrait, a 12px cast bar 8px below) sits 64 over
-- the Target's top left corner. Target of Focus is off; Target of Target
-- keeps its defaults. See docs/UNIT_FRAMES.md, "Mode-Default layout".
local PLAYER_X, FOCUS_RISE = 317, 64
local HEIGHT = { ["1080"] = 300, ["1440"] = 325 }

-- The Target frame's size in this profile, as Edit Mode measures its
-- stand-in: the Player's look (it matches the Player) at its own Frame Width.
local function TargetSize(db)
    local fdb = db.target
    if fdb.matchPlayer then fdb = setmetatable({ barWidth = fdb.barWidth }, { __index = db.player }) end
    local g = M:Geometry(fdb, 1, addon.Style.EdgeDepth(M.EdgePreset("target")))
    return g.width * fdb.scale / 100, g.height * fdb.scale / 100
end

addon.Layouts:Contribute("mode-default", "unitFrames", function(db, ctx)
    local y = ctx.V(HEIGHT)
    db.enabled = true
    db.player.texts.border.align = "LEFT"
    db.target.buffs.anchor, db.target.buffs.grow = "TOPLEFT", "right"
    local focus = db.focus
    focus.barWidth, focus.healthHeight, focus.powerHeight, focus.scale = 120, 20, 3, 100
    focus.showPortrait = false
    focus.buffs.enabled, focus.debuffs.enabled = false, false
    focus.castBar.enabled, focus.castBar.height, focus.castBar.gap = true, 12, 8
    db.focustarget.enabled = false
    ctx.Place(M.elementIds.player, "screen", "CENTER", "BOTTOM", -PLAYER_X, y)
    ctx.Place(M.elementIds.target, "screen", "CENTER", "BOTTOM", PLAYER_X, y)
    -- The editor hung the Focus from the Target frame (its bottom left 64 over
    -- the Target's top left), but unit frames place only on the screen
    -- (Build.lua, RegisterPosition), so it gets that same spot from the
    -- screen's bottom centre.
    local width, height = TargetSize(db)
    ctx.Place(M.elementIds.focus, "screen", "BOTTOMLEFT", "BOTTOM", PLAYER_X - width / 2, y + height / 2 + FOCUS_RISE)
end)
