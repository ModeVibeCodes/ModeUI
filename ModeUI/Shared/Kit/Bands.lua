local _, addon = ...
local Kit = addon.Kit

-- A box whose middle can be see-through. Its rim and gap are filled shapes,
-- so instead of drawing them behind the middle, four bands (top, bottom, left,
-- right) each clip a full copy of them: together they draw the box minus a
-- rectangular hole, and nothing opaque sits under the hole.

-- Four clipped bands on `parent`; draw into each band's `layer`.
function Kit.Bands(parent)
    local bands = {}
    for i = 1, 4 do
        local band = CreateFrame("Frame", nil, parent)
        band:SetClipsChildren(true)
        band.layer = CreateFrame("Frame", nil, band)
        band.layer:SetAllPoints(band)
        bands[i] = band
    end
    return bands
end

-- Places the bands around a hole inset `left`, `top`, `right` and `bottom`
-- units from the box's edges; `room` is how far they reach outside the box
-- (for outlines drawn beyond it). Frames can sit at sub-pixel positions and
-- each band's clip rectangle rounds to the pixel grid on its own, so the side
-- bands overlap the top and bottom bands by one physical pixel (`px`) and no
-- seam can open between them.
function Kit.PlaceBands(bands, box, left, top, right, bottom, px, room)
    local t, b, l, r = bands[1], bands[2], bands[3], bands[4]
    local seam, out = px or 1, room or 0
    for _, band in ipairs(bands) do band:ClearAllPoints() end
    t:SetPoint("TOPLEFT", box, "TOPLEFT", -out, out)
    t:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", out, -top)
    b:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -out, bottom)
    b:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", out, -out)
    l:SetPoint("TOPLEFT", box, "TOPLEFT", -out, -top + seam)
    l:SetPoint("BOTTOMRIGHT", box, "BOTTOMLEFT", left, bottom - seam)
    r:SetPoint("TOPLEFT", box, "TOPRIGHT", -right, -top + seam)
    r:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", out, bottom - seam)
end
