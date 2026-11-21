local _, addon = ...
local M = addon.PartyFrames
if not M or not addon.Layouts then return end

-- The party frames' part of the built-in Mode-Default layout (DPS / Tank,
-- Shared/Runtime/Layouts.lua), from the owner's layout editor (November 18,
-- 2026): your four party members (you have your own frame) in a column left
-- of the Player frame, 28 tall each with their rim, 1px apart, power bars on
-- healers only, aura icons by the owner's 6px rule (6 wider than tall),
-- health in Dark, 8px taller (30 health) and no buffs but Big Defensives
-- (owner's tuning, November 18, 2026; debuffs keep their defaults).
-- See docs/PARTY_FRAMES.md, "Mode-Default layout".
--
-- Members are an even number of pixels wide (Layout.lua, Geometry), so the
-- editor's 135 is drawn 136: 136 it is, the right edge where the owner put it.
-- 30 health + the 1px line + 3 power + the 1px rim top and bottom = 36. Below
-- Health keeps that row for everyone, so every member is 36 tall; one without
-- a power bar fills it with health.
local WIDTH, HEALTH, POWER, SPACING = 136, 30, 3, 1
-- The right edge lines up with the Player portrait's outer edge (the Player
-- frame's centre x -256 less half its 206 width); the group's middle at:
local RIGHT_X, MIDDLE = -359, { ["1080"] = 40, ["1440"] = -1 }
local ICONS = { heals = { 18, 12 }, defensives = { 22, 16 }, dispellable = { 20, 14 }, otherDebuffs = { 20, 14 },
    crowdControl = { 24, 18 }, buffs = { 16, 10 } }
for group in pairs(M.groupDispelType) do ICONS[group] = { 20, 14 } end
for group in pairs(M.TRACKED) do ICONS[group] = { 16, 10 } end

addon.Layouts:Contribute("mode-default", "partyFrames", function(db, ctx)
    db.enabled = true
    db.width, db.healthHeight, db.powerHeight, db.powerStyle = WIDTH, HEALTH, POWER, "below"
    db.spacing, db.growth, db.showPlayer, db.powerShown = SPACING, "down", false, "healers"
    db.healthColorMode = "default"
    for group, size in pairs(ICONS) do db.auras[group].width, db.auras[group].height = size[1], size[2] end
    -- Buffs: Big Defensives only.
    for _, group in ipairs(M.buffGroups) do db.auras[group].show = false end
    db.auras.defensives.show, db.auras.defensives.filter = true, "big"
    -- The Edit Mode stand-in is sized for a full party of five (Ghost.lua) and
    -- the header fills it from the top, so without you the four members take
    -- its top part. Its middle sits half the empty fifth slot below the
    -- group's, rounded to a whole pixel.
    local g = M.Geometry({ db = db }, 1)
    local shown = M.MAX_MEMBERS - 1
    local full = M.MAX_MEMBERS * g.height + (M.MAX_MEMBERS - 1) * SPACING
    local group = shown * g.height + (shown - 1) * SPACING
    ctx.Place(M.ELEMENT_ID, "screen", "RIGHT", "CENTER", RIGHT_X, math.floor(ctx.V(MIDDLE) - (full - group) / 2 + 0.5))
end)

-- The Healer layout (owner, November 19, 2026; design/healer-layout/): you
-- and your party (you alone too: Show When Solo) in a column under the
-- Player mana frame, 136 x 64 each (135 x 65 asked; members are an even
-- number of pixels): 58 health, the line and a 3px power row on healers.
-- Mode-Border, Mode-FG health in Dark on Mode-BG at 85 (Mode-Obsidian,
-- November 20, 2026). The name at the top left with
-- the role icon on its end, health percent in the middle (12). Inside the
-- bottom edge: debuffs at the left (20 x 18, up to 3, growing right),
-- Dispellable by You on the row above them (22 x 20, up to 2: three would
-- reach the health text), your healing buffs at the right (22 x 18, up to 3,
-- growing left). Group, Tracked and Defensive buffs hidden (Defensives until
-- its double icon is fixed). The dispel overlay: the top edge gradient at 35.
-- Place: the right edge at x -323; the last member's bottom edge level with
-- the Cooldown Manager's Essential second row (its bands lined up, the
-- shadows on one pixel). Essential's first line is centered 300 up from the
-- bottom at 1080 and 325 at 1440 (ModeCDM's layout part), 42 x 34 icons with
-- their 2px edges, lines 1px apart, so its second row ends 56 under that
-- middle: the last member's bottom is 55 under it. With you shown, the five
-- members fill the stand-in, so its middle is 162 over that, and its top
-- (the first member's) 162 over the middle: the column hangs from its top
-- right (owner, November 20, 2026: hung from its middle, a stand-in a few
-- units shorter than 5 x 64 + 4 off the pixel-perfect scale left a gap
-- under the Player mana frame; from the top, the first member always sits
-- snug under the frame, the Player block's shadow on its top pixel).
local HEALER = { width = 136, health = 58, power = 3, right = -323,
    middle = { ["1080"] = 300 - 540 - 55 + 162, ["1440"] = 325 - 720 - 55 + 162 } }
local HEALER_ICONS = { heals = { 22, 18, 3 }, dispellable = { 22, 20, 2 }, otherDebuffs = { 20, 18, 3 } }
for group in pairs(M.groupDispelType) do HEALER_ICONS[group] = { 20, 18, 3 } end

addon.Layouts:Contribute("healer", "partyFrames", function(db, ctx)
    db.enabled = true
    db.width, db.healthHeight, db.powerHeight, db.powerStyle = HEALER.width, HEALER.health, HEALER.power, "below"
    db.spacing, db.growth, db.showPlayer, db.powerShown = SPACING, "down", true, "healers"
    -- Shown when solo too (owner, November 19, 2026): your own frame in the column.
    db.showSolo = true
    db.healthColorMode, db.foregroundTexture, db.backgroundOpacity = "default", "media:Mode-FG", 85
    db.edgeStyle, db.edgeMetal = "obsidian", "default"
    -- Name top left (4 in from the edges), the role icon 2px after it; health in the middle.
    db.nameAnchor, db.nameX, db.nameY, db.nameSize = "TOPLEFT", 2, -2, 11
    db.roleAfterName, db.roleX, db.roleY, db.roleSize = true, 2, 0, 10
    db.healthTextAnchor, db.healthTextX, db.healthTextY, db.healthTextSize = "CENTER", 0, 0, 12
    db.dispelGradientOpacity = 35
    for _, group in ipairs(M.buffGroups) do db.auras[group].show = false end
    for group, size in pairs(HEALER_ICONS) do
        local adb = db.auras[group]
        adb.width, adb.height, adb.max, adb.perRow, adb.spacing = size[1], size[2], size[3], size[3], 1
    end
    db.auras.heals.show = true
    -- Dispellable on its own anchor, so it starts its own row: Left, 1 under
    -- the middle puts its 20px icons 1px over the 18px debuff row.
    local dispellable = db.auras.dispellable
    dispellable.anchor, dispellable.place, dispellable.grow, dispellable.y = "LEFT", "inside", "right", -1
    local g = M.Geometry({ db = db }, 1)
    local column = M.MAX_MEMBERS * g.height + (M.MAX_MEMBERS - 1) * SPACING
    ctx.Place(M.ELEMENT_ID, "screen", "TOPRIGHT", "CENTER", HEALER.right, ctx.V(HEALER.middle) + column / 2)
end)
