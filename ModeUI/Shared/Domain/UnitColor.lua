local _, addon = ...
local Q, Public, Number = addon.Domain.Query, addon.IsPublic, addon.IsNumber

-- Class and reaction colors as { r, g, b } fields. A module may supply custom
-- class colors (Global > Class Colors does) through SetClassOverride.
local UnitColor = {}
addon.Domain.UnitColor = UnitColor

-- WoW Forever's classes, in the order the game lists them.
UnitColor.classes = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
-- Used only if the client can't report a class color.
local FALLBACK = { WARRIOR = { .78, .61, .43 }, PALADIN = { .96, .55, .73 }, HUNTER = { .67, .83, .45 },
    ROGUE = { 1, .96, .41 }, PRIEST = { 1, 1, 1 }, SHAMAN = { 0, .44, .87 }, MAGE = { .25, .78, .92 },
    WARLOCK = { .53, .53, .93 }, DRUID = { 1, .49, .04 } }

-- The game's color for a class.
function UnitColor.NativeClass(class)
    if not Public(class) or type(class) ~= "string" then return end
    local native
    if C_ClassColor and type(C_ClassColor.GetClassColor) == "function" then
        local ok, value = pcall(C_ClassColor.GetClassColor, class)
        if ok and Public(value) then native = value end
    end
    native = native or (type(RAID_CLASS_COLORS) == "table" and RAID_CLASS_COLORS[class])
    if Public(native) and type(native) == "table" and Number(native.r, 0, 1) and Number(native.g, 0, 1) and Number(native.b, 0, 1) then
        return { r = native.r, g = native.g, b = native.b }
    end
    local color = FALLBACK[class]
    if color then return { r = color[1], g = color[2], b = color[3] } end
end

-- override(class) returns { r, g, b } fields for a custom color, or nil.
function UnitColor.SetClassOverride(override)
    assert(override == nil or type(override) == "function", "ModeUI: class color override must be a function.")
    UnitColor.override = override
end

-- The color ModeUI uses for a class: a custom one if set, else the game's.
function UnitColor.Class(class)
    if not Public(class) or type(class) ~= "string" then return end
    local custom = UnitColor.override and UnitColor.override(class)
    if custom then return custom end
    return UnitColor.NativeClass(class)
end

-- For a player unit, its class color; otherwise nil.
function UnitColor.PlayerClass(unit)
    if not Q.Truthy(UnitIsPlayer, unit) then return end
    local _, class = Q.Plain(UnitClass, unit)
    return class and UnitColor.Class(class)
end

-- How the unit relates to the player: "tapped", "hostile", "neutral",
-- "friendly", or nil when unknown.
function UnitColor.Reaction(unit)
    if Q.Truthy(UnitIsTapDenied, unit) then return "tapped" end
    local reaction = Q.Plain(UnitReaction, unit, "player")
    if Number(reaction, 1, 8) then
        return reaction <= 3 and "hostile" or reaction == 4 and "neutral" or "friendly"
    end
end
