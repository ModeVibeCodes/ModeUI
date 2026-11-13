local _, addon = ...

-- Color math and tinting for { r, g, b[, a] } arrays.
local Kit = addon.Kit or {}
addon.Kit = Kit
Kit.FLAT = "Interface\\Buttons\\WHITE8X8"

function Kit.Tint(region, color, alpha) region:SetVertexColor(color[1], color[2], color[3], alpha or 1) end
-- Blend toward white by t (0-1).
function Kit.Lighten(c, t) return { c[1] + (1 - c[1]) * t, c[2] + (1 - c[2]) * t, c[3] + (1 - c[3]) * t } end
function Kit.Scale(c, f) return { c[1] * f, c[2] * f, c[3] * f } end

-- Vertical gradient on an already textured region; flat tint when the client
-- lacks SetGradient/CreateColor. Returns true when the gradient applied.
function Kit.Gradient(texture, top, bottom, alpha)
    local ok = texture.SetGradient and CreateColor and pcall(texture.SetGradient, texture, "VERTICAL",
        CreateColor(bottom[1], bottom[2], bottom[3], bottom[4] or alpha or 1), CreateColor(top[1], top[2], top[3], top[4] or alpha or 1))
    if not ok then texture:SetVertexColor(top[1], top[2], top[3], top[4] or alpha or 1) end
    return ok
end
