local _, addon = ...
local Kit = addon.Kit

-- The pre-Mode palettes (Mode text plus Mode-toned gameplay colors, and the
-- Onyx skin), kept only as the defaults saved settings still hold and the
-- values migrations recognize. They live in Style.LEGACY; new code reads
-- Style.Tone.
Kit.palette = addon.Style.LEGACY.palette
Kit.onyx = addon.Style.LEGACY.onyx
Kit.OLD_ONYX_HEALTH = addon.Style.LEGACY.oldOnyxHealth
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
