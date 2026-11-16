local _, addon = ...
local Skin, Kit = addon.Skin, addon.Kit

-- More of Blizzard's shared pieces in the Mode look (Forever's
-- Blizzard_Menu, SharedUIPanelTemplates and ScrollBox):
--   Dropdown      WowStyle1/2DropdownTemplate: its Background and Arrow
--                 faded; a Graphite field in the `control` edge with a chevron, Ivory on hover. The
--                 legacy UIDropDownMenuTemplate gets the same field over its
--                 Left/Middle/Right art. The menu a WowStyle dropdown opens is
--                 dressed too (Skin.Menu).
--   RightSideTab  RightSideTabTemplate (the Guild window's Chat, Roster,
--                 Benefits and Info tabs): its art faded, the icon cropped
--                 on a `control` box, Ivory when checked.
--   MaxMin        MaximizeMinimizeButtonFrameTemplate: both buttons as Mode
--                 glyph buttons beside the close button.
--   Lists         rows in a ScrollBox are made and filled by Blizzard as you
--                 scroll; each one gets the Mode face (and, where a window
--                 asks, its row strip faded) when Blizzard initializes it.
--   Texts         every font string in a window in the Mode face, at the
--                 game's own sizes and outlines.
-- All plain widget calls, post-hooks and callback registrations; nothing is
-- written to Blizzard's tables.
local M, Style = Skin.mode, addon.Style
local Snap, Fade = Skin.Snap, Skin.Fade
local TEXT_DEPTH = 8

local function FadeStates(button)
    if not button then return end
    for _, key in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture", "GetCheckedTexture" }) do
        if button[key] then Fade(button[key](button)) end
    end
end
local function Public(value) return addon.IsPublic(value) and value end

-- Dropdowns ------------------------------------------------------------------

function Skin.Dropdown(dropdown, style)
    local legacy = dropdown.Button ~= nil and dropdown.Arrow == nil
    if legacy then
        for _, key in ipairs({ "Left", "Middle", "Right" }) do Fade(dropdown[key]) end
        FadeStates(dropdown.Button)
    else
        Fade(dropdown.Background); Fade(dropdown.Arrow)
    end
    local parts = Skin.Box(dropdown, "control")
    local px = Kit.PixelSize(dropdown)
    parts.px = px
    if not parts.box then
        parts.box = dropdown:CreateTexture(nil, "BACKGROUND", nil, -8)
        parts.box:SetAlpha(0)
        parts.chevron = dropdown:CreateTexture(nil, "OVERLAY", nil, 7)
        addon.Media:ApplyTexture(parts.chevron, "ModeChevron")
        parts.regions[parts.box], parts.regions[parts.chevron] = true, true
        local hover = legacy and dropdown.Button or dropdown
        hover:HookScript("OnEnter", function() parts.hovered = true; Skin.PaintDropdown(dropdown) end)
        hover:HookScript("OnLeave", function() parts.hovered = false; Skin.PaintDropdown(dropdown) end)
        Skin.WatchMenu(dropdown)
    end
    -- The legacy template's art reaches 16 px past the visible field.
    local x, top, bottom = legacy and Snap(17, px) or 0, legacy and Snap(4, px) or 0, legacy and Snap(6, px) or 0
    parts.box:ClearAllPoints()
    parts.box:SetPoint("TOPLEFT", dropdown, "TOPLEFT", x, -top)
    parts.box:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", -x, bottom)
    local size = Snap(16, px)
    parts.chevron:ClearAllPoints(); parts.chevron:SetPoint("RIGHT", parts.box, "RIGHT", -Snap(4, px), 0)
    parts.chevron:SetSize(size, size)
    local text = dropdown.Text
    if text and style then Skin.Font(text, style.path, nil, style.outline, style.shadow, px) end
    Skin.PaintDropdown(dropdown)
end

function Skin.PaintDropdown(dropdown)
    local parts = Skin.parts[dropdown]
    if not parts or not parts.box then return end
    local open = dropdown.IsMenuOpen and Public(dropdown:IsMenuOpen()) == true
    local lit = parts.hovered or open
    Skin.PaintBox(parts, parts.box, "Solid", M.field, 1, true, lit and "accent" or nil)
    Style.Paint(parts.chevron, lit and M.accent or M.label)
end

-- The menu a skinned WowStyle dropdown opens: its one background texture is
-- faded (the menu pool restores it on release) and a Mode panel shown under
-- the entries. Menu frames are pooled across every menu in the game, so the
-- panel is ModeUI's own frame, lent to this menu and taken back on close.
local menuPanel
local function MenuPanel()
    if menuPanel then return menuPanel end
    menuPanel = CreateFrame("Frame")
    menuPanel:EnableMouse(false)
    menuPanel.parts = Skin.Box(menuPanel, "window")
    menuPanel:Hide()
    return menuPanel
end

function Skin.Menu(menu)
    if not menu or not menu.GetRegions then return end
    local ok, background = pcall(menu.GetRegions, menu)
    if ok and background and background.GetAtlas then
        local atlas = background:GetAtlas()
        if Public(atlas) and tostring(atlas):find("dropdown", 1, true) then background:SetAlpha(0) end
    end
    local panel = MenuPanel()
    panel:SetParent(menu)
    panel:ClearAllPoints()
    local px = Kit.PixelSize(menu)
    panel:SetPoint("TOPLEFT", menu, "TOPLEFT", -Snap(4, px), Snap(3, px))
    panel:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", Snap(4, px), -Snap(3, px))
    local level = menu:GetFrameLevel()
    if Public(level) then panel:SetFrameLevel(level + 1) end
    -- A Mode window: Graphite panel in the `window` edge.
    Skin.PaintBox(panel.parts, panel, "Panel", M.panel, 1, true)
    panel.menu = menu
    panel:Show()
end
function Skin.MenuClosed(menu)
    if menuPanel and (menu == nil or menuPanel.menu == menu) then
        menuPanel:Hide(); menuPanel:SetParent(UIParent); menuPanel.menu = nil
    end
end

-- WowStyle dropdowns fire OnMenuOpen/OnMenuClose through their callback
-- registry (DropdownButtonMixin.Event); legacy ones have no menu frame to dress.
function Skin.WatchMenu(dropdown)
    local events = DropdownButtonMixin and DropdownButtonMixin.Event
    if not (events and events.OnMenuOpen and dropdown.RegisterCallback) then return end
    local owner = Skin.parts[dropdown]
    pcall(dropdown.RegisterCallback, dropdown, events.OnMenuOpen, function()
        Skin.Menu(dropdown.menu); Skin.PaintDropdown(dropdown)
    end, owner)
    pcall(dropdown.RegisterCallback, dropdown, events.OnMenuClose, function(_, _, menu)
        Skin.MenuClosed(menu); Skin.PaintDropdown(dropdown)
    end, owner)
end

-- Right side tabs --------------------------------------------------------------

function Skin.RightSideTab(tab)
    local keep = {}
    if tab.Icon then keep[tab.Icon] = true end
    if tab.IconOverlay then keep[tab.IconOverlay] = true end
    Skin.FadeTextures(tab, keep)
    FadeStates(tab)
    local parts = Skin.Box(tab, "control")
    local px = Kit.PixelSize(tab)
    parts.px = px
    if tab.Icon then
        local inset = Snap(3, px)
        tab.Icon:ClearAllPoints()
        tab.Icon:SetPoint("TOPLEFT", tab, "TOPLEFT", inset, -inset)
        tab.Icon:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -inset, inset)
        if not parts.iconCoords then
            local ulx, uly, llx, lly, urx, ury, lrx, lry = tab.Icon:GetTexCoord()
            local ok = addon.IsNumber(ulx) and addon.IsNumber(uly) and addon.IsNumber(lry) and addon.IsNumber(urx)
            parts.iconCoords = ok and { ulx, urx, uly, lly or lry } or { 0, 1, 0, 1 }
        end
        local c = parts.iconCoords
        local dx, dy = (c[2] - c[1]) * 0.08, (c[4] - c[3]) * 0.08
        tab.Icon:SetTexCoord(c[1] + dx, c[2] - dx, c[3] + dy, c[4] - dy)
    end
    Skin.Once(tab, "rightSideTab", function()
        if tab.SetChecked then hooksecurefunc(tab, "SetChecked", function() Skin.PaintSideTab(tab) end) end
        tab:HookScript("OnClick", function() Skin.PaintSideTab(tab) end)
        tab:HookScript("OnShow", function() Skin.PaintSideTab(tab) end)
        tab:HookScript("OnEnter", function() parts.hovered = true; Skin.PaintSideTab(tab) end)
        tab:HookScript("OnLeave", function() parts.hovered = false; Skin.PaintSideTab(tab) end)
    end)
    Skin.PaintSideTab(tab)
end

-- Maximize / minimize -----------------------------------------------------------

-- The pair's holder: whichever key the window gave it.
function Skin.MaxMinOf(frame)
    local holder = frame.MaximizeMinimizeFrame or frame.MaxMinButtonFrame
    if holder and holder.MaximizeButton and holder.MinimizeButton then return holder end
    return nil
end

-- Both buttons as glyph buttons the close button's size, the holder one
-- Close Inset left of the close button. Anchoring: the caller checks combat.
function Skin.MaxMin(holder, close)
    local px = Kit.PixelSize(holder)
    local size = Snap(Skin.CLOSE_SIZE, px)
    for key, glyph in pairs({ MaximizeButton = "ModeMaximize", MinimizeButton = "ModeMinimize" }) do
        local button = holder[key]
        Skin.GlyphButton(button, glyph)
        button:ClearAllPoints(); button:SetPoint("CENTER", holder, "CENTER", 0, 0)
        button:SetSize(size, size)
    end
    holder:SetSize(size, size)
    if close then
        holder:ClearAllPoints()
        holder:SetPoint("RIGHT", close, "LEFT", -Snap(Skin.CLOSE_INSET, px), 0)
    end
end

-- Text ----------------------------------------------------------------------------

-- Dark text Blizzard draws for its parchment (quest, gossip, book and letter
-- text in dark brown or black) is lost on Graphite: such a font string takes
-- the Graphite text color, now and whenever Blizzard sets a dark color again
-- (quest pages set theirs in code each time they show). Any color with light
-- in it stays, and text colored inline (|c codes) keeps its codes.
local DARK = 0.35
local inking = setmetatable({}, { __mode = "k" })
local function Dark(r, g, b)
    local Number = addon.IsNumber
    return Number(r) and Number(g) and Number(b) and (0.299 * r + 0.587 * g + 0.114 * b) < DARK
end
local function Check(text)
    if inking[text] or not text.GetTextColor then return end
    local r, g, b = text:GetTextColor()
    if not Dark(r, g, b) then return end
    inking[text] = true
    Skin.Ink(text, M.text)
    inking[text] = nil
end
function Skin.Readable(text)
    if not text or not text.SetTextColor then return end
    Skin.Once(text, "readable", function()
        hooksecurefunc(text, "SetTextColor", Check)
        if text.SetFontObject then hooksecurefunc(text, "SetFontObject", Check) end
    end)
    Check(text)
end

-- Every font string on `frame` and its children (TEXT_DEPTH levels) in the
-- Mode face, except ModeUI's own and those in `skip`.
function Skin.Texts(frame, path, skip, depth)
    depth = depth or 0
    if depth > TEXT_DEPTH or not frame or not frame.GetRegions then return end
    if frame.IsForbidden and frame:IsForbidden() then return end
    local own = Skin.parts[frame]
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "FontString" and not (skip and skip[region])
            and not (own and own.regions and own.regions[region]) then
            Skin.Face(region, path)
            Skin.Readable(region)
        end
    end
    if frame.GetFontString then
        local text = frame:GetFontString()
        if text and not (skip and skip[text]) then Skin.Face(text, path); Skin.Readable(text) end
    end
    if frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do Skin.Texts(child, path, skip, depth + 1) end
    end
end

-- Lists -------------------------------------------------------------------------

-- A ScrollBox: `onRow(row)` runs on every row now and on each row Blizzard
-- initializes later (ScrollUtil.AddInitializedFrameCallback, run through the
-- box's callback registry). Registered once per box.
function Skin.IsScrollBox(frame)
    return frame.RegisterCallback ~= nil and frame.ForEachFrame ~= nil and frame.GetFrames ~= nil
end
Skin.lists = setmetatable({}, { __mode = "k" })
function Skin.WatchList(box, onRow)
    Skin.lists[box] = onRow
    Skin.Once(box, "list", function()
        local function Run(_, row) local fn = Skin.lists[box]; if fn and row then fn(row) end end
        if ScrollUtil and ScrollUtil.AddInitializedFrameCallback then
            pcall(ScrollUtil.AddInitializedFrameCallback, box, Run, Skin.lists, false)
        end
    end)
    pcall(box.ForEachFrame, box, function(row) onRow(row) end)
end

-- A list row: the Mode face on its text and, with `fadeRows`, its row strip
-- (the button's normal texture) faded so the window's fill shows through.
function Skin.Row(row, style, fadeRows)
    if fadeRows and row.GetNormalTexture then Fade(row:GetNormalTexture()) end
    -- The Guild roster's brown profession header strip.
    local header = fadeRows and row.ProfessionHeader
    if header then for _, key in ipairs({ "Left", "Middle", "Right" }) do Fade(header[key]) end end
    if style.bodyFont then Skin.Texts(row, style.path) end
end
