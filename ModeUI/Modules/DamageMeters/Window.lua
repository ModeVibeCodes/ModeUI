local _, addon = ...
local M = addon.DamageMeters
if not M then return end

-- A meter window in the Mode design language (docs/DESIGN_LANGUAGE.md,
-- "Windows and panels"): Mode Panel in Background Color at Background
-- Opacity with the `window` edge inside it (no soft drop when see-through),
-- the header strip (Header Texture, a Mode Title strip in Graphite raised by
-- default; the meter title placed by Title Position, X and Y; the lock,
-- Reset, the fight letter and the timer on the right, the timer at the edge)
-- over a one-pixel Graphite line, then the rows. Each row is a square class
-- icon and a bar (Mode Panel on Mode BG by default) with the name and value
-- on it. The same code paints the real
-- windows, the breakdown panel and the settings preview, so they always match.
-- Windows are plain frames (nothing here is protected), hung from a stand-in
-- that Edit Mode moves.
local Kit, L, Skin, Style = addon.Kit, addon.L, addon.Skin, addon.Style
local Tone = Style.Tone
local REACH = Style.EdgeReach("window")
-- The edge rides above the rows, bars and their text.
local EDGE_LEVEL = 8

local function TextWithLift(layer)
    local text = Kit.Text(layer)
    text.lift = Kit.Text(layer, "ARTWORK")
    return text
end

function M:BuildRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.iconBg = row:CreateTexture(nil, "BACKGROUND")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.bar = Kit.Bar(row)
    row.bar:SetMinMaxValues(0, 1); row.bar:SetValue(0)
    row.textLayer = CreateFrame("Frame", nil, row.bar)
    row.textLayer:SetAllPoints()
    row.textLayer:SetFrameLevel(row.bar:GetFrameLevel() + 2)
    row.name, row.value = TextWithLift(row.textLayer), TextWithLift(row.textLayer)
    row.highlight = row.textLayer:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints(); Style.ApplyAsset(row.highlight, "Solid")
    Style.Paint(row.highlight, Tone.mono.white, 0.06); row.highlight:Hide()
    row:SetScript("OnEnter", function() row.highlight:Show() end)
    row:SetScript("OnLeave", function() row.highlight:Hide() end)
    row:Hide()
    return row
end

-- The window's shell: face and edge, header and an empty-state line.
-- `name` is a global frame name (real windows) or nil (breakdown, preview).
function M:BuildShell(parent, name)
    local frame = CreateFrame("Frame", name, parent)
    frame:SetSize(240, 160)
    frame.parts = Skin.Box(frame, "window", { inset = REACH, level = EDGE_LEVEL })
    local header = CreateFrame("Button", nil, frame)
    header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    -- The header strip is a full bar, so it takes the same textures as the rows.
    header.bar = Kit.Bar(header)
    header.bar:SetAllPoints(); header.bar:SetMinMaxValues(0, 1); header.bar:SetValue(1)
    header.bar.bg:Hide()
    -- A Mode texture (Mode Title by default) draws as a box face instead,
    -- tiled one texel per pixel with its lift (Skin.PaintBox).
    header.parts = Skin.Box(header, nil, { sublevel = -6 })
    header.text = CreateFrame("Frame", nil, header)
    header.text:SetAllPoints(); header.text:SetFrameLevel(header.bar:GetFrameLevel() + 2)
    header.title, header.info = TextWithLift(header.text), TextWithLift(header.text)
    frame.divider = frame:CreateTexture(nil, "BORDER")
    Style.ApplyAsset(frame.divider, "Solid")
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

-- One text's settings in the shape Kit.Font and Kit.LayoutLift read, and
-- its font file.
function M.PartStyle(style, part)
    return { font = style[part .. "Font"], fontMedia = style[part .. "FontMedia"], outline = style[part .. "Outline"],
        shadow = style[part .. "Shadow"], liftedShadow = style[part .. "Lifted"], slug = style[part .. "Slug"],
        textColor = style[part .. "Color"] }
end
function M:PaintText(text, style, part, px, shown, justify)
    local look = self.PartStyle(style, part)
    local path, size = Kit.FontPath(look, self.id), style[part .. "Size"]
    Kit.Font(text, look, size, path, px)
    if text.lift then Kit.LayoutLift(text, look, size, path, px, shown, justify) end
    return path
end

-- One row's place and look; its data is filled by Render.lua.
function M:PaintRow(row, frame, style, g, index)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", g.left, -self.RowTop(g, index))
    row:SetSize(g.rowW, g.rowH)
    local iconed = g.icon > 0
    for _, texture in ipairs({ row.iconBg, row.icon }) do
        texture:ClearAllPoints(); texture:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        texture:SetSize(math.max(g.px, g.icon), g.rowH)
        texture:SetShown(iconed)
    end
    Style.ApplyAsset(row.iconBg, "Solid")
    local track = Kit.BarBackgroundColor(style.barBackground)
    Kit.Tint(row.iconBg, track, style.barBackgroundOpacity / 100)
    row.bar:ClearAllPoints()
    row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", iconed and g.icon + g.iconGap or 0, 0)
    row.bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    Kit.BarForeground(row.bar, style.barTexture, g.rowH, g.px)
    Kit.BarBackground(row.bar, style.barBackground)
    Kit.Tint(row.bar.bg, track, style.barBackgroundOpacity / 100)
    local name, value = row.name, row.value
    value:ClearAllPoints(); value:SetPoint("RIGHT", row.bar, "RIGHT", -g.inset, 0); value:SetJustifyH("RIGHT")
    name:ClearAllPoints(); name:SetPoint("LEFT", row.bar, "LEFT", g.inset, 0)
    name:SetPoint("RIGHT", value, "LEFT", -g.inset, 0); name:SetJustifyH("LEFT")
    self:PaintText(name, style, "name", g.px, true, "LEFT")
    self:PaintText(value, style, "value", g.px, true, "RIGHT")
end

-- Paints a style onto a shell: size, face and edge, header and `rows` rows
-- (the window's Rows by default). Returns the geometry.
function M:PaintShell(frame, style, rows)
    local px = Kit.PixelSize(frame)
    local g = self.Geometry(style, px, rows)
    frame.g, frame.style = g, style
    frame:SetSize(g.width, g.height)
    -- The Mode window; no soft drop under a see-through one.
    local alpha = style.backgroundOpacity / 100
    Skin.PaintBox(frame.parts, frame, "Panel", style.backgroundColor, alpha, true)
    -- Border Style and Border Metal; every style has the same reach.
    frame.parts.modeEdge:SetStyle(style.edgeStyle, style.edgeMetal)
    frame.parts.modeEdge:SetDrop(alpha >= 1 and style.opacity >= 100)
    local header = frame.header
    header:SetShown(style.header)
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", g.border, -g.border)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -g.border, -g.border)
    header:SetHeight(math.max(px, g.header))
    self:PaintHeaderFace(header, style, math.max(px, g.header), px)
    local divider = frame.divider
    divider:ClearAllPoints()
    divider:SetPoint("TOPLEFT", frame, "TOPLEFT", g.border, -(g.border + g.header))
    divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -g.border, -(g.border + g.header))
    divider:SetHeight(px)
    Style.Paint(divider, Tone.graphite.line)
    divider:SetShown(g.divider > 0)
    local title, info = header.title, header.info
    -- The timer at the header's right edge; the title in the room left of it
    -- (and of the buttons, which Controls.lua puts between them).
    info:ClearAllPoints(); info:SetPoint("RIGHT", header, "RIGHT", -g.inset, 0); info:SetJustifyH("RIGHT")
    self:PlaceTitle(frame, style, g, info)
    frame.fontPath = self:PaintText(title, style, "title", px, style.header, self.TITLE_JUSTIFY[style.titleAlign])
    self:PaintText(info, style, "timer", px, style.header, "RIGHT")
    local empty = frame.empty
    self:PaintText(empty, style, "name", px)
    local nc = style.nameColor
    empty:SetTextColor(nc[1], nc[2], nc[3], 0.6)
    empty:ClearAllPoints()
    empty:SetPoint("TOPLEFT", frame, "TOPLEFT", g.left + g.inset, -(g.rowsTop + g.px))
    empty:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(g.left + g.inset), g.pad + g.border)
    empty:SetJustifyH("CENTER"); empty:SetJustifyV("MIDDLE")
    for i = 1, g.rows do
        frame.rows[i] = frame.rows[i] or self:BuildRow(frame)
        self:PaintRow(frame.rows[i], frame, style, g, i)
    end
    for i = g.rows + 1, #frame.rows do frame.rows[i]:Hide() end
    self:LayoutControls(frame, style, g, frame.window)
    return g
end

-- The header's face: Header Texture in Header Color at Header Opacity. A
-- Mode texture (Mode Title by default) is a box face, tiled with its lift;
-- anything else (Mode Gradient, Flat, a SharedMedia bar) the header's bar.
function M:PaintHeaderFace(header, style, height, px)
    local _, key = Style.MediaAsset(style.headerTexture)
    local alpha, parts, bar = style.headerOpacity / 100, header.parts, header.bar
    bar:SetShown(key == nil)
    parts.face:SetShown(key ~= nil)
    if parts.lift then parts.lift:SetShown(key ~= nil and Style.ASSETS[key].lift ~= nil) end
    if key then
        Skin.PaintBox(parts, header, key, style.headerColor, alpha)
        return
    end
    Kit.BarForeground(bar, style.headerTexture, height, px)
    local c = style.headerColor
    bar:SetStatusBarColor(c[1], c[2], c[3], alpha)
end

-- The title between the header's left edge and `limit` (the timer, or the
-- leftmost button): justified by Title Position, moved by Title X and Title
-- Y on whole pixels. It is never measured (a breakdown's name can be secret).
M.TITLE_JUSTIFY = { left = "LEFT", center = "CENTER", right = "RIGHT" }
function M:PlaceTitle(frame, style, g, limit)
    local header = frame.header
    local function Snap(v) return math.floor(v / g.px + 0.5) * g.px end
    local x, y = Snap(style.titleOffsetX), Snap(style.titleOffsetY)
    header.title:ClearAllPoints()
    header.title:SetPoint("LEFT", header, "LEFT", g.inset + x, y)
    header.title:SetPoint("RIGHT", limit, "LEFT", -g.inset + x, y)
    header.title:SetJustifyH(self.TITLE_JUSTIFY[style.titleAlign])
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
    mover.fill:SetAllPoints(); mover.fill:SetTexture(Kit.FLAT)
    self.movers[window] = mover
    -- Measured before registering; the Position Manager then moves it.
    mover:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    local ok, element = addon.PositionManager:RegisterElement(self.elementIds[window], mover, { moduleId = self.id,
        defaultPosition = self.defaultPositions[window], allowedTargets = self.allowedTargets[window],
        label = L[self.windowLabels[window]], canDrag = function() return self.active == true and self.db[window].show and not self:IsGrouped(window) end })
    assert(ok, "ModeUI: damage meter position registration failed: " .. tostring(element))
    -- Match Width and Match Height in the Edit Mode window (Group.lua).
    addon.PositionManager:SetSizeMatch(self.elementIds[window], self:SizeMatchHandlers(window))
    addon.PositionManager:SetAnchorSizeListener(self.elementIds[window], function() self:AnchorResized() end)
    mover:Hide()
end

function M:LayoutMover(window)
    local mover = self.movers[window]
    Kit.Tint(mover.fill, Kit.palette.accent, 0.18)
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
