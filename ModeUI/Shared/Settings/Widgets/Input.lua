local _, addon = ...
local T, W = addon.InterfaceTheme, addon.ConfigWidgets
local Paint, ART = W.Paint, W.BlizzardArt

-- Integer by default; optional decimal precision for presentation parameters.
function W.NumericInput(parent, getter, setter, minimum, maximum, width, decimals)
    local input = CreateFrame("EditBox", nil, parent)
    input:SetSize(width or 52, 28)
    input:SetAutoFocus(false)
    input:SetMaxLetters(9)
    input:SetFontObject(GameFontHighlight)
    input:SetTextInsets(T.id=="mode" and 4 or 8,T.id=="mode" and 4 or 8,0,0)
    if T.id=="mode" then input:SetJustifyH("CENTER") end
    addon.Media:BindInterfaceFont(input, GameFontHighlight)
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

-- Hairline track with an accent fill up to the current value and a flat
-- rectangular thumb.
function W.Slider(parent, minimum, maximum, step, getter, setter, suffix, numeric)
    local settingsParent=parent
    while settingsParent do
        if settingsParent.row then settingsParent.row.settingsHasSlider=true;break end
        settingsParent=settingsParent:GetParent()
    end
    local label = W.Label(parent, "", nil, 0, -8, 52, T.secondary)
    label:ClearAllPoints()
    label:SetPoint("RIGHT", 0, 0)
    label:SetJustifyH(T.id=="mode" and "CENTER" or "RIGHT")
    local slider = CreateFrame("Slider", nil, parent)
    slider:SetPoint("LEFT", 0, 0)
    slider:SetPoint("RIGHT", -62, 0)
    slider:SetHeight(24)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minimum, maximum)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    -- Modern draws a thicker track at control-edge contrast and a larger thumb
    -- so the slider reads as draggable; Blizzard keeps its hairline.
    local modern = not T.blizzardArt
    local trackHeight = modern and 4 or 2
    local track = W.Texture(slider, "SliderTrack")
    track:ClearAllPoints()
    track:SetPoint("LEFT", 0, 0); track:SetPoint("RIGHT", 0, 0); track:SetHeight(trackHeight)
    if modern then Paint(track, T.lineStrong) end
    local progress = W.Fill(slider, T.primary, "BORDER")
    progress:ClearAllPoints()
    progress:SetPoint("LEFT", 0, 0); progress:SetHeight(trackHeight); progress:SetWidth(1)
    local thumb = W.Texture(slider, "SliderThumb", "OVERLAY")
    thumb:ClearAllPoints()
    thumb:SetSize(modern and 10 or 8, modern and 20 or 16)
    if T.id=="mode" then thumb.modeAsset="ModeSliderThumb";Paint(thumb,T.text) end
    thumb:SetVertexColor(unpack(T.text))
    -- Blizzard: the stock slider knob, untinted.
    local stockThumb = T.blizzardArt and thumb:SetTexture(ART.sliderThumb) ~= false
    if stockThumb then thumb:SetSize(32, 32); thumb:SetVertexColor(1, 1, 1, 1) end
    slider:SetThumbTexture(thumb)
    local hovered
    local function Tint(color) if not stockThumb then thumb:SetVertexColor(unpack(color)) end end
    local function Progress()
        local low, high = slider:GetMinMaxValues()
        local width = slider:GetWidth()
        if (issecretvalue and (issecretvalue(low) or issecretvalue(high) or issecretvalue(width)))
            or type(low) ~= "number" or type(high) ~= "number" or type(width) ~= "number" then return end
        local span = high - low
        local ratio = span > 0 and (slider:GetValue() - low) / span or 0
        progress:SetWidth(math.max(1, math.min(1, math.max(0, ratio)) * width))
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
        label:Hide()
        local options = type(numeric) == "table" and numeric or {}
        input = W.NumericInput(parent, getter, setter, options.minimum or minimum, options.maximum or maximum,nil,options.decimals)
        input:SetPoint("RIGHT")
        input.afterApply = Refresh
        parent.numericInput = input
    end
    parent.slider = slider
    return Refresh
end
