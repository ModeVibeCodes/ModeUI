local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- The stand-in: a plain frame the size of a full party that Edit Mode moves
-- (the secure header copies its place outside combat, Header.lua). In Edit
-- Mode, Preview and Test on Screen it shows a sample party, so the frames can
-- be placed and styled without a group. Samples are drawn by the same code as
-- the members in the world (BuildFace, ApplyLayout; Samples.lua). When its size changes
-- (width, height, scale, growth) the corner the group grows from stays where
-- it was on the screen.
local L = addon.L

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
    return self:SampleSize(count, g, spacing, gap)
end

-- The size `count` members take in groups of five, in their own units.
function M:SampleSize(count, g, spacing, gap)
    local across = self.growthPoints[self.db.growth][2] ~= 0
    local inGroup, groups = math.min(count, self.MAX_MEMBERS), math.ceil(count / self.MAX_MEMBERS)
    local long = inGroup * (across and g.width or g.height) + (inGroup - 1) * spacing
    local wide = groups * (across and g.height or g.width) + (groups - 1) * gap
    if across then return long, wide end
    return wide, long
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
