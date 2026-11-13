local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- Indicators: a quest icon, a classification icon (elite, rare elite, rare,
-- boss) and the unit's level. Each has its own switch, anchor, offset and size.
-- Indicators that share an anchor line up in one row (quest, classification,
-- level), placed like the raid marker; on a side of the bar the row sits past
-- the marker, and aura rows and target arrows sit past it. Level and
-- classification come from UnitLevel and UnitClassification, quest from
-- UnitIsQuestBoss and C_QuestLog.UnitIsRelatedToActiveQuest (Domain/Level,
-- Domain/Quest); an unknown or secret answer hides that indicator.
local Kit, Domain = addon.Kit, addon.Domain
local Level, Quest = Domain.Level, Domain.Quest

-- Blizzard's own nameplate classification atlases
-- (Blizzard_NamePlateClassificationFrame.lua) and the target frame quest icon.
M.classificationAtlas = { elite = "nameplates-icon-elite-gold", worldboss = "nameplates-icon-elite-gold",
    rareelite = "nameplates-icon-elite-silver", rare = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star" }
M.QUEST_ATLAS = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Quest"
-- Each indicator's switch; its anchor, offsets and size are <part>Anchor,
-- <part>X, <part>Y and <part>Size (the level's size is its text size).
M.indicatorShowKeys = { quest = "indicatorQuest", classification = "indicatorClassification", level = "indicatorLevel" }

local function Snap(value, px) return math.max(px, math.floor(value / px + 0.5) * px) end
local function Round(value, px) return math.floor(value / px + 0.5) * px end

function M:BuildIndicator(plate)
    local layer = plate.textLayer
    local level = Kit.Text(layer)
    level.lift = Kit.Text(layer, "ARTWORK")
    plate.indicatorParts = { quest = layer:CreateTexture(nil, "OVERLAY"), classification = layer:CreateTexture(nil, "OVERLAY"), level = level }
    for _, part in ipairs(M.indicatorParts) do plate.indicatorParts[part]:Hide() end
    level.lift:Hide()
    plate.indicatorRows, plate.indicatorRoom = {}, { LEFT = 0, RIGHT = 0 }
end

-- One row frame per anchor in use, made on demand.
local function Row(plate, anchor)
    local row = plate.indicatorRows[anchor]
    if not row then
        row = CreateFrame("Frame", nil, plate.textLayer)
        row.width, row.height = 0, 0
        plate.indicatorRows[anchor] = row
    end
    return row
end

-- Fonts follow the plate's text settings; called from LayoutPlate.
function M:LayoutIndicator(plate)
    local db, px, path = self:Style(plate), plate.px or 1, plate.fontPath
    local level = plate.indicatorParts.level
    Kit.Font(level, db, db.levelSize, path, px)
    level:SetJustifyH("LEFT")
    Kit.LayoutLift(level, db, db.levelSize, path, px, level:IsShown(), "LEFT")
    local state = plate.indicatorState or {}
    self:PaintIndicator(plate, state.quest, state.classification, state.level, state.color)
end

-- Shows the indicators given: quest is a boolean, classification a
-- UnitClassification string, level the text to show ("" for none) and color
-- its { r, g, b } or nil for the text color.
function M:PaintIndicator(plate, quest, classification, level, color)
    plate.indicatorState = { quest = quest, classification = classification, level = level, color = color }
    local db, px, parts = self:Style(plate), plate.px or 1, plate.indicatorParts
    local on, gap = db.showIndicator, 2 * px
    local content = {
        quest = on and db.indicatorQuest and quest and M.QUEST_ATLAS or nil,
        classification = on and db.indicatorClassification and classification and M.classificationAtlas[classification] or nil,
        level = on and db.indicatorLevel and level ~= nil and level ~= "" and level or nil,
    }
    for _, row in pairs(plate.indicatorRows) do row.width, row.height = 0, 0 end
    for _, part in ipairs(M.indicatorParts) do
        local region, value = parts[part], content[part]
        if not value then
            region:Hide()
            if part == "level" then region.lift:Hide() end
        else
            local anchor = db[part .. "Anchor"]
            local row = Row(plate, anchor)
            local w, h
            if part == "level" then
                Kit.Write(region, value)
                local c = color or db.textColor
                region:SetTextColor(c[1], c[2], c[3], 1)
                w, h = Snap(region:GetStringWidth(), px), Snap(db.levelSize + 2, px)
                region.lift:SetShown(db.shadow and db.liftedShadow)
            else
                region:SetAtlas(value)
                w = Snap(db[part .. "Size"], px); h = w
                region:SetSize(w, h)
            end
            region:ClearAllPoints()
            region:SetPoint("LEFT", row, "LEFT", row.width + Round(db[part .. "X"], px), Round(db[part .. "Y"], px))
            region:Show()
            row.width, row.height = row.width + w + gap, math.max(row.height, h)
        end
    end
    local room = { LEFT = 0, RIGHT = 0 }
    for anchor, row in pairs(plate.indicatorRows) do
        local width = math.max(0, row.width - gap)
        row:SetShown(width > 0)
        if width > 0 then
            local marker = (db.showRaidIcon and db.raidAnchor == anchor) and (plate.markSize or 0) + 3 * px or 0
            local dx = anchor == "LEFT" and -marker or anchor == "RIGHT" and marker or 0
            self:PlaceIcon(plate, row, anchor, width, math.max(px, row.height), dx, 0)
            if room[anchor] then room[anchor] = width + 3 * px end
        end
    end
    local changed = room.LEFT ~= plate.indicatorRoom.LEFT or room.RIGHT ~= plate.indicatorRoom.RIGHT
    plate.indicatorRoom = room
    -- Wider or narrower indicators beside the bar move the aura rows and arrows.
    if changed and plate.auraIcons then self:LayoutAuras(plate) end
end

-- Room the indicators take beside the bar on one side, with a 3px gap.
function M:IndicatorRoom(plate, side)
    return plate.indicatorRoom and plate.indicatorRoom[side] or 0
end

function M:UpdateIndicator(plate)
    local db, unit = self:Style(plate), plate.unit
    if not db.showIndicator or not unit then self:PaintIndicator(plate); return end
    local level, text = Level.Number(unit), ""
    if level then text = level < 0 and "??" or tostring(level) end
    self:PaintIndicator(plate, Quest.IsRelated(unit), Level.Classification(unit), text, level and Level.DifficultyColor(level))
end
