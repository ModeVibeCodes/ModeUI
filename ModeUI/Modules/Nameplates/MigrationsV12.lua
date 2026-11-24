local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- Version 11 -> 12, the nameplates pass (owner, November 23, 2026;
-- docs/NAMEPLATES.md, "Settings versions"). A value still equal to its
-- version 11 default takes the owner's baseline; anything the player picked
-- stays, and the new switches keep a customized plate looking as it did.
-- Called from Initialize (Migrations.lua) on detached copies too, so nothing
-- here touches frames.
local function Copy(value) return addon.ProfileCodec.Copy(value) end
local Style = addon.Style
local Same, Legacy = Style.SameColor, Style.LEGACY

-- Version 11's defaults for the keys whose default changed, per kind.
M.V11 = {
    enemy = { width = 140, healthHeight = 12, castY = -2, healthFontSize = 9, nameFontSize = 10, castFontSize = 9,
        castTargetAnchor = "BOTTOM", raidSize = 16, questSize = 14, levelSize = 9, targetStyle = "border",
        targetArrowSize = 12, targetArrowGap = 4, softTargetSize = 20, auraSpacing = 2, auraShape = "cropped" },
    friendly = { display = "plate", showAuras = true, nameFontSize = 10, castY = 0, softTargetSize = 20, auraSpacing = 2,
        auraShape = "cropped" },
}
-- Version 11's aura groups (enemy): the anchor and grow move together.
local V11_GROUPS = { crowdControl = { anchor = "LEFT", grow = "left", size = 24 },
    debuffs = { anchor = "TOP", grow = "center", size = 20, max = 6 }, buffs = { size = 18 } }

local function Plain(style, key, old, new)
    if style[key] == old then style[key] = Copy(new) end
end

local function Groups(style, defaults)
    local moved = 0
    for group, old in pairs(V11_GROUPS) do
        local value, new = style[group], defaults[group]
        if type(value) == "table" and addon.IsPublic(value) then
            if old.anchor and value.anchor == old.anchor and value.grow == old.grow and value.x == 0 and value.y == 0 then
                value.anchor, value.grow, value.attach = new.anchor, new.grow, new.attach
                moved = moved + 1
            end
            if old.size and value.size == old.size then value.size = new.size end
            if old.max and value.max == old.max then value.max = new.max end
        end
    end
    return moved
end

local function Kind(style, kind, defaults)
    for key, old in pairs(M.V11[kind]) do Plain(style, key, old, defaults[key]) end
    -- Every Mode cast bar: the old amber and gray take light blue and orange-red.
    if Same(style.castColor, Legacy.palette.neutral) then style.castColor = Copy(defaults.castColor) end
    if Same(style.castLockedColor, Legacy.palette.tapped) then style.castLockedColor = Copy(defaults.castLockedColor) end
    if kind ~= "enemy" then return end
    -- The name on the top border, top left, 3px into the rim.
    local nameMoved = style.nameAnchor == "TOP" and style.nameX == 0 and style.nameY == 0
    if nameMoved then style.nameAnchor, style.nameY = defaults.nameAnchor, defaults.nameY end
    style.nameOnBorder = nameMoved
    -- The raid marker in the bar's middle; level and elite inside it on the left.
    if style.raidAnchor == "LEFT" and style.raidX == 0 and style.raidY == 0 then style.raidAnchor = defaults.raidAnchor end
    style.levelInside = style.levelAnchor == "LEFT" and style.levelX == 0 and style.levelY == 0
    style.classificationInside = style.classificationAnchor == "LEFT" and style.classificationX == 0 and style.classificationY == 0
    -- Aura groups: crowd control above, your debuffs on the border line. Auras
    -- come first only where the groups moved; a customized plate keeps its order.
    style.auraOrder = Groups(style, defaults) == 2 and "auras" or "indicators"
    -- Combo points move up while nothing is cast, where they still sit below.
    style.comboFollowCast = style.comboAnchor == "BOTTOM"
end

function M.MigrateV11(db)
    for _, kind in ipairs(M.kinds) do
        local style = db[kind]
        if type(style) == "table" and addon.IsPublic(style) then Kind(style, kind, M.styleDefaults[kind]) end
    end
end

-- Version 12 -> 13, readable text (owner, November 24, 2026): enemy names
-- still in Class or Reaction (the old default) take the text color. The new
-- halo keys and Same Size at Any Distance fill in from the defaults.
function M.MigrateV12(db)
    local style = db.enemy
    if type(style) == "table" and addon.IsPublic(style) and style.nameColorMode == "class" then
        style.nameColorMode = M.styleDefaults.enemy.nameColorMode
    end
end

-- Version 13 -> 14 (owner, November 24, 2026): outlined slug text a size
-- larger instead of the halos, and plates scale with the game again (Same
-- Size at Any Distance is gone). Values still at version 13's defaults take
-- the new ones; anything picked stays.
M.V13 = {
    enemy = { nameFontSize = 13, healthFontSize = 11, castFontSize = 10, levelSize = 10, outline = false,
        nameTextGlow = true, healthTextGlow = true },
    friendly = { nameFontSize = 12, outline = false, nameTextGlow = true, healthTextGlow = true },
}
function M.MigrateV13(db)
    db.fixedScale = nil
    for _, kind in ipairs(M.kinds) do
        local style = db[kind]
        if type(style) == "table" and addon.IsPublic(style) then
            for key, old in pairs(M.V13[kind]) do Plain(style, key, old, M.styleDefaults[kind][key]) end
        end
    end
end
