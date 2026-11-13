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
function Kit.ValidBarTexture(value, foreground)
    return value == "flat" or (foreground and value == "mode") or (type(value) == "string" and value:match("^media:.+") ~= nil)
end
function Kit.BarTextureChoices(foreground)
    local list = { { id = "flat", label = "Flat" } }
    if foreground then table.insert(list, 1, { id = "mode", label = "Mode Gradient" }) end
    for _, choice in ipairs(addon.Media:GetStatusBars()) do
        if choice.key ~= "default" then list[#list + 1] = { id = choice.key, label = choice.label } end
    end
    return list
end

-- A bar's background texture choice: "flat" (the default) or "media:<name>".
function Kit.BarBackground(bar, choice)
    local path = choice ~= "flat" and addon.Media:GetStatusBar(choice) or nil
    bar.bg:SetTexture(path or Kit.FLAT)
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
