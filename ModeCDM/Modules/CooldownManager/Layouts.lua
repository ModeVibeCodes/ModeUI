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
local function Copy(value) return addon.ProfileCodec.Copy(value) end
local E, CAST, POWER = M.ElementId("essential"), M.CAST_ELEMENT, M.ResourceElementId("power")

-- A bar's shape: icon size, Icons per Line, Spacing, Growth, New Lines.
local function Shape(style, width, height, perLine, spacing, grow, lineGrowth)
    style.width, style.height, style.perLine, style.spacing = width, height, perLine, spacing
    style.grow, style.lineGrowth = grow, lineGrowth
end

addon.Layouts:Contribute("mode-default", "cooldownManager", function(db, ctx)
    db.enabled = true
    Shape(db.essential, 46, 40, 7, 2, "centerH", "down")
    ctx.Place(E, "screen", "CENTER", "BOTTOM", 0, ctx.V({ ["1080"] = 300, ["1440"] = 325 }))
    Shape(db.utility, 36, 30, 6, 2, "centerH", "down")
    ctx.Place(M.ElementId("utility"), E, "TOP", "BOTTOM", 0, -82)

    -- Group Resources: Power hosts the block (Power 10, Combo Points and
    -- Alternate Mana 8, in Dark mode), as wide as Essential, on top of it.
    -- Health stays off.
    db.resourceLayout = "grouped"
    local bars = db.resources
    bars.power.height, bars.combo.height, bars.mana.height = 10, 8, 8
    for _, id in ipairs(M.resourceGroup) do bars[id].barMode = "dark" end
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
    Shape(db.buffIcon, 30, 24, 10, 1, "centerH", "up")
    ctx.Place(M.ElementId("buffIcon"), CAST, "BOTTOM", "TOP", 0, 1)

    -- The default bars at their own sizes and places; Ultra Emphasized Buffs
    -- further out on a 1440 screen.
    local places = { ultra = { x = ctx.V({ ["1080"] = 110, ["1440"] = 135 }) } }
    for _, tag in ipairs(M.presetOrder) do
        local bar = M.PresetBar(db, tag)
        assert(bar, "the " .. tag .. " bar is missing")
        local style, defaults = db[bar.id], M.presetDefaults[tag]
        for key in pairs(M.presets[tag].style) do style[key] = Copy(defaults[key]) end
        local place = Copy(M.presets[tag].place)
        for key, value in pairs(places[tag] or {}) do place[key] = value end
        ctx.Place(M.ElementId(bar.id), place.target, place.point, place.relativePoint, place.x, place.y)
    end
end)
