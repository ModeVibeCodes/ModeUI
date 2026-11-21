local _, addon = ...
local M = addon.Minimap
if not M then return end

-- Blizzard's minimap buttons on small Mode tiles in the map's corners: a
-- Mode Button face in Mono raised in the `group` edge (Button Border: a 1 or
-- 2px rim, in Border Color), with Blizzard's own button scaled into it, so
-- clicking works as before. A tile shows while
-- its setting is on and Blizzard shows the button (mail only with new mail,
-- the expansion button only when the game offers it). Two tiles in one
-- corner stack away from it. The group-finder eye gets a tile too, placed in
-- ModeUI's Edit Mode (bottom left of the map by default); Blizzard's Edit
-- Mode position for it doesn't apply while the module is on.
local Kit, L, Skin = addon.Kit, addon.L, addon.Skin
local QUEUE_SIZE = 45 -- QueueStatusButton's own size (Blizzard_QueueStatusFrame)

-- Blizzard's frame for each tile, and the frame whose Show/Hide says
-- whether there is anything to show.
local function Sources()
    local cluster = MinimapCluster or {}
    local indicator = cluster.IndicatorFrame
    return {
        tracking = { frame = cluster.Tracking },
        calendar = { frame = GameTimeFrame },
        mail = { frame = indicator, shown = indicator and indicator.MailFrame },
        expansion = { frame = ExpansionLandingPageMinimapButton },
    }
end

function M:NewTile(parent)
    local tile = CreateFrame("Frame", nil, parent)
    tile.parts = Skin.Box(tile, "group", { level = 3 })
    return tile
end

-- size defaults to TILE_SIZE (UI units, snapped here); height to the size
-- (square map tiles; the addon tray's are a little shorter).
function M:LayoutTile(tile, size, height)
    local px = self.px
    size = Skin.Snap(size or self.TILE_SIZE, px)
    height = height or size
    tile:SetSize(size, height)
    Skin.PaintBox(tile.parts, tile, "FG", self.TILE_FILL, 1, true)
    self:PaintEdge(tile.parts.modeEdge, self.db.buttonBorder)
    return size, height
end

-- Scale that fits a Blizzard frame into a tile.
local function Fit(frame, size)
    local w, h = frame:GetSize()
    if not (addon.IsNumber(w, 1) and addon.IsNumber(h, 1)) then return 1 end
    return size / math.max(w, h)
end

function M:BuildTiles()
    self.tiles, self.sources = {}, Sources()
    for _, name in ipairs(self.BUTTONS) do
        local tile = self:NewTile(self.overlay)
        self.tiles[name] = tile
        local source = self.sources[name]
        if source.frame then
            local size = self.TILE_SIZE
            self:Adopt(source.frame, tile, function(frame) frame:SetPoint("CENTER", tile, "CENTER", 0, 0) end, Fit(source.frame, size))
            self:FollowShown(source.shown or source.frame, function() self:LayoutTiles() end)
        end
    end
    self:BuildQueue()
end

-- The eye: an Edit Mode stand-in, a tile that follows it, and Blizzard's
-- button centered on the tile.
function M:BuildQueue()
    local mover = CreateFrame("Frame", "ModeUIMinimapQueueMover", UIParent)
    mover:SetFrameStrata("HIGH")
    mover:SetSize(self.TILE_SIZE, self.TILE_SIZE)
    mover.fill = mover:CreateTexture(nil, "BACKGROUND", nil, -8)
    mover.fill:SetAllPoints(); mover.fill:SetTexture(Kit.FLAT)
    Kit.Tint(mover.fill, Kit.palette.accent, 0.35)
    mover:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    self.queueMover = mover
    local tile = self:NewTile(self.holder)
    tile:SetPoint("CENTER", mover, "CENTER", 0, 0)
    self.queueTile = tile
    local ok, reason = addon.PositionManager:RegisterElement(self.QUEUE_ID, mover, { moduleId = self.id,
        defaultPosition = self.QUEUE_POSITION, label = L["Group Finder"], anyTarget = true,
        canDrag = function() return self.active == true end })
    assert(ok, "ModeUI: group finder position registration failed: " .. tostring(reason))
    mover:Hide()
    if QueueStatusButton then
        self:Adopt(QueueStatusButton, tile, function(frame) frame:SetPoint("CENTER", tile, "CENTER", 0, 0) end,
            (self.TILE_SIZE + 8) / QUEUE_SIZE)
        self:FollowShown(QueueStatusButton, function() self:LayoutTiles() end)
    end
end

-- Corner offsets: x and y step away from the corner into the map.
local STEP = { TOPLEFT = { 1, -1 }, TOPRIGHT = { -1, -1 }, BOTTOMLEFT = { 1, 1 }, BOTTOMRIGHT = { -1, 1 } }

function M:LayoutTiles()
    if not self.tiles or not self.px then return end
    local inset = self.TILE_INSET
    local used = {}
    for _, name in ipairs(self.BUTTONS) do
        local tile, source, setting = self.tiles[name], self.sources[name], self.db.buttons[name]
        local size = self:LayoutTile(tile)
        local watch = source.shown or source.frame
        local shown = setting.shown and watch ~= nil and watch:IsShown()
        tile:SetShown(shown)
        if shown then
            local corner = setting.corner
            local index = used[corner] or 0
            used[corner] = index + 1
            local step = STEP[corner]
            tile:ClearAllPoints()
            tile:SetPoint(corner, self.map, corner, step[1] * inset, step[2] * (inset + index * (size + self.TILE_GAP)))
        end
        if source.frame then self:Replace(source.frame, nil, Fit(source.frame, size)) end
    end
    local queue = self.queueTile
    if queue then
        self:LayoutTile(queue)
        queue:SetFrameLevel(self.overlay:GetFrameLevel() + 2)
        local eye = QueueStatusButton
        queue:SetShown(self.editing == true or (eye ~= nil and eye:IsShown()))
    end
end
