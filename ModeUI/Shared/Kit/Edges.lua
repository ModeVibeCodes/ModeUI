local _, addon = ...
local Kit = addon.Kit

-- Hard-edged outlines: four flat strips, square corners, no texture filtering,
-- so a border is exactly `thickness` units on every side with nothing soft
-- bleeding into what it frames. The strips never overlap, so a translucent
-- color stays even all the way round. Sizes are in the host's units; pass
-- whole physical pixels (Kit.PixelSize) to stay on the pixel grid.

function Kit.Edges(parent, layer, sublevel)
    local edges = {}
    for i = 1, 4 do
        edges[i] = parent:CreateTexture(nil, layer or "BORDER", nil, sublevel or 0)
        edges[i]:SetTexture(Kit.FLAT)
    end
    return edges
end

-- Top and bottom run the full width; left and right fill the height between them.
function Kit.PlaceEdges(edges, host, inset, thickness, color, alpha)
    local top, bottom, left, right = edges[1], edges[2], edges[3], edges[4]
    for _, edge in ipairs(edges) do
        if edge.ClearTextureSlice then edge:ClearTextureSlice() end
        edge:SetTexture(Kit.FLAT)
        edge:ClearAllPoints()
        Kit.Tint(edge, color, alpha or 1)
    end
    top:SetPoint("TOPLEFT", host, "TOPLEFT", inset, -inset)
    top:SetPoint("TOPRIGHT", host, "TOPRIGHT", -inset, -inset)
    top:SetHeight(thickness)
    bottom:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", inset, inset)
    bottom:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -inset, inset)
    bottom:SetHeight(thickness)
    left:SetPoint("TOPLEFT", host, "TOPLEFT", inset, -inset - thickness)
    left:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", inset, inset + thickness)
    left:SetWidth(thickness)
    right:SetPoint("TOPRIGHT", host, "TOPRIGHT", -inset, -inset - thickness)
    right:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -inset, inset + thickness)
    right:SetWidth(thickness)
end

-- A 1px light line on the end of a bar's fill, marking where it stops. It
-- follows the fill texture, which the client sizes (values may be secret), on
-- the side the bar fills toward.
function Kit.FillEdge(bar, shown, reverse, px, color, alpha)
    local edge = bar.fillEdge
    if not edge then
        edge = bar:CreateTexture(nil, "ARTWORK", nil, 2)
        edge:SetTexture(Kit.FLAT)
        bar.fillEdge = edge
    end
    edge:SetShown(shown and true or false)
    if not shown then return end
    local fill = bar:GetStatusBarTexture()
    local side = reverse and "LEFT" or "RIGHT"
    edge:ClearAllPoints()
    edge:SetPoint("TOP" .. side, fill, "TOP" .. side, 0, 0)
    edge:SetPoint("BOTTOM" .. side, fill, "BOTTOM" .. side, 0, 0)
    edge:SetWidth(px)
    Kit.Tint(edge, color or { 1, 1, 1 }, alpha or 0.45)
end
