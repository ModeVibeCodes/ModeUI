local _, addon = ...
-- Icons and portraits (docs/DESIGN_LANGUAGE.md, "Sizes"). Square elements are a
-- little wider than tall, cropped evenly; portraits sit in a Steel Sheen ring.
local Style = addon.Style
local Tone = Style.Tone

-- Height for an icon `width` pixels wide: 4px shorter up to 35, 5px up to 43,
-- 6px from 44.
function Style.IconHeight(width)
    if width >= 44 then return width - 6 end
    if width >= 36 then return width - 5 end
    return width - 4
end

-- Crops an icon texture to fill `width` x `height` without stretching: Blizzard
-- icons carry a 1/14 border trimmed on every side, then the extra width is
-- taken off the top and bottom.
function Style.CropIcon(texture, width, height)
    local trim = 1 / 14
    local span = 1 - 2 * trim
    local ratio = (width and height and width > 0) and (height / width) or 1
    local cut = span * (1 - ratio) / 2
    texture:SetTexCoord(trim, 1 - trim, trim + cut, 1 - trim - cut)
end

-- A portrait in a ring (the `ring` preset): a metal disc `diameter + 2 * rim`
-- wide with its light band, and the portrait texture cropped to a circle on top.
-- Returns { frame, portrait, disc } sized in `host`'s units.
function Style.Ring(host, diameter, rim)
    rim = rim or 2
    local px = Style.Pixel(host)
    local outer = (diameter + 2 * rim) * px
    local ring = { rim = rim }
    local frame = CreateFrame("Frame", nil, host)
    frame:SetSize(outer, outer)
    ring.frame = frame
    local disc = frame:CreateTexture(nil, "BORDER", nil, 0)
    Style.ApplyAsset(disc, "Circle")
    disc:SetAllPoints()
    local base, light = Tone.steel.dark, Tone.steel.mid
    local tone = Style.Mix(base, light, 0.5)
    Style.Paint(disc, tone)
    local sheen = frame:CreateTexture(nil, "BORDER", nil, 1)
    Style.ApplyAsset(sheen, "RingSheen")
    sheen:SetAllPoints()
    sheen:SetVertexColor(1, 1, 1, 0.22)
    local portrait = frame:CreateTexture(nil, "ARTWORK")
    portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", rim * px, -rim * px)
    portrait:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -rim * px, rim * px)
    local mask = frame:CreateMaskTexture()
    mask:SetTexture(Style.AssetPath("Circle"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(portrait)
    portrait:AddMaskTexture(mask)
    ring.disc, ring.sheen, ring.portrait, ring.mask = disc, sheen, portrait, mask
    return ring
end
