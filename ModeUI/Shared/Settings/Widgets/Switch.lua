local _, addon = ...
local T, W = addon.InterfaceTheme, addon.ConfigWidgets
local Paint, ART = W.Paint, W.BlizzardArt

-- Square switch (toggle) and checkbox. Both are sharp-cornered to match the
-- rest of the shell; state is carried by fill, not by artwork.
-- Blizzard: toggles and checkboxes are both the stock check button.
local function BlizzardCheck(button, text)
    local box = button:CreateTexture(nil, "BACKGROUND")
    if box:SetTexture(ART.checkbox) == false then box:Hide(); return nil end
    box:SetPoint("CENTER"); box:SetSize(26, 26)
    -- Drawn by state rather than the HIGHLIGHT layer so a hovered grid cell
    -- lights its box too.
    local glow = button:CreateTexture(nil, "OVERLAY")
    glow:SetPoint("CENTER"); glow:SetSize(26, 26)
    glow:SetTexture(ART.checkboxHighlight); glow:SetBlendMode("ADD"); glow:Hide()
    local mark = button:CreateTexture(nil, "ARTWORK")
    mark:SetPoint("CENTER"); mark:SetSize(26, 26)
    mark:SetTexture(ART.check)
    button.fill, button.knob = box, mark
    -- Inert stand-ins so shared consumers can still address these regions.
    button.switchOutline = W.Outline(button, T.background, "BORDER", 0, 0)
    button.switchOutline:SetShown(false)
    button.activeGlow = W.Fill(button, T.primary, "ARTWORK", 0, 0)
    button.activeGlow:Hide()
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    addon.Media:BindInterfaceFont(button.label, GameFontHighlight)
    W.CrispText(button.label)
    function button:RefreshAppearance()
        local available = self:IsEnabled()
        mark:SetTexture(available and ART.check or ART.checkDisabled)
        mark:SetShown(self.selected == true)
        box:SetAlpha(available and 1 or 0.5)
        glow:SetShown(available and self.hovered == true)
        local color = self.labelColor or T.text
        self.label:SetTextColor(color[1], color[2], color[3], available and (color[4] or 1) or 0.5)
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

function W.Switch(button, text, height, style)
    if T.blizzardArt then
        local check = BlizzardCheck(button, text)
        if check then return check end
    end
    local toggle = style == "toggle"
    local h = 18
    local w = toggle and 34 or 18
    local frame = CreateFrame("Frame", nil, button)
    frame:SetPoint("CENTER"); frame:SetSize(w, h)
    frame.modeSquareOutline=T.id~="mode"
    if T.id=="mode" then
        frame.modeFixedSprite=true
        -- A solid outer silhouette backs the inset interior. A hollow ring on
        -- a separate frame can leave bright fill pixels visible past its edge.
        frame.modeBorderAsset=toggle and "ModeToggleSurface" or "ModeCheckSurface"
    end
    local outline = W.Outline(frame, T.lineStrong, T.id=="mode" and "BACKGROUND" or "BORDER")
    local track = (T.id=="mode" and frame or button):CreateTexture(nil, T.id=="mode" and "ARTWORK" or "BACKGROUND")
    track:SetPoint("CENTER",frame,"CENTER",0,0); track:SetSize(w, h)
    if T.id=="mode" then
        track:SetSize(w-2,h-2)
        track.modeAsset=toggle and "ModeToggleSurface" or "ModeCheckSurface"
    end
    local mark = (T.id=="mode" and frame or button):CreateTexture(nil, T.id=="mode" and "OVERLAY" or "ARTWORK")
    if T.id=="mode" then mark.modeAsset=toggle and "ModeThumb" or "ModeCheckMark" end
    mark:SetSize(toggle and 12 or 10, toggle and 12 or 10)
    button.fill, button.knob, button.switchOutline = track, mark, outline
    -- Inert stand-in so shared consumers can still address the glow region.
    button.activeGlow = W.Fill(button, T.primary, "ARTWORK", 0, 0)
    button.activeGlow:Hide()
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    addon.Media:BindInterfaceFont(button.label, GameFontHighlight)
    W.CrispText(button.label)
    function button:RefreshAppearance()
        local available = self:IsEnabled()
        local on = self.selected == true
        local hovered = available and self.hovered
        if toggle then Paint(track, on and T.primary or T.surface)
        -- Mode recolors the same interior; other themes retain the faint wash.
        elseif on then Paint(track, T.primary, T.id=="mode" and 1 or 0.16) else Paint(track, T.field) end
        outline:SetColor(on and T.primary or (hovered and T.secondary or T.lineStrong))
        if T.id == "mode" then
            self.activeGlow:Hide()
            -- A thin charcoal rim stays the same color in both states.
            outline:SetColor(T.background,1)
        end
        mark:ClearAllPoints()
        if toggle then
            mark:SetPoint(on and "RIGHT" or "LEFT", track, on and "RIGHT" or "LEFT", on and -3 or 3, 0)
            Paint(mark, on and T.ink or (hovered and T.text or T.secondary))
            mark:Show()
        else
            mark:SetPoint("CENTER", track, "CENTER", 0, 0)
            Paint(mark, T.primary)
            mark:SetShown(on)
        end
        local alpha = available and 1 or 0.4
        track:SetAlpha(alpha); mark:SetAlpha(alpha)
        for _, edge in ipairs(outline.edges) do edge:SetAlpha(alpha) end
        local color = self.labelColor or T.text
        self.label:SetTextColor(color[1], color[2], color[3], available and (color[4] or 1) or 0.5)
        if T.id == "mode" then
            self.label:SetShadowColor(T.primary[1],T.primary[2],T.primary[3],hovered and 0.55 or 0)
            self.label:SetShadowOffset(0,-1)
        end
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

-- Exclusive settings use one getter/setter; no independent saved flags.
function W.Exclusive(parent, choices, getter, setter)
    local buttons, x = {}, 0
    for _, choice in ipairs(choices) do
        local value = choice.value
        local button = W.Button(parent, choice.label, choice.width or 132, 30, "choice")
        button:SetPoint("LEFT", x, 0)
        button:SetScript("OnClick", function() setter(value) end)
        buttons[#buttons + 1] = button
        x = x + (choice.width or 132) + 8
    end
    local function Refresh()
        for index, button in ipairs(buttons) do button:SetSelected(getter() == choices[index].value) end
    end
    return buttons, Refresh
end
