local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- Building a plate on a game nameplate, and its pixel-perfect layout. Plates
-- are plain frames (never secure), so they can be built and changed in combat.
-- Each box is a 1px slate rim, a 1px black gap, then the bar.
local Kit = addon.Kit
local ONYX, FLAT = Kit.onyx, Kit.FLAT
local Tint, Text, Bar, Gradient = Kit.Tint, Kit.Text, Kit.Bar, Kit.Gradient

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

function M:EnsurePlate(nameplate)
    local plate = self.plates[nameplate]
    if plate then return plate end
    plate = CreateFrame("Frame", nil, nameplate)
    plate.nameplate = nameplate
    plate:SetPoint("CENTER", nameplate, "CENTER", 0, 0)
    plate.healthBox = Box(plate)
    plate.health = plate.healthBox.bar
    plate.castBox = Box(plate)
    plate.cast = plate.castBox.bar
    plate.castIcon = plate.castBox:CreateTexture(nil, "ARTWORK")
    plate.textLayer = CreateFrame("Frame", nil, plate)
    plate.textLayer:SetAllPoints()
    plate.name, plate.healthText, plate.castText = LiftedText(plate.textLayer), LiftedText(plate.textLayer), LiftedText(plate.textLayer)
    plate.raidIcon = plate.textLayer:CreateTexture(nil, "OVERLAY")
    plate.castBox:Hide()
    plate:Hide()
    -- Blizzard acquires its unit frame for each new unit; fade it on arrival.
    if hooksecurefunc and type(nameplate.AcquireUnitFrame) == "function" then
        hooksecurefunc(nameplate, "AcquireUnitFrame", function(frame) self:OnBlizzardAcquired(frame) end)
    end
    self.plates[nameplate] = plate
    return plate
end

function M:BarTexture()
    local db = self.db
    if db.texture == "satin" then return addon.Media:GetTexture("UnitFrameBar") or FLAT, false end
    if db.texture == "mode" then return FLAT, true end
    return addon.Media:GetStatusBar(db.texture, self.id) or FLAT, false
end

-- Lays out one box and returns its full height.
local function LayoutBox(box, width, barHeight, px, texture, sheen)
    local inset = 2 * px
    box:SetSize(width, barHeight + 2 * inset)
    box.rim:ClearAllPoints(); box.rim:SetAllPoints(box); Tint(box.rim, ONYX.border, 1)
    Kit.Inset(box.gap, box, px); Tint(box.gap, ONYX.inner, 1)
    local bar = box.bar
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", box, "TOPLEFT", inset, -inset)
    bar:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -inset, inset)
    bar:SetStatusBarTexture(texture)
    local fill = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if fill and fill.SetDrawLayer then fill:SetDrawLayer("ARTWORK", 0) end
    bar.bg:SetTexture(FLAT); Tint(bar.bg, ONYX.track, 1)
    bar.sheen:SetTexture(FLAT)
    bar.sheen:SetHeight(math.max(px, math.floor(barHeight / (2 * px)) * px))
    Gradient(bar.sheen, { 1, 1, 1, 0.12 }, { 1, 1, 1, 0 }, 0.06)
    bar.sheen:SetShown(sheen)
    return barHeight + 2 * inset
end

function M:LayoutPlate(plate)
    local db, px = self.db, Kit.PixelSize(plate)
    local function Snap(v) return math.max(px, math.floor(v / px + 0.5) * px) end
    local width = Snap(db.width)
    local texture, sheen = self:BarTexture()
    local healthHeight = LayoutBox(plate.healthBox, width, Snap(db.healthHeight), px, texture, sheen)
    local gap = 2 * px
    local castHeight = LayoutBox(plate.castBox, width, Snap(db.castHeight), px, texture, false)
    plate.castBarHeight = castHeight
    plate:SetSize(width, healthHeight + gap + castHeight)
    plate.healthBox:ClearAllPoints(); plate.healthBox:SetPoint("TOP", plate, "TOP", 0, 0)
    plate.castBox:ClearAllPoints(); plate.castBox:SetPoint("TOP", plate.healthBox, "BOTTOM", 0, -gap)
    plate.textLayer:SetFrameLevel(plate.healthBox:GetFrameLevel() + 3)
    -- The cast bar's icon sits inside its box on the left, square to the bar,
    -- and the bar starts one pixel after it.
    local icon, inner, inset = plate.castIcon, Snap(db.castHeight), 2 * px
    icon:ClearAllPoints(); icon:SetPoint("TOPLEFT", plate.castBox, "TOPLEFT", inset, -inset); icon:SetSize(inner, inner)
    plate.cast:ClearAllPoints()
    plate.cast:SetPoint("TOPLEFT", icon, "TOPRIGHT", px, 0)
    plate.cast:SetPoint("BOTTOMRIGHT", plate.castBox, "BOTTOMRIGHT", -inset, inset)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local path = Kit.FontPath(db, self.id)
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
    plate.raidIcon:ClearAllPoints(); plate.raidIcon:SetPoint("RIGHT", plate.healthBox, "LEFT", -3 * px, 0)
    plate.raidIcon:SetSize(mark, mark)
end
