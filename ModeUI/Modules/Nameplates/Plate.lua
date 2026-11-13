local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- Building a plate and laying out its two boxes. Plates are plain frames
-- (never secure), so they can be built and changed in combat. Each box is a
-- 1px rim and a 1px black gap with rounded corners, then the bar in the Mode
-- Gradient texture. Health and cast boxes use the same rim textures, so they
-- round alike at every size. Elements are placed in Layout.lua and the target
-- indicator in Target.lua.
--
-- The health bar's background can be see-through (Background Opacity). The rim
-- and gap are filled shapes, so the health box draws them in four clipped
-- bands around the bar instead of behind it: nothing opaque sits under the
-- bar's empty part, and the rim stays solid. The target outline lives in the
-- same bands. The cast box keeps a solid background: a channel drains by
-- covering the cast color with the track color.
local Kit = addon.Kit
local ONYX, FLAT = Kit.onyx, Kit.FLAT
local Tint, Text, Bar = Kit.Tint, Kit.Text, Kit.Bar
local BAND_ROOM = 16 -- room the bands keep outside the box, for the target outline

local function Box(parent)
    local box = CreateFrame("Frame", nil, parent)
    box.rim = box:CreateTexture(nil, "BACKGROUND", nil, 0)
    box.gap = box:CreateTexture(nil, "BACKGROUND", nil, 1)
    box.rim:SetTexture(FLAT); box.gap:SetTexture(FLAT)
    box.rims, box.gaps = { box.rim }, { box.gap }
    box.bar = Bar(box)
    return box
end

-- Top, bottom, left and right bands; each clips a full copy of the rim, gap
-- and outline, so together they draw the box minus the bar's rectangle.
local function BandedBox(parent)
    local box = CreateFrame("Frame", nil, parent)
    box.bands, box.rims, box.gaps, box.outlines = {}, {}, {}, {}
    for i = 1, 4 do
        local band = CreateFrame("Frame", nil, box)
        band:SetClipsChildren(true)
        band.layer = CreateFrame("Frame", nil, band)
        band.layer:SetAllPoints(band)
        local layer = band.layer
        box.bands[i] = band
        box.outlines[i] = layer:CreateTexture(nil, "BACKGROUND", nil, -1)
        box.rims[i] = layer:CreateTexture(nil, "BACKGROUND", nil, 0)
        box.gaps[i] = layer:CreateTexture(nil, "BACKGROUND", nil, 1)
        box.rims[i]:SetTexture(FLAT); box.gaps[i]:SetTexture(FLAT)
        box.outlines[i]:Hide()
    end
    box.rim, box.gap, box.outline = box.rims[1], box.gaps[1], box.outlines[1]
    box.bar = Bar(box)
    return box
end

local function PlaceBands(box, inset)
    local top, bottom, left, right = box.bands[1], box.bands[2], box.bands[3], box.bands[4]
    for _, band in ipairs(box.bands) do band:ClearAllPoints() end
    top:SetPoint("TOPLEFT", box, "TOPLEFT", -BAND_ROOM, BAND_ROOM)
    top:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", BAND_ROOM, -inset)
    bottom:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -BAND_ROOM, inset)
    bottom:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", BAND_ROOM, -BAND_ROOM)
    left:SetPoint("TOPLEFT", box, "TOPLEFT", -BAND_ROOM, -inset)
    left:SetPoint("BOTTOMRIGHT", box, "BOTTOMLEFT", inset, inset)
    right:SetPoint("TOPLEFT", box, "TOPRIGHT", -inset, -inset)
    right:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", BAND_ROOM, inset)
    -- Bands under the bar; the text and aura layers sit above both.
    local level = box:GetFrameLevel()
    for _, band in ipairs(box.bands) do band:SetFrameLevel(level); band.layer:SetFrameLevel(level) end
    box.bar:SetFrameLevel(level + 1)
end
local function LiftedText(layer)
    local text = Text(layer)
    text.lift = Text(layer, "ARTWORK")
    return text
end

-- A plate's frames, on any parent: a game nameplate, or the settings preview.
function M:BuildPlate(parent)
    local plate = CreateFrame("Frame", nil, parent)
    plate.healthBox = BandedBox(plate)
    plate.health = plate.healthBox.bar
    plate.castBox = Box(plate)
    plate.cast = plate.castBox.bar
    plate.castIcon = plate.castBox:CreateTexture(nil, "ARTWORK")
    -- Target indicator: a thicker border under the rim (in the health box's
    -- bands), a soft glow around it (hollow, so it never shows through), arrows.
    plate.targetOutline, plate.targetOutlines = plate.healthBox.outline, plate.healthBox.outlines
    plate.targetGlow = plate:CreateTexture(nil, "BACKGROUND", nil, -8)
    plate.textLayer = CreateFrame("Frame", nil, plate)
    plate.textLayer:SetAllPoints()
    plate.name, plate.healthText, plate.castText = LiftedText(plate.textLayer), LiftedText(plate.textLayer), LiftedText(plate.textLayer)
    plate.raidIcon = plate.textLayer:CreateTexture(nil, "OVERLAY")
    plate.arrows = { left = plate.textLayer:CreateTexture(nil, "OVERLAY"), right = plate.textLayer:CreateTexture(nil, "OVERLAY") }
    plate.auraLayer = CreateFrame("Frame", nil, plate)
    plate.auraLayer:SetAllPoints()
    plate.auraIcons, plate.auraShown, plate.auraCount = { crowdControl = {}, debuffs = {}, buffs = {} }, {}, 0
    for _, region in ipairs({ plate.targetGlow, plate.arrows.left, plate.arrows.right }) do region:Hide() end
    self:BuildIndicator(plate)
    plate.castBox:Hide()
    plate:Hide()
    return plate
end

function M:EnsurePlate(nameplate)
    local plate = self.plates[nameplate]
    if plate then return plate end
    plate = self:BuildPlate(nameplate)
    plate.nameplate = nameplate
    plate:SetPoint("CENTER", nameplate, "CENTER", 0, 0)
    -- Blizzard acquires its unit frame for each new unit; fade it on arrival.
    if hooksecurefunc and type(nameplate.AcquireUnitFrame) == "function" then
        hooksecurefunc(nameplate, "AcquireUnitFrame", function(frame) self:OnBlizzardAcquired(frame) end)
    end
    self.plates[nameplate] = plate
    return plate
end

-- The nameplate rim textures (corner radius 3, sliced at 4) need at least
-- this many units each way; only the very smallest bars stay square.
local ROUNDED_MINIMUM = 8
function M.SkinRounded(texture, key, rounded)
    if rounded then Kit.Rounded(texture, key); return end
    if texture.ClearTextureSlice then texture:ClearTextureSlice() end
    texture:SetTexture(FLAT)
end
local Skin = M.SkinRounded

-- Lays out one box and returns its full height. `background` is the track's
-- opacity (0-1); only a banded box can show the world through it.
function M.LayoutBox(box, width, barHeight, px, background)
    local inset = 2 * px
    local height = barHeight + 2 * inset
    box:SetSize(width, height)
    local rounded = height >= ROUNDED_MINIMUM and width >= ROUNDED_MINIMUM
    for _, rim in ipairs(box.rims) do
        rim:ClearAllPoints(); rim:SetAllPoints(box)
        Skin(rim, "NameplateRim", rounded); Tint(rim, ONYX.border, 1)
    end
    for _, gap in ipairs(box.gaps) do
        Kit.Inset(gap, box, px)
        Skin(gap, "NameplateGap", rounded); Tint(gap, ONYX.inner, 1)
    end
    if box.bands then PlaceBands(box, inset) end
    local bar = box.bar
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", box, "TOPLEFT", inset, -inset)
    bar:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -inset, inset)
    Kit.ModeGradient(bar, barHeight, px)
    bar.bg:SetTexture(FLAT); Tint(bar.bg, ONYX.track, box.bands and background or 1)
    return height
end
