local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M or not addon.Layouts then return end

-- ModeCDM's part of the Mode-Default layout (DPS / Tank; owner's layout
-- editor, November 18, 2026; ModeUI/Shared/Runtime/Layouts.lua). It writes a
-- brand-new profile only. From the bottom up: Essential Cooldowns above the
-- action bars, Utility below it; on Essential the grouped Resource Bars, the
-- Cast Bar and Tracked Buffs, one pixel apart, the first two as wide as
-- Essential; the five default bars (Presets.lua) in their places.
-- Measured in UI units, a pixel each at the pixel-perfect scale: a bar's
-- place is its Edit Mode stand-in's (one line of icons with their edges).
--
-- The owner's tuning (November 18, 2026, testing at 1080p): every bar in
-- Mode-Round Gunmetal, icons at Spacing -1 (neighbours share one shadow
-- pixel), cooldown numbers in cooldownHot; Essential and Emphasized Buffs
-- 38 x 30, Defensive Cooldowns 36 x 30 on the Player frame's top border;
-- Power filled in your class color, Combo Points and Alternate Mana in color.
local function Copy(value) return addon.ProfileCodec.Copy(value) end
local Tone = addon.Style.Tone
local E, CAST, POWER = M.ElementId("essential"), M.CAST_ELEMENT, M.ResourceElementId("power")
local SPACING = -1

-- Every bar's look in this layout.
local function Look(style)
    style.spacing, style.edgeStyle, style.edgeMetal = SPACING, "round", "gunmetal"
    style.cooldownColor = Copy(Tone.cooldownHot)
end
-- A bar's shape: icon size, Icons per Line, Growth, New Lines; and the look.
local function Shape(style, width, height, perLine, grow, lineGrowth)
    style.width, style.height, style.perLine = width, height, perLine
    style.grow, style.lineGrowth = grow, lineGrowth
    Look(style)
end
-- The default bars' own sizes here, and places. Defensive Cooldowns hang
-- from the Player frame's bar block (unitFramesPlayerBars: its border on
-- the block's edge), right ends lined up, so Portrait Size, Health Height
-- and Frame Width never move them into the frame: the bar's stand-in ends in
-- its icons' shadow ring, so on the block's top the two share one shadow
-- pixel; +1 lines the icons' band up with the frame's.
-- Ultra Emphasized Buffs further out on a 1440 screen.
local SIZES = { defensives = { 36, 30 }, emphasized = { 38, 30 } }

-- The five default bars (Presets.lua) at their sizes here, in the layout's
-- look, at their default places but for `places` (each a place's changes).
local function Presets(db, ctx, places)
    places.ultra = places.ultra or { x = ctx.V({ ["1080"] = 110, ["1440"] = 135 }) }
    for _, tag in ipairs(M.presetOrder) do
        local bar = M.PresetBar(db, tag)
        assert(bar, "the " .. tag .. " bar is missing")
        local style, defaults = db[bar.id], M.presetDefaults[tag]
        for key in pairs(M.presets[tag].style) do style[key] = Copy(defaults[key]) end
        if SIZES[tag] then style.width, style.height = SIZES[tag][1], SIZES[tag][2] end
        Look(style)
        local place = Copy(M.presets[tag].place)
        for key, value in pairs(places[tag] or {}) do place[key] = value end
        ctx.Place(M.ElementId(bar.id), place.target, place.point, place.relativePoint, place.x, place.y)
    end
end

addon.Layouts:Contribute("mode-default", "cooldownManager", function(db, ctx)
    db.enabled = true
    Shape(db.essential, 38, 30, 7, "centerH", "down")
    ctx.Place(E, "screen", "CENTER", "BOTTOM", 0, ctx.V({ ["1080"] = 300, ["1440"] = 325 }))
    -- Utility 36 under Essential's second row, as the owner placed it.
    Shape(db.utility, 36, 30, 6, "centerH", "down")
    local row = db.essential.height + 2 * M.IconReach(db.essential) + SPACING
    ctx.Place(M.ElementId("utility"), E, "TOP", "BOTTOM", 0, -(row + 36))
    Look(db.buffBar)

    -- Group Resources: Power hosts the block (Power 10, Combo Points and
    -- Alternate Mana 8, filled: Power in your class color, the others in
    -- their own), as wide as Essential, on top of it. Health stays off.
    db.resourceLayout = "grouped"
    local bars = db.resources
    bars.power.height, bars.combo.height, bars.mana.height = 10, 8, 8
    for _, id in ipairs(M.resourceGroup) do bars[id].barMode = "color" end
    bars.power.colorMode = "class"
    bars.health.show = false
    bars.power.matchWidth = true
    ctx.Match(POWER, "width", E)
    ctx.Place(POWER, E, "BOTTOM", "TOP", 0, 1)

    -- The Cast Bar on the block, as wide as Essential; its icon hidden.
    local cast = db.castBar
    cast.height, cast.matchWidth, cast.icon = 12, true, "none"
    ctx.Match(CAST, "width", E)
    ctx.Place(CAST, POWER, "BOTTOM", "TOP", 0, 1)

    -- Tracked Buffs on the Cast Bar.
    Shape(db.buffIcon, 30, 24, 10, "centerH", "up")
    ctx.Place(M.ElementId("buffIcon"), CAST, "BOTTOM", "TOP", 0, 1)

    -- The default bars at their sizes and places here.
    Presets(db, ctx, { defensives = { target = "unitFramesPlayerBars", x = 1, y = 0 } })
end)

-- The Healer layout (owner, November 19, 2026; design/healer-layout/): the
-- same bars in the same look, with a bigger Essential and no Power bar (the
-- Player frame shows your mana). From the bottom up: Utility 70 under
-- Essential's first line (33 under its second); Essential 42 x 34 (4px
-- bigger), seven to a line, at the same place; on it a thin Combo Points
-- strip (6px, Mode-Thin: Mode-Round can't draw under 10) and the Cast Bar
-- (16 tall) at a fixed place over that strip, so nothing moves when a class
-- has no combo points; then Tracked Buffs and Emphasized Buffs as before.
-- With Power off the resources stand apart, so the Cast Bar hangs from
-- Essential. Defensive Cooldowns is hidden (its spells, none in a new
-- profile, stay where Blizzard's Cooldown Manager categories put them), and
-- Alternate Mana too. Left and Right Buffs sit 12 closer to the center and
-- 16 lower (x -138 and 138, y -16), clear of the Target's portrait ring.
local COMBO = M.ResourceElementId("combo")
local HEALER = { essential = { 42, 34 }, utility = 70, combo = 6, cast = 16, side = { x = 138, y = -16 } }

addon.Layouts:Contribute("healer", "cooldownManager", function(db, ctx)
    db.enabled = true
    Shape(db.essential, HEALER.essential[1], HEALER.essential[2], 7, "centerH", "down")
    ctx.Place(E, "screen", "CENTER", "BOTTOM", 0, ctx.V({ ["1080"] = 300, ["1440"] = 325 }))
    Shape(db.utility, 36, 30, 6, "centerH", "down")
    ctx.Place(M.ElementId("utility"), E, "TOP", "BOTTOM", 0, -HEALER.utility)
    Look(db.buffBar)

    -- Resources apart: Power and Alternate Mana off, Combo Points a 6px
    -- Mode-Thin Gunmetal strip as wide as Essential, 1px over it.
    db.resourceLayout = "separate"
    local bars = db.resources
    bars.power.show, bars.mana.show, bars.health.show = false, false, false
    local combo = bars.combo
    combo.height, combo.barMode, combo.matchWidth = HEALER.combo, "color", true
    combo.edgeStyle, combo.edgeMetal = "thin", "gunmetal"
    ctx.Match(COMBO, "width", E)
    ctx.Place(COMBO, E, "BOTTOM", "TOP", 0, 1)

    -- The Cast Bar over the strip's place (1 + 6 + 1), as wide as Essential; its icon hidden.
    local cast = db.castBar
    cast.height, cast.matchWidth, cast.icon = HEALER.cast, true, "none"
    ctx.Match(CAST, "width", E)
    ctx.Place(CAST, E, "BOTTOM", "TOP", 0, 1 + HEALER.combo + 1)
    Shape(db.buffIcon, 30, 24, 10, "centerH", "up")
    ctx.Place(M.ElementId("buffIcon"), CAST, "BOTTOM", "TOP", 0, 1)

    local side = HEALER.side
    Presets(db, ctx, { leftBuffs = { x = -side.x, y = side.y }, rightBuffs = { x = side.x, y = side.y } })
    -- Defensive Cooldowns: hidden, not deleted, so it can come back.
    db[M.PresetBar(db, "defensives").id].show = false
end)
