local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- Building a plate and laying out its two boxes. Plates are plain frames
-- (never secure), so they can be built and changed in combat. Each box is a
-- 1px rim and a 1px black gap with rounded corners, then the bar in the Mode
-- Gradient texture. Health and cast boxes use the same rim textures, so they
-- round alike at every size. Elements are placed in Layout.lua and the target
-- indicator in Target.lua.
local Kit = addon.Kit
local ONYX, FLAT = Kit.onyx, Kit.FLAT
local Tint, Text, Bar = Kit.Tint, Kit.Text, Kit.Bar

local function Box(parent)
    local box = CreateFrame("Frame", nil, parent)
    box.rim = box:CreateTexture(nil, "BACKGROUND", nil, 0)
    box.gap = box:CreateTexture(nil, "BACKGROUND", nil, 1)
    box.rim:SetTexture(FLAT); box.gap:SetTexture(FLAT)
    box.bar = Bar(box)
    return box
end
local function LiftedText(layer)
    local text = Text(layer)
    text.lift = Text(layer, "ARTWORK")
    return text
end

-- A plate's frames, on any parent: a game nameplate, or the settings preview.
function M:BuildPlate(parent)
    local plate = CreateFrame("Frame", nil, parent)
    plate.healthBox = Box(plate)
    plate.health = plate.healthBox.bar
    plate.castBox = Box(plate)
    plate.cast = plate.castBox.bar
    plate.castIcon = plate.castBox:CreateTexture(nil, "ARTWORK")
    -- Target indicator: a thicker border under the rim, a soft glow, arrows.
    plate.targetOutline = plate.healthBox:CreateTexture(nil, "BACKGROUND", nil, -1)
    plate.targetGlow = plate:CreateTexture(nil, "BACKGROUND", nil, -8)
    plate.textLayer = CreateFrame("Frame", nil, plate)
    plate.textLayer:SetAllPoints()
    plate.name, plate.healthText, plate.castText = LiftedText(plate.textLayer), LiftedText(plate.textLayer), LiftedText(plate.textLayer)
    plate.raidIcon = plate.textLayer:CreateTexture(nil, "OVERLAY")
    plate.arrows = { left = plate.textLayer:CreateTexture(nil, "OVERLAY"), right = plate.textLayer:CreateTexture(nil, "OVERLAY") }
    plate.auraLayer = CreateFrame("Frame", nil, plate)
    plate.auraLayer:SetAllPoints()
    plate.auraIcons, plate.auraShown, plate.auraCount = { crowdControl = {}, debuffs = {}, buffs = {} }, {}, 0
    for _, region in ipairs({ plate.targetOutline, plate.targetGlow, plate.arrows.left, plate.arrows.right }) do region:Hide() end
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

-- Lays out one box and returns its full height.
function M.LayoutBox(box, width, barHeight, px)
    local inset = 2 * px
    local height = barHeight + 2 * inset
    box:SetSize(width, height)
    local rounded = height >= ROUNDED_MINIMUM and width >= ROUNDED_MINIMUM
    box.rim:ClearAllPoints(); box.rim:SetAllPoints(box)
    Skin(box.rim, "NameplateRim", rounded); Tint(box.rim, ONYX.border, 1)
    Kit.Inset(box.gap, box, px)
    Skin(box.gap, "NameplateGap", rounded); Tint(box.gap, ONYX.inner, 1)
    local bar = box.bar
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", box, "TOPLEFT", inset, -inset)
    bar:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -inset, inset)
    Kit.ModeGradient(bar, barHeight, px)
    bar.bg:SetTexture(FLAT); Tint(bar.bg, ONYX.track, 1)
    return height
end
