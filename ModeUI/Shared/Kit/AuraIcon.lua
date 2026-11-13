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
    -- A soft glow around the icon (crowd control), behind the rim.
    icon.glow = icon:CreateTexture(nil, "BACKGROUND", nil, -1)
    icon.glow:Hide()
    icon.rim = icon:CreateTexture(nil, "BACKGROUND", nil, 0)
    icon.gap = icon:CreateTexture(nil, "BACKGROUND", nil, 1)
    icon.rim:SetTexture(Kit.FLAT); icon.gap:SetTexture(Kit.FLAT)
    icon.icon = icon:CreateTexture(nil, "ARTWORK")
    -- CooldownFrameTemplate carries the swipe texture; a bare Cooldown draws nothing.
    icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.cooldown:SetAllPoints(icon.icon)
    if icon.cooldown.SetDrawSwipe then icon.cooldown:SetDrawSwipe(true) end
    if icon.cooldown.SetDrawBling then icon.cooldown:SetDrawBling(false) end
    if icon.cooldown.SetDrawEdge then icon.cooldown:SetDrawEdge(false) end
    if icon.cooldown.SetReverse then icon.cooldown:SetReverse(true) end
    if icon.cooldown.SetHideCountdownNumbers then icon.cooldown:SetHideCountdownNumbers(true) end
    icon.textLayer = CreateFrame("Frame", nil, icon)
    icon.textLayer:SetAllPoints()
    icon.count = Kit.Text(icon.textLayer)
    icon.count.lift = Kit.Text(icon.textLayer, "ARTWORK")
    -- Seconds left, in the middle of the icon.
    icon.timer = Kit.Text(icon.textLayer)
    icon.timer.lift = Kit.Text(icon.textLayer, "ARTWORK")
    return icon
end

local function Skin(texture, key, rounded)
    if rounded and addon.Media:ApplyTexture(texture, key) then Kit.Unsnap(texture); return end
    if texture.ClearTextureSlice then texture:ClearTextureSlice() end
    texture:SetTexture(Kit.FLAT)
    Kit.Unsnap(texture)
end
Kit.AURA_GLOW_OUTSET = 6 -- the aura glow texture's hollow core starts 6 texels in

-- Size, rim, crop and text for one icon. width and height are whole pixels;
-- px is one physical pixel. The icon's texture is cropped so it is never
-- stretched: 8% off each side, and the height cut to the icon's shape.
function Kit.LayoutAuraIcon(icon, width, height, px, style, fontPath)
    icon:SetSize(width, height)
    local rounded = width >= 8 and height >= 8
    -- The rim is style.auraBorderSize pixels (1 when unset), then a 1px black gap.
    local border = (style.auraBorderSize or 1) * px
    icon.rim:ClearAllPoints(); icon.rim:SetAllPoints(icon)
    Skin(icon.rim, "NameplateRim", rounded)
    Kit.Inset(icon.gap, icon, border)
    Skin(icon.gap, "NameplateGap", rounded); Kit.Tint(icon.gap, Kit.onyx.inner, 1)
    Kit.Inset(icon.icon, icon, border + px)
    local o = Kit.AURA_GLOW_OUTSET
    icon.glow:ClearAllPoints()
    icon.glow:SetPoint("TOPLEFT", icon, "TOPLEFT", -o, o); icon.glow:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", o, -o)
    Kit.Rounded(icon.glow, "AuraGlow")
    local innerWidth, innerHeight = math.max(px, width - 2 * (border + px)), math.max(px, height - 2 * (border + px))
    local span = 0.84 * innerHeight / innerWidth
    icon.icon:SetTexCoord(0.08, 0.92, 0.5 - span / 2, 0.5 + span / 2)
    icon.textLayer:SetFrameLevel(icon.cooldown:GetFrameLevel() + 2)
    local countSize = math.max(7, math.floor(height * 0.45 + 0.5))
    Kit.Font(icon.count, style, countSize, fontPath, px)
    icon.count:ClearAllPoints()
    icon.count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -px, px)
    icon.count:SetJustifyH("RIGHT")
    Kit.LayoutLift(icon.count, style, countSize, fontPath, px, true, "RIGHT")
    local timerSize = math.max(7, math.floor(height * 0.5 + 0.5))
    Kit.Font(icon.timer, style, timerSize, fontPath, px)
    icon.timer:ClearAllPoints()
    icon.timer:SetPoint("CENTER", icon, "CENTER", 0, 0)
    icon.timer:SetJustifyH("CENTER")
    Kit.LayoutLift(icon.timer, style, timerSize, fontPath, px, style.auraTimerText ~= false, "CENTER")
    icon.timer:SetShown(style.auraTimerText ~= false)
end

-- The rim color: a dispel type's color, or the Onyx rim.
function Kit.TintAuraRim(icon, color) Kit.Tint(icon.rim, color or Kit.onyx.border, 1) end

-- The glow: shown in a color at a soft strength, or hidden (color nil).
Kit.AURA_GLOW_ALPHA = 0.6
function Kit.GlowAura(icon, color)
    if not color then icon.glow:Hide(); return end
    Kit.Tint(icon.glow, color, Kit.AURA_GLOW_ALPHA)
    icon.glow:Show()
end
