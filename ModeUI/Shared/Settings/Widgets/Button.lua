local _, addon = ...
local T, W = addon.InterfaceTheme, addon.ConfigWidgets
local Paint, ART, ThreeSlice, BUTTON_SLICES = W.Paint, W.BlizzardArt, W.ThreeSlice, W.BUTTON_SLICES

-- Visual recipes per button style: fill, outline and label color for each state.
local BUTTON = {
    button = {
        fill = "surface", line = "lineStrong", label = "text",
        hoverFill = "hover", hoverLine = "secondary",
        pressedFill = "panel", selectedLine = "primary",
    },
    primary = {
        fill = "primary", label = "ink", hoverFill = "highlight", pressedFill = "primary",
        selectedLabel = "ink",
    },
    secondary = {
        line = "line", label = "secondary",
        hoverFill = "surface", hoverLine = "lineStrong", hoverLabel = "text",
        pressedFill = "panel", selectedLine = "primary",
    },
    choice = {
        line = "line", label = "muted",
        hoverFill = "surface", hoverLabel = "text",
        selectedFill = "surface", selectedLine = "primary", selectedLabel = "text",
    },
    tab = {
        label = "secondary", hoverFill = "surface", hoverLabel = "text",
        selectedFill = "surface", selectedLabel = "text", edge = true,
    },
    underline = {
        label = "muted", hoverLabel = "text", selectedLabel = "text",
    },
}
-- List rows draw exactly like plain buttons in Modern; in Blizzard they are
-- stock list rows rather than push buttons.
BUTTON.row = BUTTON.button
-- Modern recipes. Every clickable edge rests at the control-edge contrast so
-- targets read as buttons before they are hovered; hover lifts the fill one
-- clear step, and a selected choice shows a full accent edge on a raised fill.
local MODERN_BUTTON = {
    button = {
        fill = "surface", line = "lineStrong", label = "text",
        hoverFill = "hover", hoverLine = "muted",
        pressedFill = "panel", selectedLine = "primary",
    },
    secondary = {
        line = "lineStrong", label = "secondary",
        hoverFill = "hover", hoverLine = "muted", hoverLabel = "text",
        pressedFill = "surface", selectedFill = "surface", selectedLine = "primary",
    },
    choice = {
        line = "lineStrong", label = "secondary",
        hoverFill = "hover", hoverLine = "muted", hoverLabel = "text",
        selectedFill = "surface", selectedLine = "primary", selectedLabel = "text",
    },
    tab = {
        label = "secondary", hoverFill = "hover", hoverLabel = "text",
        selectedFill = "surface", selectedLabel = "text", edge = true,
    },
    underline = {
        label = "secondary", hoverLabel = "text", selectedLabel = "text",
    },
}
MODERN_BUTTON.row = MODERN_BUTTON.button
-- Blizzard: styles drawn with the stock push-button art, and styles that
-- receive the stock list highlight bar. Segmented choices stay flat: a row of
-- red buttons is loud, and the pressed art alone barely shows which is chosen.
local PUSH = { button = true, primary = true, secondary = true }
local LIST = { tab = true, row = true }

local function Color(key) return key and T[key] end
-- Stock push-button label gold (NORMAL_FONT_COLOR); reads on the red art.
local BUTTON_GOLD = { 1, 0.82, 0, 1 }
local MODE_HEADING = { label = "heading", hoverLabel = "highlight" }

function W.Button(parent, text, width, height, style)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 120, height or 30)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp")
    style = style or "button"
    button.skinStyle = style
    if style == "toggle" or style == "checkbox" then
        if style=="checkbox" and parent.row then parent.row.settingsStandaloneToggle=button end
        return W.Switch(button, text, height, style)
    end
    -- Resolved per button: the theme is applied after this file loads.
    local recipe = (T.id == "mode" and style == "categoryHeading" and MODE_HEADING)
        or (not T.blizzardArt and MODERN_BUTTON[style]) or BUTTON[style] or BUTTON.button
    button.fill = W.Fill(button, T.surface, T.id=="mode" and style=="roundedTab" and "ARTWORK" or "BACKGROUND")
    if T.id=="mode" then
        button.modeBorderAsset=style=="roundedTab" and "ModePillSurface" or "ModeControlBorder"
        if style=="roundedTab" or style=="subTab" then button.modeFixedSprite=true end
        button.fill:ClearAllPoints()
        local inset=style=="roundedTab" and 1.5 or 1
        button.fill:SetPoint("TOPLEFT",inset,-inset);button.fill:SetPoint("BOTTOMRIGHT",-inset,inset)
        button.fill.modeAsset=style=="roundedTab" and "ModePillSurface" or "ModeControlSurface";Paint(button.fill,T.surface)
    end
    button.outline = W.Outline(button, T.line, T.id=="mode" and style=="roundedTab" and "BACKGROUND" or "BORDER")
    -- Kept for consumers that tint the selected state directly.
    button.activeGlow = W.Fill(button, T.primary, "ARTWORK", 0, 0.08)
    button.activeGlow:Hide()
    if recipe.edge or T.id == "mode" then
        -- Selected navigation rows carry an accent bar on the leading edge
        -- (3px in Modern, where it is the main "you are here" marker).
        button.selectionEdge = W.Fill(button, T.primary, "OVERLAY")
        button.selectionEdge:ClearAllPoints()
        button.selectionEdge:SetPoint("TOPLEFT"); button.selectionEdge:SetPoint("BOTTOMLEFT")
        button.selectionEdge:SetWidth(T.blizzardArt and 2 or 3)
        button.selectionEdge:Hide()
        if T.id == "mode" then
            button.selectionEdge.modeAsset="ModeSelection"
            -- Export already contains cyan; white tint keeps its exact hue.
            Paint(button.selectionEdge,{1,1,1,1})
            button.selectionEdge:SetTexCoord(0,1,0,1)
        end
    end
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    addon.Media:BindInterfaceFont(button.label, GameFontHighlight)
    W.CrispText(button.label)
    if T.blizzardArt and PUSH[style] then
        button.blizzardArt = ThreeSlice(button, "BACKGROUND", ART.buttonUp, 12, BUTTON_SLICES)
        if button.blizzardArt then
            local glow = button:CreateTexture(nil, "HIGHLIGHT")
            glow:SetAllPoints()
            glow:SetTexture(ART.buttonHighlight)
            glow:SetTexCoord(0, 0.625, 0, 0.6875)
            glow:SetBlendMode("ADD")
            button.blizzardButtonHighlight = glow
        end
    elseif T.blizzardArt and LIST[style] then
        local glow = button:CreateTexture(nil, "ARTWORK")
        glow:SetAllPoints()
        glow:Hide()
        if glow:SetTexture(ART.rowHighlight) ~= false then
            glow:SetBlendMode("ADD")
            -- Warm the stock bar so it reads as gold rather than a white flare.
            glow:SetVertexColor(1, 0.82, 0.45)
            button.blizzardHighlight = glow
        end
    end
    -- Stock push button: gold label, white on hover or while held selected.
    local function RefreshPush(self, available, hovered, pressed, selected)
        local down = pressed or selected
        self.blizzardArt:SetFile((not available and ART.buttonDisabled) or (down and ART.buttonDown) or ART.buttonUp)
        Paint(self.fill, T.background, 0)
        self.outline:SetShown(false)
        self.activeGlow:Hide()
        local color = self.labelColor or ((hovered or selected) and T.highlight or BUTTON_GOLD)
        if not available then color = T.unavailable end
        self.label:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    end
    function button:RefreshAppearance()
        local available = self:IsEnabled()
        local hovered = available and self.hovered
        local pressed = hovered and self.pressed
        local selected = available and self.selected == true
        if self.blizzardArt then return RefreshPush(self, available, hovered, pressed, selected) end
        local fill = recipe.fill
        local line = recipe.line
        local label = recipe.label
        if selected then
            fill = recipe.selectedFill or fill
            line = recipe.selectedLine or line
            label = recipe.selectedLabel or "primary"
        end
        if hovered then
            fill = recipe.hoverFill or fill
            line = recipe.hoverLine or line
            label = selected and label or recipe.hoverLabel or label
        end
        if pressed then fill = recipe.pressedFill or fill end
        local fillColor, lineColor = Color(fill), Color(line)
        if selected and line == "primary" and hovered then lineColor = T.primary end
        if not available then
            fillColor = recipe.fill and (style == "primary" and T.surface or T.sidebar) or nil
            lineColor = recipe.line and T.line or nil
        end
        if fillColor then Paint(self.fill, fillColor) else Paint(self.fill, T.background, 0) end
        if lineColor then
            self.outline:SetColor(lineColor, T.blizzardArt and selected and line == "primary" and 0.7 or nil)
            self.outline:SetShown(true)
        else self.outline:SetShown(false) end
        local color = self.labelColor or Color(label) or T.text
        if not available then color = T.unavailable end
        self.label:SetTextColor(color[1], color[2], color[3], color[4] or 1)
        self.activeGlow:SetShown(selected and style ~= "primary" and style ~= "underline")
        if T.id == "mode" then
            -- Hover lights text only. A separate etched line marks selection;
            -- resting fills and borders never brighten with hover/selection.
            local plain=style=="tab" or style=="underline" or style=="categoryHeading"
            Paint(self.fill, plain and T.background or T.surface, plain and 0 or 1)
            self.outline:SetShown(not plain)
            if not plain then self.outline:SetColor(T.line,0.8) end
            if style=="roundedTab" then
                -- Same solid backing / inset interior construction as switches.
                Paint(self.fill,T.surface)
                self.outline:SetColor(T.line,1);self.outline:SetShown(true)
            elseif style=="subTab" then
                Paint(self.fill,selected and T.panel or T.background)
                self.outline:SetColor(selected and T.primary or T.line,selected and 0.55 or 1)
                self.outline:SetShown(true)
            end
            self.activeGlow:Hide()
            local modeColor=self.labelColor or (style=="categoryHeading" and T.heading or T.secondary)
            if not available then modeColor=T.unavailable
            elseif selected or hovered then modeColor=T.primary end
            self.label:SetTextColor(unpack(modeColor))
            self.label:SetShadowColor(T.primary[1], T.primary[2], T.primary[3], available and (selected or hovered) and 0.55 or 0)
            self.label:SetShadowOffset(0, -1)
        end
        if self.selectionEdge then
            if T.id=="mode" then W.AlignTextLine(self,self.selectionEdge) end
            self.selectionEdge:SetShown(selected)
        end
        if self.blizzardHighlight then
            -- Stock list rows: the highlight bar shows on hover and holds while selected.
            self.blizzardHighlight:SetShown(hovered or selected)
            self.blizzardHighlight:SetAlpha(selected and 0.45 or 0.25)
            self.activeGlow:Hide()
        end
    end
    function button:SetLabelColor(color)
        self.labelColor = color
        self:RefreshAppearance()
    end
    local nativeSetEnabled = button.SetEnabled
    function button:SetEnabled(enabled)
        nativeSetEnabled(self, enabled)
        self:RefreshAppearance()
    end
    function button:SetSelected(selected)
        self.selected = selected
        self:RefreshAppearance()
    end
    -- Hooks preserve existing tooltip and hide handlers on consumers.
    button:HookScript("OnEnter",function(self) self.hovered=true;self:RefreshAppearance() end)
    button:HookScript("OnLeave",function(self) self.hovered=false;self.pressed=false;self:RefreshAppearance() end)
    button:HookScript("OnMouseDown",function(self) self.pressed=true;self:RefreshAppearance() end)
    button:HookScript("OnMouseUp",function(self) self.pressed=false;self:RefreshAppearance() end)
    button:HookScript("OnHide",function(self) self.hovered=false;self.pressed=false;self:RefreshAppearance() end)
    if T.id=="mode" then
        addon.Media:RegisterFontListener(button,function(owner) W.AlignTextLine(owner,owner.selectionEdge) end)
        button:HookScript("OnSizeChanged",function(owner) W.AlignTextLine(owner,owner.selectionEdge) end)
    end
    button:RefreshAppearance()
    return button
end
