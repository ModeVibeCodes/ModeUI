local _, addon = ...
local M = addon.PartyFrames
if not M or not addon.Layouts then return end

-- The party frames' part of the built-in Mode-Default layout (DPS / Tank,
-- Shared/Runtime/Layouts.lua), from the owner's layout editor (November 18,
-- 2026): your four party members (you have your own frame) in a column left
-- of the Player frame, 28 tall each with their rim, 1px apart, power bars on
-- healers only, aura icons by the owner's 6px rule (6 wider than tall),
-- health in Dark (owner's tuning, November 18, 2026).
-- See docs/PARTY_FRAMES.md, "Mode-Default layout".
--
-- Members are an even number of pixels wide (Layout.lua, Geometry), so the
-- editor's 135 is drawn 136: 136 it is, the right edge where the owner put it.
-- 22 health + the 1px line + 3 power + the 1px rim top and bottom = 28. Below
-- Health keeps that row for everyone, so every member is 28 tall; one without
-- a power bar fills it with health.
local WIDTH, HEALTH, POWER, SPACING = 136, 22, 3, 1
-- The right edge lines up with the Player portrait's outer edge (the Player
-- frame's centre x -276 less half its 246 width); the group's middle at:
local RIGHT_X, MIDDLE = -399, { ["1080"] = 40, ["1440"] = -1 }
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
