local _, addon = ...
local Kit = addon.Kit

-- The Mode slot: the look of an icon button (Action Bars' buttons, the
-- Cooldown Manager's icons). A hollow border (Border Size, in the Border
-- Color) around the background (Background Color, lightened by the
-- ActionBarSlot texture), then the icon one pixel further in, cropped (never
-- stretched) to the slot's shape. Glows sit over it: a soft glow reaching past
-- the slot, or a colored frame on it. The callers keep their own state;
-- nothing here is stored on the host.
--
-- `style` carries: border ("rounded", "square" or "none"), borderSize,
-- borderColor, backgroundColor and backgroundOpacity. `g` carries: w, h (the
-- slot's size), px (one physical pixel), border (the border's thickness) and
-- inset (border plus a pixel: where the icon starts).
local FLAT = Kit.FLAT
local GLOW_OUTSET = 7 -- how far the soft glow reaches past the slot

-- The border's four edges, the background fill and its texture. The border
-- is hollow, so a see-through background never takes on its color.
function Kit.SlotArt(host)
    local art = { edges = {}, fill = host:CreateTexture(nil, "BACKGROUND", nil, -7), grain = host:CreateTexture(nil, "BACKGROUND", nil, -6) }
    for i = 1, 4 do art.edges[i] = host:CreateTexture(nil, "BACKGROUND", nil, -8) end
    return art
end

local function Edge(edge, host, point, x1, y1, relative, x2, y2)
    edge:ClearAllPoints()
    edge:SetPoint("TOPLEFT", host, point, x1, y1)
    edge:SetPoint("BOTTOMRIGHT", host, relative, x2, y2)
end

-- Rounded leaves out each corner's outermost pixel, so the edges meet in a
-- soft corner; Square fills it. The slot texture adds its bevel and grain
-- (ADD), so the Background Color stays the base.
function Kit.PaintSlotArt(art, host, style, g)
    local on = style.border ~= "none"
    local t, cut = g.border, (on and style.border == "rounded") and g.px or 0
    local top, bottom, left, right = art.edges[1], art.edges[2], art.edges[3], art.edges[4]
    Edge(top, host, "TOPLEFT", cut, 0, "TOPRIGHT", -cut, -t)
    Edge(bottom, host, "BOTTOMLEFT", cut, t, "BOTTOMRIGHT", -cut, 0)
    Edge(left, host, "TOPLEFT", 0, -cut, "BOTTOMLEFT", t, cut)
    Edge(right, host, "TOPRIGHT", -t, -cut, "BOTTOMRIGHT", 0, cut)
    for _, edge in ipairs(art.edges) do
        edge:SetTexture(FLAT); Kit.Tint(edge, style.borderColor, 1); edge:SetShown(on)
    end
    local alpha = style.backgroundOpacity / 100
    Kit.Inset(art.fill, host, t)
    art.fill:SetTexture(FLAT); Kit.Tint(art.fill, style.backgroundColor, alpha)
    Kit.Inset(art.grain, host, t)
    if not addon.Media:ApplyTexture(art.grain, "ActionBarSlot") then art.grain:SetTexture(FLAT) end
    if art.grain.SetBlendMode then art.grain:SetBlendMode("ADD") end
    art.grain:SetVertexColor(1, 1, 1, alpha)
end

-- The border's thickness and the icon's inset for a style, in px units.
function Kit.SlotInsets(style, px)
    if style.border == "none" then return 0, 0 end
    local border = style.borderSize * px
    return border, border + px
end

-- Crops the icon to the slot's shape: 8% off its edges, then the long side
-- cut to the inner aspect, so a 42 by 36 slot shows the icon unstretched.
function Kit.CropIcon(icon, g)
    local iw, ih = math.max(g.px, g.w - 2 * g.inset), math.max(g.px, g.h - 2 * g.inset)
    if iw >= ih then
        local span = 0.84 * ih / iw
        icon:SetTexCoord(0.08, 0.92, 0.5 - span / 2, 0.5 + span / 2)
    else
        local span = 0.84 * iw / ih
        icon:SetTexCoord(0.5 - span / 2, 0.5 + span / 2, 0.08, 0.92)
    end
end

-- A flat overlay inside the border (highlight, pushed, out of range...).
function Kit.SlotOverlay(texture, host, inset, color, alpha)
    if not texture then return end
    if texture.ClearTextureSlice then texture:ClearTextureSlice() end
    texture:SetTexture(FLAT)
    texture:SetTexCoord(0, 1, 0, 1)
    Kit.Inset(texture, host, inset)
    texture:SetVertexColor(color[1], color[2], color[3], alpha)
end

-- A glow on a slot: a soft glow texture and a border of four edges; the
-- style ("mode"/"glow" soft, "border" a frame, and in Glows.lua "pixel",
-- "blizzard" and "gcd") picks which shows. It can pulse (an alpha bounce).
-- `frame.parts` lists every texture it draws with, for callers that fade
-- them (from a boolean that may be secret, say).
function Kit.SlotGlow(host)
    local frame = CreateFrame("Frame", nil, host)
    frame:SetAllPoints(host)
    frame.soft = frame:CreateTexture(nil, "OVERLAY")
    frame.edges = {}
    for i = 1, 4 do frame.edges[i] = frame:CreateTexture(nil, "OVERLAY", nil, 1) end
    frame.parts = { frame.soft, frame.edges[1], frame.edges[2], frame.edges[3], frame.edges[4] }
    if frame.CreateAnimationGroup then
        local pulse = frame:CreateAnimationGroup()
        local fade = pulse:CreateAnimation("Alpha")
        fade:SetFromAlpha(1); fade:SetToAlpha(0.35); fade:SetDuration(0.6)
        pulse:SetLooping("BOUNCE")
        frame.pulse = pulse
    end
    frame:Hide()
    return frame
end

-- options (optional): width and height (the slot's, so nothing is measured),
-- lines and thickness (Pixel).
function Kit.PaintSlotGlow(frame, host, style, color, pulse, px, options)
    px = px or 1
    frame:SetFrameLevel(host:GetFrameLevel() + 6)
    frame.glowWidth, frame.glowHeight = options and options.width, options and options.height
    Kit.HideGlowExtras(frame, style)
    local soft = style == "glow" or style == "mode"
    local drawn = soft or style == "border"
    frame.isSoft = soft or style == "blizzard" or style == "gcd"
    frame.soft:SetShown(soft)
    if soft then
        frame.soft:ClearAllPoints()
        frame.soft:SetPoint("TOPLEFT", host, "TOPLEFT", -GLOW_OUTSET, GLOW_OUTSET)
        frame.soft:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", GLOW_OUTSET, -GLOW_OUTSET)
        if not addon.Media:ApplyTexture(frame.soft, "NameplateGlow") then frame.soft:SetTexture(FLAT) end
        Kit.Tint(frame.soft, color, 0.9)
    end
    local t = 2 * px
    local top, bottom, left, right = frame.edges[1], frame.edges[2], frame.edges[3], frame.edges[4]
    local function Side(edge, a, x1, y1, b, x2, y2)
        edge:ClearAllPoints(); edge:SetPoint("TOPLEFT", host, a, x1, y1); edge:SetPoint("BOTTOMRIGHT", host, b, x2, y2)
        edge:SetTexture(FLAT); Kit.Tint(edge, color, 1); edge:SetShown(drawn and not soft)
    end
    Side(top, "TOPLEFT", 0, 0, "TOPRIGHT", 0, -t); Side(bottom, "BOTTOMLEFT", 0, t, "BOTTOMRIGHT", 0, 0)
    Side(left, "TOPLEFT", 0, -t, "BOTTOMLEFT", t, t); Side(right, "TOPRIGHT", -t, -t, "BOTTOMRIGHT", 0, t)
    if style == "pixel" then Kit.PaintPixelGlow(frame, host, color, px, options and options.lines, options and options.thickness)
    elseif style == "blizzard" or style == "gcd" then Kit.PaintFlipbookGlow(frame, host, style, color, px) end
    -- Pulse is for the soft glow and the border; the others move already.
    pulse = pulse and drawn
    if frame.pulse then
        if pulse and not frame.pulse:IsPlaying() then frame.pulse:Play() elseif not pulse then frame.pulse:Stop(); frame:SetAlpha(1) end
    end
end
