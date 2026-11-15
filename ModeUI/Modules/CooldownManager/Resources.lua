local _, addon = ...
local M = addon.CooldownManager
if not M then return end

-- Building and laying out the Resource Bars. Each bar has a stand-in (its
-- Edit Mode element, named ModeUIResourcePower and so on) and, on it, the
-- bar the player sees. A bar is one box, or one box per point for Combo
-- Points; a box is a status bar (the fill in Bar Texture and Bar Color over
-- Bar Background) in the `frameThin` edge outside it (docs/DESIGN_LANGUAGE.md,
-- "Bars"); the bar's frame leaves room for the edges, so its width matches
-- the cooldown rows' and Spacing counts between the shadows. No masks.
-- Values may be secret, so they only ever go to the status bars and text
-- setters (ResourceUpdate.lua). The settings preview draws a bar with these
-- same functions.
local Kit, L, Style = addon.Kit, addon.L, addon.Style
local PM = addon.PositionManager
local PAD = 4 -- pixels between a text and the end of its bar

-- One box: a status bar (Kit.Bar: fill, background and the lift) in the
-- Mode edge.
local function NewBox(parent)
    local box = CreateFrame("Frame", nil, parent)
    box.bar = Kit.Bar(box)
    box.edge = Style.Edge(box, M.EDGE)
    return box
end
-- How far a bar's edges reach past its boxes, in px units.
function M.ResourceReach(style, px) return style.border == "none" and 0 or M.EDGE_REACH * px end

-- A bar's frame: its boxes (made as they're needed) and a text above them.
function M:NewResourceFrame(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame.boxes = {}
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

-- Lays one box out: `w` by `h` at `x`, `y` from the frame's top left.
local function LayoutBox(box, frame, style, x, y, w, h, px, edge)
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
    box:SetSize(w, h)
    box.edge:SetShown(style.border ~= "none")
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
    Kit.FillEdge(bar, edge, style.reverse, px)
    box:Show()
end

-- Lays a bar's frame out at `width` (the frame is sized by the caller,
-- edges included). Combo Points split the width into `count` boxes with
-- their edges, `spacing` apart between the shadows, on whole pixels, the last
-- one ending exactly at the bar's end.
function M:LayoutResourceFrame(frame, id, width, px, sample)
    local style = self.db.resources[id]
    local function Snap(v) return math.max(px, math.floor(v / px + 0.5) * px) end
    local function Round(v) return math.floor(v / px + 0.5) * px end
    local h = Snap(style.height)
    local segmented = self.resourceSpecs[id].segmented
    local count = self:ResourceBoxCount(id, sample)
    local gap = segmented and Round(style.spacing) or 0
    local reach = M.ResourceReach(style, px)
    for i = 1, count do
        local box = frame.boxes[i]
        if not box then box = NewBox(frame); frame.boxes[i] = box end
        local left = Round((i - 1) * (width + gap) / count)
        local right = i == count and width or Round(i * (width + gap) / count) - gap
        box:SetFrameLevel(frame:GetFrameLevel() + 1)
        LayoutBox(box, frame, style, left + reach, reach, math.max(px, right - left - 2 * reach), h, px, style.fillEdge and not segmented)
        -- A point's box fills from (i - 1) to i: SetValue(count) lights it or
        -- leaves it dark without the count ever being compared.
        if segmented then box.bar:SetMinMaxValues(i - 1, i) end
    end
    for i = count + 1, #frame.boxes do frame.boxes[i]:Hide() end
    frame.count, frame.px, frame.barHeight = count, px, h
    self:LayoutResourceText(frame, style, width, h, px)
    return h + 2 * reach
end

-- The text: at Text Anchor on the bar (Left, Center or Right), PAD pixels
-- in from that end, then moved by its offsets. Nothing is measured: the
-- text can be secret.
function M:LayoutResourceText(frame, style, width, h, px)
    local text = frame.text
    local look = { outline = style.outline, shadow = style.shadow, slug = style.slug, textColor = style.textColor }
    local path, size = Style.Weighted(Kit.FontPath(style, self.id), "bold"), style.textSize
    Kit.Font(text, look, size, path, px)
    local anchor = style.textAnchor
    local inset = PAD * px + M.ResourceReach(style, px)
    local dx = (anchor == "LEFT" and inset) or (anchor == "RIGHT" and -inset) or 0
    local function Snap(v) return math.floor(v / px + 0.5) * px end
    text:ClearAllPoints()
    text:SetPoint(anchor, frame, anchor, dx + Snap(style.textX), Snap(style.textY))
    text:SetJustifyH(anchor)
    local shown = style.text ~= "none"
    text:SetShown(shown)
    Kit.LayoutLift(text, look, size, path, px, false, anchor)
    frame.textLayer:SetFrameLevel(frame:GetFrameLevel() + 6)
    return width
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
        canDrag = function() return self.active == true and self.db.resources[id].show end,
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

-- Sizes the stand-in and lays the bar out, then fills it.
function M:LayoutResource(id)
    local frame, mover = self.resourceFrames and self.resourceFrames[id], self.resourceMovers and self.resourceMovers[id]
    if not frame then return end
    local px = Kit.PixelSize(mover)
    local width = self:ResourceWidth(id, px)
    local style = self.db.resources[id]
    local h = math.max(px, math.floor(style.height / px + 0.5) * px)
    mover:SetSize(width, h + 2 * M.ResourceReach(style, px))
    self:LayoutResourceFrame(frame, id, width, px, false)
    self:UpdateResource(id)
end

-- In ModeUI's Edit Mode each bar that's on shows its stand-in, even while
-- it has nothing to show (Combo Points on a class without them).
function M:RenderResourceMovers()
    if not self.resourceMovers then return end
    for id, mover in pairs(self.resourceMovers) do
        local show = self.editing == true and self.active == true and self.db.resources[id].show
        PM:SetEditable(self.ResourceElementId(id), show)
        mover:SetShown(show)
    end
end

-- Everything again: after a settings change, a new form, or the scale.
function M:RefreshResources()
    if not self.resourceFrames then return end
    for _, id in ipairs(self.resources) do
        if self.active then self:LayoutResource(id) else self.resourceFrames[id]:Hide() end
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
    return L["Shows now. Move it in Edit Mode."]
end
