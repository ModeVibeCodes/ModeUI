local _, addon = ...
local T, W = addon.InterfaceTheme, addon.ConfigWidgets

local Style = addon.Style
-- The slide toggle (docs/DESIGN_LANGUAGE.md, "Settings window"): two 34px
-- halves, OFF and ON, on a near-black track in a Steel Sheen rim; a 30px block
-- slides under the chosen half, Rosewood Deep with bold white OFF, or Celadon
-- with dark ON. The button keeps its own size as the hit target.
local HALF, HEIGHT, INSET = 34, 20, 2
local SWITCH_WIDTH = HALF * 2

-- The font is bound before any text: WoW refuses text on a font string
-- without one ("Font not set").
local function Half(frame, text, side)
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    addon.Media:BindInterfaceFont(label, GameFontHighlight, T.fontSize.group, nil, "heading")
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
    for _, half in ipairs({ off, on }) do half:SetDrawLayer("OVERLAY", 2) end
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
    local buttons, widths, x = {}, {}, PADDING
    for _, choice in ipairs(choices) do
        local value = choice.value
        local width = choice.width or 132
        widths[#widths + 1] = width
        local button = W.Button(container, choice.label, width, SEGMENT_HEIGHT, "segment")
        button:SetPoint("LEFT", x, 0)
        button:SetScript("OnClick", function() setter(value) end)
        buttons[#buttons + 1] = button
        x = x + width
    end
    container:SetSize(x + PADDING, SEGMENT_HEIGHT + 2 * PADDING)
    -- Fitting (docs/DESIGN_LANGUAGE.md, "Settings window"): side by side while
    -- every label fits; otherwise the same choices become a compact dropdown in
    -- place (one line, never stacked or wrapped).
    local function Measure(value) return type(value) == "number" and not (issecretvalue and issecretvalue(value)) and value or nil end
    local function Need(index) return math.max(40, math.ceil(Measure(buttons[index].label:GetStringWidth()) or 40) + 20) end
    local function Needed()
        local total = 2 * PADDING
        for index in ipairs(buttons) do total = total + Need(index) end
        return total
    end
    local menu
    local function Menu(width)
        if menu then return menu end
        menu = W.Select(parent, width, function()
            local list = {}
            for _, choice in ipairs(choices) do list[#list + 1] = { id = choice.value, label = choice.label } end
            return list
        end, function()
            local value = getter()
            for _, choice in ipairs(choices) do if choice.value == value then return value, choice.label end end
            return value, tostring(value or "")
        end, setter)
        container.menu = menu
        return menu
    end
    local function Fit(available)
        available = Measure(available) or (x + PADDING)
        -- Each segment's width: its natural width shrunk evenly toward the room,
        -- never below its label. More than the room in total: compact.
        local inner, natural = available - 2 * PADDING, x - PADDING
        local scale = inner < natural and inner / natural or 1
        local planned, total = {}, 0
        for index in ipairs(buttons) do
            planned[index] = math.max(Need(index), math.floor(widths[index] * scale))
            total = total + planned[index]
        end
        local compact = available >= 40 and total > inner
        container.compact = compact
        container:SetShown(not compact)
        if compact then
            local field = Menu(available)
            field:SetWidth(available); field:Show(); field:Refresh()
            return
        end
        if menu then menu:Hide() end
        local left = PADDING
        for index, button in ipairs(buttons) do
            button:SetWidth(planned[index]); button:ClearAllPoints(); button:SetPoint("LEFT", left, 0)
            left = left + planned[index]
        end
        container:SetWidth(left + PADDING)
    end
    local row = parent.row
    if row then
        local previous = row.layoutChildren
        function row:layoutChildren(width)
            if previous then previous(self, width) end
            local available = parent == self.settingsHost and (self.stacked and width or width - 198) or Measure(parent:GetWidth())
            Fit(available)
        end
    end
    container.FitSegments = Fit
    local function Refresh()
        for index, button in ipairs(buttons) do button:SetSelected(getter() == choices[index].value) end
        if menu and menu:IsShown() then menu:Refresh() end
    end
    return buttons, Refresh
end
