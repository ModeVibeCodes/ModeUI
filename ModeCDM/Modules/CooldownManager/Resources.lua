local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M then return end

-- Building and laying out the Resource Bars. Each bar has a stand-in (its
-- Edit Mode element, named ModeUIResourcePower and so on) and, on it, the
-- bar the player sees. A bar is one box, or one box per point for Combo
-- Points; a box is a status bar (the fill in Bar Texture and Bar Color over
-- Bar Background) in the `frameThin` edge outside it (docs/DESIGN_LANGUAGE.md,
-- "Bars"); the bar's frame leaves room for the edges, so its width matches
-- the cooldown rows' and Spacing counts between the shadows. Grouped combo
-- points share one edge (frame.outer) with a line between points. A bar is
-- never shorter than its border's floor (Style.EdgeMinHeight). No masks.
-- Values may be secret, so they only ever go to the status bars and text
-- setters (ResourceUpdate.lua). The settings preview draws a bar with these
-- same functions; ResourceGroup.lua lays out Group Resources.
local Kit, L, Style = addon.Kit, addon.L, addon.Style
local PM = addon.PositionManager

-- One box: a status bar (Kit.Bar: fill, background and the lift) in the
-- Mode edge.
local function NewBox(parent)
    local box = CreateFrame("Frame", nil, parent)
    box.bar = Kit.Bar(box)
    -- Pieces: a sliced ring on a host this thin draws as specks (Style.Edge).
    box.edge = Style.Edge(box, M.EDGE, { pieces = true })
    return box
end
-- How far a bar's edges reach past its boxes, in px units.
function M.ResourceReach(style, px) return style.border == "none" and 0 or M.EDGE_REACH * px end
-- The shortest bar its border fits, in px units (one pixel without a border).
function M.ResourceFloor(style, px)
    if style.border == "none" then return px end
    return Style.EdgeMinHeight(M.EDGE, style.edgeStyle) * px
end
-- A bar's height on whole pixels, raised to its border's floor unless it sits
-- inside a Grouped block (`free`), where only the block has a floor.
function M.ResourceBarHeight(style, px, free)
    local h = math.max(px, math.floor(style.height / px + 0.5) * px)
    if free then return h end
    return math.max(h, M.ResourceFloor(style, px))
end

-- A bar's frame: its boxes (made as they're needed), the shared edge of
-- grouped points with the lines between them, and a text above them.
function M:NewResourceFrame(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame.boxes, frame.dividers = {}, {}
    frame.outer = CreateFrame("Frame", nil, frame)
    frame.outer.edge = Style.Edge(frame.outer, M.EDGE, { pieces = true })
    frame.textLayer = CreateFrame("Frame", nil, frame)
    frame.textLayer:SetAllPoints(frame)
    frame.text = Kit.Text(frame.textLayer)
    frame.text.lift = Kit.Text(frame.textLayer, "ARTWORK")
    return frame
end

-- How many boxes a bar has now: Combo Points one per point the player can
-- hold (5 in the preview for a class without them), the others one.
function M:ResourceBoxCount(id, sample)
    if not self.resourceSpecs[id].segmented then return 1 end
    local max = addon.Domain.ClassResource.Max()
    if max < 1 and sample then return addon.Domain.ClassResource.DEFAULT_MAX end
    return math.max(1, max)
end

-- The bar's width: the width of what it hangs from with Match Width on
-- (Edit Mode), else its own Width; snapped to whole pixels. The anchor's
-- width is read fresh outside combat (the Position Manager doesn't give it
-- in combat; the last one known is kept) and its size listener lays the bar
-- out again when that changes.
function M:ResourceWidth(id, px)
    local style = self.db.resources[id]
    local width = style.width
    if style.matchWidth and self.anchorWidths then
        if not addon.InCombat() then
            local live = PM:GetAnchorWidth(self.ResourceElementId(id))
            self.anchorWidths[id] = addon.IsNumber(live, 1, 10000) and live or nil
        end
        width = self.anchorWidths[id] or width
    end
    return math.max(px, math.floor(width / px + 0.5) * px)
end

-- Lays one box out: `w` by `h` at `x`, `y` from the frame's top left, in its
-- own edge when `edged`.
local function LayoutBox(box, frame, style, x, y, w, h, px, edged, fillEdge)
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
    box:SetSize(w, h)
    box.edge:SetStyle(style.edgeStyle, style.edgeMetal)
    box.edge:SetShown(edged)
    box.edge:Layout()
    local bar = box.bar
    bar:ClearAllPoints()
    bar:SetAllPoints(box)
    bar:SetFrameLevel(box:GetFrameLevel() + 1)
    Kit.BarForeground(bar, style.barTexture, h, px)
    Kit.BarBackground(bar, style.barBackground, w, h, px)
    Kit.Tint(bar.bg, Kit.BarBackgroundColor(style.barBackground), style.barBackgroundOpacity / 100)
    local fill = bar:GetStatusBarTexture()
    if fill and fill.ClearTextureSlice then fill:ClearTextureSlice() end
    if bar.SetReverseFill then bar:SetReverseFill(style.reverse) end
    Kit.FillEdge(bar, fillEdge, style.reverse, px)
    box:Show()
end

-- The Full color on a combo point: a second bar over it spanning max - 1 to
-- max, so the count lights every point's layer only once it reaches the
-- maximum, without the count ever being compared.
local function LayoutFull(box, style, index, count, h, px)
    if not style.fullShow then
        if box.full then box.full:Hide() end
        return
    end
    local full = box.full
    if not full then full = Kit.Bar(box); full.bg:Hide(); box.full = full end
    full:ClearAllPoints(); full:SetAllPoints(box)
    full:SetFrameLevel(box.bar:GetFrameLevel() + 1)
    Kit.BarForeground(full, style.barTexture, h, px)
    if full.SetReverseFill then full:SetReverseFill(style.reverse) end
    full:SetMinMaxValues(count - 1, count)
    full:SetValue(count - 1)
    full:SetStatusBarColor(style.fullColor[1], style.fullColor[2], style.fullColor[3], 1)
    full.index = index
    full:Show()
end

-- Lays a bar's frame out at `width` (the frame is sized by the caller,
-- edges included) and returns its height. Combo Points split the width into
-- `count` boxes on whole pixels, the last one ending exactly at the bar's
-- end: Separated, each in its edge, Spacing apart between the shadows;
-- Grouped (and always inside a block), in one edge with a Divider Width line
-- between points. opts (Group Resources): inBlock (no edges, no floor),
-- height, x and y (the boxes' offset), textHost (the region the text sits on).
function M:LayoutResourceFrame(frame, id, width, px, sample, opts)
    opts = opts or {}
    local style = self.db.resources[id]
    local function Round(v) return math.floor(v / px + 0.5) * px end
    local h = opts.height or M.ResourceBarHeight(style, px, opts.inBlock)
    local segmented = self.resourceSpecs[id].segmented
    local count = self:ResourceBoxCount(id, sample)
    local reach = opts.inBlock and 0 or M.ResourceReach(style, px)
    local x0, y0 = (opts.x or 0) + reach, (opts.y or 0) + reach
    local combined = segmented and (opts.inBlock or style.layout == "grouped")
    local outer = frame.outer
    outer:ClearAllPoints()
    outer:SetPoint("TOPLEFT", frame, "TOPLEFT", x0, -y0)
    outer:SetSize(math.max(px, width - 2 * reach), h)
    outer:SetFrameLevel(frame:GetFrameLevel() + 1)
    outer.edge:SetStyle(style.edgeStyle, style.edgeMetal)
    outer.edge:SetShown(combined and not opts.inBlock and style.border ~= "none")
    outer.edge:Layout()
    local inner = width - 2 * reach
    local gap = combined and style.dividerWidth * px or (segmented and Round(style.spacing) or 0)
    local span = combined and inner or width
    local edged = not combined and not opts.inBlock and style.border ~= "none"
    local firstWidth
    for i = 1, count do
        local box = frame.boxes[i]
        if not box then box = NewBox(frame); frame.boxes[i] = box end
        local left = Round((i - 1) * (span + gap) / count)
        local right = i == count and span or Round(i * (span + gap) / count) - gap
        box:SetFrameLevel(frame:GetFrameLevel() + 1)
        local w = combined and math.max(px, right - left) or math.max(px, right - left - 2 * reach)
        firstWidth = firstWidth or w
        if combined then LayoutBox(box, frame, style, x0 + left, y0, w, h, px, false, false)
        else LayoutBox(box, frame, style, (opts.x or 0) + left + reach, y0, w, h, px, edged, style.fillEdge and not segmented) end
        -- A point's box fills from (i - 1) to i: SetValue(count) lights it or
        -- leaves it dark without the count ever being compared.
        if segmented then box.bar:SetMinMaxValues(i - 1, i); LayoutFull(box, style, i, count, h, px) end
        -- The line after a grouped point, in Divider Color.
        local line = frame.dividers[i]
        if combined and i < count then
            if not line then line = frame:CreateTexture(nil, "ARTWORK"); line:SetTexture(Kit.FLAT); frame.dividers[i] = line end
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", frame, "TOPLEFT", x0 + right, -y0)
            line:SetSize(gap, h)
            Kit.Tint(line, style.dividerColor, 1)
            line:Show()
        elseif line then line:Hide() end
    end
    for i = count + 1, #frame.boxes do frame.boxes[i]:Hide() end
    for i = math.max(1, count), #frame.dividers do frame.dividers[i]:Hide() end
    frame.count, frame.px, frame.barHeight, frame.barWidth = count, px, h, firstWidth
    frame.rimKey, frame.textKey, frame.markKey = nil, nil, nil
    local host = opts.textHost == "box" and frame.boxes[1] or opts.textHost
    self:LayoutResourceText(frame, style, width, h, px, host)
    if self.LayoutResourceMarks then self:LayoutResourceMarks(frame, id) end
    return h + 2 * reach
end

-- The text: in the middle of the bar (owner, November 18, 2026), moved by
-- its offsets; on `host` when given (Power's box in a Grouped block), and
-- shown with Show Text. Nothing is measured: the text can be secret.
function M:LayoutResourceText(frame, style, width, h, px, host)
    local text = frame.text
    local look = { outline = style.outline, shadow = style.shadow, slug = style.slug, textColor = style.textColor }
    local path, size = Style.Weighted(Kit.FontPath(style, self.id), "bold"), style.textSize
    Kit.Font(text, look, size, path, px)
    local function Snap(v) return math.floor(v / px + 0.5) * px end
    text:ClearAllPoints()
    text:SetPoint("CENTER", host or frame, "CENTER", Snap(style.textX), Snap(style.textY))
    text:SetJustifyH("CENTER")
    text:SetShown(style.textShow == true)
    Kit.LayoutLift(text, look, size, path, px, false, "CENTER")
    frame.textLayer:SetFrameLevel(frame:GetFrameLevel() + 6)
    return width
end

-- Rim Color: Bar Color and Custom paint every edge of the bar flat in that
-- color (Edge:SetTint); Metal leaves the style's lit metal. Painted only
-- when the color changes.
function M:PaintResourceEdges(frame, id, barColor)
    local style = self.db.resources[id]
    local tint = (style.rimColor == "bar" and barColor) or (style.rimColor == "custom" and style.rimCustom) or nil
    local key = tint and string.format("%.3f,%.3f,%.3f", tint[1], tint[2], tint[3]) or "metal"
    if frame.rimKey == key then return end
    frame.rimKey = key
    for _, box in ipairs(frame.boxes) do box.edge:SetTint(tint) end
    frame.outer.edge:SetTint(tint)
    if frame.block then frame.block.edge:SetTint(tint) end
end

-- Stand-ins and frames ---------------------------------------------------------

-- Built with the module's other frames on first enable.
function M:BuildResources()
    if self.resourceFrames then return end
    self.resourceFrames, self.resourceMovers, self.anchorWidths = {}, {}, {}
    for _, id in ipairs(self.resources) do self:BuildResource(id) end
    -- A viewer saved as attached to a resource bar was registered before the
    -- bar existed and sat at its saved screen spot; attach it now.
    PM:Refresh(true)
end

function M:BuildResource(id)
    local style = self.db.resources[id]
    local eid = self.ResourceElementId(id)
    local mover = CreateFrame("Frame", self.ResourceFrameName(id), UIParent)
    mover:SetFrameStrata("HIGH")
    mover:SetSize(style.width, style.height)
    mover.fill = mover:CreateTexture(nil, "BACKGROUND", nil, -8)
    mover.fill:SetAllPoints(); mover.fill:SetTexture(Kit.FLAT); Kit.Tint(mover.fill, Kit.palette.accent, 0.18)
    mover:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    self.resourceMovers[id] = mover
    local ok, reason = PM:RegisterElement(eid, mover, { moduleId = self.id,
        -- Anchors to any ModeUI element, 1 physical pixel off its side.
        defaultPosition = self.resourcePositions[id], anyTarget = true, gapPixels = 1,
        canDrag = function() return self.active == true and self.db.resources[id].show and not self:ResourceInBlock(id) end,
        label = self:ResourceLabel(id) })
    assert(ok, "ModeUI: resource bar position registration failed: " .. tostring(reason))
    -- Match Width in the Edit Mode window: the bar takes the width of what
    -- it hangs from, and follows it when that changes size.
    PM:SetSizeMatch(eid, {
        axes = { width = true },
        get = function() return self.db.resources[id].matchWidth end,
        set = function(_, on) return self:SetResourceOption(id, "matchWidth", on == true) end,
    })
    PM:SetAnchorSizeListener(eid, function(_, width)
        if addon.IsNumber(width, 1, 10000) then self.anchorWidths[id] = width else self.anchorWidths[id] = nil end
        if self.active then self:LayoutResource(id) end
    end)
    mover:Hide()
    local frame = self:NewResourceFrame(UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetAllPoints(mover)
    frame:Hide()
    self.resourceFrames[id] = frame
end

-- Sizes the stand-in and lays the bar out, then fills it. A bar in a
-- Grouped block is laid out with the block (ResourceGroup.lua).
function M:LayoutResource(id)
    local frame, mover = self.resourceFrames and self.resourceFrames[id], self.resourceMovers and self.resourceMovers[id]
    if not frame then return end
    if self:ResourceGrouped(id) then self:LayoutResourceGroup(); return end
    if frame.block then frame.block:Hide() end
    local px = Kit.PixelSize(mover)
    local width = self:ResourceWidth(id, px)
    local style = self.db.resources[id]
    mover:SetSize(width, M.ResourceBarHeight(style, px) + 2 * M.ResourceReach(style, px))
    -- Back on its own stand-in (it may have sat in a block), on whole pixels.
    self:PlaceResourceFrame(frame, mover)
    self:LayoutResourceFrame(frame, id, width, px, false)
    self:UpdateResource(id)
end

-- In ModeUI's Edit Mode each bar that's on shows its stand-in, even while
-- it has nothing to show (Combo Points on a class without them); a bar in a
-- Grouped block moves with Power's.
function M:RenderResourceMovers()
    if not self.resourceMovers then return end
    for id, mover in pairs(self.resourceMovers) do
        local show = self.editing == true and self.active == true and self.db.resources[id].show and not self:ResourceInBlock(id)
        PM:SetEditable(self.ResourceElementId(id), show)
        mover:SetShown(show)
    end
end

-- Everything again: after a settings change, a new form, or the scale.
function M:RefreshResources()
    if not self.resourceFrames then return end
    local grouped = false
    for _, id in ipairs(self.resources) do
        if not self.active then self.resourceFrames[id]:Hide()
        elseif self:ResourceGrouped(id) then
            if not grouped then grouped = true; self:LayoutResourceGroup() end
        else self:LayoutResource(id) end
    end
    self:RenderResourceMovers()
end

-- Status line for a bar's page: whether it shows for this character now.
function M:ResourceStatus(id)
    if not self.active then return L["Off. Turn the Cooldown Manager on (the switch at the top) to use the resource bars."] end
    local style = self.db.resources[id]
    if not style.show then return L["This bar is off."] end
    if id == "combo" then
        local spec = addon.Domain.ClassResource.Spec()
        if not spec then return L["Your class has no combo points; this bar stays hidden."] end
        if spec.when and not addon.Domain.ClassResource.Active() then return L["Shows in Cat Form."] end
    elseif id == "mana" then
        if not addon.Domain.Power.HasAlternateMana("player") then return L["Only Druids have mana under another power; this bar stays hidden."] end
        if not addon.Domain.Power.AlternateManaActive("player") then return L["Shows in Bear and Cat Form."] end
    end
    if self:ResourceInBlock(id) then return L["Shows now, in the Grouped block. Move the block with Power in Edit Mode."] end
    return L["Shows now. Move it in Edit Mode."]
end
