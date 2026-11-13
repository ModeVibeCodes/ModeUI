local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- The indicator: a quest icon, a classification icon (elite, rare elite, rare,
-- boss) and the unit's level, side by side in one small frame placed by
-- anchor like the raid marker. On a side of the bar it sits past the marker,
-- and aura rows and target arrows sit past it. Level and classification come
-- from UnitLevel and UnitClassification, quest from UnitIsQuestBoss and
-- C_QuestLog.UnitIsRelatedToActiveQuest (Domain/Level, Domain/Quest); an
-- unknown or secret answer hides that part.
local Kit, Domain = addon.Kit, addon.Domain
local Level, Quest = Domain.Level, Domain.Quest

-- Blizzard's own nameplate classification atlases
-- (Blizzard_NamePlateClassificationFrame.lua) and the target frame quest icon.
M.classificationAtlas = { elite = "nameplates-icon-elite-gold", worldboss = "nameplates-icon-elite-gold",
    rareelite = "nameplates-icon-elite-silver", rare = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star" }
M.QUEST_ATLAS = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Quest"

local function Snap(value, px) return math.max(px, math.floor(value / px + 0.5) * px) end

function M:BuildIndicator(plate)
    local frame = CreateFrame("Frame", nil, plate.textLayer)
    frame.quest = frame:CreateTexture(nil, "OVERLAY")
    frame.classification = frame:CreateTexture(nil, "OVERLAY")
    frame.level = Kit.Text(frame)
    frame.level.lift = Kit.Text(frame, "ARTWORK")
    frame:Hide()
    plate.indicator, plate.indicatorWidth = frame, 0
end

-- Fonts follow the plate's text settings; called from LayoutPlate.
function M:LayoutIndicator(plate)
    local db, px, path = self:Style(plate), plate.px or 1, plate.fontPath
    local level = plate.indicator.level
    Kit.Font(level, db, db.indicatorFontSize, path, px)
    level:SetJustifyH("LEFT")
    Kit.LayoutLift(level, db, db.indicatorFontSize, path, px, true, "LEFT")
    self:PlaceIndicator(plate)
end

-- Shows the parts given, left to right: quest, classification, level.
-- quest is a boolean, classification a UnitClassification string, level the
-- text to show ("" for none) and color its { r, g, b } or nil for the text color.
function M:PaintIndicator(plate, quest, classification, level, color)
    local db, frame, px = self:Style(plate), plate.indicator, plate.px or 1
    local size, gap, x = Snap(db.indicatorSize, px), 2 * px, 0
    local function Icon(texture, atlas)
        if not atlas then texture:Hide(); return end
        texture:SetAtlas(atlas)
        texture:SetSize(size, size)
        texture:ClearAllPoints(); texture:SetPoint("LEFT", frame, "LEFT", x, 0)
        texture:Show()
        x = x + size + gap
    end
    local on = db.showIndicator
    Icon(frame.quest, on and db.indicatorQuest and quest and M.QUEST_ATLAS or nil)
    Icon(frame.classification, on and db.indicatorClassification and classification and M.classificationAtlas[classification] or nil)
    local text = (on and db.indicatorLevel and level) or ""
    Kit.Write(frame.level, text)
    if text ~= "" then
        local c = color or db.textColor
        frame.level:SetTextColor(c[1], c[2], c[3], 1)
        frame.level:ClearAllPoints(); frame.level:SetPoint("LEFT", frame, "LEFT", x, 0)
        x = x + Snap(frame.level:GetStringWidth(), px) + gap
    end
    frame.level:SetShown(text ~= ""); frame.level.lift:SetShown(text ~= "" and db.shadow and db.liftedShadow)
    local width = math.max(0, x - gap)
    frame:SetSize(math.max(px, width), size)
    frame:SetShown(width > 0)
    local changed = width ~= plate.indicatorWidth
    plate.indicatorWidth = width
    self:PlaceIndicator(plate)
    -- A wider or narrower indicator beside the bar moves the aura rows and arrows.
    if changed and (db.indicatorAnchor == "LEFT" or db.indicatorAnchor == "RIGHT") then self:LayoutAuras(plate) end
end

-- Placed like the raid marker; on a side shared with the marker, past it.
function M:PlaceIndicator(plate)
    local db, px = self:Style(plate), plate.px or 1
    local anchor, dx = db.indicatorAnchor, db.indicatorX
    local marker = (db.showRaidIcon and db.raidAnchor == anchor) and (plate.markSize or 0) + 3 * px or 0
    if anchor == "LEFT" then dx = dx - marker elseif anchor == "RIGHT" then dx = dx + marker end
    local frame = plate.indicator
    self:PlaceIcon(plate, frame, anchor, math.max(px, plate.indicatorWidth or 0), Snap(db.indicatorSize, px), dx, db.indicatorY)
end

-- Room the indicator takes beside the bar on one side, with a 3px gap.
function M:IndicatorRoom(plate, side)
    local db, px = self:Style(plate), plate.px or 1
    if db.showIndicator and db.indicatorAnchor == side and (plate.indicatorWidth or 0) > 0 then
        return plate.indicatorWidth + 3 * px
    end
    return 0
end

function M:UpdateIndicator(plate)
    local db, unit = self:Style(plate), plate.unit
    if not db.showIndicator or not unit then self:PaintIndicator(plate); return end
    local level, text = Level.Number(unit), ""
    if level then text = level < 0 and "??" or tostring(level) end
    self:PaintIndicator(plate, Quest.IsRelated(unit), Level.Classification(unit), text, level and Level.DifficultyColor(level))
end
