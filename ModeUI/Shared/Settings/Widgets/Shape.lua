local _, addon = ...
local T, W = addon.InterfaceTheme, addon.ConfigWidgets
local Kit = addon.Kit

-- Settings control faces in the Mode design language: a box is a fill (a
-- Mode texture tinted with the fill color) inside a Style.Edge border, the
-- `control` preset (1px Steel Sheen and a 1px shadow) unless the box asks for
-- another. W.Shape still cuts the older rounded shapes for small glyphs.
local Style = addon.Style

-- A texture cut from a bundled shape (a Media texture key), or a flat square
-- when the key is nil or the client refuses the file.
function W.Shape(frame, key, layer, sublevel)
    local texture = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel)
    if key then Kit.Rounded(texture, key) else texture:SetTexture(Kit.FLAT) end
    return texture
end

local Box = {}
Box.__index = Box

-- Re-lays the border on whole pixels (after the window's scale changes).
function Box:Inset()
    if self.edge then self.edge:Layout() end
end


-- Rim colors that mean "the preset's metal"; any other color tints the rim.
local function MetalRim(color)
    return color == T.rim or color == T.trackRim or color == T.lineStrong or color == T.cardBorder
end

-- Palette colors for the fill and the rim; nil hides that part. alpha scales both.
function Box:SetColors(fill, rim, alpha)
    self.fillColor, self.rimColor = fill, rim
    if fill then
        self.fill:SetVertexColor(fill[1], fill[2], fill[3], (fill[4] or 1) * (alpha or 1))
        self.fill:Show()
    else self.fill:Hide() end
    if self.edge then
        self.edge:SetShown(rim ~= nil)
        if rim then
            self.edge:SetTint(not MetalRim(rim) and rim or nil)
            self.edge.holder:SetAlpha(alpha or 1)
        end
    end
end

function Box:SetShown(shown)
    if shown then self:SetColors(self.fillColor, self.rimColor)
    else self.fill:Hide(); if self.edge then self.edge:SetShown(false) end end
end

-- The face texture: a Style.ASSETS key ("Solid" by default; buttons use "Gradient").
function Box:SetAsset(key)
    local asset = Style.ASSETS[key]
    Style.ApplyAsset(self.fill, asset and asset.fill or key)
    if self.fillColor then self:SetColors(self.fillColor, self.rimColor) end
end

-- frame: the host; key: nil for a square, borderless face (sidebar rows),
-- otherwise any value for a bordered face; layer: the fill's draw layer.
-- opts.preset: a Style.EDGE_PRESETS key (default "control").
function W.Box(frame, key, layer, sublevel, opts)
    local box = setmetatable({ frame = frame }, Box)
    box.fill = frame:CreateTexture(nil, layer or "BACKGROUND", nil, (sublevel or 0) + 1)
    box.fill:SetAllPoints(frame)
    Style.ApplyAsset(box.fill, "Solid")
    box.rim = box.fill -- older callers only read the fill
    if key then box.edge = Style.Edge(frame, opts and opts.preset or "control") end
    return box
end

function W.RefreshPixelInsets()
    Style.RelayoutEdges()
end

-- A small down chevron at the right of a dropdown button; muted, lit by hover.
function W.Chevron(button)
    local chevron = W.Shape(button, "ModeChevron", "OVERLAY")
    chevron:SetSize(16, 16)
    chevron:SetPoint("RIGHT", -6, 0)
    local function Tint()
        local color = not button:IsEnabled() and T.unavailable or button.hovered and T.text or T.muted
        chevron:SetVertexColor(color[1], color[2], color[3], 1)
    end
    button:HookScript("OnEnter", Tint)
    button:HookScript("OnLeave", Tint)
    button:HookScript("OnHide", Tint)
    local setEnabled = button.SetEnabled
    function button:SetEnabled(enabled) setEnabled(self, enabled); Tint() end
    Tint()
    button.chevron = chevron
    return chevron
end

-- Turns a button into a dropdown field: the chosen label at the left, a
-- chevron at the right.
function W.DropdownLabel(button)
    local label = button.label
    label:ClearAllPoints()
    label:SetPoint("LEFT", 10, 0); label:SetPoint("RIGHT", -28, 0)
    label:SetJustifyH("LEFT"); label:SetWordWrap(false)
    return W.Chevron(button)
end
