local _, addon = ...
local Kit = addon.Kit

-- More glow looks for Kit.SlotGlow frames (Kit.PaintSlotGlow picks them by
-- style): Pixel (lines marching around the edge) and two of Blizzard's
-- FlipBook animations, Blizzard (the action bar proc loop) and GCD (the
-- Assisted Combat ants). FlipBooks run in the client (AnimationGroup), with
-- no Lua each frame; Pixel lines move from one shared ticker that runs only
-- while a pixel glow shows, at most 30 times a second.

-- Blizzard's FlipBook art: the atlas, its grid and loop, and how much bigger
-- than the slot it's drawn (the art carries its own transparent padding).
Kit.FLIPBOOK_GLOWS = {
    blizzard = { atlas = "UI-HUD-ActionBar-Proc-Loop-Flipbook", rows = 6, columns = 5, frames = 30, duration = 1, padding = 1.4 },
    gcd = { atlas = "RotationHelper_Ants_Flipbook", rows = 6, columns = 5, frames = 30, duration = 1, padding = 1.6 },
}
local PIXEL_PERIOD, TICK = 4, 1 / 30

-- Whether the client has an atlas (a missing one draws nothing).
local function HasAtlas(atlas)
    local api = C_Texture and C_Texture.GetAtlasInfo
    if type(api) ~= "function" then return true end
    local ok, info = pcall(api, atlas)
    return ok and info ~= nil
end

function Kit.PaintFlipbookGlow(frame, host, style, color, px)
    local spec = Kit.FLIPBOOK_GLOWS[style]
    if not HasAtlas(spec.atlas) then spec = Kit.FLIPBOOK_GLOWS.blizzard end
    if not frame.flipbook then
        local texture = frame:CreateTexture(nil, "OVERLAY", nil, 2)
        frame.flipbook = texture
        frame.parts[#frame.parts + 1] = texture
        if frame.CreateAnimationGroup then
            local group = frame:CreateAnimationGroup()
            group:SetLooping("REPEAT")
            frame.flipGroup, frame.flipAnim = group, group:CreateAnimation("FlipBook")
        end
    end
    local texture, anim = frame.flipbook, frame.flipAnim
    texture:SetAtlas(spec.atlas)
    -- The art is gold; gray it so the color tints it evenly.
    if texture.SetDesaturated then texture:SetDesaturated(true) end
    Kit.Tint(texture, color, 1)
    local w, h = frame.glowWidth or host:GetWidth(), frame.glowHeight or host:GetHeight()
    texture:ClearAllPoints(); texture:SetPoint("CENTER", host, "CENTER", 0, 0)
    texture:SetSize(w * spec.padding, h * spec.padding)
    texture:Show()
    if not anim then return end
    if anim.SetFlipBookRows then
        anim:SetFlipBookRows(spec.rows); anim:SetFlipBookColumns(spec.columns); anim:SetFlipBookFrames(spec.frames)
        anim:SetFlipBookFrameWidth(0); anim:SetFlipBookFrameHeight(0)
    end
    anim:SetDuration(spec.duration)
    if not frame.flipGroup:IsPlaying() then frame.flipGroup:Play() end
end

-- Pixel glow: `lines` dashes, each half its share of the edge, `thickness`
-- physical pixels, going round once every PIXEL_PERIOD seconds. A dash that
-- reaches a corner bends round it (a second piece on the next side).
local ticker, glowing = nil, {}
local function Side(w, h, d)
    -- Distance d along the edge, clockwise from the top left corner, to a
    -- side (1 top, 2 right, 3 bottom, 4 left), how far along it, and its length.
    if d < w then return 1, d, w end
    d = d - w
    if d < h then return 2, d, h end
    d = d - h
    if d < w then return 3, d, w end
    return 4, d - w, h
end
local function Piece(texture, host, side, from, to, t, w, h)
    texture:ClearAllPoints()
    if side == 1 then texture:SetPoint("TOPLEFT", host, "TOPLEFT", from, 0); texture:SetSize(to - from, t)
    elseif side == 2 then texture:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, -from); texture:SetSize(t, to - from)
    elseif side == 3 then texture:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -from, 0); texture:SetSize(to - from, t)
    else texture:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 0, from); texture:SetSize(t, to - from) end
    texture:Show()
end
local function DrawPixels(frame, phase)
    local host, w, h = frame.pixelHost, frame.glowWidth, frame.glowHeight
    local perimeter = 2 * (w + h)
    local count, t = frame.pixelLines, frame.pixelThickness
    local length = perimeter / count / 2
    for i = 1, count do
        local start = ((phase + (i - 1) / count) % 1) * perimeter
        local side, along, size = Side(w, h, start)
        local main, rest = frame.pixels[2 * i - 1], frame.pixels[2 * i]
        local finish = along + length
        if finish <= size then
            Piece(main, host, side, along, finish, t, w, h); rest:Hide()
        else
            Piece(main, host, side, along, size, t, w, h)
            Piece(rest, host, side % 4 + 1, 0, math.min(finish - size, side % 2 == 1 and h or w), t, w, h)
        end
    end
end
local function Tick(_, elapsed)
    ticker.elapsed = ticker.elapsed + elapsed
    if ticker.elapsed < TICK then return end
    ticker.elapsed = 0
    local phase = (GetTime() / PIXEL_PERIOD) % 1
    local any = false
    for frame in pairs(glowing) do
        if frame:IsShown() and frame.pixelLines then DrawPixels(frame, phase); any = true end
    end
    if not any then ticker:Hide() end
end
local function Track(frame, on)
    glowing[frame] = on or nil
    if on then
        if not ticker then
            ticker = CreateFrame("Frame"); ticker.elapsed = 0
            ticker:SetScript("OnUpdate", Tick)
        end
        ticker:Show()
    end
end

function Kit.PaintPixelGlow(frame, host, color, px, lines, thickness)
    lines = math.max(2, math.min(16, lines or 8))
    frame.pixels = frame.pixels or {}
    for i = #frame.pixels + 1, 2 * lines do
        local texture = frame:CreateTexture(nil, "OVERLAY", nil, 2)
        texture:SetTexture(Kit.FLAT)
        frame.pixels[i] = texture
        frame.parts[#frame.parts + 1] = texture
    end
    for i, texture in ipairs(frame.pixels) do Kit.Tint(texture, color, 1); if i > 2 * lines then texture:Hide() end end
    frame.pixelHost, frame.pixelLines = host, lines
    frame.pixelThickness = math.max(1, math.min(4, thickness or 2)) * (px or 1)
    frame.glowWidth, frame.glowHeight = frame.glowWidth or host:GetWidth(), frame.glowHeight or host:GetHeight()
    if not frame.pixelHooked then
        frame.pixelHooked = true
        frame:HookScript("OnShow", function(self) if self.pixelLines then Track(self, true) end end)
        frame:HookScript("OnHide", function(self) Track(self, false) end)
    end
    DrawPixels(frame, (GetTime() / PIXEL_PERIOD) % 1)
    Track(frame, frame:IsShown())
end

-- Puts away the looks a style doesn't use.
function Kit.HideGlowExtras(frame, style)
    if frame.flipbook and style ~= "blizzard" and style ~= "gcd" then frame.flipbook:Hide(); if frame.flipGroup then frame.flipGroup:Stop() end end
    if frame.pixels and style ~= "pixel" then
        for _, texture in ipairs(frame.pixels) do texture:Hide() end
        frame.pixelLines = nil
        Track(frame, false)
    end
end
