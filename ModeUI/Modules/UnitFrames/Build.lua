local _, addon = ...
local M = addon.UnitFrames
if not M then return end

-- Frame faces, the secure unit buttons and their Edit Mode stand-ins.
local Number, Kit, Style = M.Number, addon.Kit, addon.Style
local Bar = Kit.Bar

-- Player and Target use the 2px Mode Frame border; the smaller frames the 1px
-- frameThin (docs/DESIGN_LANGUAGE.md, "Borders").
function M.EdgePreset(unit) return (unit == "player" or unit == "target") and "frame" or "frameThin" end

-- One face for both the secure button and its Edit Mode/preview stand-in
-- (docs/DESIGN_LANGUAGE.md, "Unit frames"): the bar block (health, a 1px black
-- line, 3px power) inside its Mode Frame border, which covers its own rounded
-- corners (no masks); the portrait in an edge-lit Steel ring centred on the
-- block's portrait-side edge, over the bars; Combined shields on health.
function M:BuildFace(f)
    local panel = CreateFrame("Frame", nil, f)
    f.panel = panel
    -- The bars' area, one rim inside the block; the border sits around it.
    panel.inner = CreateFrame("Frame", nil, panel)
    panel.back = panel:CreateTexture(nil, "BACKGROUND", nil, -1)
    Style.ApplyAsset(panel.back, "Solid")
    panel.hairline = panel:CreateTexture(nil, "BACKGROUND", nil, 0)
    Style.ApplyAsset(panel.hairline, "Solid")
    f.health, f.power = Bar(panel), Bar(panel)
    f.health.shield = Style.Shield(f.health)
    panel.edge = Style.Edge(panel.inner, M.EdgePreset(f.unit))
    local ring = Style.Ring(f, 64)
    f.portrait = ring.frame
    f.portrait.ring, f.portrait.icon = ring, ring.portrait
    f.textLayer = CreateFrame("Frame", nil, f)
    f.textLayer:SetAllPoints()
    self:BuildTexts(f)
    if f.unit == "target" then self:BuildCombo(f) end
    self:BuildCast(f)
    self:BuildAuras(f)
    self:BuildStatus(f)
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
        defaultPosition = self.defaultPositions[unit], allowedTargets = { "screen" }, label = addon.L[self.titles[unit]],
        canDrag = function() return self:FrameOn(unit) end,
        onPositionChanged = function() self:SyncPosition(unit) end })
    assert(ok, "ModeUI: unit frame position registration failed: " .. tostring(reason))
    -- Edit Mode's Match Width and Match Height: the frame takes the size of
    -- the element picked for each, told on change (Layout.lua, MatchedFrame).
    local PM, id = addon.PositionManager, self.elementIds[unit]
    local function Key(axis) return axis == "width" and "matchWidth" or "matchHeight" end
    PM:SetSizeMatch(id, { axes = { width = true, height = true },
        get = function(axis) return self.db[unit][Key(axis)] == true end,
        set = function(axis, on) return self:SetFrameOption(unit, Key(axis), on == true) end })
    PM:SetAnchorSizeListener(id, function(_, width, height)
        local Number = addon.IsNumber
        self.matchSizes = self.matchSizes or {}
        self.matchSizes[unit] = { width = Number(width, 1, 10000) and width or nil, height = Number(height, 1, 10000) and height or nil }
        if self.db[unit].matchWidth or self.db[unit].matchHeight then self:Refresh() end
    end)
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
