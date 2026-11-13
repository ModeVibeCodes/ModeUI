local _, addon = ...
local M = addon.UnitFrames
if not M then return end

-- Frame faces, the secure unit buttons and their Edit Mode stand-ins.
local Number, Kit = M.Number, addon.Kit
local CIRCLE_MASK = M.CIRCLE_MASK
local Bar, Text, Circle = Kit.Bar, Kit.Text, Kit.Circle

-- One face for both the secure button and its Edit Mode/preview stand-in.
-- Bar block: slate rim fill, black gap inset by the rim, then the bars. The
-- portrait sits above the block, so its full ring is drawn over the bar's end.
-- The bars' background can be see-through (Background Opacity), so the rim and
-- gap are drawn in four clipped bands around the bars (Kit.Bands) rather than
-- behind them, and the hairline between health and power is its own texture.
function M:BuildFace(f)
    local panel = CreateFrame("Frame", nil, f)
    f.panel = panel
    panel.bands, panel.fills, panel.inners = Kit.Bands(panel), {}, {}
    for i, band in ipairs(panel.bands) do
        panel.fills[i] = band.layer:CreateTexture(nil, "BACKGROUND", nil, 0)
        panel.inners[i] = band.layer:CreateTexture(nil, "BORDER")
    end
    panel.fill, panel.border = panel.fills[1], panel.inners[1]
    panel.hairline = panel:CreateTexture(nil, "BACKGROUND", nil, 0)
    f.health, f.power = Bar(panel), Bar(panel)
    local p = CreateFrame("Frame", nil, f)
    f.portrait = p
    p.ring = Circle(p, "BACKGROUND", 0)
    p.innerEdge = Circle(p, "BACKGROUND", 1)
    p.back = Circle(p, "BACKGROUND", 2)
    p.icon = p:CreateTexture(nil, "ARTWORK")
    if p.CreateMaskTexture then
        p.mask = p:CreateMaskTexture()
        p.mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        p.icon:AddMaskTexture(p.mask)
    end
    f.textLayer = CreateFrame("Frame", nil, f)
    f.textLayer:SetAllPoints()
    f.nameText, f.levelText, f.healthText, f.powerText = Text(f.textLayer), Text(f.textLayer), Text(f.textLayer), Text(f.textLayer)
    for _, text in ipairs({ f.nameText, f.levelText, f.healthText, f.powerText }) do text.lift = Text(f.textLayer, "ARTWORK") end
end

function M:CreateDisplay()
    if self.displayCreated then return end
    self.displayCreated = true
    for _, unit in ipairs(self.units) do
        local label = self.frameNames[unit]
        local b = CreateFrame("Button", "ModeUI" .. label .. "UnitFrame", UIParent, "SecureUnitButtonTemplate")
        b.unit = unit
        b:SetAttribute("unit", unit); b:SetAttribute("*type1", "target"); b:SetAttribute("*type2", "togglemenu")
        b:RegisterForClicks("AnyUp"); b:SetFrameStrata("MEDIUM"); b:Hide()
        b:SetScript("OnEnter", function(button)
            if GameTooltip_SetDefaultAnchor then GameTooltip_SetDefaultAnchor(GameTooltip, button) end
            if GameTooltip and GameTooltip.SetUnit then GameTooltip:SetUnit(unit); GameTooltip:Show() end
        end)
        b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        self:BuildFace(b)
        b:SetPoint("CENTER", UIParent, "CENTER", self.defaultPositions[unit].x, self.defaultPositions[unit].y)
        self.frames[unit] = b
        self:CreateGhost(unit)
    end
end

-- Position Manager refuses protected frames, so Edit Mode moves a plain stand-in
-- and the secure button copies its anchor outside combat.
function M:CreateGhost(unit)
    local label = self.frameNames[unit]
    local g = CreateFrame("Frame", "ModeUI" .. label .. "UnitFramePreview", UIParent)
    g.unit, g.ghost = unit, true
    g:SetFrameStrata("HIGH")
    self:BuildFace(g)
    self:ApplyLayout(g, unit)
    -- Registration measures the frame via GetCenter, which is nil until it has an anchor;
    -- the Position Manager then moves it to the saved position.
    local default = self.defaultPositions[unit]
    g:SetPoint("CENTER", UIParent, "CENTER", default.x, default.y)
    self.ghosts[unit] = g
    self:RegisterPosition(unit)
end

function M:RegisterPosition(unit)
    local g = self.ghosts[unit]
    local shown = g:IsShown()
    g:Show()
    local ok, reason = addon.PositionManager:RegisterElement(self.elementIds[unit], g, { moduleId = self.id,
        defaultPosition = self.defaultPositions[unit], allowedTargets = { "screen" },
        canDrag = function() return self:FrameOn(unit) end,
        onPositionChanged = function() self:SyncPosition(unit) end })
    assert(ok, "ModeUI: unit frame position registration failed: " .. tostring(reason))
    g:SetShown(shown)
end

-- The parent a frame is attached to (Attach to Target/Focus Frame), while
-- that parent is shown; otherwise the frame keeps its own screen position.
function M:AttachedTo(unit)
    local parent = self.attachParents[unit]
    if parent and self.db[unit].attach and self:FrameOn(parent) then return parent end
end

-- An attached frame leaves the Position Manager (so Edit Mode can't move it,
-- and nothing re-places it); detaching registers it again at its saved
-- position, which the Position Manager kept. Outside combat only.
function M:SyncPlacement(unit)
    local id, PM = self.elementIds[unit], addon.PositionManager
    local registered = PM:Element(id) ~= nil
    if self:AttachedTo(unit) then
        if registered then PM:UnregisterElement(id) end
    elseif not registered then
        self:RegisterPosition(unit)
    end
end

-- Joins `frame` to `parent` at the chosen corner. Offsets are whole physical
-- pixels in the frame's own scale, so both frames stay on the pixel grid.
local function Attach(self, frame, parent, fdb)
    local spec = self.attachPoints[fdb.attachPoint]
    local px = self:PixelSize(frame)
    frame:ClearAllPoints()
    frame:SetPoint(spec.point, parent, spec.relative, fdb.attachOffsetX * px, fdb.attachOffsetY * px)
end

function M:SyncPosition(unit)
    local b, g = self.frames[unit], self.ghosts[unit]
    if not b or not g then return end
    if InCombatLockdown() then self.pending = true; return end
    local parent = self:AttachedTo(unit)
    if parent then
        -- Button to button and stand-in to stand-in: a secure frame is never
        -- anchored to a plain one.
        local fdb = self:FrameDB(unit)
        Attach(self, b, self.frames[parent], fdb); Attach(self, g, self.ghosts[parent], fdb)
        return
    end
    local count = g:GetNumPoints()
    if not Number(count, 1, 10) then return end
    local px = self:PixelSize(b)
    local function Snap(v) return Number(v, -100000, 100000) and math.floor(v / px + 0.5) * px or v end
    b:ClearAllPoints()
    for i = 1, count do
        local point, relative, relativePoint, x, y = g:GetPoint(i)
        b:SetPoint(point, relative or UIParent, relativePoint, Snap(x), Snap(y))
    end
end

function M:RenderGhosts()
    if not self.ghosts then return end
    for _, unit in ipairs(self.units) do
        local g = self.ghosts[unit]
        if g then
            local show = (self.editing or self.previewing) and self:FrameOn(unit)
            if show then self:ApplyLayout(g, unit); self:PaintSample(g, unit) end
            g:SetShown(show and true or false)
        end
    end
end
