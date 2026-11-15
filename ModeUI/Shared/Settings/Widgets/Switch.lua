local _, addon = ...
local T, W = addon.InterfaceTheme, addon.ConfigWidgets

local Style = addon.Style
-- The slide toggle (docs/DESIGN_LANGUAGE.md, "Settings window"): two 34px
-- halves, OFF and ON, on a near-black track in a Steel Sheen rim; a 30px block
-- slides under the chosen half, Rosewood Deep with bold white OFF, or Celadon
-- with dark ON. The button keeps its own size as the hit target.
local HALF, HEIGHT, INSET = 34, 20, 2
local SWITCH_WIDTH = HALF * 2

local function Half(frame, text, side)
    local label = frame:CreateFontString(nil, "OVERLAY")
    label:SetPoint(side, frame, side, 0, 0)
    label:SetSize(HALF, HEIGHT)
    label:SetJustifyH("CENTER")
    label:SetText(text)
    return label
end

-- Toggles and checkboxes are both a slide toggle centered on the button.
function W.Switch(button, text, height, style)
    local frame = CreateFrame("Frame", nil, button)
    frame:SetPoint("CENTER"); frame:SetSize(SWITCH_WIDTH, HEIGHT)
    if button:GetWidth() < SWITCH_WIDTH then button:SetWidth(SWITCH_WIDTH) end
    local track = W.Box(frame, "ModeFlat", "ARTWORK")
    local knob = frame:CreateTexture(nil, "OVERLAY", nil, 0)
    Style.ApplyAsset(knob, "Knob")
    knob:SetSize(HALF - 2 * INSET, HEIGHT - 2 * INSET)
    local off, on = Half(frame, "OFF", "LEFT"), Half(frame, "ON", "RIGHT")
    for _, half in ipairs({ off, on }) do
        addon.Media:BindInterfaceFont(half, GameFontHighlight, T.fontSize.group, nil, "heading")
        half:SetDrawLayer("OVERLAY", 2)
    end
    button.switchFrame, button.track, button.fill, button.knob = frame, track, track.fill, knob
    button.offLabel, button.onLabel = off, on
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    addon.Media:BindInterfaceFont(button.label, GameFontHighlight, T.fontSize.body)
    W.CrispText(button.label)
    local function Text(label, color, shadow)
        label:SetTextColor(color[1], color[2], color[3], color[4] or 1)
        label:SetShadowColor(0, 0, 0, shadow and 0.5 or 0)
        label:SetShadowOffset(0, shadow and -1 or 0)
    end
    function button:RefreshAppearance()
        local available = self:IsEnabled()
        local isOn = self.selected == true
        local hovered = available and self.hovered
        local alpha = available and 1 or 0.4
        track:SetColors(T.toggleTrack, hovered and T.primary or T.rim, alpha)
        local block = isOn and T.toggleOn or T.toggleOff
        knob:SetVertexColor(block[1], block[2], block[3], alpha)
        knob:ClearAllPoints()
        knob:SetPoint(isOn and "RIGHT" or "LEFT", frame, isOn and "RIGHT" or "LEFT", isOn and -INSET or INSET, 0)
        Text(off, isOn and T.toggleIdle or T.highlight, not isOn)
        Text(on, isOn and T.onInk or T.toggleIdle, false)
        frame:SetAlpha(alpha)
        local label = self.labelColor or T.text
        self.label:SetTextColor(label[1], label[2], label[3], available and (label[4] or 1) or 0.5)
    end
    function button:SetLabelColor(color) self.labelColor = color; self:RefreshAppearance() end
    local nativeSetEnabled = button.SetEnabled
    function button:SetEnabled(enabled) nativeSetEnabled(self, enabled); self:RefreshAppearance() end
    function button:SetSelected(selected) self.selected = selected; self:RefreshAppearance() end
    button:HookScript("OnEnter",function(self) self.hovered=true;self:RefreshAppearance() end)
    button:HookScript("OnLeave",function(self) self.hovered=false;self:RefreshAppearance() end)
    button:HookScript("OnHide",function(self) self.hovered=false;self:RefreshAppearance() end)
    button:RefreshAppearance()
    return button
end

-- Exclusive settings use one getter/setter; no independent saved flags. The
-- segments sit in one field with a rim and 2 px of padding; the chosen one is
-- filled. The container carries its host's row so callers can still reach
-- the row through a segment's parent.
local SEGMENT_HEIGHT, PADDING = 22, 2
function W.Exclusive(parent, choices, getter, setter)
    local container = CreateFrame("Frame", nil, parent)
    container.row, container.rowLabel = parent.row, parent.rowLabel
    container:SetPoint("LEFT", 0, 0)
    container.box = W.Box(container, "ModeFlat")
    container.box:SetColors(T.field, T.rim)
    local buttons, x = {}, PADDING
    for _, choice in ipairs(choices) do
        local value = choice.value
        local width = choice.width or 132
        local button = W.Button(container, choice.label, width, SEGMENT_HEIGHT, "segment")
        button:SetPoint("LEFT", x, 0)
        button:SetScript("OnClick", function() setter(value) end)
        buttons[#buttons + 1] = button
        x = x + width
    end
    container:SetSize(x + PADDING, SEGMENT_HEIGHT + 2 * PADDING)
    local function Refresh()
        for index, button in ipairs(buttons) do button:SetSelected(getter() == choices[index].value) end
    end
    return buttons, Refresh
end
