local _, addon = ...
local PM, P = addon.PositionManager, addon.Positioning

-- Alignment guides and nudging in Edit Mode. While an element is dragged, a
-- cyan line shows when its center comes near a guide: where its X or Y
-- offset is 0, the screen's center, or the center of another movable
-- element. Dropping it there snaps onto the line. Nudging moves the selected
-- element one physical pixel at a time.
local Combat, Number = addon.InCombat, addon.IsNumber
local SNAP = 8 -- UI units from a guide that count as near it

-- The nearest guide on each axis: { delta, line } in UIParent units, where
-- delta moves the element onto the line at screen coordinate `line`.
function PM:FindGuides(element, x, y)
    local cx, cy = P:Geometry(element.frame)
    if not cx then return {} end
    local best = {}
    local function Try(axis, delta, line)
        if Number(delta) and math.abs(delta) <= SNAP and (not best[axis] or math.abs(delta) < math.abs(best[axis].delta)) then
            best[axis] = { delta = delta, line = line, zero = false }
        end
    end
    -- An offset of 0 wins ties, so a drop there lands on exactly 0.
    if Number(x) then Try("x", -x, cx - x) end
    if Number(y) then Try("y", -y, cy - y) end
    if best.x then best.x.zero = true end
    if best.y then best.y.zero = true end
    local sx, sy = UIParent:GetCenter()
    Try("x", sx - cx, sx); Try("y", sy - cy, sy)
    for _, other in pairs(self.elements) do
        local frame = other.frame
        if other ~= element and other.editMode and other.module.enabled and frame and frame:IsShown() then
            local ex, ey = P:Geometry(frame)
            if ex then Try("x", ex - cx, ex); Try("y", ey - cy, ey) end
        end
    end
    return best
end

local function Line(parent)
    local line = parent:CreateTexture(nil, "OVERLAY")
    local color = addon.Theme.primary
    line:SetColorTexture(color[1], color[2], color[3], 0.85)
    line:Hide()
    return line
end

function PM:ShowGuides(element)
    if Combat() or not addon.editMode then return self:HideGuides() end
    if not self.guides then
        local frame = CreateFrame("Frame", nil, UIParent)
        frame:SetAllPoints(UIParent); frame:SetFrameStrata("DIALOG"); frame:EnableMouse(false)
        self.guides = { frame = frame, x = Line(frame), y = Line(frame) }
    end
    local x, y = P:ReadFrame(element.subject)
    local found, px = self:FindGuides(element, x, y), addon.Kit.PixelSize(UIParent)
    local g = self.guides
    g.frame:Show()
    g.x:SetShown(found.x ~= nil); g.y:SetShown(found.y ~= nil)
    if found.x then
        g.x:ClearAllPoints()
        g.x:SetPoint("TOPLEFT", UIParent, "TOPLEFT", found.x.line, 0)
        g.x:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", found.x.line, 0)
        g.x:SetWidth(px)
    end
    if found.y then
        g.y:ClearAllPoints()
        g.y:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, found.y.line)
        g.y:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, found.y.line)
        g.y:SetHeight(px)
    end
end

function PM:HideGuides()
    if self.guides then self.guides.frame:Hide() end
end

-- The offsets after snapping onto the nearest guides.
function PM:GuideSnap(element, x, y)
    local found = self:FindGuides(element, x, y)
    if found.x then x = found.x.zero and 0 or x + found.x.delta end
    if found.y then y = found.y.zero and 0 or y + found.y.delta end
    return x, y
end

-- Moves an element by whole physical pixels (dx and dy are pixel counts).
function PM:Nudge(id, dx, dy)
    local element = self:Element(id)
    if not element or not self:CanDrag(element) then return false, "nudge-not-allowed" end
    local x, y = self:GetOffsets(id)
    if not Number(x) or not Number(y) then return false, "invalid-offsets" end
    local px = addon.Kit.PixelSize(UIParent)
    local function Step(value, delta) return math.floor(value / px + 0.5) * px + delta * px end
    return self:SetOffsets(id, Step(x, dx), Step(y, dy))
end
