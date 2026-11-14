local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- The stand-in: a plain frame the size of a full party that Edit Mode moves
-- (the secure header copies its place outside combat, Header.lua). In Edit
-- Mode, Preview and Test on Screen it shows a sample party, so the frames can
-- be placed and styled without a group. Samples are drawn by the same code as
-- the members in the world (BuildFace, ApplyLayout).
local Kit, UnitColor = addon.Kit, addon.Domain.UnitColor
local L = addon.L

-- Five sample members: class, health %, power %, and what each shows.
M.SAMPLES = {
    { class = "WARRIOR", health = 82, power = 40, powerToken = "RAGE" },
    { class = "PRIEST", health = 64, power = 75, powerToken = "MANA", absorb = 12 },
    { class = "MAGE", health = 100, power = 90, powerToken = "MANA", target = true },
    { class = "ROGUE", health = 38, power = 60, powerToken = "ENERGY", heal = 22, faded = true },
    { class = "HUNTER", health = 0, power = 0, powerToken = "MANA", state = "Dead" },
}
M.SAMPLE_CLASS_NAMES = { WARRIOR = "Warrior", PRIEST = "Priest", MAGE = "Mage", ROGUE = "Rogue", HUNTER = "Hunter" }

-- Lays sample faces out the way the header lays out members.
function M:LayoutSamples(host, faces, count)
    local db = self.db
    local first = faces[1]
    self:ApplyLayout(first)
    local g = first.geometry
    local spacing = math.floor(db.spacing + 0.5) * g.px
    local growth = self.growthPoints[db.growth]
    local point = growth[1]
    for i = 1, #faces do
        local face = faces[i]
        if i <= count then
            if i > 1 then self:ApplyLayout(face) end
            local step = (i - 1) * ((growth[2] ~= 0 and g.width or g.height) + spacing)
            face:ClearAllPoints()
            face:SetPoint(point, host, point, growth[2] * step, growth[3] * step)
            face:Show()
        else face:Hide() end
    end
    local across = growth[2] ~= 0
    local width = across and count * g.width + (count - 1) * spacing or g.width
    local height = across and g.height or count * g.height + (count - 1) * spacing
    return width, height
end

-- Paints one sample member.
function M:PaintSample(f, index)
    local s, db = self.SAMPLES[index], self.db
    f.role = self.SAMPLE_ICONS.role[index]
    self:LayoutBars(f)
    local class = UnitColor.Class(s.class)
    local classColor = class and { class.r, class.g, class.b }
    local color = self:HealthColor(nil, classColor)
    f.health:SetMinMaxValues(0, 100); f.health:SetValue(s.health)
    f.health:SetStatusBarColor(color[1], color[2], color[3], db.healthOpacity / 100)
    local power = db.powerColorMode == "custom" and db.powerColor or addon.Domain.Power.Color(s.powerToken)
    f.power:SetMinMaxValues(0, 100); f.power:SetValue(s.power)
    f.power:SetStatusBarColor(power[1], power[2], power[3], db.healthOpacity / 100)
    for _, part in ipairs({ { f.healPrediction, db.showHealPrediction, s.heal }, { f.absorb, db.showAbsorbs, s.absorb } }) do
        part[1]:SetMinMaxValues(0, 100); part[1]:SetValue(part[3] or 0); part[1]:SetShown(part[2] and true or false)
    end
    local name = self:NameColor(nil, classColor)
    Kit.Write(f.texts.name, L[self.SAMPLE_CLASS_NAMES[s.class]])
    f.texts.name:SetTextColor(name[1], name[2], name[3], 1)
    local text = db.healthText == "percent" and (s.health .. "%") or db.healthText == "current" and tostring(s.health * 120)
        or (s.health < 100 and ("-" .. (100 - s.health) * 120) or "")
    Kit.Write(f.texts.healthText, (db.healthTextShow and not s.state) and text or "")
    Kit.Write(f.texts.status, s.state and L[s.state] or "")
    for _, key in ipairs({ "healthText", "status" }) do
        local c = db.textColor
        f.texts[key]:SetTextColor(c[1], c[2], c[3], 1)
    end
    f:SetAlpha(s.state and db.deadOpacity / 100 or (s.faded and db.rangeFade) and db.rangeOpacity / 100 or 1)
    f.isTarget = s.target == true
    self:PaintTarget(f)
    self:PaintIconSample(f, index)
    self:PaintAuraSample(f, index)
end

function M:CreateGhost()
    if self.ghost then return end
    local ghost = CreateFrame("Frame", "ModeUIPartyFramesMover", UIParent)
    ghost:SetFrameStrata("HIGH")
    ghost.faces = {}
    for i = 1, self.MAX_MEMBERS do
        local face = CreateFrame("Frame", nil, ghost)
        face.ghost, face.inheritScale = true, true
        self:BuildFace(face)
        ghost.faces[i] = face
    end
    self.ghost = ghost
    self:LayoutGhost()
    -- Registration measures the frame, which needs an anchor first; the
    -- Position Manager then moves it to the saved place.
    local default = self.defaultPosition
    ghost:SetPoint("CENTER", UIParent, "CENTER", default.x, default.y)
    ghost:Show()
    local ok, reason = addon.PositionManager:RegisterElement(self.ELEMENT_ID, ghost, { moduleId = self.id,
        defaultPosition = default, allowedTargets = { "screen" }, label = L["Party Frames"],
        canDrag = function() return self.active == true end,
        onPositionChanged = function() addon.Defer:Run("partyFrames:position", function() self:SyncHeaderPosition() end) end })
    assert(ok, "ModeUI: party frame position registration failed: " .. tostring(reason))
    ghost:Hide()
end

function M:LayoutGhost()
    local ghost = self.ghost
    ghost:SetScale(self.db.scale / 100)
    local width, height = self:LayoutSamples(ghost, ghost.faces, self.MAX_MEMBERS)
    ghost:SetSize(width, height)
end

function M:RenderGhost()
    local ghost = self.ghost
    if not ghost then return end
    local show = self.active and (self.editing or self.previewing or self.testing) and true or false
    -- Laid out even while hidden: the header takes its place from it.
    self:LayoutGhost()
    if show then for i, face in ipairs(ghost.faces) do self:PaintSample(face, i) end end
    ghost:SetShown(show)
end
