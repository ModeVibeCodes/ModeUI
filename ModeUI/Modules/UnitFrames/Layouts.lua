local _, addon = ...
local M = addon.UnitFrames
if not M or not addon.Layouts then return end

-- The unit frames' part of the built-in Mode-Default layout (DPS / Tank,
-- Shared/Runtime/Layouts.lua), from the owner's layout editor (November 18,
-- 2026) and the owner's tuning the same day. Player and Target sit either
-- side of the screen's bottom centre, as tall as an Essential Cooldowns icon:
-- no power bar, 28 health and the 2px rim make a 32px bar block, 34 with its
-- shadow, as an icon is 30 plus its 2px edge each side; Portrait Size 145
-- makes the ring 46, and Frame Width 166 (18 under the default) each frame
-- 206 x 46 (the frame is measured from the ring, so both set its width).
-- Their bands sit 10px from Essential's (288 wide with its edges, its band 143
-- out). In the health bar: the name (11) at the top right, the health text
-- (10) at the bottom right, the level (10) at the bottom left, no text glow;
-- the top border's right end is Defensive Cooldowns'. The Target mirrors it
-- (its power hidden too, as it matches the Player), its buffs at the top left
-- growing right.
-- A small Focus (120 wide, 20px health, 3px power, no portrait, a 12px cast
-- bar 8px below) sits 64 over the Target's top left corner. Target of Focus
-- is off; Target of Target keeps its defaults. See docs/UNIT_FRAMES.md,
-- "Mode-Default layout".
local HEALTH, WIDTH, PORTRAIT = 28, 166, 145
local SIZES = { name = 11, health = 10, level = 10 }
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

-- What both layouts share: no text glow, Mode-Thin Steel on every frame and
-- cast bar, no soft drop under the Player and Target (the icons on them keep
-- a crisp 1px shadow line), aura icons 1px apart (neighbours share one
-- shadow pixel; the border is inside the icon), the Target's buffs at its top
-- left growing right, Target of Focus off.
local function Common(db)
    db.enabled = true
    for _, unit in ipairs(FRAMES) do
        local fdb = db[unit]
        fdb.nameTextGlow, fdb.healthTextGlow = false, false
        fdb.edgeStyle, fdb.edgeMetal = "thin", "steel"
        fdb.buffs.spacing, fdb.debuffs.spacing = 1, 1
    end
    db.player.dropShadow, db.target.dropShadow = false, false
    db.target.buffs.anchor, db.target.buffs.grow = "TOPLEFT", "right"
    db.focustarget.enabled = false
end

addon.Layouts:Contribute("mode-default", "unitFrames", function(db, ctx)
    local y = ctx.V(HEIGHT)
    Common(db)
    db.player.healthHeight, db.player.showPower = HEALTH, false
    db.player.barWidth, db.target.barWidth = WIDTH, WIDTH
    db.player.portraitScale, db.target.portraitScale = PORTRAIT, PORTRAIT
    -- The name from the border to the top right, the health text from the
    -- right to the bottom right; the level stays at the bottom left.
    local texts = db.player.texts
    texts.topRight.content, texts.topRight.size = texts.border.content, SIZES.name
    texts.bottomRight.content, texts.bottomRight.size = texts.right.content, SIZES.health
    texts.border.content, texts.right.content = "none", "none"
    texts.bottomLeft.size = SIZES.level
    local focus = db.focus
    focus.barWidth, focus.healthHeight, focus.powerHeight, focus.scale = 120, 20, 3, 100
    focus.showPortrait = false
    focus.buffs.enabled, focus.debuffs.enabled = false, false
    focus.castBar.enabled, focus.castBar.height, focus.castBar.gap = true, 12, 8
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

-- The Healer layout (owner, November 19, 2026; design/healer-layout/): a
-- minimal Player "mana frame" (Bar Shows: Mana, no power bar) over the party
-- column left of center. Its bar block is 20 tall (5/8 of Mode-Default's 32)
-- with a 30px ring (Portrait Size 145), and Frame Width 140 shows 136 of bar
-- past the ring: the party frames' width. The block's right edge is the
-- column's (x -323) and it sits 1px over the first member, whose top is set
-- by the party column ending level with Essential's second row
-- (Modules/PartyFrames/Layouts.lua). The Target is the same size, mirrored,
-- its block 1px right of the Player's; it doesn't match the Player, so the
-- mana frame and its texts stay the Player's. Its buffs (18 wide, 7 to a row)
-- and its cast bar (12 tall) sit 1px off its block, and the Focus (136 x 20,
-- no portrait) 1px under that cast bar, left edges lined up, its own cast
-- bar 1px under it. Every join 1px apart: the two shadows share one pixel.
-- Target of Target is off. Unit frames place only on the screen (Build.lua,
-- RegisterPosition), so each place is worked out from the frames' sizes.
local HEALER = { health = 16, width = 140, portrait = 145, right = -323, partyTop = { ["1080"] = 29, ["1440"] = -126 },
    focus = { width = 134, health = 14, power = 3 }, cast = 12, buffs = { size = 18, perRow = 7 } }

-- Every health slot and the border empty, then each text in its slot.
local function Texts(fdb, slots)
    local texts = fdb.texts
    for _, slot in ipairs(M.healthSlots) do texts[slot].content = "none" end
    texts.border.content = "none"
    for slot, text in pairs(slots) do texts[slot].content, texts[slot].size = text[1], text[2] end
end

addon.Layouts:Contribute("healer", "unitFrames", function(db, ctx)
    Common(db)
    local player, target, focus = db.player, db.target, db.focus
    target.matchPlayer = false
    for _, fdb in ipairs({ player, target }) do
        fdb.healthHeight, fdb.showPower, fdb.barWidth, fdb.portraitScale = HEALER.health, false, HEALER.width, HEALER.portrait
    end
    player.barShows = "mana"
    -- The name beside the ring, the value at the far end; no level.
    Texts(player, { left = { "name", SIZES.name }, right = { "powerPercent", SIZES.health } })
    Texts(target, { right = { "name", SIZES.name }, left = { "healthPercent", SIZES.health } })
    local buffs = target.buffs
    buffs.size, buffs.perRow, buffs.max, buffs.y = HEALER.buffs.size, HEALER.buffs.perRow, HEALER.buffs.perRow, -1
    for _, fdb in ipairs({ target, focus }) do
        local cast = fdb.castBar
        cast.enabled, cast.height, cast.gap, cast.icon = true, HEALER.cast, -1, "none"
    end
    db.targettarget.enabled = false
    focus.barWidth, focus.healthHeight, focus.powerHeight, focus.showPower = HEALER.focus.width, HEALER.focus.health, HEALER.focus.power, true
    focus.scale, focus.showPortrait = 100, false
    focus.buffs.enabled, focus.debuffs.enabled = false, false

    -- Places: the Player's block on the party column's top right, 1px over it.
    local g = M:Geometry(player, 1, addon.Style.EdgeDepth(M.EdgePreset("player")))
    local blockBottom = ctx.V(HEALER.partyTop) + 1
    local y = blockBottom - g.blockY + g.height / 2
    ctx.Place(M.elementIds.player, "screen", "CENTER", "CENTER", HEALER.right - g.width / 2, y)
    ctx.Place(M.elementIds.target, "screen", "CENTER", "CENTER", HEALER.right + 1 + g.width / 2, y)
    -- The Target's cast bar: its rim (1px) round the bar, Gap -1 off the block.
    local castBottom = blockBottom - (target.castBar.gap + 2) - (target.castBar.height + 2)
    ctx.Place(M.elementIds.focus, "screen", "TOPLEFT", "CENTER", HEALER.right + 1, castBottom - 1)
end)
