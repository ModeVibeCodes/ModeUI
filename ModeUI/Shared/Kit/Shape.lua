local _, addon = ...
local Kit = addon.Kit

-- Pixel size, bars and rounded shapes for frames in the Mode look.

-- One physical pixel in this frame's units (Blizzard's PixelUtil factor over
-- the frame's effective scale); 1 when the client cannot report it.
function Kit.PixelSize(frame)
    local Plain, Number = addon.Domain.Query.Plain, addon.IsNumber
    local factor = PixelUtil and Plain(PixelUtil.GetPixelToUIUnitFactor)
    local scale = Plain(frame.GetEffectiveScale, frame)
    if not (Number(factor, 0.01, 10) and Number(scale, 0.01, 100)) then return 1 end
    return factor / scale
end

-- A status bar with a background track and a top sheen texture.
function Kit.Bar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND", nil, -8); bar.bg:SetAllPoints()
    bar.sheen = bar:CreateTexture(nil, "OVERLAY")
    bar.sheen:SetPoint("TOPLEFT"); bar.sheen:SetPoint("TOPRIGHT")
    return bar
end

-- An anti-aliased circle texture.
function Kit.Circle(frame, layer, sublevel)
    local texture = frame:CreateTexture(nil, layer, nil, sublevel)
    if not addon.Media:ApplyTexture(texture, "UnitFrameCircle") then addon.Media:ApplyTexture(texture, "ModeThumb") end
    return texture
end

-- A hollow pixel rim: four flat edges on `host`. Hollow, so a see-through
-- fill inside never takes on the rim's color.
function Kit.Rim(host, layer, sublevel)
    local edges = {}
    for i = 1, 4 do
        edges[i] = host:CreateTexture(nil, layer or "BORDER", nil, sublevel or 0)
        edges[i]:SetTexture(Kit.FLAT)
    end
    return edges
end

-- Lays the rim along host's edges, `thickness` units thick. `cut` leaves out
-- each corner's outermost pixel so the edges meet in a soft corner (Rounded);
-- 0 fills it (Square). A thickness of 0 hides the rim.
function Kit.PlaceRim(edges, host, thickness, cut, color, alpha)
    local t = thickness
    local spots = {
        { "TOPLEFT", cut, 0, "TOPRIGHT", -cut, -t }, { "BOTTOMLEFT", cut, t, "BOTTOMRIGHT", -cut, 0 },
        { "TOPLEFT", 0, -cut, "BOTTOMLEFT", t, cut }, { "TOPRIGHT", -t, -cut, "BOTTOMRIGHT", 0, cut },
    }
    for i, edge in ipairs(edges) do
        local s = spots[i]
        edge:ClearAllPoints()
        edge:SetPoint("TOPLEFT", host, s[1], s[2], s[3])
        edge:SetPoint("BOTTOMRIGHT", host, s[4], s[5], s[6])
        Kit.Tint(edge, color, alpha or 1)
        edge:SetShown(t > 0)
    end
end

-- Anchor a texture inside its host, `inset` units in on every side.
function Kit.Inset(texture, host, inset)
    texture:ClearAllPoints(); texture:SetPoint("TOPLEFT", host, "TOPLEFT", inset, -inset)
    texture:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -inset, inset)
end

-- A sliced rounded texture from Media, or a flat one if it is unavailable.
function Kit.Rounded(texture, key)
    if not addon.Media:ApplyTexture(texture, key) then
        if texture.ClearTextureSlice then texture:ClearTextureSlice() end
        texture:SetTexture(Kit.FLAT)
    end
    Kit.Unsnap(texture)
end

-- Sliced textures on moving frames: each slice snapping to the pixel grid on
-- its own makes rounded rims flicker and clip as a nameplate slides at
-- sub-pixel positions while the camera turns. Blizzard's NineSlice turns
-- snapping off for its pieces the same way (NineSlice.lua).
function Kit.Unsnap(texture)
    if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false) end
    if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0) end
end

-- Mode Gradient: ModeUI's one bar texture, used by every skinned bar. A flat
-- fill with a soft white gradient over its top half, drawn above the track.
-- `bar` comes from Kit.Bar; barHeight and px are in the bar's units.
-- A bar's foreground texture choice: "mode" (Mode Gradient, the default),
-- "flat", or "media:<name>" (a SharedMedia status bar texture; Mode Gradient
-- while it isn't available).
function Kit.BarForeground(bar, choice, barHeight, px)
    local path = choice == "flat" and Kit.FLAT or (choice ~= "mode" and addon.Media:GetStatusBar(choice)) or nil
    if not path then Kit.ModeGradient(bar, barHeight, px); return end
    bar:SetStatusBarTexture(path)
    local fill = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if fill and fill.SetDrawLayer then fill:SetDrawLayer("ARTWORK", 0) end
    bar.sheen:Hide()
end

-- Bar texture choices: "mode" (foreground only), "flat", or any SharedMedia
-- status bar ("media:<name>"); a missing one draws as the default until it loads.
-- Backgrounds may also be "slate" (Mode Slate: flat, a near-neutral gray well
-- lighter than the Onyx fill) or "slateHatch" (Mode Slate Hatch: the same with
-- a 1px diagonal every 4px, kept for overlays such as overshields).
local BACKGROUNDS = { slate = true, slateHatch = true }
function Kit.ValidBarTexture(value, foreground)
    return value == "flat" or (foreground and value == "mode") or (not foreground and BACKGROUNDS[value] == true)
        or (type(value) == "string" and value:match("^media:.+") ~= nil)
end
function Kit.BarTextureChoices(foreground)
    local list = { { id = "flat", label = "Flat" } }
    if foreground then table.insert(list, 1, { id = "mode", label = "Mode Gradient" })
    else
        table.insert(list, 1, { id = "slateHatch", label = "Mode Slate Hatch" })
        table.insert(list, 1, { id = "slate", label = "Mode Slate" })
    end
    for _, choice in ipairs(addon.Media:GetStatusBars()) do
        if choice.key ~= "default" then list[#list + 1] = { id = choice.key, label = choice.label } end
    end
    return list
end

-- A bar's background texture: "flat", "slate", "slateHatch" or "media:<name>".
-- The hatch tiles one texel per screen pixel when the bar's size (width,
-- height) and pixel size (px) are given, so its lines stay 1px at any scale.
function Kit.BarBackground(bar, choice, width, height, px)
    local bg = bar.bg
    if bg.ClearTextureSlice then bg:ClearTextureSlice() end
    bg:SetTexCoord(0, 1, 0, 1)
    if choice == "slateHatch" then
        local path = addon.Media:GetTexture("ModeSlateHatch")
        if path and bg:SetTexture(path, "REPEAT", "REPEAT", "NEAREST") ~= false then
            if width and height and px then bg:SetTexCoord(0, width / (4 * px), 0, height / (4 * px)) end
            return
        end
    end
    local path = not BACKGROUNDS[choice] and choice ~= "flat" and addon.Media:GetStatusBar(choice) or nil
    bg:SetTexture(path or Kit.FLAT)
end

-- The color a background texture is tinted: Mode Slate's gray (the hatch tile
-- is 80% gray, so its tint is a fifth lighter), else the Onyx track.
function Kit.BarBackgroundColor(choice)
    if choice == "slate" then return Kit.onyx.slate end
    if choice == "slateHatch" then return Kit.onyx.slateHatch end
    return Kit.onyx.track
end

function Kit.ModeGradient(bar, barHeight, px)
    bar:SetStatusBarTexture(Kit.FLAT)
    local fill = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if fill and fill.SetDrawLayer then fill:SetDrawLayer("ARTWORK", 0) end
    bar.sheen:SetTexture(Kit.FLAT)
    bar.sheen:SetHeight(math.max(px, math.floor(barHeight / (2 * px)) * px))
    Kit.Gradient(bar.sheen, { 1, 1, 1, 0.12 }, { 1, 1, 1, 0 }, 0.06)
    bar.sheen:Show()
end

-- A status bar's fill in any texture choice, Mode Slate Hatch included (for
-- shields and overshields). The hatch has to tile one texel per screen pixel,
-- which a status bar's own fill can't do (it stretches its texture to the
-- value). So the bar's fill stays invisible and only drives a clipping frame
-- that follows it, and a full-size hatch texture inside shows just where the
-- bar is filled, with crisp lines at any value, secret ones included.
-- `bar` comes from Kit.Bar; width, height and px are in the bar's units.
-- Returns the region that shows the fill, for the caller's masks.
function Kit.FillTexture(bar, choice, width, height, px, color, alpha)
    if choice ~= "slateHatch" then
        if bar.hatchClip then bar.hatchClip:Hide() end
        if choice == "slate" then
            bar:SetStatusBarTexture(Kit.FLAT)
            if bar.sheen then bar.sheen:Hide() end
        else Kit.BarForeground(bar, choice, height, px) end
        bar:SetStatusBarColor(color[1], color[2], color[3], alpha)
        return bar:GetStatusBarTexture()
    end
    bar:SetStatusBarTexture(Kit.FLAT)
    bar:SetStatusBarColor(color[1], color[2], color[3], 0)
    if bar.sheen then bar.sheen:Hide() end
    local fill = bar:GetStatusBarTexture()
    if not bar.hatchClip then
        bar.hatchClip = CreateFrame("Frame", nil, bar)
        bar.hatchClip:SetClipsChildren(true)
        bar.hatch = bar.hatchClip:CreateTexture(nil, "ARTWORK")
    end
    local clip, hatch = bar.hatchClip, bar.hatch
    clip:ClearAllPoints()
    clip:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, 0); clip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0)
    hatch:ClearAllPoints()
    hatch:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0); hatch:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    local path = addon.Media:GetTexture("ModeSlateHatch")
    if not path or hatch:SetTexture(path, "REPEAT", "REPEAT", "NEAREST") == false then hatch:SetTexture(Kit.FLAT) end
    hatch:SetTexCoord(0, width / (4 * px), 0, height / (4 * px))
    Kit.Tint(hatch, color, alpha)
    clip:Show()
    return hatch
end
-- Fill choices for such bars: every foreground and background texture.
function Kit.ValidFillTexture(value) return Kit.ValidBarTexture(value, true) or Kit.ValidBarTexture(value, false) end
function Kit.FillTextureChoices()
    local list = { { id = "slateHatch", label = "Mode Slate Hatch" }, { id = "mode", label = "Mode Gradient" },
        { id = "flat", label = "Flat" }, { id = "slate", label = "Mode Slate" } }
    for _, choice in ipairs(addon.Media:GetStatusBars()) do
        if choice.key ~= "default" then list[#list + 1] = { id = choice.key, label = choice.label } end
    end
    return list
end
