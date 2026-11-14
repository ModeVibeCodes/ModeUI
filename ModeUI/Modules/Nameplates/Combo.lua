local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- Combo points on your target's plate (Domain.ClassResource): on WoW Forever,
-- a Rogue's or a Cat Form Druid's combo points, which live on the target
-- (GetComboPoints("player", "target")), so they follow the target from plate
-- to plate. Forever's own nameplates draw none: Blizzard_NamePlates loads its
-- Rogue and Druid class bars only outside camelot. A class without combo
-- points shows nothing.
--
-- One round socket per point (Shared/Kit/Points.lua: secret-safe, one
-- StatusBar per point) in a row, placed by anchor like the raid marker: Top
-- and Bottom anchors sit past the name and cast bar, Left and Right beside the
-- bar past the marker, indicators and aura rows (the target arrows sit past
-- them), Center on the bar. Settings: each kind's showCombo and combo* keys.
local Kit, Resource, NP = addon.Kit, addon.Domain.ClassResource, addon.Domain.Nameplate
M.COMBO_SAMPLE = 3 -- points lit on the settings preview
-- The player's power changes the count; Cat Form changes whether there is one.
local POWER_EVENTS = { "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }

function M:BuildCombo(plate)
    local combo = CreateFrame("Frame", nil, plate)
    combo.sockets, combo.count, combo.width, combo.size = {}, 0, 0, 0
    for i = 1, Resource.MAX do combo.sockets[i] = Kit.ResourcePoint(combo, i) end
    combo:Hide()
    plate.combo, plate.comboRoom = combo, { LEFT = 0, RIGHT = 0 }
end

-- Sizes `count` sockets (default: the count already shown) from the kind's
-- settings, in a row from the left. Called from LayoutPlate and whenever the
-- count changes; PlaceCombo then places the row.
function M:SizeCombo(plate, count)
    local combo, db, px = plate.combo, self:Style(plate), plate.px or 1
    count = count or combo.count
    local size = Kit.ResourcePointSize(db.comboSize, px)
    local spacing = math.floor(db.comboSpacing / px + 0.5) * px
    combo:SetFrameLevel(plate.textLayer:GetFrameLevel() + 1)
    for i, point in ipairs(combo.sockets) do
        point:SetShown(i <= count)
        if i <= count then
            Kit.LayoutResourcePoint(point, size, px, db.comboEmptyColor, db.comboActiveColor)
            point:ClearAllPoints()
            point:SetPoint("LEFT", combo, "LEFT", (i - 1) * (size + spacing), 0)
        end
    end
    combo.count, combo.size = count, size
    combo.width = count > 0 and count * size + (count - 1) * spacing or 0
    combo:SetShown(count > 0)
end

-- Places the row; called from PlaceArrows, so it moves whenever the aura rows
-- beside the bar do. Records the room it takes on its side for the arrows.
function M:PlaceCombo(plate)
    local combo, db, px = plate.combo, self:Style(plate), plate.px or 1
    plate.comboRoom = { LEFT = 0, RIGHT = 0 }
    if not combo or combo.count == 0 then return end
    local anchor = db.comboAnchor
    local side = (anchor == "LEFT" or anchor == "RIGHT") and anchor or nil
    local sign = anchor == "LEFT" and -1 or 1
    local clear = side and math.max(self:SideRoom(plate, side), (plate.auraExtent or {})[side] or 0) or 0
    self:PlaceIcon(plate, combo, anchor, combo.width, combo.size, db.comboX + sign * clear, db.comboY)
    if side then plate.comboRoom[side] = clear + 3 * px + combo.width + math.max(0, sign * db.comboX) end
end

function M:ComboRoom(plate, side) return plate.comboRoom and plate.comboRoom[side] or 0 end

-- Shows `count` sockets, re-placing the row (and the arrows) when it changes.
local function Show(self, plate, count)
    if count == plate.combo.count then return end
    self:SizeCombo(plate, count)
    self:PlaceArrows(plate)
end

-- How many sockets the target's plate shows: the player's maximum while they
-- build combo points (a Rogue, or a Druid in Cat Form), else none.
function M:ComboCount() return Resource.Active() and Resource.Max() or 0 end

-- The target is found by comparing nameplate frames, never secret units.
function M:UpdateCombo(plate, targetPlate, count)
    if plate.sample or not plate.combo then return end
    if targetPlate == nil then targetPlate = NP.ForUnit("target") or false end
    local on = plate.unit ~= nil and self:Style(plate).showCombo and plate.nameplate == targetPlate
    local shown = on and (count or self:ComboCount()) or 0
    Show(self, plate, shown)
    if shown > 0 then
        self.comboPlate = plate
        Kit.FillResourcePoints(plate.combo.sockets, shown, Resource.Read())
    elseif self.comboPlate == plate then
        self.comboPlate = nil
    end
end

function M:UpdateCombos()
    if not self.byUnit then return end
    local targetPlate, count = NP.ForUnit("target") or false, self:ComboCount()
    for _, plate in pairs(self.byUnit) do self:UpdateCombo(plate, targetPlate, count) end
end

-- A plate losing its unit drops its points.
function M:ClearCombo(plate)
    if self.comboPlate == plate then self.comboPlate = nil end
    if plate.combo then Show(self, plate, 0) end
end

-- The player's power events are unit-filtered on a frame of the module's own
-- (Shared/Runtime/Events.lua registers events for every unit, and nameplate
-- units send many). COMBO_TARGET_CHANGED moves the points to a new target
-- without a power event (Camelot TargetBoundComboPointBar); registered through
-- pcall, since RegisterEvent errors on an event a client lacks.
function M:SetComboEvents(on)
    local frame = self.comboEvents
    if not frame then
        if not on then return end
        frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", function(_, event)
            -- A power tick only refills the plate already showing points.
            if event == "UNIT_POWER_FREQUENT" and self.comboPlate then
                Kit.FillResourcePoints(self.comboPlate.combo.sockets, self.comboPlate.combo.count, Resource.Read())
            else
                self:UpdateCombos()
            end
        end)
        self.comboEvents = frame
    end
    if frame.on == on then return end
    frame.on = on
    for _, event in ipairs(POWER_EVENTS) do
        if on then frame:RegisterUnitEvent(event, "player") else frame:UnregisterEvent(event) end
    end
    if on then pcall(frame.RegisterEvent, frame, "COMBO_TARGET_CHANGED") else pcall(frame.UnregisterEvent, frame, "COMBO_TARGET_CHANGED") end
end

-- The preview's sample shows every socket with a few lit, for a class with
-- combo points (a Druid sees them in any form).
function M:SampleComboCount(style) return style.showCombo and Resource.Max() or 0 end
function M:PaintSampleCombo(plate, style)
    local count = self:SampleComboCount(style)
    Show(self, plate, count)
    for i = 1, count do plate.combo.sockets[i].bar:SetValue(self.COMBO_SAMPLE) end
end
