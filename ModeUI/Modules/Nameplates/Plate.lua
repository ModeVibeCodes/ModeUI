local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- Building a plate and laying out its two boxes. Plates are plain frames
-- (never secure), so they can be built and changed in combat. Each box is the
-- bar inside the `frameThin` edge (docs/DESIGN_LANGUAGE.md: 1px Gunmetal,
-- edge-lit, a 1px shadow ring); the rim art sits outside the bar and covers
-- its own corners, so nothing is masked and nothing opaque sits under the
-- bar: the health bar's background can be see-through (Background Opacity).
-- Elements are placed in Layout.lua and the target indicator in Target.lua.
local Kit, Style = addon.Kit, addon.Style
local Tint, Text, Bar = Kit.Tint, Kit.Text, Kit.Bar
local RIM = Style.EDGE_PRESETS.frameThin.rim

-- A box: the bar area one rim inside it, the edge round that area. The edge
-- is drawn in pieces: a plate's bars are shorter than the ring art, whose
-- sliced corners shrank and looked square (owner, November 18, 2026;
-- docs/DESIGN_LANGUAGE.md, "Pieces").
local function Box(parent)
    local box = CreateFrame("Frame", nil, parent)
    box.inner = CreateFrame("Frame", nil, box)
    box.bar = Bar(box)
    box.edge = Style.Edge(box.inner, "frameThin", { pieces = true })
    return box
end
local function LiftedText(layer)
    local text = Text(layer)
    text.lift = Text(layer, "ARTWORK")
    return text
end

-- A plate's frames, on any parent: a game nameplate, or the settings preview
-- (`sample`). In the world, an aura container carries the forbidden aspect
-- UntrustedLayoutScriptExecution, and the game refuses to anchor anything to
-- it, or to a mark anchored to it, that doesn't carry the aspect itself (it is
-- never inherited through SetPoint: ForbiddenAspectTemplates.xml). So the
-- parts that follow an aura row are made inside frames from Blizzard's
-- DisableUntrustedLayoutScriptsTemplate: the name's holder (the name stops at
-- the border row) and the arrows' frames.
function M:BuildPlate(parent, sample)
    local plate = CreateFrame("Frame", nil, parent)
    plate.healthBox = Box(plate)
    plate.health = plate.healthBox.bar
    plate.castBox = Box(plate)
    plate.cast = plate.castBox.bar
    plate.castIcon = plate.castBox:CreateTexture(nil, "ARTWORK")
    -- The Comet spark on the cast bar (Style.Comet).
    plate.comet = Style.Comet(plate.cast)
    -- Target indicator: the edge's outer line (Target.lua), a soft glow
    -- around it (hollow, so it never shows through), arrows.
    plate.targetGlow = plate:CreateTexture(nil, "BACKGROUND", nil, -8)
    plate.textLayer = CreateFrame("Frame", nil, plate)
    plate.textLayer:SetAllPoints()
    local follower = (not sample and self:UsesAuraContainers() and M.HasFollowerTemplate()) and M.FOLLOWER_TEMPLATE or nil
    plate.followers = follower ~= nil
    plate.nameHolder = CreateFrame("Frame", nil, plate.textLayer, follower)
    plate.nameHolder:SetAllPoints()
    plate.name = LiftedText(plate.nameHolder)
    plate.healthText, plate.castText = LiftedText(plate.textLayer), LiftedText(plate.textLayer)
    plate.raidIcon = plate.textLayer:CreateTexture(nil, "OVERLAY")
    plate.arrowFrames, plate.arrows = {}, {}
    for _, side in ipairs({ "left", "right" }) do
        local frame = CreateFrame("Frame", nil, plate.textLayer, follower)
        plate.arrowFrames[side] = frame
        plate.arrows[side] = frame:CreateTexture(nil, "OVERLAY")
        plate.arrows[side]:SetAllPoints()
    end
    plate.auraLayer = CreateFrame("Frame", nil, plate)
    plate.auraLayer:SetAllPoints()
    plate.auraIcons, plate.auraShown, plate.auraCount = { crowdControl = {}, debuffs = {}, buffs = {} }, {}, 0
    for _, region in ipairs({ plate.targetGlow, plate.arrows.left, plate.arrows.right }) do region:Hide() end
    self:BuildIndicator(plate)
    self:BuildFocus(plate)
    self:BuildCombo(plate)
    self:BuildSoftTarget(plate)
    self:BuildCastTexts(plate, LiftedText)
    plate.castBox:Hide()
    plate:Hide()
    return plate
end

function M:EnsurePlate(nameplate)
    local plate = self.plates[nameplate]
    if plate then return plate end
    plate = self:BuildPlate(nameplate)
    plate.nameplate = nameplate
    plate:SetPoint("CENTER", nameplate, "CENTER", 0, 0)
    -- Blizzard acquires its unit frame for each new unit; fade it on arrival.
    if hooksecurefunc and type(nameplate.AcquireUnitFrame) == "function" then
        hooksecurefunc(nameplate, "AcquireUnitFrame", function(frame) self:OnBlizzardAcquired(frame) end)
    end
    self.plates[nameplate] = plate
    return plate
end

-- Same Size at Any Distance (db.fixedScale, every kind; owner, November 24,
-- 2026): the game scales each nameplate by distance and grows your target's,
-- so a plate's 1px rims, shadows and halos fell between screen pixels and its
-- text went soft. With it on, the plate ignores its nameplate's scale and
-- takes the scale of the nameplate's parent (what a nameplate at full size
-- has), so it keeps one size and whole pixels. Preview plates are left alone.
function M:ApplyPlateScale(plate)
    local nameplate = plate.nameplate
    if not nameplate or type(plate.SetIgnoreParentScale) ~= "function" then return end
    local Plain = addon.Domain.Query.Plain
    local fixed = self.db.fixedScale == true
    local scale = 1
    if fixed then
        local parent = Plain(nameplate.GetParent, nameplate)
        local base = parent and Plain(parent.GetEffectiveScale, parent)
        if addon.IsNumber(base, 0.01, 100) then scale = base else fixed = false end
    end
    plate:SetIgnoreParentScale(fixed)
    plate:SetScale(scale)
end

function M:SetFixedScale(fixed)
    if not self:CanConfigure() or type(fixed) ~= "boolean" then return false end
    self.db.fixedScale = fixed
    self:Refresh()
    if self.page then self.page:Refresh() end
    return true
end

-- Lays out one box and returns its full height (the bar and its rim). The
-- bar is `barHeight` tall inside a `width` wide box. `background` is the
-- track's opacity (0-1); `texture` the fill (the kind's Foreground when nil).
function M.LayoutBox(box, width, barHeight, px, background, db, texture)
    local inset = RIM * px
    local height = barHeight + 2 * inset
    box:SetSize(width, height)
    box.inner:ClearAllPoints()
    box.inner:SetPoint("TOPLEFT", box, "TOPLEFT", inset, -inset)
    box.inner:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -inset, inset)
    local bar = box.bar
    bar:ClearAllPoints()
    bar:SetAllPoints(box.inner)
    bar:SetFrameLevel(box:GetFrameLevel() + 1)
    Kit.BarForeground(bar, texture or (db and db.foregroundTexture) or "media:Mode-FG", barHeight, px)
    local backgroundTexture = db and db.backgroundTexture or "media:Mode-BG"
    Kit.BarBackground(bar, backgroundTexture, width - 2 * inset, barHeight, px)
    Tint(bar.bg, Kit.BarBackgroundColor(backgroundTexture), background or 1)
    -- Border Style and Border Metal (every style reaches the same: the box keeps its size).
    if db then box.edge:SetStyle(db.edgeStyle, db.edgeMetal) end
    box.edge.holder:SetFrameLevel(bar:GetFrameLevel() + 2)
    box.edge:Layout()
    return height
end
