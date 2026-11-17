local _, addon = ...
local Kit, Style = addon.Kit, addon.Style

-- An aura icon in the Mode design language (docs/DESIGN_LANGUAGE.md: icons
-- and auras wear the `frameThin` edge in Mode-Thin): the art one rim inside
-- the icon, cropped to its shape, inside a 1px Steel bevel (2px at Border
-- Size 2) that a dispel type tints, with a cooldown swipe and the stack count
-- in the corner. The rim art covers its own corners: no masks. Fill it with
-- Domain.Auras.Apply.
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
    -- The art's area, one rim inside the icon; the edge sits round it. A
    -- black back so nothing shows past the art's edge.
    icon.inner = CreateFrame("Frame", nil, icon)
    icon.back = icon:CreateTexture(nil, "BACKGROUND", nil, 1)
    Style.ApplyAsset(icon.back, "Solid"); Style.Paint(icon.back, Style.Tone.shadow)
    icon.edge = Style.Edge(icon.inner, "frameThin", { style = "thin" })
    -- The rim's base ring: aura containers recolor it by dispel type
    -- (Kit.DispelAuraRim), the lighting layers over it hidden.
    icon.rim = icon.edge.rimTexture
    icon.icon = icon:CreateTexture(nil, "ARTWORK")
    -- CooldownFrameTemplate carries the swipe texture; a bare Cooldown draws nothing.
    icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.cooldown:SetAllPoints(icon.icon)
    if icon.cooldown.SetDrawSwipe then icon.cooldown:SetDrawSwipe(true) end
    if icon.cooldown.SetDrawBling then icon.cooldown:SetDrawBling(false) end
    if icon.cooldown.SetDrawEdge then icon.cooldown:SetDrawEdge(false) end
    if icon.cooldown.SetReverse then icon.cooldown:SetReverse(true) end
    if icon.cooldown.SetHideCountdownNumbers then icon.cooldown:SetHideCountdownNumbers(true) end
    -- The GCD glow: Blizzard's action button cooldown flash, looping, over the
    -- icon's edge and under its text.
    icon.flashLayer = CreateFrame("Frame", nil, icon)
    icon.flashLayer:SetAllPoints()
    icon.flash = icon.flashLayer:CreateTexture(nil, "ARTWORK")
    icon.flash:SetAtlas(Kit.GCD_FLASH_ATLAS)
    icon.flash:SetDesaturated(true)
    icon.flash:Hide()
    if icon.flashLayer.CreateAnimationGroup then
        local ok, group = pcall(function()
            local made = icon.flashLayer:CreateAnimationGroup()
            local flip = made:CreateAnimation("FlipBook")
            flip:SetTarget(icon.flash)
            flip:SetFlipBookRows(11); flip:SetFlipBookColumns(2); flip:SetFlipBookFrames(22)
            flip:SetFlipBookFrameWidth(0); flip:SetFlipBookFrameHeight(0)
            flip:SetDuration(0.75)
            made:SetLooping("REPEAT")
            return made
        end)
        if ok then icon.flashAnim = group end
    end
    icon.textLayer = CreateFrame("Frame", nil, icon)
    icon.textLayer:SetAllPoints()
    icon.count = Kit.Text(icon.textLayer)
    icon.count.lift = Kit.Text(icon.textLayer, "ARTWORK")
    -- Seconds left, in the middle of the icon.
    icon.timer = Kit.Text(icon.textLayer)
    icon.timer.lift = Kit.Text(icon.textLayer, "ARTWORK")
    return icon
end

-- Blizzard's GCD flash (ActionButtonCooldownFlashTemplate): 11 x 2 frames.
Kit.GCD_FLASH_ATLAS = "UI-HUD-ActionBar-GCD-Flipbook"
Kit.AURA_GLOW_OUTSET = 6 -- the aura glow texture's hollow core starts 6 texels in

-- Size, rim, crop and text for one icon. width and height are whole pixels;
-- px is one physical pixel. The icon's texture is cropped so it is never
-- stretched: 8% off each side, and the height cut to the icon's shape.
-- style.auraBorderSize: 1 or 2 (the rim's pixels; 1 when unset).
function Kit.LayoutAuraIcon(icon, width, height, px, style, fontPath)
    icon:SetSize(width, height)
    icon.edge:SetRim(math.max(1, math.min(2, style.auraBorderSize or 1)))
    local border = icon.edge.rim * px
    icon.inner:ClearAllPoints()
    icon.inner:SetPoint("TOPLEFT", icon, "TOPLEFT", border, -border)
    icon.inner:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -border, border)
    icon.back:ClearAllPoints(); icon.back:SetAllPoints(icon.inner)
    icon.icon:ClearAllPoints(); icon.icon:SetAllPoints(icon.inner)
    icon.edge.holder:SetFrameLevel(icon:GetFrameLevel() + 2)
    icon.edge:Layout()
    local o = Kit.AURA_GLOW_OUTSET
    icon.glow:ClearAllPoints()
    icon.glow:SetPoint("TOPLEFT", icon, "TOPLEFT", -o, o); icon.glow:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", o, -o)
    Kit.Rounded(icon.glow, "AuraGlow")
    local innerWidth, innerHeight = math.max(px, width - 2 * border), math.max(px, height - 2 * border)
    local span = 0.84 * innerHeight / innerWidth
    icon.icon:SetTexCoord(0.08, 0.92, 0.5 - span / 2, 0.5 + span / 2)
    icon.textLayer:SetFrameLevel(icon.cooldown:GetFrameLevel() + 2)
    local countSize = math.max(7, math.floor(height * 0.45 + 0.5))
    -- Counts and timers in Geist Bold (another font keeps its one weight).
    fontPath = Style.Weighted(fontPath, "bold")
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
    local c = style.auraTimerColor or Kit.palette.cooldown
    icon.timer:SetTextColor(c[1], c[2], c[3], 1)
    icon.timer:SetShown(style.auraTimerText ~= false)
end

-- The rim color: a dispel type's color, or nil for the border's metal.
function Kit.TintAuraRim(icon, color) icon.edge:SetTint(color) end
-- Hands the rim to an aura button's container to color by dispel type
-- (AddDispelTypeTexture with `options`): the rim goes flat first (its base
-- ring alone, `color` until the game recolors it), so no lighting layer
-- covers the type's color.
function Kit.DispelAuraRim(button, options, color)
    button.edge:SetTint(color or Style.Tone.metal.silver.mid)
    button.rim = button.edge.rimTexture
    button:AddDispelTypeTexture(button.rim, options)
end
-- Lets an aura's art follow a module's Border choice (style and metal ids).
function Kit.AuraBorderStyle(icon, styleId, metalId) icon.edge:SetStyle(styleId or "thin", metalId) end
-- Shows or hides the whole edge (a group's Border: None).
function Kit.ShowAuraRim(icon, shown) icon.edge:SetShown(shown and true or false) end

-- The glow: shown in a color at a soft strength, or hidden (color nil).
-- `style` is "gcd" (Blizzard's GCD flash, looping) or "soft" (a soft halo).
Kit.AURA_GLOW_ALPHA, Kit.AURA_FLASH_ALPHA = 0.4, 0.75
function Kit.GlowAura(icon, color, style)
    local soft, gcd = color ~= nil and style == "soft", color ~= nil and style ~= "soft"
    icon.glow:SetShown(soft)
    if soft then Kit.Tint(icon.glow, color, Kit.AURA_GLOW_ALPHA) end
    icon.flash:SetShown(gcd)
    if gcd then Kit.Tint(icon.flash, color, Kit.AURA_FLASH_ALPHA) end
    local anim = icon.flashAnim
    if anim then
        if gcd and not anim:IsPlaying() then anim:Play() elseif not gcd and anim:IsPlaying() then anim:Stop() end
    end
end
