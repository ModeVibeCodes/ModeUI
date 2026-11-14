local _, addon = ...
local T, W = addon.InterfaceTheme, addon.ConfigWidgets

local SWITCH_WIDTH, SWITCH_HEIGHT, KNOB = 28, 16, 10
local KNOB_MARGIN = (SWITCH_HEIGHT - KNOB) / 2

-- Toggles and checkboxes are both a 28x16 pill switch centered on the button:
-- off is a dark track with a muted knob at the left, on an accent track with
-- an ink knob at the right. The button keeps its own size as the hit target.
function W.Switch(button, text, height, style)
    local frame = CreateFrame("Frame", nil, button)
    frame:SetPoint("CENTER"); frame:SetSize(SWITCH_WIDTH, SWITCH_HEIGHT)
    local track = W.Box(frame, "ModeSwitch", "ARTWORK")
    local knob = W.Shape(frame, "ModeCircle", "OVERLAY")
    knob:SetSize(KNOB, KNOB)
    button.switchFrame, button.track, button.fill, button.knob = frame, track, track.fill, knob
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    addon.Media:BindInterfaceFont(button.label, GameFontHighlight, T.fontSize.body)
    W.CrispText(button.label)
    function button:RefreshAppearance()
        local available = self:IsEnabled()
        local on = self.selected == true
        local hovered = available and self.hovered
        local alpha = available and 1 or 0.4
        if on then track:SetColors(T.primary, T.primary, alpha)
        else track:SetColors(T.track, T.trackRim, alpha) end
        knob:ClearAllPoints()
        knob:SetPoint(on and "RIGHT" or "LEFT", frame, on and "RIGHT" or "LEFT", on and -KNOB_MARGIN or KNOB_MARGIN, 0)
        local color = on and T.ink or (hovered and T.text or T.muted)
        knob:SetVertexColor(color[1], color[2], color[3], alpha)
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
