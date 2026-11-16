local _, addon = ...
local Kit = addon.Kit

-- The suite's colors, shared by every module that draws in the Onyx look.
function Kit.RGB(r, g, b) return { r / 255, g / 255, b / 255 } end
local RGB = Kit.RGB

-- Mode text plus Mode-toned gameplay colors.
Kit.palette = {
    text = RGB(212, 212, 212), accent = RGB(0, 240, 255), green = RGB(127, 219, 151), hostile = RGB(224, 102, 102),
    neutral = RGB(232, 176, 75), tapped = RGB(140, 140, 140), mana = RGB(64, 150, 255), muted = RGB(185, 185, 185),
    -- Cooldown numbers, as on the action bars.
    cooldown = RGB(255, 177, 47),
}
-- The Onyx skin: default health fill, empty bar, the rim and the black gap
-- inside it. The rim was slate (#6A737D) until the owner asked for it closer
-- to black (November 12, 2026). The health fill was #1C1E21 until the owner
-- asked for #131212 (November 13, 2026); modules that saved a copy of it
-- move a value still at OLD_ONYX_HEALTH.
Kit.OLD_ONYX_HEALTH = RGB(28, 30, 33)
Kit.onyx = { health = RGB(19, 18, 18), track = RGB(10, 11, 12), border = RGB(37, 40, 44), inner = RGB(0, 0, 0),
    -- Mode Slate (November 13, 2026): bar backgrounds in a near-neutral gray,
    -- clearly lighter than the Onyx fill, shown at a strong opacity.
    -- A touch darker since (#44464A, owner, November 13, 2026).
    slate = RGB(68, 70, 74), slateHatch = RGB(85, 88, 93),
    -- Unit frame rims: a little lighter than `border`, to stand apart from
    -- the health bar (owner, November 13, 2026).
    frameRim = RGB(64, 69, 76) }
-- The pre-Mode unit frame rim (#40454C), which saved settings still hold as
-- a default (aura borders, combo point sockets).
Kit.BORDER_COLOR = Kit.onyx.frameRim

-- True when a saved color is still the old Onyx health fill (#1C1E21), for
-- the migrations that move it to the current one.
function Kit.IsOldOnyxHealth(color)
    if type(color) ~= "table" then return false end
    for i = 1, 3 do
        local value = color[i]
        if not (addon.IsNumber(value) and math.abs(value - Kit.OLD_ONYX_HEALTH[i]) < 1e-6) then return false end
    end
    return true
end

-- Colors a region from a boolean that may be secret: a public value picks the
-- color here; a secret one goes to SetVertexColorFromBoolean, which accepts
-- secrets from addon code. nil counts as false.
function Kit.ColorFromBoolean(region, value, ifTrue, ifFalse)
    if addon.IsPublic(value) then
        local c = value and ifTrue or ifFalse
        region:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
        return true
    end
    if region.SetVertexColorFromBoolean and CreateColor then
        local ok = pcall(region.SetVertexColorFromBoolean, region, value,
            CreateColor(ifTrue[1], ifTrue[2], ifTrue[3], ifTrue[4] or 1), CreateColor(ifFalse[1], ifFalse[2], ifFalse[3], ifFalse[4] or 1))
        if ok then return true end
    end
    region:SetVertexColor(ifFalse[1], ifFalse[2], ifFalse[3], ifFalse[4] or 1)
    return false
end
