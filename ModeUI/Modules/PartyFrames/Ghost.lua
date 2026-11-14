local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- The stand-in: a plain frame the size of a full party that Edit Mode moves
-- (the secure header copies its place outside combat, Header.lua). In Edit
-- Mode, Preview and Test on Screen it shows a sample party, so the frames can
-- be placed and styled without a group. Samples are drawn by the same code as
-- the members in the world (BuildFace, ApplyLayout). When its size changes
-- (width, height, scale, growth) the corner the group grows from stays where
-- it was on the screen.
local Kit, UnitColor = addon.Kit, addon.Domain.UnitColor
local L = addon.L

-- Five sample members: class, health %, power %, and what each shows.
M.SAMPLES = {
    { class = "WARRIOR", health = 82, power = 40, powerToken = "RAGE" },
    { class = "PRIEST", health = 64, power = 75, powerToken = "MANA", absorb = 12 },
    { class = "MAGE", health = 100, power = 90, powerToken = "MANA", target = true, overshield = 18 },
    { class = "ROGUE", health = 38, power = 60, powerToken = "ENERGY", heal = 22, faded = true },
    { class = "HUNTER", health = 0, power = 0, powerToken = "MANA", state = "Dead" },
}
M.SAMPLE_CLASS_NAMES = { WARRIOR = "Warrior", PRIEST = "Priest", MAGE = "Mage", ROGUE = "Rogue", HUNTER = "Hunter" }
-- The corner each growth direction starts from.
M.growthCorners = { down = "TOPLEFT", up = "BOTTOMLEFT", right = "TOPLEFT", left = "TOPRIGHT" }
M.RAID_GROUP_GAP = 8

-- Lays sample faces out the way the header lays out members; more than five
-- go in groups of five side by side (raid previews).
function M:LayoutSamples(host, faces, count)
    local db = self.db
    self:ApplyLayout(faces[1])
    local g = faces[1].geometry
    local spacing = math.floor(db.spacing + 0.5) * g.px
    local gap = spacing + self.RAID_GROUP_GAP * g.px
    local growth = self.growthPoints[db.growth]
    local corner = self.growthCorners[db.growth]
    local across = growth[2] ~= 0
    for i = 1, #faces do
        local face = faces[i]
        if i <= count then
            if i > 1 then self:ApplyLayout(face) end
            local step, group = (i - 1) % self.MAX_MEMBERS, math.floor((i - 1) / self.MAX_MEMBERS)
            local along = step * ((across and g.width or g.height) + spacing)
            local aside = group * ((across and g.height or g.width) + gap)
            local x = across and growth[2] * along or (corner:find("RIGHT") and -aside or aside)
            local y = across and -aside or growth[3] * along
            face:ClearAllPoints()
            face:SetPoint(corner, host, corner, x, y)
            face:Show()
        else face:Hide() end
    end
    local inGroup, groups = math.min(count, self.MAX_MEMBERS), math.ceil(count / self.MAX_MEMBERS)
    local long = inGroup * (across and g.width or g.height) + (inGroup - 1) * spacing
    local wide = groups * (across and g.height or g.width) + (groups - 1) * gap
    if across then return long, wide end
    return wide, long
end

-- Paints one sample member (raid samples repeat the five).
function M:PaintSample(f, index, auraGroup)
    index = (index - 1) % #self.SAMPLES + 1
    local s, db = self.SAMPLES[index], self.db
    f.role, f.powerToken = self.SAMPLE_ICONS.role[index], s.powerToken
    self:LayoutBars(f)
    local class = UnitColor.Class(s.class)
    local classColor = class and { class.r, class.g, class.b }
    local color = self:HealthColor(nil, classColor)
    f.health:SetMinMaxValues(0, 100); f.health:SetValue(s.health)
    f.health:SetStatusBarColor(color[1], color[2], color[3], db.healthOpacity / 100)
    local power = db.powerColorMode == "custom" and db.powerColor or addon.Domain.Power.Color(s.powerToken)
    f.power:SetMinMaxValues(0, 100); f.power:SetValue(s.power)
    f.power:SetStatusBarColor(power[1], power[2], power[3], db.healthOpacity / 100)
    for _, part in ipairs({ { f.healPrediction, db.showHealPrediction, s.heal }, { f.absorb, db.showAbsorbs, s.absorb },
        { f.overshield, db.showOvershields, s.overshield } }) do
        part[1]:SetMinMaxValues(0, 100); part[1]:SetValue(part[3] or 0); part[1]:SetShown(part[2] and true or false)
    end
    f.overshield:SetAlpha(s.overshield and 1 or 0)
    local name = self:NameColor(nil, classColor)
    Kit.Write(f.texts.name, L[self.SAMPLE_CLASS_NAMES[s.class]])
    f.texts.name:SetTextColor(name[1], name[2], name[3], 1)
    local texts = { percent = s.health .. "%", percentPlain = tostring(s.health), current = tostring(s.health * 120),
        deficit = s.health < 100 and ("-" .. (100 - s.health) * 120) or "" }
    Kit.Write(f.texts.healthText, (db.healthTextShow and not s.state) and texts[db.healthText] or "")
    Kit.Write(f.texts.status, s.state and L[s.state] or "")
    for _, key in ipairs({ "healthText", "status" }) do
        local c = db.textColor
        f.texts[key]:SetTextColor(c[1], c[2], c[3], 1)
    end
    f:SetAlpha(s.state and db.deadOpacity / 100 or (s.faded and db.rangeFade) and db.rangeOpacity / 100 or 1)
    f.isTarget = s.target == true
    self:PaintTarget(f)
    self:PaintIconSample(f, index)
    self:PaintAuraSample(f, index, auraGroup)
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
    self.ghostRegistered = true
    ghost:Hide()
end

-- The stand-in's start corner in UIParent's units, or nil.
function M:GhostCorner()
    local ghost, Number = self.ghost, addon.IsNumber
    local left, bottom, width, height = ghost:GetLeft(), ghost:GetBottom(), ghost:GetWidth(), ghost:GetHeight()
    local scale, parent = ghost:GetEffectiveScale(), UIParent:GetEffectiveScale()
    if not (Number(left) and Number(bottom) and Number(width) and Number(height) and Number(scale, 0.01) and Number(parent, 0.01)) then return end
    local corner, ratio = self.growthCorners[self.db.growth], scale / parent
    local x = corner:find("RIGHT") and left + width or left
    local y = corner:find("TOP") and bottom + height or bottom
    return x * ratio, y * ratio
end

-- Sizes the stand-in for a full party. A size change moves its saved offset
-- by however far the start corner moved, so the group stays put on screen.
function M:LayoutGhost()
    local ghost, PM = self.ghost, addon.PositionManager
    local beforeX, beforeY = nil, nil
    if self.ghostRegistered and not addon.InCombat() then beforeX, beforeY = self:GhostCorner() end
    ghost:SetScale(self.db.scale / 100)
    local width, height = self:LayoutSamples(ghost, ghost.faces, self.MAX_MEMBERS)
    ghost:SetSize(width, height)
    if not beforeX then return end
    PM:ApplyPosition(self.ELEMENT_ID, true)
    local afterX, afterY = self:GhostCorner()
    local x, y = PM:GetOffsets(self.ELEMENT_ID)
    if not (afterX and addon.IsNumber(x) and addon.IsNumber(y)) then return end
    local dx, dy = beforeX - afterX, beforeY - afterY
    if math.abs(dx) > 0.01 or math.abs(dy) > 0.01 then PM:SetOffsets(self.ELEMENT_ID, x + dx, y + dy) end
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
