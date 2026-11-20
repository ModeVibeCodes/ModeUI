local _, addon = ...
local Kit = addon.Kit

-- The line marking where a bar's fill ends. (Box outlines are Kit.CapRing,
-- in Capsule.lua.)

-- A 1px light line on the end of a bar's fill, marking where it stops. It
-- follows the fill texture, which the client sizes (values may be secret), on
-- the side the bar fills toward. It sits in a clipping frame that stops one
-- pixel short of the bar's end, so a full bar shows no line (owner,
-- November 13, 2026) without the value ever being compared.
function Kit.FillEdge(bar, shown, reverse, px, color, alpha)
    local edge = bar.fillEdge
    if not edge then
        bar.fillEdgeClip = CreateFrame("Frame", nil, bar)
        bar.fillEdgeClip:SetClipsChildren(true)
        edge = bar.fillEdgeClip:CreateTexture(nil, "ARTWORK", nil, 2)
        edge:SetTexture(Kit.FLAT)
        bar.fillEdge = edge
    end
    local clip = bar.fillEdgeClip
    clip:ClearAllPoints()
    clip:SetPoint("TOPLEFT", bar, "TOPLEFT", reverse and px or 0, 0)
    clip:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", reverse and 0 or -px, 0)
    edge:SetShown(shown and true or false)
    if not shown then return end
    local fill = bar:GetStatusBarTexture()
    local side = reverse and "LEFT" or "RIGHT"
    -- The theme's look (Style.FillEnd): Mode-Obsidian's ice line stays 1px
    -- inside the bar's top and bottom.
    local themeColor, themeAlpha, inset = addon.Style.FillEnd(0.22)
    edge:ClearAllPoints()
    edge:SetPoint("TOP" .. side, fill, "TOP" .. side, 0, -inset * px)
    edge:SetPoint("BOTTOM" .. side, fill, "BOTTOM" .. side, 0, inset * px)
    edge:SetWidth(px)
    Kit.Tint(edge, color or themeColor, alpha or themeAlpha)
end
