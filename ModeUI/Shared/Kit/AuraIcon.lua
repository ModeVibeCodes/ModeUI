local _, addon = ...
local Kit = addon.Kit

-- An aura icon in the Mode look, built like a plate box: a rounded 1px rim
-- (tinted per dispel type or the Onyx rim color), a 1px black gap, then the
-- icon inset two pixels and cropped to the icon's shape, with a cooldown swipe
-- and the stack count in the corner. Fill it with Domain.Auras.Apply.
function Kit.AuraIcon(parent)
    local icon = CreateFrame("Frame", nil, parent)
    Kit.AuraIconParts(icon)
    icon:Hide()
    return icon
end

-- The parts of an aura icon, made on an existing frame (a Kit.AuraIcon, or a
-- button an aura container made).
function Kit.AuraIconParts(icon)
    icon.rim = icon:CreateTexture(nil, "BACKGROUND", nil, 0)
    icon.gap = icon:CreateTexture(nil, "BACKGROUND", nil, 1)
    icon.rim:SetTexture(Kit.FLAT); icon.gap:SetTexture(Kit.FLAT)
    icon.icon = icon:CreateTexture(nil, "ARTWORK")
    icon.cooldown = CreateFrame("Cooldown", nil, icon)
    icon.cooldown:SetAllPoints(icon.icon)
    if icon.cooldown.SetDrawEdge then icon.cooldown:SetDrawEdge(false) end
    if icon.cooldown.SetReverse then icon.cooldown:SetReverse(true) end
    if icon.cooldown.SetHideCountdownNumbers then icon.cooldown:SetHideCountdownNumbers(true) end
    icon.textLayer = CreateFrame("Frame", nil, icon)
    icon.textLayer:SetAllPoints()
    icon.count = Kit.Text(icon.textLayer)
    icon.count.lift = Kit.Text(icon.textLayer, "ARTWORK")
    return icon
end

local function Skin(texture, key, rounded)
    if rounded and addon.Media:ApplyTexture(texture, key) then return end
    if texture.ClearTextureSlice then texture:ClearTextureSlice() end
    texture:SetTexture(Kit.FLAT)
end

-- Size, rim, crop and text for one icon. width and height are whole pixels;
-- px is one physical pixel. The icon's texture is cropped so it is never
-- stretched: 8% off each side, and the height cut to the icon's shape.
function Kit.LayoutAuraIcon(icon, width, height, px, style, fontPath)
    icon:SetSize(width, height)
    local rounded = width >= 8 and height >= 8
    icon.rim:ClearAllPoints(); icon.rim:SetAllPoints(icon)
    Skin(icon.rim, "NameplateRim", rounded)
    Kit.Inset(icon.gap, icon, px)
    Skin(icon.gap, "NameplateGap", rounded); Kit.Tint(icon.gap, Kit.onyx.inner, 1)
    Kit.Inset(icon.icon, icon, 2 * px)
    local innerWidth, innerHeight = math.max(px, width - 4 * px), math.max(px, height - 4 * px)
    local span = 0.84 * innerHeight / innerWidth
    icon.icon:SetTexCoord(0.08, 0.92, 0.5 - span / 2, 0.5 + span / 2)
    icon.textLayer:SetFrameLevel(icon.cooldown:GetFrameLevel() + 2)
    local countSize = math.max(7, math.floor(height * 0.45 + 0.5))
    Kit.Font(icon.count, style, countSize, fontPath, px)
    icon.count:ClearAllPoints()
    icon.count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -px, px)
    icon.count:SetJustifyH("RIGHT")
    Kit.LayoutLift(icon.count, style, countSize, fontPath, px, true, "RIGHT")
end

-- The rim color: a dispel type's color, or the Onyx rim.
function Kit.TintAuraRim(icon, color) Kit.Tint(icon.rim, color or Kit.onyx.border, 1) end
