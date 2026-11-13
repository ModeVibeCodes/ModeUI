local _, addon = ...
local T, W = addon.InterfaceTheme, addon.ConfigWidgets
local Paint = W.Paint
-- The value box beside a slider, and the gap between them.
local VALUE_WIDTH, VALUE_HEIGHT, VALUE_GAP = 48, 24, 10

-- Integer by default; optional decimal precision for presentation parameters.
function W.NumericInput(parent, getter, setter, minimum, maximum, width, decimals)
    local input = CreateFrame("EditBox", nil, parent)
    input:SetSize(width or VALUE_WIDTH, VALUE_HEIGHT)
    input:SetAutoFocus(false)
    input:SetMaxLetters(9)
    input:SetFontObject(GameFontHighlight)
    input:SetTextInsets(4,4,0,0)
    input:SetJustifyH("CENTER")
    addon.Media:BindInterfaceFont(input, GameFontHighlight, T.fontSize.body)
    W.CrispText(input)
    W.Texture(input, "InputField")
    local applying
    function input:Refresh(force)
        if force or not self:HasFocus() then
            local text = decimals and string.format("%."..decimals.."f",getter()) or tostring(math.floor(getter() + 0.5))
            if text ~= self:GetText() then self:SetText(text) end
        end
    end
    local function Apply()
        if applying then return end
        applying = true
        local text = input:GetText()
        local pattern=decimals and "^%s*[+-]?%d+%.?%d*%s*$" or "^%s*[+-]?%d+%s*$"
        if text:match(pattern) then
            local value = tonumber(text)
            if value and value == value and math.abs(value) < math.huge then
                local low = type(minimum) == "function" and minimum() or minimum
                local high = type(maximum) == "function" and maximum() or maximum
                setter(math.max(low, math.min(high, value)))
            end
        end
        input:ClearFocus()
        input:Refresh(true)
        if input.afterApply then input.afterApply() end
        applying = false
    end
    input:SetScript("OnEnterPressed", Apply)
    input:SetScript("OnEditFocusLost", Apply)
    input:SetScript("OnEscapePressed", function()
        input:Refresh(true)
        input:ClearFocus()
    end)
    input:Refresh(true)
    return input
end

function W.ScrollThumb(bar, height)
    local thumb = W.Texture(bar, "ScrollThumb", "OVERLAY")
    thumb:ClearAllPoints()
    if T.id=="mode" then thumb.modeAsset="ModeScrollThumb";Paint(thumb,T.lineStrong) end
    thumb:SetSize(T.id=="mode" and 2 or 4, height)
    thumb:SetVertexColor(unpack(T.lineStrong))
    bar:SetThumbTexture(thumb)
    bar:HookScript("OnEnter", function() thumb:SetVertexColor(unpack(T.muted)) end)
    bar:HookScript("OnLeave", function() thumb:SetVertexColor(unpack(T.lineStrong)) end)
    return thumb
end

-- A 4 px rounded track with the accent filled up to the value, a light round
-- thumb in a dark ring, and the value in a small field at the right (an
-- editable number when numeric is set).
function W.Slider(parent, minimum, maximum, step, getter, setter, suffix, numeric)
    local settingsParent=parent
    while settingsParent do
        if settingsParent.row then settingsParent.row.settingsHasSlider=true;break end
        settingsParent=settingsParent:GetParent()
    end
    local valueBox = CreateFrame("Frame", nil, parent)
    valueBox:SetPoint("RIGHT", 0, 0); valueBox:SetSize(VALUE_WIDTH, VALUE_HEIGHT)
    valueBox.box = W.Box(valueBox, "ModeFlat"); valueBox.box:SetColors(T.field, T.rim)
    local label = W.Label(valueBox, "", nil, 0, 0, VALUE_WIDTH - 4, T.text)
    label:ClearAllPoints()
    label:SetPoint("CENTER", 0, 0)
    label:SetJustifyH("CENTER")
    local slider = CreateFrame("Slider", nil, parent)
    slider:SetPoint("LEFT", 0, 0)
    slider:SetPoint("RIGHT", -(VALUE_WIDTH + VALUE_GAP), 0)
    slider:SetHeight(24)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minimum, maximum)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    local track = W.Shape(slider, "ModeTrack", "BACKGROUND")
    track:SetPoint("LEFT", 0, 0); track:SetPoint("RIGHT", 0, 0); track:SetHeight(4)
    track:SetVertexColor(unpack(T.track))
    local progress = W.Shape(slider, "ModeTrack", "BORDER")
    progress:SetPoint("LEFT", 0, 0); progress:SetHeight(4); progress:SetWidth(4)
    progress:SetVertexColor(unpack(T.primary))
    -- The thumb texture is the dark ring; the light dot is centered on it.
    local thumb = W.Shape(slider, "ModeCircle", "OVERLAY")
    thumb:SetSize(16, 16)
    thumb:SetVertexColor(unpack(T.ink))
    slider:SetThumbTexture(thumb)
    local dot = W.Shape(slider, "ModeCircle", "OVERLAY", 1)
    dot:SetSize(12, 12); dot:SetPoint("CENTER", thumb, "CENTER", 0, 0)
    local hovered
    local function Tint(color) dot:SetVertexColor(unpack(color)) end
    Tint(T.text)
    local function Progress()
        local low, high = slider:GetMinMaxValues()
        local width = slider:GetWidth()
        if (issecretvalue and (issecretvalue(low) or issecretvalue(high) or issecretvalue(width)))
            or type(low) ~= "number" or type(high) ~= "number" or type(width) ~= "number" then return end
        local span = high - low
        local ratio = span > 0 and (slider:GetValue() - low) / span or 0
        progress:SetWidth(math.max(4, math.min(1, math.max(0, ratio)) * width))
        progress:SetShown(ratio > 0)
    end
    slider:SetScript("OnEnter", function() hovered = true; Tint(T.primary) end)
    slider:SetScript("OnLeave", function() hovered = false; Tint(T.text) end)
    slider:HookScript("OnMouseDown",function(_,button)
        if button=="LeftButton" then Tint(T.highlight) end
    end)
    slider:HookScript("OnMouseUp",function() Tint(hovered and T.primary or T.text) end)
    slider:HookScript("OnHide",function() hovered = false; Tint(T.text) end)
    slider:HookScript("OnSizeChanged", Progress)
    local updating, input
    local function Refresh()
        updating = true
        local value = getter()
        label:SetText(tostring(value) .. (suffix or ""))
        slider:SetValue(value, false) -- programmatic values retain exact integers
        Progress()
        if input then input:Refresh() end
        updating = false
    end
    slider:SetScript("OnValueChanged", function(_, value)
        if updating then return end
        setter(value)
        Refresh()
        if input then input:Refresh(true) end
    end)
    if numeric then
        valueBox:Hide()
        local options = type(numeric) == "table" and numeric or {}
        input = W.NumericInput(parent, getter, setter, options.minimum or minimum, options.maximum or maximum,nil,options.decimals)
        input:SetPoint("RIGHT")
        input.afterApply = Refresh
        parent.numericInput = input
    end
    parent.slider = slider
    return Refresh
end
