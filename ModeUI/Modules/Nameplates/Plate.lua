local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- Building a plate on a game nameplate, and its pixel-perfect layout. Plates
-- are plain frames (never secure), so they can be built and changed in combat.
-- Each box is a 1px slate rim and a 1px black gap with rounded corners, like
-- the unit frames, then the bar in the Mode Gradient texture.
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
    plate.textLayer = CreateFrame("Frame", nil, plate)
    plate.textLayer:SetAllPoints()
    plate.name, plate.healthText, plate.castText = LiftedText(plate.textLayer), LiftedText(plate.textLayer), LiftedText(plate.textLayer)
    plate.raidIcon = plate.textLayer:CreateTexture(nil, "OVERLAY")
    plate.auraLayer = CreateFrame("Frame", nil, plate)
    plate.auraLayer:SetAllPoints()
    plate.auraIcons = {}
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
-- The rounded rim textures need at least this many units each way.
local ROUNDED_MINIMUM = 12
local function Skin(texture, key, rounded)
    if rounded then Kit.Rounded(texture, key); return end
    if texture.ClearTextureSlice then texture:ClearTextureSlice() end
    texture:SetTexture(FLAT)
end

-- Lays out one box and returns its full height.
local function LayoutBox(box, width, barHeight, px)
    local inset = 2 * px
    local height = barHeight + 2 * inset
    box:SetSize(width, height)
    local rounded = height >= ROUNDED_MINIMUM and width >= ROUNDED_MINIMUM
    box.rim:ClearAllPoints(); box.rim:SetAllPoints(box)
    Skin(box.rim, "UnitFrameFrame", rounded); Tint(box.rim, ONYX.border, 1)
    Kit.Inset(box.gap, box, px)
    Skin(box.gap, "UnitFrameFrameInner", rounded); Tint(box.gap, ONYX.inner, 1)
    local bar = box.bar
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", box, "TOPLEFT", inset, -inset)
    bar:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -inset, inset)
    Kit.ModeGradient(bar, barHeight, px)
    bar.bg:SetTexture(FLAT); Tint(bar.bg, ONYX.track, 1)
    return height
end

function M:LayoutPlate(plate)
    local db, px = self:Style(plate), Kit.PixelSize(plate)
    local function Snap(v) return math.max(px, math.floor(v / px + 0.5) * px) end
    local width = Snap(db.width)
    local healthHeight = LayoutBox(plate.healthBox, width, Snap(db.healthHeight), px)
    local gap = 2 * px
    local castHeight = LayoutBox(plate.castBox, width, Snap(db.castHeight), px)
    plate.castBarHeight = castHeight
    plate:SetSize(width, healthHeight + gap + castHeight)
    plate.healthBox:ClearAllPoints(); plate.healthBox:SetPoint("TOP", plate, "TOP", 0, 0)
    plate.castBox:ClearAllPoints(); plate.castBox:SetPoint("TOP", plate.healthBox, "BOTTOM", 0, -gap)
    plate.textLayer:SetFrameLevel(plate.healthBox:GetFrameLevel() + 3)
    plate.auraLayer:SetFrameLevel(plate.healthBox:GetFrameLevel() + 4)
    -- The cast bar's icon sits inside its box on the left, square to the bar,
    -- and the bar starts one pixel after it.
    local icon, inner, inset = plate.castIcon, Snap(db.castHeight), 2 * px
    icon:ClearAllPoints(); icon:SetPoint("TOPLEFT", plate.castBox, "TOPLEFT", inset, -inset); icon:SetSize(inner, inner)
    plate.cast:ClearAllPoints()
    plate.cast:SetPoint("TOPLEFT", icon, "TOPRIGHT", px, 0)
    plate.cast:SetPoint("BOTTOMRIGHT", plate.castBox, "BOTTOMRIGHT", -inset, inset)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local path = Kit.FontPath(db, self.id)
    plate.fontPath, plate.px = path, px
    local function Place(text, size, shown, justify)
        Kit.Font(text, db, size, path, px)
        text:SetJustifyH(justify)
        Kit.LayoutLift(text, db, size, path, px, shown, justify)
        text:SetShown(shown)
    end
    plate.name:ClearAllPoints()
    plate.name:SetPoint("BOTTOMLEFT", plate.healthBox, "TOPLEFT", 0, 2 * px)
    plate.name:SetPoint("BOTTOMRIGHT", plate.healthBox, "TOPRIGHT", 0, 2 * px)
    Place(plate.name, db.nameFontSize, db.showName, "CENTER")
    plate.healthText:ClearAllPoints(); plate.healthText:SetPoint("RIGHT", plate.health, "RIGHT", -2 * px, 0)
    Place(plate.healthText, db.healthFontSize, db.healthText ~= "none", "RIGHT")
    plate.castText:ClearAllPoints()
    plate.castText:SetPoint("LEFT", plate.cast, "LEFT", 2 * px, 0); plate.castText:SetPoint("RIGHT", plate.cast, "RIGHT", -2 * px, 0)
    Place(plate.castText, db.castFontSize, true, "LEFT")
    -- The raid marker stands just left of the health box.
    local mark = Snap(math.max(14, healthHeight + 4))
    plate.markSize = mark
    plate.raidIcon:ClearAllPoints(); plate.raidIcon:SetPoint("RIGHT", plate.healthBox, "LEFT", -3 * px, 0)
    plate.raidIcon:SetSize(mark, mark)
    for _, auraIcon in ipairs(plate.auraIcons) do Kit.LayoutAuraIcon(auraIcon, Snap(db.auraSize), px, db, path) end
end
