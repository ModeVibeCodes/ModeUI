local _, addon = ...
local M = addon.Minimap
if not M then return end

-- The map: an Edit Mode stand-in (the mover), the holder that follows it,
-- and inside it the map frame that carries Blizzard's Minimap, the mask and
-- the Mode `frame` edge round it (Map Border: a 1 or 2px rim; Border Color
-- tints it). The mask is square: the edge's rim covers the map's corners.
-- The game draws the minimap square, so Minimap stays as wide as it is tall
-- and hangs half the difference above and below the map frame;
-- the mask crops those bands and the click area is trimmed to match.
-- Blizzard puts its round mask back in MinimapCluster:UpdateMinimapConfig
-- (at load and whenever Rotate Minimap changes), so a post-hook sets ModeUI's
-- again; the hybrid minimap (some indoor maps) has a round mask of its own,
-- swapped when it loads.
local Kit, Skin, L, Style = addon.Kit, addon.Skin, addon.L, addon.Style
local RINGS = { "SetArchBlobRingScalar", "SetArchBlobRingAlpha", "SetQuestBlobRingScalar", "SetQuestBlobRingAlpha",
    "SetTaskBlobRingScalar", "SetTaskBlobRingAlpha" }

-- A Border Color choice as { r, g, b }; Class Color is the player's.
function M.BorderColorFor(key)
    if key == "class" then
        local c = addon.Domain.UnitColor.PlayerClass("player")
        if c then return { c.r, c.g, c.b } end
        return M.BORDER_COLORS.rim
    end
    return M.BORDER_COLORS[key]
end
function M:BorderColor() return M.BorderColorFor(self.db.borderColor) end
-- The rim's tint: nil for `rim` (the edge's own lit metal); any other Border
-- Color paints it one flat color.
function M:RimTint()
    if self.db.borderColor == "rim" then return nil end
    return self:BorderColor()
end
-- The metal the edges are drawn in: Border Metal, else Border Style's own
-- (the `rim` swatch shows its mid tone).
function M:EdgeMetal()
    local db, metals = self.db, Style.Tone.metal
    local style = Style.EDGE_STYLES[Style.EdgeStyle(db.edgeStyle) or "blizz"]
    return metals[db.edgeMetal] or metals[style.metal]
end
-- Paints a Mode edge in Border Style and Border Metal with the Map Border or
-- Button Border rim and Border Color (the map, its bar and every tile).
function M:PaintEdge(edge, choice)
    edge:SetStyle(self.db.edgeStyle, self.db.edgeMetal)
    edge:SetRim(self.BORDER_PIXELS[choice] or 2)
    edge:SetTint(self:RimTint())
    edge:Layout()
end

function M:BuildShape()
    local mover = CreateFrame("Frame", "ModeUIMinimapMover", UIParent)
    mover:SetFrameStrata("HIGH")
    mover:SetSize(self.db.size, self.db.size - self.db.difference)
    mover.fill = mover:CreateTexture(nil, "BACKGROUND", nil, -8)
    mover.fill:SetAllPoints(); mover.fill:SetTexture(Kit.FLAT)
    Kit.Tint(mover.fill, Kit.palette.accent, 0.18)
    mover:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", self.DEFAULT_POSITION.x, self.DEFAULT_POSITION.y)
    self.mover = mover
    local holder = CreateFrame("Frame", "ModeUIMinimap", UIParent)
    holder:SetFrameStrata("LOW")
    holder:SetAllPoints(mover)
    local map = CreateFrame("Frame", "ModeUIMinimapMap", holder)
    map:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    self.holder, self.map = holder, map
    self.edge = Style.Edge(map, "frame")
    -- Text and tiles draw above the map and its border.
    self.overlay = CreateFrame("Frame", nil, map)
    self.overlay:SetAllPoints(map)
    local ok, reason = addon.PositionManager:RegisterElement(self.ELEMENT_ID, mover, { moduleId = self.id,
        defaultPosition = self.DEFAULT_POSITION, label = L["Minimap"],
        canDrag = function() return self.active == true end })
    assert(ok, "ModeUI: minimap position registration failed: " .. tostring(reason))
    mover:Hide()
end

-- Blizzard's pieces: the Minimap onto the map frame; the round art, zoom
-- buttons and the cluster (zone text, day and night ring, coordinates)
-- hidden. Buttons that get tiles are adopted in Tiles.lua first, so hiding
-- the cluster leaves them alone.
function M:AdoptBlizzard()
    if self.adopted then return end
    self.adopted = true
    self:Adopt(Minimap, self.map, function(frame) frame:SetPoint("TOPLEFT", self.map, "TOPLEFT", 0, self.crop or 0) end)
    if Minimap.ZoomIn then self:Stash(Minimap.ZoomIn) end
    if Minimap.ZoomOut then self:Stash(Minimap.ZoomOut) end
    if Minimap.ZoomHitArea then self:Stash(Minimap.ZoomHitArea) end
    if MinimapBackdrop then self:Stash(MinimapBackdrop) end
    if MinimapCluster then
        Skin.Suppress(MinimapCluster)
        if MinimapCluster.UpdateMinimapConfig then
            hooksecurefunc(MinimapCluster, "UpdateMinimapConfig", function() if self.active then self:ApplyMask() end end)
        end
    end
    -- Pings: Blizzard pings only inside a circle, so the corners ping here.
    Minimap:HookScript("OnMouseUp", function(frame) self:PingCorner(frame) end)
    Minimap:HookScript("OnMouseWheel", function() self:StartZoomReset() end)
end

function M:PingCorner(frame)
    if not self.active or type(GetCursorPosition) ~= "function" then return end
    local x, y = GetCursorPosition()
    local scale = frame:GetEffectiveScale()
    local cx, cy = frame:GetCenter()
    local width = frame:GetWidth()
    if not (addon.IsNumber(x) and addon.IsNumber(y) and addon.IsNumber(scale, 0.01) and addon.IsNumber(cx)
        and addon.IsNumber(cy) and addon.IsNumber(width)) then return end
    x, y = x / scale - cx, y / scale - cy
    if math.sqrt(x * x + y * y) < width / 2 then return end -- Blizzard's own ping
    if frame.PingLocation then frame:PingLocation(x, y) end
end

-- The mask for the current size, difference and corners; the hybrid map's too.
function M:ApplyMask()
    local db = self.db
    local path = self.MaskPath(db.size, db.difference, "square")
    Style.SetShapeMask(Minimap, path)
    for _, method in ipairs(RINGS) do
        if Minimap[method] then pcall(Minimap[method], Minimap, 0) end
    end
    self:SkinHybrid(path)
end

function M:SkinHybrid(path)
    local hybrid = HybridMinimap
    if not (hybrid and hybrid.MapCanvas and hybrid.CircleMask) then return end
    local canvas, mask = hybrid.MapCanvas, hybrid.CircleMask
    if canvas.SetUseMaskTexture then canvas:SetUseMaskTexture(false) end
    mask:SetTexture(path or self.MaskPath(self.db.size, self.db.difference, "square"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:ClearAllPoints(); mask:SetAllPoints(Minimap)
    if canvas.SetUseMaskTexture then canvas:SetUseMaskTexture(true) end
end

-- Sizes in whole physical pixels. Returns the map's width and height.
function M:LayoutShape()
    local db, px = self.db, Kit.PixelSize(self.holder)
    local size = Skin.Snap(db.size, px)
    local crop = db.difference > 0 and Skin.Snap(db.difference / 2, px) or 0
    local height = size - 2 * crop
    self.crop, self.px, self.mapWidth, self.mapHeight = crop, px, size, height
    self.map:SetSize(size, height)
    local resized = self.appliedSize ~= size
    self.appliedSize = size
    Minimap:SetSize(size, size)
    self:Replace(Minimap)
    if Minimap.SetHitRectInsets then Minimap:SetHitRectInsets(0, 0, crop, crop) end
    self:ApplyMask()
    -- The map redraws at a new size only when the zoom changes.
    if resized and Minimap.GetZoom and Minimap.SetZoom then
        local zoom = Minimap:GetZoom()
        if addon.IsNumber(zoom) then
            Minimap:SetZoom(zoom > 0 and zoom - 1 or zoom + 1)
            Minimap:SetZoom(zoom)
        end
    end
    if Minimap.EnableMouseWheel then Minimap:EnableMouseWheel(db.wheelZoom) end
    self:LayoutBorder()
    return size, height
end

-- The Mode edge round the map, above the Minimap and anything Blizzard
-- draws on it (its soft drop stays under the map).
function M:LayoutBorder()
    local map = self.map
    local level = Minimap:GetFrameLevel() + 6
    local base = map:GetFrameLevel()
    if addon.IsNumber(base) and addon.IsNumber(level) then self.edge:SetLevel(level - base) end
    self:PaintEdge(self.edge, self.db.border)
    self.overlay:SetFrameLevel(level + 2)
end

-- Zoom Out After: back to the widest zoom some seconds after the last wheel turn.
function M:StartZoomReset()
    if self.zoomTimer then self.zoomTimer:Cancel(); self.zoomTimer = nil end
    local delay = self.db.zoomReset
    if not self.active or delay == 0 or not (C_Timer and C_Timer.NewTimer) then return end
    self.zoomTimer = C_Timer.NewTimer(delay, function()
        self.zoomTimer = nil
        if self.active and Minimap.GetZoom and Minimap:GetZoom() ~= 0 then Minimap:SetZoom(0) end
    end)
end
