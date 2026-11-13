local _, addon = ...
local Kit = addon.Kit

-- The suite's colors, shared by every module that draws in the Onyx look.
function Kit.RGB(r, g, b) return { r / 255, g / 255, b / 255 } end
local RGB = Kit.RGB

-- Mode text plus Mode-toned gameplay colors.
Kit.palette = {
    text = RGB(212, 212, 212), accent = RGB(0, 240, 255), green = RGB(127, 219, 151), hostile = RGB(224, 102, 102),
    neutral = RGB(232, 176, 75), tapped = RGB(140, 140, 140), mana = RGB(64, 150, 255), muted = RGB(185, 185, 185),
}
-- The Onyx skin: default health fill, empty bar, the rim and the black gap
-- inside it. The rim was slate (#6A737D) until the owner asked for it closer
-- to black (November 12, 2026).
Kit.onyx = { health = RGB(28, 30, 33), track = RGB(10, 11, 12), border = RGB(37, 40, 44), inner = RGB(0, 0, 0),
    -- Mode Slate (November 13, 2026): bar backgrounds in a near-neutral gray,
    -- clearly lighter than the Onyx fill, shown at a strong opacity.
    slate = RGB(76, 78, 82), slateHatch = RGB(95, 98, 103) }

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
