local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M then return end

-- Default bars (owner, November 18, 2026): five custom bars every new
-- profile starts with, and version 9 adds to an older one. Each is an
-- ordinary custom bar (renamed, emptied or deleted like any other) whose
-- db.customBars entry carries `preset = "<tag>"`, so it keeps its own
-- defaults (Reset to Defaults, a style filled on load, the glows a spell
-- starts from) and its own default place in Edit Mode. A deleted one stays
-- deleted: only a new profile and the version 9 step add them.
local L = addon.L
local function Copy(value) return addon.ProfileCodec.Copy(value) end

-- `style`: what differs from its kind's defaults (M.customDefaults).
-- `place`: its default Edit Mode place (its `point` on the target's
-- `relativePoint`, no gap added).
local function Place(target, point, relativePoint, x, y)
    return { target = target, placement = "center", point = point, relativePoint = relativePoint, x = x, y = y }
end
M.presetOrder = { "defensives", "emphasized", "leftBuffs", "rightBuffs", "ultra" }
M.presets = {
    defensives = { name = "Defensive Cooldowns", kind = "cooldown",
        style = { width = 30, height = 24, perLine = 3, grow = "left", lineGrowth = "up", spacing = 2 },
        place = Place("unitFramesPlayer", "BOTTOMRIGHT", "TOPRIGHT", 0, -12) },
    emphasized = { name = "Emphasized Buffs", kind = "buff",
        style = { width = 46, height = 40, perLine = 4, grow = "centerH", lineGrowth = "up", spacing = 2 },
        place = Place(M.ElementId("buffIcon"), "BOTTOM", "TOP", 0, 1) },
    leftBuffs = { name = "Left Buffs", kind = "buff",
        style = { width = 30, height = 24, perLine = 6, grow = "centerV", lineGrowth = "left", spacing = 1 },
        place = Place("screen", "CENTER", "CENTER", -150, 0) },
    rightBuffs = { name = "Right Buffs", kind = "buff",
        style = { width = 30, height = 24, perLine = 6, grow = "centerV", lineGrowth = "right", spacing = 1 },
        place = Place("screen", "CENTER", "CENTER", 150, 0) },
    ultra = { name = "Ultra Emphasized Buffs", kind = "buff",
        style = { width = 54, height = 48, perLine = 2, grow = "centerH", lineGrowth = "up", spacing = 2,
            cooldownSize = 22, countSize = 18 },
        place = Place("screen", "CENTER", "CENTER", 110, 115) },
}
-- Each preset's full defaults: its kind's, with its own values.
M.presetDefaults = {}
for _, tag in ipairs(M.presetOrder) do
    local preset = M.presets[tag]
    local style = Copy(M.customDefaults[preset.kind])
    for key, value in pairs(preset.style) do style[key] = value end
    M.presetDefaults[tag] = style
end

-- A custom bar's defaults: its preset's, else its kind's.
function M.BarDefaults(bar)
    return (bar.preset ~= nil and M.presetDefaults[bar.preset]) or M.customDefaults[bar.kind]
end

-- Validation (Migrations.lua, ValidCustom): a preset tag, when there is one,
-- names a known preset of the bar's kind, once per profile (`seen`).
function M.ValidPreset(bar, seen)
    local tag = bar.preset
    if tag == nil then return end
    local preset = type(tag) == "string" and M.presets[tag]
    assert(preset and preset.kind == bar.kind and not seen[tag], "Invalid cooldown manager preset bar: " .. tostring(bar.id))
    seen[tag] = true
end

-- Adds every preset `db` doesn't hold, after its own bars, with new IDs,
-- while there's room (a new profile, and the version 8 -> 9 step). Bars
-- already there are never touched; anything malformed is left for
-- validation to refuse.
function M.SeedPresets(db)
    if db.customBars == nil then db.customBars = {} end
    if db.nextCustom == nil then db.nextCustom = 1 end
    local bars, counter = db.customBars, db.nextCustom
    if type(bars) ~= "table" or type(counter) ~= "number" or counter ~= math.floor(counter) or counter < 1 then return end
    local held = {}
    for _, bar in ipairs(bars) do if type(bar) == "table" and bar.preset ~= nil then held[bar.preset] = true end end
    for _, tag in ipairs(M.presetOrder) do
        if not held[tag] and #bars < M.MAX_CUSTOM then
            local preset, id = M.presets[tag], "custom" .. db.nextCustom
            db.nextCustom = db.nextCustom + 1
            bars[#bars + 1] = { id = id, kind = preset.kind, name = L[preset.name], entries = {}, preset = tag }
            db[id] = Copy(M.presetDefaults[tag])
        end
    end
end

-- A preset bar's default place, when what it hangs from is a target
-- (Layout.lua); nil sends it to the custom bars' own default.
function M.PresetPosition(tag)
    local preset = tag ~= nil and M.presets[tag]
    if not preset then return nil end
    local target = preset.place.target
    for _, item in ipairs(addon.Positioning.targets) do
        if item.id == target then return Copy(preset.place) end
    end
end

-- The bar holding a preset in `db`, if any (the layouts find them by tag).
function M.PresetBar(db, tag)
    for _, bar in ipairs(db.customBars) do if bar.preset == tag then return bar end end
end
