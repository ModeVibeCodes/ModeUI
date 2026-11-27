local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M then return end

-- The text popout: a spell menu Text row's > opens it beside the menu (on
-- its left, like the glow popout, which it replaces) to give that spell its
-- own look for that text: Show This Text, Text Shadow, Font, Size, Color
-- (Blizzard's color picker), Outline (None, Outline, Thick), Anchor and
-- Offset X and Y. The first change copies the bar's look (the Text tab) and
-- changes it; Use Bar's Look goes back. It closes with the menu, its >
-- again, or its close button; while it's open the preview shows that text
-- on the spell (a sample cooldown, a sample count).
local W, T, L, Kit = addon.ConfigWidgets, addon.InterfaceTheme, addon.L, addon.Kit
local WIDTH, PAD = 300, 14
local INNER = WIDTH - 2 * PAD

-- The spell and text the popout edits now, and its look (own or the bar's).
local function Target(popout)
    local menu = M.spellMenu
    if not menu or not menu:IsShown() or not menu.key then return end
    return M:PreviewViewer(), menu.key, popout.part
end
local function Look(popout)
    local id, key, part = Target(popout)
    if not id then return nil end
    return M:SpellText(id, key, part) or M:TextDefaults(id, part)
end
local function Set(popout, field, value)
    local id, key, part = Target(popout)
    if id then M:SetSpellText(id, key, part, field, value); M:RefreshSpellMenu() end
end

local function Row(popout, label, height)
    local row = CreateFrame("Frame", nil, popout)
    row:SetSize(INNER, height + 18)
    row.label = W.Label(row, label, nil, 0, 0, INNER, T.muted)
    row.host = CreateFrame("Frame", nil, row)
    row.host:SetPoint("TOPLEFT", 0, -18); row.host:SetSize(INNER, height)
    popout.rows[#popout.rows + 1] = row
    return row
end

local function Slider(popout, label, field, suffix)
    local row = Row(popout, label, 24)
    row.refresh = W.Slider(row.host, -40, 40, 1, function() local look = Look(popout); return look and look[field] or 0 end,
        function(value) Set(popout, field, math.floor(value + 0.5)) end, suffix)
    row.field = field
    return row
end

-- A checkbox line for a true-or-false field.
local function Check(popout, label, field)
    local box = W.Button(popout, "", 24, 24, "checkbox")
    box.text = W.Label(popout, label, nil, 0, 0, INNER - box:GetWidth() - 8, T.text)
    box:SetScript("OnClick", function() local look = Look(popout); if look then Set(popout, field, not look[field]) end end)
    box.field = field
    return box
end

local function OpenColor(popout)
    local picker = _G.ColorPickerFrame
    local look = Look(popout)
    if not picker or not look then return end
    local id, key, part = Target(popout)
    local before = { look.color[1], look.color[2], look.color[3] }
    local apply = W.Throttle(function(rgb) M:SetSpellText(id, key, part, "color", rgb); M:RefreshSpellMenu() end)
    M:OpenColorPicker(popout, { r = before[1], g = before[2], b = before[3], hasOpacity = false,
        swatchFunc = function() local r, g, b = picker:GetColorRGB(); apply({ r, g, b }) end,
        cancelFunc = function() M:SetSpellText(id, key, part, "color", before); M:RefreshSpellMenu() end })
end

-- The shared font list reads and writes the spell's own font.
local function FontOwner(popout)
    local appearance = setmetatable({}, { __index = function(_, key) local look = Look(popout); return look and look[key] end })
    local owner = { db = { appearance = appearance } }
    function owner.CanConfigure() return M:CanConfigure() end
    function owner.GetFonts() return addon.Media:GetFonts() end
    function owner.SetAppearance(_, key, value) if key == "font" or key == "fontMedia" then Set(popout, key, value) end end
    return owner
end

function M:TextPopout()
    if self.textPopout then return self.textPopout end
    local popout = CreateFrame("Frame", "ModeUICooldownTextPopout", UIParent)
    popout:SetSize(WIDTH, 200); popout:SetFrameStrata("TOOLTIP"); popout:SetFrameLevel(210)
    popout:SetClampedToScreen(true); popout:EnableMouse(true); popout:Hide()
    W.Texture(popout, "Window"); W.Texture(popout, "BorderSilver", "BORDER")
    popout.rows = {}
    popout.title = W.Label(popout, "", nil, PAD, -12, INNER - 34, T.secondary)
    popout.spell = W.Label(popout, "", nil, PAD, -30, INNER - 34, T.muted)
    popout.close = W.Button(popout, "X", 24, 24, "secondary")
    popout.close:SetPoint("TOPRIGHT", -10, -8)
    popout.close:SetScript("OnClick", function() popout:Hide() end)
    popout.showBox = Check(popout, L["Show This Text"], "show")
    popout.shadowBox = Check(popout, L["Text Shadow"], "shadow")
    popout.fontRow = Row(popout, L["Font"], 28)
    popout.font, popout.fontRow.refresh = W.FontDropdown(popout.fontRow.host, FontOwner(popout))
    popout.sizeRow = Row(popout, L["Size"], 24)
    local range = M.ranges.cooldownSize
    popout.sizeRow.refresh = W.Slider(popout.sizeRow.host, range[1], range[2], range[3],
        function() local look = Look(popout); return look and look.size or range[1] end,
        function(value) Set(popout, "size", math.floor(value + 0.5)) end)
    popout.colorRow = Row(popout, L["Color"], 24)
    popout.swatch = W.Button(popout.colorRow.host, "", 72, 24, "secondary")
    popout.swatch:SetPoint("LEFT")
    popout.swatch.fill = popout.swatch:CreateTexture(nil, "OVERLAY")
    popout.swatch.fill:SetPoint("TOPLEFT", 4, -4); popout.swatch.fill:SetPoint("BOTTOMRIGHT", -4, 4); popout.swatch.fill:SetTexture(Kit.FLAT)
    popout.swatch:SetScript("OnClick", function() OpenColor(popout) end)
    popout.outlineRow = Row(popout, L["Outline"], 28)
    local outlines = {}
    for _, item in ipairs(M.outlineChoices) do outlines[#outlines + 1] = { label = L[item.label], value = item.id, width = 80 } end
    popout.outlineButtons, popout.outlineRow.refresh = W.Exclusive(popout.outlineRow.host, outlines,
        function() local look = Look(popout); return look and look.outline end, function(value) Set(popout, "outline", value) end)
    popout.anchorRow = Row(popout, L["Anchor"], W.ANCHOR_PICKER_HEIGHT)
    local labels = setmetatable({}, { __index = function(_, key) return L[M.anchorLabels[key] or key] end })
    popout.anchorButtons, popout.anchorRow.refresh = W.AnchorPicker(popout.anchorRow.host,
        function() local look = Look(popout); return look and look.anchor end, function(value) Set(popout, "anchor", value) end,
        labels, { center = true })
    popout.xRow = Slider(popout, L["Offset X"], "x", "px")
    popout.yRow = Slider(popout, L["Offset Y"], "y", "px")
    popout.reset = W.Button(popout, L["Use Bar's Look"], INNER, 26, "secondary")
    popout.reset:SetScript("OnClick", function()
        local id, key, part = Target(popout)
        if id then M:ResetSpellText(id, key, part); M:RefreshSpellMenu() end
    end)
    popout:SetScript("OnHide", function()
        local view = M.previewView
        popout.part = nil
        if addon.CloseFontDropdown then addon:CloseFontDropdown() end
        if view then view.textPart = nil; view.Refresh() end
        M:RefreshSpellMenu()
    end)
    self.textPopout = popout
    return popout
end

-- Opens the popout for a text beside the menu, or closes it when it's open
-- on that text already.
function M:ToggleTextPopout(part, button)
    local popout = self:TextPopout()
    if popout:IsShown() and popout.part == part then popout:Hide(); return end
    if self.glowPopout then self.glowPopout:Hide() end
    local menu = self.spellMenu
    popout.part = part
    popout:SetScale(menu:GetScale())
    popout:ClearAllPoints()
    popout:SetPoint("TOPRIGHT", menu, "TOPLEFT", -6, 0)
    popout:Show()
    if self.previewView then self.previewView.textPart = part; self.previewView.Refresh() end
    self:RefreshSpellMenu()
end

-- Brings the popout up to date with the spell's text look.
function M:RefreshTextPopout()
    local popout = self.textPopout
    if not popout or not popout:IsShown() then return end
    local id, key, part = Target(popout)
    local parts = {}
    for _, p in ipairs(id and self:Parts(id) or {}) do parts[p] = true end
    if not id or not parts[part] then popout:Hide(); return end
    local look = Look(popout)
    local own = self:SpellText(id, key, part) ~= nil
    popout.title:SetText(string.format(L["%s Text"], L[self.textPartLabels[part]]))
    popout.spell:SetText(self:SpellLabel(key) .. " · " .. (own and L["own look"] or L["bar's look"]))
    popout.swatch.fill:SetVertexColor(look.color[1], look.color[2], look.color[3], 1)
    local y = -54
    for _, box in ipairs({ popout.showBox, popout.shadowBox }) do
        box:SetSelected(look[box.field] == true)
        box:ClearAllPoints(); box:SetPoint("TOPLEFT", PAD, y)
        -- Right of the switch (W.Switch widens the box to fit).
        box.text:ClearAllPoints(); box.text:SetPoint("LEFT", box, "RIGHT", 8, 0)
        y = y - 30
    end
    y = y - 4
    for _, row in ipairs(popout.rows) do
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", PAD, y)
        if row.refresh then row.refresh() end
        y = y - row:GetHeight() - 8
    end
    popout.reset:ClearAllPoints(); popout.reset:SetPoint("TOPLEFT", PAD, y)
    popout.reset:SetEnabled(own)
    popout:SetHeight(-y + 40)
end
