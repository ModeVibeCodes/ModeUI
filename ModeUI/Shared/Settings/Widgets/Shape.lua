local _, addon = ...
local T, W = addon.InterfaceTheme, addon.ConfigWidgets
local Kit = addon.Kit

-- Rounded shapes for settings controls, cut from the white textures made by
-- tools/build_shape_textures.lua and tinted. A box is a rim with its fill one
-- physical pixel inside, so every control edge is exactly one screen pixel.
-- Insets follow the frame's effective scale; the window re-applies them
-- after its own scale changes (W.RefreshPixelInsets).
local boxes = setmetatable({}, { __mode = "k" })

-- A texture cut from a bundled shape (a Media texture key), or a flat square
-- when the key is nil or the client refuses the file.
function W.Shape(frame, key, layer, sublevel)
    local texture = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel)
    if key then Kit.Rounded(texture, key) else texture:SetTexture(Kit.FLAT) end
    return texture
end

local Box = {}
Box.__index = Box

function Box:Inset()
    Kit.Inset(self.fill, self.frame, Kit.PixelSize(self.frame))
end

local function Tint(texture, color, alpha)
    if not color then texture:Hide(); return end
    texture:SetVertexColor(color[1], color[2], color[3], (color[4] or 1) * (alpha or 1))
    texture:Show()
end

-- Palette colors for the fill and the rim; nil hides that part. alpha scales both.
function Box:SetColors(fill, rim, alpha)
    self:Inset()
    Tint(self.fill, fill, alpha)
    Tint(self.rim, rim, alpha)
end

function Box:SetShown(shown)
    if shown then self:SetColors(self.fillColor, self.rimColor) else self.fill:Hide(); self.rim:Hide() end
end

-- frame: the host; key: the Media shape (nil: square); layer: draw layer for
-- both parts (the rim one sublevel below the fill).
function W.Box(frame, key, layer, sublevel)
    sublevel = sublevel or 0
    local box = setmetatable({ frame = frame }, Box)
    box.rim = W.Shape(frame, key, layer, sublevel)
    box.rim:SetAllPoints(frame)
    box.fill = W.Shape(frame, key, layer, sublevel + 1)
    local setColors = box.SetColors
    function box:SetColors(fill, rim, alpha)
        self.fillColor, self.rimColor = fill, rim
        setColors(self, fill, rim, alpha)
    end
    box:Inset()
    boxes[box] = true
    return box
end

function W.RefreshPixelInsets()
    for box in pairs(boxes) do box:Inset() end
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
