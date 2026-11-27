local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M then return end

-- The glow popout: a spell menu row's > opens it beside the menu (on its
-- left, so the preview stays in view) to set that glow's look for that
-- spell: on or off; Style (Mode Glow, Border, Pixel, Blizzard, GCD); Color
-- (Blizzard's color picker); Pulse (Mode Glow and Border); Lines and
-- Thickness (Pixel); and for the off-cooldown glow, When (Flash or While
-- Ready) and Glow Time. Changing the look switches the glow on. It closes
-- with the menu, its > again, or its close button; while it's open the
-- preview shows that glow on the spell.
local W, T, L, Kit = addon.ConfigWidgets, addon.InterfaceTheme, addon.L, addon.Kit
local WIDTH, PAD = 300, 14
local INNER = WIDTH - 2 * PAD
local SHORT = { mode = "Mode", border = "Border", pixel = "Pixel", blizzard = "Blizzard", gcd = "GCD" }
local STYLE_WIDTHS = { mode = 50, border = 56, pixel = 46, blizzard = 62, gcd = 42 }

-- The spell and glow the popout edits now.
local function Target(popout)
    local menu = M.spellMenu
    if not menu or not menu:IsShown() or not menu.key then return end
    return M:PreviewViewer(), menu.key, popout.kind
end
local function Look(popout)
    local id, key, kind = Target(popout)
    if not id then return nil end
    return M:SpellGlow(id, key, kind) or M:GlowDefaults(id, kind)
end
local function Set(popout, field, value)
    local id, key, kind = Target(popout)
    if id then M:SetSpellGlow(id, key, kind, field, value); M:RefreshSpellMenu() end
end

-- A labeled row on the popout: a host frame below its label.
local function Row(popout, label, height)
    local row = CreateFrame("Frame", nil, popout)
    row:SetSize(INNER, height + 18)
    row.label = W.Label(row, label, nil, 0, 0, INNER, T.muted)
    row.host = CreateFrame("Frame", nil, row)
    row.host:SetPoint("TOPLEFT", 0, -18); row.host:SetSize(INNER, height)
    popout.rows[#popout.rows + 1] = row
    return row
end

local function Slider(popout, label, field, range, suffix)
    local row = Row(popout, label, 24)
    local refresh = W.Slider(row.host, range[1], range[2], range[3], function() local look = Look(popout); return look and look[field] or range[1] end,
        function(value) Set(popout, field, math.floor(value + 0.5)) end, suffix)
    row.refresh = refresh
    return row
end

-- The color swatch opens Blizzard's color picker; the color applies live.
local function OpenPicker(popout)
    local picker = _G.ColorPickerFrame
    local look = Look(popout)
    if not picker or not look or not picker.SetupColorPickerAndShow or addon.InCombat() then return end
    local id, key, kind = Target(popout)
    local before = { look.color[1], look.color[2], look.color[3] }
    local apply = W.Throttle(function(rgb) M:SetSpellGlow(id, key, kind, "color", rgb); M:RefreshSpellMenu() end)
    picker:SetupColorPickerAndShow({ r = before[1], g = before[2], b = before[3], hasOpacity = false,
        swatchFunc = function() local r, g, b = picker:GetColorRGB(); apply({ r, g, b }) end,
        cancelFunc = function() M:SetSpellGlow(id, key, kind, "color", before); M:RefreshSpellMenu() end })
end

function M:GlowPopout()
    if self.glowPopout then return self.glowPopout end
    local popout = CreateFrame("Frame", "ModeUICooldownGlowPopout", UIParent)
    popout:SetSize(WIDTH, 200); popout:SetFrameStrata("TOOLTIP"); popout:SetFrameLevel(210)
    popout:SetClampedToScreen(true); popout:EnableMouse(true); popout:Hide()
    W.Texture(popout, "Window"); W.Texture(popout, "BorderSilver", "BORDER")
    popout.rows = {}
    popout.title = W.Label(popout, "", nil, PAD, -12, INNER - 34, T.secondary)
    popout.spell = W.Label(popout, "", nil, PAD, -30, INNER - 34, T.muted)
    popout.close = W.Button(popout, "X", 24, 24, "secondary")
    popout.close:SetPoint("TOPRIGHT", -10, -8)
    popout.close:SetScript("OnClick", function() popout:Hide() end)
    -- On or off for this spell.
    popout.onBox = W.Button(popout, "", 24, 24, "checkbox")
    popout.onText = W.Label(popout, L["Glow On"], nil, 0, 0, INNER - popout.onBox:GetWidth() - 8, T.text)
    popout.onBox:SetScript("OnClick", function()
        local id, key, kind = Target(popout)
        if id then M:SetSpellSwitch(id, key, kind, not M:SpellSwitch(id, key, kind)); M:RefreshSpellMenu() end
    end)
    local styles = {}
    for _, item in ipairs(M.glowStyles) do styles[#styles + 1] = { label = L[SHORT[item.id]], value = item.id, width = STYLE_WIDTHS[item.id] } end
    popout.styleRow = Row(popout, L["Style"], 28)
    popout.styleButtons, popout.styleRow.refresh = W.Exclusive(popout.styleRow.host, styles,
        function() local look = Look(popout); return look and look.style end, function(value) Set(popout, "style", value) end)
    popout.colorRow = Row(popout, L["Color"], 24)
    popout.swatch = W.Button(popout.colorRow.host, "", 72, 24, "secondary")
    popout.swatch:SetPoint("LEFT")
    popout.swatch.fill = popout.swatch:CreateTexture(nil, "OVERLAY")
    popout.swatch.fill:SetPoint("TOPLEFT", 4, -4); popout.swatch.fill:SetPoint("BOTTOMRIGHT", -4, 4); popout.swatch.fill:SetTexture(Kit.FLAT)
    popout.swatch:SetScript("OnClick", function() OpenPicker(popout) end)
    popout.pulseRow = Row(popout, L["Pulse"], 24)
    popout.pulseBox = W.Button(popout.pulseRow.host, "", 24, 24, "checkbox")
    popout.pulseBox:SetPoint("LEFT")
    popout.pulseBox:SetScript("OnClick", function() local look = Look(popout); if look then Set(popout, "pulse", not look.pulse) end end)
    popout.linesRow = Slider(popout, L["Lines"], "lines", M.glowRanges.lines)
    popout.thicknessRow = Slider(popout, L["Thickness"], "thickness", M.glowRanges.thickness, "px")
    popout.whenRow = Row(popout, L["When"], 28)
    local whens = {}
    for _, item in ipairs(M.choices.readyMode) do whens[#whens + 1] = { label = L[item.label], value = item.id, width = 110 } end
    popout.whenButtons, popout.whenRow.refresh = W.Exclusive(popout.whenRow.host, whens,
        function() local look = Look(popout); return look and look.mode end, function(value) Set(popout, "mode", value) end)
    popout.timeRow = Slider(popout, L["Glow Time"], "duration", M.glowRanges.duration, "s")
    popout:SetScript("OnHide", function()
        local view = M.previewView
        popout.kind = nil
        if view then view.glowKind = nil; view.Refresh() end
        M:RefreshSpellMenu()
    end)
    self.glowPopout = popout
    return popout
end

-- Opens the popout for a glow beside the menu, or closes it when it's open
-- on that glow already.
function M:ToggleGlowPopout(kind, button)
    local popout = self:GlowPopout()
    if popout:IsShown() and popout.kind == kind then popout:Hide(); return end
    -- One popout at a time.
    if self.textPopout then self.textPopout:Hide() end
    local menu = self.spellMenu
    popout.kind = kind
    popout:SetScale(menu:GetScale())
    popout:ClearAllPoints()
    popout:SetPoint("TOPRIGHT", menu, "TOPLEFT", -6, 0)
    popout:Show()
    if self.previewView then self.previewView.glowKind = kind; self.previewView.Refresh() end
    self:RefreshSpellMenu()
end

-- Brings the popout up to date with the spell's glow, showing the rows
-- its style uses.
function M:RefreshGlowPopout()
    local popout = self.glowPopout
    if not popout or not popout:IsShown() then return end
    local id, key, kind = Target(popout)
    if not id then popout:Hide(); return end
    local look = Look(popout)
    popout.title:SetText(L[self.glowLabels[kind]])
    popout.spell:SetText(self:SpellLabel(key))
    local on = self:SpellSwitch(id, key, kind)
    popout.onBox:SetSelected(on)
    popout.swatch.fill:SetVertexColor(look.color[1], look.color[2], look.color[3], 1)
    popout.pulseBox:SetSelected(look.pulse)
    local y = -54
    popout.onBox:ClearAllPoints(); popout.onBox:SetPoint("TOPLEFT", PAD, y)
    -- Right of the switch (W.Switch widens the box to fit).
    popout.onText:ClearAllPoints(); popout.onText:SetPoint("LEFT", popout.onBox, "RIGHT", 8, 0)
    y = y - 34
    local shown = { [popout.styleRow] = true, [popout.colorRow] = true,
        [popout.pulseRow] = look.style == "mode" or look.style == "border",
        [popout.linesRow] = look.style == "pixel", [popout.thicknessRow] = look.style == "pixel",
        [popout.whenRow] = kind == "ready", [popout.timeRow] = kind == "ready" and look.mode == "flash" }
    for _, row in ipairs(popout.rows) do
        row:SetShown(shown[row] == true)
        if shown[row] then
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", PAD, y)
            if row.refresh then row.refresh() end
            y = y - row:GetHeight() - 8
        end
    end
    popout:SetHeight(-y + 8)
end
