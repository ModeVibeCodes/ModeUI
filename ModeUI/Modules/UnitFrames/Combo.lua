local _, addon = ...
local M = addon.UnitFrames
if not M then return end

-- The class resource (Domain.ClassResource; on Forever, a Rogue's or Cat Form
-- Druid's combo points) on the Target frame: one round socket per point (Onyx
-- rim, dark socket) on an arc around the portrait, replacing Blizzard's
-- ComboFrame, which Forever pins to the Target frame's portrait. A class
-- without a resource shows nothing. The count may be secret, so each point is
-- its own StatusBar spanning (i - 1, i): SetValue(count) fills it or leaves it
-- empty without the count ever being compared. Settings: db.comboPoints.
local Kit, Resource = addon.Kit, addon.Domain.ClassResource
local ONYX, Tint = M.onyx, Kit.Tint
-- Arc centres in degrees, measured from the portrait's outer side (away from
-- the bars) toward the top.
local CENTER = { outer = 0, topOuter = 45, bottomOuter = -45, top = 90, bottom = -90 }
M.COMBO_SAMPLE = 3 -- points lit on the Edit Mode and preview stand-ins

local function BuildPoint(parent, index)
    local point = CreateFrame("Frame", nil, parent)
    point.rim = Kit.Circle(point, "BACKGROUND", 0)
    point.socket = Kit.Circle(point, "BACKGROUND", 1)
    point.bar = CreateFrame("StatusBar", nil, point)
    point.bar:SetMinMaxValues(index - 1, index)
    point.bar:SetValue(index - 1)
    return point
end

function M:BuildCombo(f)
    local combo = CreateFrame("Frame", nil, f)
    combo:SetAllPoints(f)
    combo.points = {}
    for i = 1, Resource.MAX do combo.points[i] = BuildPoint(combo, i) end
    combo:Hide()
    f.combo = combo
end

-- Places `count` points. Sizes are whole, even pixel counts and centres are
-- snapped, so every socket sits on the pixel grid like the frame around it.
function M:LayoutCombo(f, count)
    local combo, g = f.combo, f.geometry
    if not combo or not g then return end
    local cdb, fdb, px = self.db.comboPoints, self:FrameDB(f.unit), g.px
    local function Snap(v) return math.floor(v / px + 0.5) * px end
    local size = math.max(2 * px, math.floor(cdb.size / (2 * px) + 0.5) * 2 * px)
    local spacing, distance = Snap(cdb.spacing), Snap(cdb.distance)
    combo:SetFrameLevel(math.max(f.portrait:GetFrameLevel(), f.health:GetFrameLevel()) + 1)
    local fill = addon.Media:GetTexture("UnitFrameCircle")
    local arc = fdb.showPortrait and g.portrait > 0
    -- On an arc: around the portrait's centre, the outer side mirrored by
    -- portrait side; the first point is the lower (or outer) end.
    local radius = g.portrait / 2 + distance + size / 2
    local outer = fdb.portraitSide == "right" and 1 or -1
    local center, step = math.rad(CENTER[cdb.arc]), (size + spacing) / radius
    local low = fdb.showPower and f.power or f.health
    for i, point in ipairs(combo.points) do
        point:SetShown(i <= count)
        if i <= count then
            point:SetSize(size, size)
            point.rim:ClearAllPoints(); point.rim:SetAllPoints(point); Tint(point.rim, M.RIM_COLOR, 1)
            Kit.Inset(point.socket, point, px); Tint(point.socket, cdb.emptyColor, 1)
            local bar = point.bar
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT", point, "TOPLEFT", 2 * px, -2 * px)
            bar:SetPoint("BOTTOMRIGHT", point, "BOTTOMRIGHT", -2 * px, 2 * px)
            bar:SetStatusBarTexture(fill)
            local c = cdb.activeColor
            bar:SetStatusBarColor(c[1], c[2], c[3], 1)
            point:ClearAllPoints()
            if arc then
                local angle = center + (i - (count + 1) / 2) * step
                point:SetPoint("CENTER", f.portrait, "CENTER", Snap(math.cos(angle) * radius * outer), Snap(math.sin(angle) * radius))
            else
                -- No portrait: a row under the bars, from their start.
                point:SetPoint("TOPLEFT", low, "BOTTOMLEFT", (i - 1) * (size + spacing), -(g.pad + distance))
            end
        end
    end
end

-- Shown while the Target frame is on, the setting is on and the player builds
-- their class resource (a Rogue, or a Druid in Cat Form).
function M:UpdateCombo()
    local f = self.frames and self.frames.target
    if not f or not f.combo then return end
    local on = self:FrameOn("target") and self.db.comboPoints.enabled and Resource.Active()
    local count = on and Resource.Max() or 0
    if count ~= f.combo.count then f.combo.count = count; self:LayoutCombo(f, count) end
    f.combo:SetShown(count > 0)
    if count == 0 then return end
    local ok, points = Resource.Read()
    for i = 1, count do
        local bar = f.combo.points[i].bar
        if ok then pcall(bar.SetValue, bar, points) else bar:SetValue(i - 1) end
    end
end

-- Re-laid out from the settings: forget the count so the next update places them.
function M:ResetComboLayout(f)
    if f.combo then f.combo.count = nil; self:LayoutCombo(f, 0) end
end

-- Stand-ins show the full arc with a few points lit, for a class with a resource.
function M:PaintComboSample(g)
    if not g.combo then return end
    local count = self.db.comboPoints.enabled and Resource.Max() or 0
    g.combo.count = count
    self:LayoutCombo(g, count)
    g.combo:SetShown(count > 0)
    for i = 1, count do g.combo.points[i].bar:SetValue(self.COMBO_SAMPLE) end
end
