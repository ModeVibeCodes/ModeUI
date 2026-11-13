local _, addon = ...
local T, W = addon.InterfaceTheme, addon.ConfigWidgets

-- Button recipes: palette keys for the fill, rim and label at rest, and what
-- hover and selection change. A missing fill or rim draws nothing. press
-- nudges the label one pixel down while the button is held.
local RECIPES = {
    -- Secondary, the default: a field with a rim that turns accent on hover.
    button = { fill = "field", rim = "rim", label = "text", hoverRim = "primary", press = true,
        selectedFill = "accentFill", selectedRim = "primary", selectedLabel = "primary" },
    primary = { fill = "primary", label = "ink", hoverAlpha = 0.86, press = true },
    -- Quiet (ghost): text only.
    quiet = { label = "muted", hoverLabel = "text", selectedLabel = "primary", press = true },
    -- A standalone choice (anchor picker cells, preview modes).
    choice = { fill = "field", rim = "rim", label = "muted", hoverLabel = "text", hoverRim = "trackRim", press = true,
        selectedFill = "accentFill", selectedRim = "primary", selectedLabel = "primary" },
    -- One segment of W.Exclusive: transparent until chosen.
    segment = { label = "muted", hoverLabel = "text",
        selectedFill = "accentFill", selectedRim = "primary", selectedLabel = "primary" },
    -- Sidebar and menu rows: a quiet fill, and an accent bar on the left edge when chosen.
    tab = { label = "secondary", hoverFill = "navSelected", hoverLabel = "text", square = true,
        selectedFill = "navSelected", selectedLabel = "text", edge = "left" },
    -- Section tabs: text, with a 2 px accent underline when chosen.
    underline = { label = "muted", hoverLabel = "text", selectedLabel = "text", edge = "bottom", size = "section" },
    -- Sidebar captions.
    categoryHeading = { label = "faint", hoverLabel = "secondary", size = "group", weight = "heading" },
}
RECIPES.secondary, RECIPES.row, RECIPES.ghost = RECIPES.button, RECIPES.button, RECIPES.quiet
RECIPES.roundedTab, RECIPES.subTab = RECIPES.underline, RECIPES.choice
W.ButtonRecipes = RECIPES

-- Moves the label's anchors one pixel down (or back up).
local function Nudge(button, down)
    if (button.labelNudged or false) == down then return end
    button.labelNudged = down
    local label, points = button.label, {}
    for i = 1, label:GetNumPoints() do points[i] = { label:GetPoint(i) } end
    label:ClearAllPoints()
    for _, p in ipairs(points) do label:SetPoint(p[1], p[2] or button, p[3] or p[1], p[4] or 0, (p[5] or 0) + (down and -1 or 1)) end
end

-- style: a RECIPES key (default "button"); "toggle" and "checkbox" are switches.
function W.Button(parent, text, width, height, style)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 120, height or 28)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp")
    style = style or "button"
    button.skinStyle = style
    if style == "toggle" or style == "checkbox" then
        if style=="checkbox" and parent.row then parent.row.settingsStandaloneToggle=button end
        return W.Switch(button, text, height, style)
    end
    local recipe = RECIPES[style] or RECIPES.button
    button.box = W.Box(button, not recipe.square and "ModeFlat" or nil, "BACKGROUND")
    button.fill = button.box.fill
    if recipe.edge then
        local edge = W.Shape(button, nil, "OVERLAY")
        edge:SetVertexColor(unpack(T.primary))
        if recipe.edge == "left" then
            edge.leftEdge = true
            edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT"); edge:SetWidth(2)
        end
        edge:Hide()
        button.selectionEdge = edge
    end
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    addon.Media:BindInterfaceFont(button.label, GameFontHighlight, T.fontSize[recipe.size or "body"], nil, recipe.weight)
    W.CrispText(button.label)
    function button:RefreshAppearance()
        local available = self:IsEnabled()
        local hovered = available and self.hovered
        local selected = available and self.selected == true
        local fill, rim, label = recipe.fill, recipe.rim, recipe.label
        if selected then
            fill, rim, label = recipe.selectedFill or fill, recipe.selectedRim or rim, recipe.selectedLabel or label
        elseif hovered then
            fill, rim, label = recipe.hoverFill or fill, recipe.hoverRim or rim, recipe.hoverLabel or label
        end
        local color = self.labelColor or T[label]
        if not available then
            if style == "primary" then fill, rim = "field", "rim" end
            color = T.unavailable
        end
        self.box:SetColors(T[fill], T[rim], hovered and recipe.hoverAlpha or nil)
        self.label:SetTextColor(color[1], color[2], color[3], color[4] or 1)
        if self.selectionEdge then
            if not self.selectionEdge.leftEdge then W.AlignTextLine(self, self.selectionEdge) end
            self.selectionEdge:SetShown(selected)
        end
        Nudge(self, recipe.press and hovered and self.pressed or false)
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
    if recipe.edge == "bottom" then
        addon.Media:RegisterFontListener(button,function(owner) W.AlignTextLine(owner,owner.selectionEdge) end)
        button:HookScript("OnSizeChanged",function(owner) W.AlignTextLine(owner,owner.selectionEdge) end)
    end
    button:RefreshAppearance()
    return button
end
