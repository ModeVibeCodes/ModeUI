local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- Indicators: a quest icon, a classification icon (elite, rare elite, rare,
-- boss) and the unit's level. Each has its own switch, anchor, offset and size,
-- and on Left or Right sits beside the bar or, with its Inside switch, inside
-- it. They join the stack on their anchor (Stacks.lua) with the raid marker
-- and the combo points; one that shows nothing takes no room, so the rest
-- close up. Level and classification come from UnitLevel and
-- UnitClassification, quest from UnitIsQuestBoss and
-- C_QuestLog.UnitIsRelatedToActiveQuest (Domain/Level, Domain/Quest); an
-- unknown or secret answer hides that indicator.
local Kit, Domain = addon.Kit, addon.Domain
local Level, Quest = Domain.Level, Domain.Quest

-- Blizzard's own nameplate classification atlases
-- (Blizzard_NamePlateClassificationFrame.lua) and the target frame quest icon.
M.classificationAtlas = { elite = "nameplates-icon-elite-gold", worldboss = "nameplates-icon-elite-gold",
    rareelite = "nameplates-icon-elite-silver", rare = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star" }
M.QUEST_ATLAS = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Quest"
-- Each indicator's switch; its anchor, offsets, size and inside switch are
-- <part>Anchor, <part>X, <part>Y, <part>Size and <part>Inside (the level's
-- size is its text size).
M.indicatorShowKeys = { quest = "indicatorQuest", classification = "indicatorClassification", level = "indicatorLevel" }

local function Snap(value, px) return math.max(px, math.floor(value / px + 0.5) * px) end

function M:BuildIndicator(plate)
    local layer = plate.textLayer
    local level = Kit.Text(layer)
    level.lift = Kit.Text(layer, "ARTWORK")
    plate.indicatorParts = { quest = layer:CreateTexture(nil, "OVERLAY"), classification = layer:CreateTexture(nil, "OVERLAY"), level = level }
    for _, part in ipairs(M.indicatorParts) do plate.indicatorParts[part]:Hide() end
    level.lift:Hide()
    plate.indicatorSizes = {}
end

-- Fonts follow the plate's text settings; called from LayoutPlate.
function M:LayoutIndicator(plate)
    local db, px, path = self:Style(plate), plate.px or 1, plate.fontPath
    local level = plate.indicatorParts.level
    Kit.Font(level, db, db.levelSize, path, px)
    level:SetJustifyH("LEFT")
    Kit.LayoutLift(level, db, db.levelSize, path, px, level:IsShown(), "LEFT")
    local state = plate.indicatorState or {}
    self:PaintIndicator(plate, state.quest, state.classification, state.level, state.color, true)
end

-- Shows the indicators given: quest is a boolean, classification a
-- UnitClassification string, level the text to show ("" for none) and color
-- its { r, g, b } or nil for the text color. The stacks are placed again
-- (unless `laying`: LayoutPlate places them itself once it's done).
function M:PaintIndicator(plate, quest, classification, level, color, laying)
    plate.indicatorState = { quest = quest, classification = classification, level = level, color = color }
    local db, px, parts = self:Style(plate), plate.px or 1, plate.indicatorParts
    local on = db.showIndicator
    local content = {
        quest = on and db.indicatorQuest and quest and M.QUEST_ATLAS or nil,
        classification = on and db.indicatorClassification and classification and M.classificationAtlas[classification] or nil,
        level = on and db.indicatorLevel and level ~= nil and level ~= "" and level or nil,
    }
    for _, part in ipairs(M.indicatorParts) do
        local region, value = parts[part], content[part]
        if not value then
            region:Hide()
            if part == "level" then region.lift:Hide() end
            plate.indicatorSizes[part] = nil
        else
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
            plate.indicatorSizes[part] = { w, h }
            region:Show()
        end
    end
    if not laying then self:PlaceStacks(plate) end
end

function M:UpdateIndicator(plate)
    local db, unit = self:Style(plate), plate.unit
    if not db.showIndicator or not unit then self:PaintIndicator(plate); return end
    local level, text = Level.Number(unit), ""
    if level then text = level < 0 and "??" or tostring(level) end
    self:PaintIndicator(plate, Quest.IsRelated(unit), Level.Classification(unit), text, level and Level.DifficultyColor(level))
end
