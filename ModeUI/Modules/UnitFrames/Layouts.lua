local _, addon = ...
local M = addon.UnitFrames
if not M or not addon.Layouts then return end

-- The unit frames' part of the built-in Mode-Default layout (DPS / Tank,
-- Shared/Runtime/Layouts.lua), from the owner's layout editor (November 18,
-- 2026) and the owner's tuning the same day. Player and Target sit either
-- side of the screen's bottom centre, as tall as an Essential Cooldowns icon:
-- 24 health, the 1px line, 3 power and the 2px rim make a 32px bar block,
-- 34 with its shadow, as an icon is 30 plus its 2px edge each side (the 52px
-- ring is 165% of it, so each frame is 230 x 52). Their bands sit 10px from Essential's
-- (288 wide with its edges, its band 143 out). The name sits inside the
-- health bar at the top right and the health text at the bottom right, both
-- without the text glow, leaving the top border's right end to Defensive
-- Cooldowns; the Target mirrors it, its buffs at the top left growing right.
-- A small Focus (120 wide, 20px health, 3px power, no portrait, a 12px cast
-- bar 8px below) sits 64 over the Target's top left corner. Target of Focus
-- is off; Target of Target keeps its defaults. See docs/UNIT_FRAMES.md,
-- "Mode-Default layout".
local HEALTH, POWER = 24, 3
local ESSENTIAL_BAND, GAP, FOCUS_RISE = 143, 10, 64
local HEIGHT = { ["1080"] = 300, ["1440"] = 325 }
local FRAMES = { "player", "target", "targettarget", "focus", "focustarget" }

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
    db.player.healthHeight, db.player.powerHeight = HEALTH, POWER
    -- The name from the border to the top right, the health text from the
    -- right to the bottom right, each at its own size; the level stays.
    local texts = db.player.texts
    texts.topRight.content, texts.topRight.size = texts.border.content, texts.border.size
    texts.bottomRight.content, texts.bottomRight.size = texts.right.content, texts.right.size
    texts.border.content, texts.right.content = "none", "none"
    for _, unit in ipairs(FRAMES) do db[unit].nameTextGlow, db[unit].healthTextGlow = false, false end
    db.target.buffs.anchor, db.target.buffs.grow = "TOPLEFT", "right"
    local focus = db.focus
    focus.barWidth, focus.healthHeight, focus.powerHeight, focus.scale = 120, 20, 3, 100
    focus.showPortrait = false
    focus.buffs.enabled, focus.debuffs.enabled = false, false
    focus.castBar.enabled, focus.castBar.height, focus.castBar.gap = true, 12, 8
    db.focustarget.enabled = false
    local width, height = TargetSize(db)
    local x = ESSENTIAL_BAND + GAP + width / 2
    ctx.Place(M.elementIds.player, "screen", "CENTER", "BOTTOM", -x, y)
    ctx.Place(M.elementIds.target, "screen", "CENTER", "BOTTOM", x, y)
    -- The editor hung the Focus from the Target frame (its bottom left 64 over
    -- the Target's top left), but unit frames place only on the screen
    -- (Build.lua, RegisterPosition), so it gets that same spot from the
    -- screen's bottom centre.
    ctx.Place(M.elementIds.focus, "screen", "BOTTOMLEFT", "BOTTOM", x - width / 2, y + height / 2 + FOCUS_RISE)
end)
