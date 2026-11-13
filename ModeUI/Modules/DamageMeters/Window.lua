local _, addon = ...
local M = addon.DamageMeters
if not M then return end

-- A meter window: a hollow pixel rim around the background, the header strip
-- (meter title on the left, fight and timer on the right) over a one-pixel
-- divider, then the rows. Each row is a square class icon and a Mode
-- Gradient bar with the name and value on it. The same code paints the real
-- windows, the breakdown panel and the settings preview, so they always match.
-- Windows are plain frames (nothing here is protected), hung from a stand-in
-- that Edit Mode moves.
local Kit, L = addon.Kit, addon.L
local FLAT = Kit.FLAT

local function TextWithLift(layer)
    local text = Kit.Text(layer)
    text.lift = Kit.Text(layer, "ARTWORK")
    return text
end

function M:BuildRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.iconBg = row:CreateTexture(nil, "BACKGROUND")
    row.iconBg:SetTexture(FLAT)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.bar = Kit.Bar(row)
    row.bar:SetMinMaxValues(0, 1); row.bar:SetValue(0)
    row.textLayer = CreateFrame("Frame", nil, row.bar)
    row.textLayer:SetAllPoints()
    row.textLayer:SetFrameLevel(row.bar:GetFrameLevel() + 2)
    row.name, row.value = TextWithLift(row.textLayer), TextWithLift(row.textLayer)
    row.highlight = row.textLayer:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints(); row.highlight:SetTexture(FLAT)
    row.highlight:SetVertexColor(1, 1, 1, 0.06); row.highlight:Hide()
    row:SetScript("OnEnter", function() row.highlight:Show() end)
    row:SetScript("OnLeave", function() row.highlight:Hide() end)
    row:Hide()
    return row
end

-- The window's shell: background, rim, header and an empty-state line.
-- `name` is a global frame name (real windows) or nil (breakdown, preview).
function M:BuildShell(parent, name)
    local frame = CreateFrame("Frame", name, parent)
    frame:SetSize(240, 160)
    frame.fill = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    frame.fill:SetTexture(FLAT)
    frame.rim = Kit.Rim(frame, "BORDER")
    local header = CreateFrame("Button", nil, frame)
    header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    header.fill = header:CreateTexture(nil, "BACKGROUND")
    header.fill:SetAllPoints(); header.fill:SetTexture(FLAT)
    header.title, header.info = TextWithLift(header), TextWithLift(header)
    frame.divider = frame:CreateTexture(nil, "BORDER")
    frame.divider:SetTexture(FLAT)
    frame.header = header
    frame.empty = Kit.Text(frame)
    frame.empty:SetWordWrap(true)
    frame.rows = {}
    frame.offset = 0
    return frame
end

function M:BuildWindow(window)
    local frame = self:BuildShell(UIParent, self.frameNames[window])
    frame.window = window
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    -- A click that ends a header drag doesn't open the menu.
    frame.header:SetScript("OnClick", function(header, button)
        if frame.dragged then frame.dragged = nil; return end
        self:ToggleMenu(window, header, button)
    end)
    frame:SetScript("OnMouseWheel", function(_, delta) self:Scroll(window, -delta) end)
    frame:Hide()
    self.frames[window] = frame
    self:BuildControls(frame)
    self:CreateMover(window)
    frame:SetPoint("TOPLEFT", self.movers[window], "TOPLEFT", 0, 0)
    return frame
end

function M:Build()
    if self.built then return end
    self.built = true
    for _, window in ipairs(self.windows) do self:BuildWindow(window) end
    for _, window in ipairs(self.windows) do self:BindControls(window) end
end

-- One row's place and look; its data is filled by Render.lua.
function M:PaintRow(row, frame, style, g, index, path)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", g.left, -self.RowTop(g, index))
    row:SetSize(g.rowW, g.rowH)
    local iconed = g.icon > 0
    for _, texture in ipairs({ row.iconBg, row.icon }) do
        texture:ClearAllPoints(); texture:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        texture:SetSize(math.max(g.px, g.icon), g.rowH)
        texture:SetShown(iconed)
    end
    Kit.Tint(row.iconBg, self.TRACK_COLOR, style.barBackgroundOpacity / 100)
    row.bar:ClearAllPoints()
    row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", iconed and g.icon + g.iconGap or 0, 0)
    row.bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    Kit.BarForeground(row.bar, style.barTexture, g.rowH, g.px)
    Kit.BarBackground(row.bar, style.barBackground)
    Kit.Tint(row.bar.bg, self.TRACK_COLOR, style.barBackgroundOpacity / 100)
    local name, value = row.name, row.value
    Kit.Font(name, style, style.nameSize, path, g.px)
    Kit.Font(value, style, style.valueSize, path, g.px)
    value:ClearAllPoints(); value:SetPoint("RIGHT", row.bar, "RIGHT", -g.inset, 0); value:SetJustifyH("RIGHT")
    name:ClearAllPoints(); name:SetPoint("LEFT", row.bar, "LEFT", g.inset, 0)
    name:SetPoint("RIGHT", value, "LEFT", -g.inset, 0); name:SetJustifyH("LEFT")
    Kit.LayoutLift(name, style, style.nameSize, path, g.px, true, "LEFT")
    Kit.LayoutLift(value, style, style.valueSize, path, g.px, true, "RIGHT")
end

-- Paints a style onto a shell: size, rim, background, header and `rows` rows
-- (the window's Rows by default). Returns the geometry.
function M:PaintShell(frame, style, rows)
    local px = Kit.PixelSize(frame)
    local g = self.Geometry(style, px, rows)
    local path = Kit.FontPath(style, self.id)
    frame.g, frame.fontPath, frame.style = g, path, style
    frame:SetSize(g.width, g.height)
    Kit.Inset(frame.fill, frame, g.border)
    Kit.Tint(frame.fill, style.backgroundColor, style.backgroundOpacity / 100)
    Kit.PlaceRim(frame.rim, frame, g.border, g.cut, style.borderColor)
    local header = frame.header
    header:SetShown(style.header)
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", g.border, -g.border)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -g.border, -g.border)
    header:SetHeight(math.max(px, g.header))
    Kit.Tint(header.fill, style.headerColor, style.headerOpacity / 100)
    local divider = frame.divider
    divider:ClearAllPoints()
    divider:SetPoint("TOPLEFT", frame, "TOPLEFT", g.border, -(g.border + g.header))
    divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -g.border, -(g.border + g.header))
    divider:SetHeight(px)
    Kit.Tint(divider, style.borderColor, 1)
    divider:SetShown(g.divider > 0)
    local title, info = header.title, header.info
    Kit.Font(title, style, style.titleSize, path, px); title:SetTextColor(style.titleColor[1], style.titleColor[2], style.titleColor[3], 1)
    Kit.Font(info, style, style.titleSize, path, px); info:SetTextColor(style.textColor[1], style.textColor[2], style.textColor[3], 0.7)
    info:ClearAllPoints(); info:SetPoint("RIGHT", header, "RIGHT", -g.inset, 0); info:SetJustifyH("RIGHT")
    title:ClearAllPoints(); title:SetPoint("LEFT", header, "LEFT", g.inset, 0)
    title:SetPoint("RIGHT", info, "LEFT", -g.inset, 0); title:SetJustifyH("LEFT")
    Kit.LayoutLift(title, style, style.titleSize, path, px, style.header, "LEFT")
    Kit.LayoutLift(info, style, style.titleSize, path, px, style.header, "RIGHT")
    local empty = frame.empty
    Kit.Font(empty, style, style.nameSize, path, px); empty:SetTextColor(style.textColor[1], style.textColor[2], style.textColor[3], 0.6)
    empty:ClearAllPoints()
    empty:SetPoint("TOPLEFT", frame, "TOPLEFT", g.left + g.inset, -(g.rowsTop + g.px))
    empty:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(g.left + g.inset), g.pad + g.border)
    empty:SetJustifyH("CENTER"); empty:SetJustifyV("MIDDLE")
    for i = 1, g.rows do
        frame.rows[i] = frame.rows[i] or self:BuildRow(frame)
        self:PaintRow(frame.rows[i], frame, style, g, i, path)
    end
    for i = g.rows + 1, #frame.rows do frame.rows[i]:Hide() end
    self:LayoutControls(frame, style, g, frame.window)
    return g
end

function M:PaintWindow(window)
    local frame, style = self.frames[window], self:Style(window)
    local g = self:PaintShell(frame, style)
    frame:SetAlpha(style.opacity / 100)
    local mover = self.movers[window]
    mover:SetSize(g.width, g.height)
    self:AnchorWindow(window, g)
    -- Click Through lets clicks and the mouse wheel pass to the world.
    local mouse = not style.clickThrough
    frame.header:EnableMouse(mouse)
    frame:EnableMouseWheel(mouse)
    -- A row's left click opens its spell breakdown; a right click the menu.
    for _, row in ipairs(frame.rows) do
        if not row.bound then
            row.bound = true
            row:SetScript("OnClick", function(clicked, button)
                if button == "RightButton" then self:ToggleMenu(window, frame.header) else self:OpenBreakdown(window, clicked) end
            end)
            -- Rows sit over the window, so they scroll it too.
            row:SetScript("OnMouseWheel", function(_, delta) self:Scroll(window, -delta) end)
        end
        row:EnableMouse(mouse)
        row:EnableMouseWheel(mouse)
    end
    self:LayoutMover(window)
end

-- Edit Mode stand-in: a plain frame Position Manager can move (it drives the
-- mouse on whatever it registers, which would make rows unclickable). The
-- window hangs from its top-left corner.
function M:CreateMover(window)
    local mover = CreateFrame("Frame", self.frameNames[window] .. "Mover", UIParent)
    mover:SetFrameStrata("HIGH")
    mover:SetSize(240, 160)
    mover.fill = mover:CreateTexture(nil, "BACKGROUND", nil, -8)
    mover.fill:SetAllPoints(); mover.fill:SetTexture(FLAT)
    mover.label = Kit.Text(mover)
    mover.label:SetPoint("CENTER")
    self.movers[window] = mover
    -- Measured before registering; the Position Manager then moves it.
    mover:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    local ok, element = addon.PositionManager:RegisterElement(self.elementIds[window], mover, { moduleId = self.id,
        defaultPosition = self.defaultPositions[window], allowedTargets = self.allowedTargets[window],
        canDrag = function() return self.active == true and self.db[window].show and not self:IsGrouped(window) end })
    assert(ok, "ModeUI: damage meter position registration failed: " .. tostring(element))
    element.label = L[self.windowLabels[window]]
    mover:Hide()
end

function M:LayoutMover(window)
    local mover = self.movers[window]
    Kit.Tint(mover.fill, Kit.palette.accent, 0.18)
    Kit.Font(mover.label, { outline = true, shadow = true, textColor = { 1, 1, 1 } }, 12,
        Kit.FontPath(self:Style(window), self.id), Kit.PixelSize(mover))
    mover.label:SetText(L[self.windowLabels[window]])
end

-- In Edit Mode every window that's switched on shows, with its stand-in over
-- it. A grouped window has none: it moves with the window it follows.
function M:RenderMovers()
    for _, window in ipairs(self.windows) do
        local mover = self.movers[window]
        if mover then
            local show = self.editing == true and self.active == true and self.db[window].show and not self:IsGrouped(window)
            addon.PositionManager:SetEditable(self.elementIds[window], show)
            mover:SetShown(show)
        end
    end
end
