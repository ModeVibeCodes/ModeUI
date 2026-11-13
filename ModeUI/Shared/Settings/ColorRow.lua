local _, addon = ...
local widgets = addon.ConfigWidgets

local function Hex(rgb)
    return string.format("#%02X%02X%02X", math.floor(rgb[1] * 255 + 0.5), math.floor(rgb[2] * 255 + 0.5), math.floor(rgb[3] * 255 + 0.5))
end

local function ParseHex(value)
    value = value:gsub("^#", "")
    if not value:match("^%x%x%x%x%x%x$") then return end
    return { tonumber(value:sub(1, 2), 16) / 255, tonumber(value:sub(3, 4), 16) / 255, tonumber(value:sub(5, 6), 16) / 255 }
end

function addon:CloseTimerColorPicker()
    if self.timerPickerCallback and ColorPickerFrame and self.timerPickerCallback == ColorPickerFrame.swatchFunc then
        ColorPickerFrame:Hide()
    end
    self.timerPickerCallback = nil
    self.timerPickerOwner = nil
end

function widgets.ColorRow(page, timer, title, key, enabledGetter, host, options)
    local function Enabled() return not enabledGetter or enabledGetter() end
    local function Action(parent, text, width, callback)
        local button = widgets.Button(parent, text, width, 30)
        button:SetPoint("LEFT")
        button:SetScript("OnClick", function() callback(); page:Refresh() end)
        return button
    end
    local row = host or page:Row(title)
    local pick
    pick = Action(row, "Pick", 72, function()
        if not Enabled() or not timer:CanConfigure() then return end
        if not ColorPickerFrame then C_AddOns.LoadAddOn("Blizzard_ColorPickerFrame") end
        if not ColorPickerFrame then
            print(addon.InterfaceTheme.id=="mode" and "ModeUI: Blizzard color picker is unavailable on this client." or "ModeUI: Blizzard color picker is unavailable; use the RGB hex field.")
            return
        end
        addon:CloseTimerColorPicker()
        local oldColor = timer.db.appearance[key]
        local previous = { oldColor[1], oldColor[2], oldColor[3] }
        local swatch = function()
            if not Enabled() then return end
            local r, g, b = ColorPickerFrame:GetColorRGB()
            timer:SetAppearance(key, { r, g, b })
            page:Refresh()
        end
        addon.timerPickerCallback = swatch
        addon.timerPickerOwner = pick
        ColorPickerFrame:SetupColorPickerAndShow({
            r = oldColor[1], g = oldColor[2], b = oldColor[3], hasOpacity = false,
            swatchFunc = swatch,
            cancelFunc = function() timer:SetAppearance(key, previous); page:Refresh() end,
        })
    end)
    local sample = (options and options.separateSwatch and row or pick):CreateTexture(nil, "OVERLAY")
    sample:SetPoint("LEFT", 6, 0)
    sample:SetSize(12, 16)
    local hex = CreateFrame("EditBox", nil, row)
    hex:SetPoint("LEFT", 80, 0)
    hex:SetSize(96, 30)
    hex:SetAutoFocus(false)
    hex:SetMaxLetters(7)
    hex:SetFontObject(GameFontHighlight)
    addon.Media:BindInterfaceFont(hex, GameFontHighlight)
    hex:SetTextInsets(8, 8, 0, 0)
    widgets.Texture(hex, "InputField")
    local applyingHex
    local function ApplyHex()
        if applyingHex then return end
        applyingHex=true
        if not Enabled() then hex:ClearFocus(); page:Refresh(); applyingHex=false;return end
        local rgb = ParseHex(hex:GetText())
        if rgb then timer:SetAppearance(key, rgb)
        else print("ModeUI: enter exactly six RGB hex digits, for example #FFFFFF.") end
        hex:ClearFocus()
        page:Refresh();applyingHex=false
    end
    local apply
    if not (options and options.immediateHex) then apply = Action(row, "Apply", 64, ApplyHex) end
    if apply then apply:ClearAllPoints();apply:SetPoint("LEFT",184,0) end
    hex:SetScript("OnEnterPressed", ApplyHex)
    if options and options.immediateHex then hex:SetScript("OnEditFocusLost",ApplyHex) end
    hex:SetScript("OnEscapePressed", function() applyingHex=true;hex:ClearFocus();page:Refresh();applyingHex=false end)
    page.refreshers[#page.refreshers + 1] = function()
        local color = timer.db.appearance[key]
        if not (options and options.immediateHex) or not hex:HasFocus() then hex:SetText(Hex(color)) end
        sample:SetColorTexture(color[1], color[2], color[3], 1)
        local enabled = Enabled()
        pick:SetEnabled(enabled);if apply then apply:SetEnabled(enabled) end;hex:SetEnabled(enabled)
        sample:SetAlpha(enabled and 1 or 0.4)
        row.rowLabel:SetTextColor(unpack(enabled and addon.Theme.text or addon.Theme.muted))
        if not enabled and addon.timerPickerOwner == pick then addon:CloseTimerColorPicker() end
    end
    page.settingsColors=page.settingsColors or {}
    page.settingsColors[#page.settingsColors+1]={host=row,pick=pick,hex=hex,apply=apply,sample=sample,key=key}
    return pick, hex, apply, sample
end
