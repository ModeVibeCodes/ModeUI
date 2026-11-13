local _, addon = ...
local Skin, Kit = addon.Skin, addon.Kit

-- Blizzard's shared controls in the Mode look, each recognised by the keys
-- its template gives it (Forever's SharedUIPanelTemplates, TabSystem,
-- MinimalScrollBar and WowTrimScrollBar):
--   Button       Left/Middle/Right art (UIPanelButtonTemplate): a field whose
--                rim turns cyan on hover
--   Field        an edit box with Left/Middle/Right art (InputBoxTemplate,
--                SearchBoxTemplate): a field whose rim turns cyan with focus
--   Tab          LeftActive/MiddleActive/RightActive (PanelTabButtonTemplate,
--                TabSystemButtonTemplate): a field; the selected tab is the
--                lighter segment with a two-pixel cyan bar on its window side
--   SideTab      SelectedTexture + Icon + Background (LargeSideTabButton):
--                a field around the icon, cyan rim when checked
--   RightSideTab Icon + a checked texture, no Background (RightSideTabTemplate:
--                Guild's Chat, Roster, Benefits and Info tabs): as SideTab
--   Dropdown     WowStyle1/2DropdownTemplate (Background + Arrow) or the legacy
--                UIDropDownMenuTemplate (Left/Middle/Right + Button): a field
--                with a chevron (Extras.lua)
--   Close        the close button: a field with a thin cross
--   ScrollBar    Track.Thumb + Back/Forward: a slim track and thumb
--   Inset        an inset frame's NineSlice and Bg: a darker field
-- Blizzard re-sets these textures' atlases on state changes but never their
-- alpha, so faded art stays faded. `style` carries the colors and font:
-- { path, size, outline, shadow } plus Skin.colors.
local C = Skin.colors
local Snap, Fade = Skin.Snap, Skin.Fade
local BUTTON_ART = { "Left", "Middle", "Right", "LeftDisabled", "MiddleDisabled", "RightDisabled" }
local TAB_ART = { "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive",
    "LeftHighlight", "MiddleHighlight", "RightHighlight", "LeftDisabled", "MiddleDisabled", "RightDisabled" }
local NINE = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center" }

local function Public(value) return addon.IsPublic(value) and value end
local function Shown(region)
    if not region or not region.IsShown then return false end
    return Public(region:IsShown()) == true
end
local function FadeStates(button)
    for _, key in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
        if button[key] then Fade(button[key](button)) end
    end
end
local function Text(button) return button.Text or (button.GetFontString and button:GetFontString()) end

-- A NineSlice's pieces faded one by one, so text kept on it (the Settings
-- panel's title) stays.
function Skin.FadeNineSlice(nine)
    if not nine then return end
    for _, key in ipairs(NINE) do Fade(nine[key]) end
end

-- What kind of control a frame is, from its template's keys; nil if none.
function Skin.Kind(frame)
    if not frame or not frame.GetObjectType then return nil end
    local kind = frame:GetObjectType()
    if (kind == "EventFrame" or kind == "Frame") and frame.Track and frame.Track.Thumb and frame.Back and frame.Forward then
        return "ScrollBar"
    end
    if kind == "EditBox" and frame.Left and frame.Right and frame.Middle then return "Field" end
    if kind == "DropdownButton" and frame.Arrow and frame.Background then return "Dropdown" end
    if kind == "Frame" and frame.Left and frame.Middle and frame.Right and frame.Button and frame.Text then return "Dropdown" end
    if kind == "Button" or kind == "CheckButton" or kind == "DropdownButton" then
        if frame.LeftActive and frame.MiddleActive and frame.RightActive then return "Tab" end
        if frame.SelectedTexture and frame.Icon and frame.Background then return "SideTab" end
        if kind == "CheckButton" and frame.Icon and not frame.Background and frame.GetCheckedTexture
            and frame:GetCheckedTexture() then return "RightSideTab" end
        if frame.Left and frame.Middle and frame.Right and Text(frame) then return "Button" end
    end
    return nil
end

local function Parts(frame) return Skin.Panel(frame, "BACKGROUND", -8) end

function Skin.Button(button, style)
    for _, key in ipairs(BUTTON_ART) do Fade(button[key]) end
    FadeStates(button)
    local parts = Parts(button)
    local px = Kit.PixelSize(button)
    parts.px, parts.hoverRim = px, true
    Skin.Once(button, "buttonHover", function()
        button:HookScript("OnEnter", function() parts.hovered = true; Skin.PaintField(button) end)
        button:HookScript("OnLeave", function() parts.hovered = false; Skin.PaintField(button) end)
    end)
    local text = Text(button)
    if text then Skin.Font(text, style.path, nil, style.outline, style.shadow, px) end
    Skin.PaintField(button)
end

function Skin.Field(edit, style)
    for _, key in ipairs({ "Left", "Middle", "Right" }) do Fade(edit[key]) end
    local parts = Parts(edit)
    local px = Kit.PixelSize(edit)
    parts.px = px
    -- InputBoxTemplate's art reaches 5 px left of the text; so does the field.
    if not parts.box then
        parts.box = edit:CreateTexture(nil, "BACKGROUND", nil, -8)
        parts.box:SetAlpha(0)
        parts.regions[parts.box] = true
    end
    parts.box:ClearAllPoints()
    parts.box:SetPoint("TOPLEFT", edit, "TOPLEFT", -Snap(5, px), 0)
    parts.box:SetPoint("BOTTOMRIGHT", edit, "BOTTOMRIGHT", 0, 0)
    Skin.Once(edit, "fieldFocus", function()
        edit:HookScript("OnEditFocusGained", function() Skin.PaintField(edit) end)
        edit:HookScript("OnEditFocusLost", function() Skin.PaintField(edit) end)
    end)
    Skin.Font(edit, style.path, nil, style.outline, style.shadow, px)
    Skin.PaintField(edit)
end

-- A field's colors: cyan rim when hovered (buttons) or focused (edit boxes).
function Skin.PaintField(frame)
    local parts = Skin.parts[frame]
    if not parts or not parts.fill then return end
    local focused = frame.HasFocus and frame:HasFocus() == true
    local lit = focused or parts.hovered
    local enabled = not frame.IsEnabled or frame:IsEnabled() ~= false
    local rim = lit and enabled and C.accent or (enabled and C.fieldRim or C.cardRim)
    Skin.PaintPanel(parts, parts.box or frame, C.field, 0.95, rim, parts.px or 1)
end

-- Tabs: a 24 px field across the tab (Blizzard's 32 px tab, its text 2 px
-- above the middle); the selected one is the lighter segment with the cyan
-- bar. `side` is "top" for tabs hanging under a window (bar on top) or
-- "bottom" for tabs sitting above one.
function Skin.Tab(tab, style, side)
    for _, key in ipairs(TAB_ART) do Fade(tab[key]) end
    local parts = Parts(tab)
    local px = Kit.PixelSize(tab)
    parts.px, parts.side = px, side or "top"
    if not parts.box then
        parts.box = tab:CreateTexture(nil, "BACKGROUND", nil, -8)
        parts.box:SetAlpha(0)
        parts.bar = tab:CreateTexture(nil, "ARTWORK", nil, 7)
        parts.bar:SetTexture(Kit.FLAT)
        parts.regions[parts.box], parts.regions[parts.bar] = true, true
    end
    local gap = Snap(1, px)
    parts.box:ClearAllPoints()
    parts.box:SetPoint("TOPLEFT", tab, "TOPLEFT", gap, -Snap(2, px))
    parts.box:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -gap, Snap(6, px))
    parts.style = style
    -- Blizzard shows and hides the active art (and resets the font) when a
    -- tab is picked; the Mode look follows right after.
    Skin.Once(Skin, "panelTabs", function()
        for _, name in ipairs({ "PanelTemplates_SelectTab", "PanelTemplates_DeselectTab", "PanelTemplates_SetDisabledTabState" }) do
            if type(_G[name]) == "function" then
                hooksecurefunc(name, function(picked) if picked and Skin.parts[picked] and Skin.parts[picked].bar then Skin.PaintTab(picked) end end)
            end
        end
    end)
    Skin.Once(tab, "tabSelected", function()
        if tab.SetTabSelected then hooksecurefunc(tab, "SetTabSelected", function() Skin.PaintTab(tab) end) end
    end)
    Skin.PaintTab(tab)
end

function Skin.PaintTab(tab)
    local parts = Skin.parts[tab]
    if not parts or not parts.box then return end
    local selected = Shown(tab.LeftActive) or Shown(tab.MiddleActive)
    local px = parts.px or 1
    Skin.PaintPanel(parts, parts.box, selected and C.selected or C.field, 0.95, C.fieldRim, px)
    local bar = parts.bar
    bar:ClearAllPoints()
    local edge = parts.side == "bottom" and "BOTTOM" or "TOP"
    bar:SetPoint(edge .. "LEFT", parts.box, edge .. "LEFT", px, parts.side == "bottom" and px or -px)
    bar:SetPoint(edge .. "RIGHT", parts.box, edge .. "RIGHT", -px, parts.side == "bottom" and px or -px)
    bar:SetHeight(Snap(2, px))
    Kit.Tint(bar, C.accent, 1)
    bar:SetShown(selected)
    local text, style = Text(tab), parts.style
    if text and style then
        Skin.Font(text, style.path, style.tabSize, style.outline, style.shadow, px)
        local color = selected and C.heading or C.muted
        text:SetTextColor(color[1], color[2], color[3], 1)
    end
end

function Skin.SideTab(tab, style)
    Fade(tab.Background); Fade(tab.SelectedTexture); Fade(tab.HighlightTexture); Fade(tab.TabGlow)
    local parts = Parts(tab)
    parts.px = Kit.PixelSize(tab)
    Skin.Once(tab, "sideTab", function()
        if tab.SetChecked then hooksecurefunc(tab, "SetChecked", function() Skin.PaintSideTab(tab) end) end
        tab:HookScript("OnEnter", function() parts.hovered = true; Skin.PaintSideTab(tab) end)
        tab:HookScript("OnLeave", function() parts.hovered = false; Skin.PaintSideTab(tab) end)
    end)
    Skin.PaintSideTab(tab)
end

function Skin.PaintSideTab(tab)
    local parts = Skin.parts[tab]
    if not parts or not parts.fill then return end
    local checked = tab.GetChecked and Public(tab:GetChecked()) == true
    local rim = (checked or parts.hovered) and C.accent or C.fieldRim
    Skin.PaintPanel(parts, tab, checked and C.selected or C.field, 0.95, rim, parts.px or 1)
end

-- A window button with a Mode glyph: Blizzard's art faded, a field with
-- the glyph (ModeClose, ModeMinimize, ModeMaximize) whose rim and glyph
-- turn cyan on hover. Placing it is anchoring, so the caller does it
-- outside combat.
function Skin.GlyphButton(button, glyph)
    FadeStates(button)
    Fade(button.Border)
    local parts = Parts(button)
    local px = Kit.PixelSize(button)
    parts.px = px
    if not parts.icon then
        parts.icon = button:CreateTexture(nil, "ARTWORK")
        parts.regions[parts.icon] = true
        addon.Media:ApplyTexture(parts.icon, glyph)
        button:HookScript("OnEnter", function() parts.hovered = true; Skin.PaintClose(button) end)
        button:HookScript("OnLeave", function() parts.hovered = false; Skin.PaintClose(button) end)
    end
    parts.icon:ClearAllPoints(); parts.icon:SetPoint("CENTER")
    parts.icon:SetSize(Snap(16, px), Snap(16, px))
    Skin.PaintClose(button)
end
function Skin.Close(button) Skin.GlyphButton(button, "ModeClose") end
function Skin.PaintClose(button)
    local parts = Skin.parts[button]
    if not parts or not parts.icon then return end
    Skin.PaintPanel(parts, button, C.field, 0.95, parts.hovered and C.accent or C.fieldRim, parts.px or 1)
    Kit.Tint(parts.icon, parts.hovered and C.accent or C.label, 1)
end

-- Scroll bars: Blizzard's track, thumb and arrows faded; a 4 px track and
-- thumb down the middle. The arrows stay clickable.
function Skin.ScrollBar(bar)
    Fade(bar.Backplate)
    -- A plain Background texture (the Guild roster's marble strip) goes too.
    if bar.Background and bar.Background.GetObjectType and bar.Background:GetObjectType() == "Texture" then Fade(bar.Background) end
    local track, thumb = bar.Track, bar.Track.Thumb
    -- WowTrimScrollBar has a Background holder too; MinimalScrollBar doesn't.
    for _, key in ipairs({ "Background", "Track", "Thumb" }) do
        local holder = key == "Thumb" and thumb or bar[key]
        if holder then Fade(holder.Begin); Fade(holder.Middle); Fade(holder.End) end
    end
    for _, key in ipairs({ "Back", "Forward" }) do
        local arrow = bar[key]
        if arrow then Fade(arrow.Texture); Fade(arrow.Overlay); FadeStates(arrow) end
    end
    local px = Kit.PixelSize(bar)
    local width = Snap(4, px)
    local own = Skin.parts[bar] or { regions = {} }
    Skin.parts[bar] = own
    if not own.track then
        own.track = track:CreateTexture(nil, "BACKGROUND", nil, -8)
        own.thumb = thumb:CreateTexture(nil, "ARTWORK", nil, 7)
        own.track:SetTexture(Kit.FLAT); own.thumb:SetTexture(Kit.FLAT)
    end
    own.track:ClearAllPoints()
    own.track:SetPoint("TOP", track, "TOP", 0, 0); own.track:SetPoint("BOTTOM", track, "BOTTOM", 0, 0)
    own.track:SetWidth(width)
    Kit.Tint(own.track, C.track, 1)
    own.thumb:ClearAllPoints()
    own.thumb:SetPoint("TOP", thumb, "TOP", 0, 0); own.thumb:SetPoint("BOTTOM", thumb, "BOTTOM", 0, 0)
    own.thumb:SetWidth(width)
    Kit.Tint(own.thumb, C.thumb, 1)
end

-- An inset: Blizzard's inset border and background faded, a darker field
-- inside a one-pixel rim. Some insets sit ABOVE the content they frame (the
-- Guild roster's InsetFrame is raised to level 100 over its rows), so the
-- field is drawn on the inset's parent, under the content, and only the
-- thin rim on the inset itself; the rows keep their full color.
function Skin.Inset(inset)
    Skin.FadeNineSlice(inset.NineSlice); Fade(inset.Bg)
    local host = inset:GetParent() or inset
    local parts = Skin.parts[inset] or { regions = {} }
    Skin.parts[inset] = parts
    if not parts.fill then
        parts.fill = host:CreateTexture(nil, "BACKGROUND", nil, -7)
        parts.fill:SetTexture(Kit.FLAT)
        parts.rim = Kit.Rim(inset, "BACKGROUND", -7)
        for _, edge in ipairs(parts.rim) do parts.regions[edge] = true end
        -- The field belongs to the host's textures too, so fading the host's
        -- own art (fadeOwn) never takes it.
        local own = Skin.parts[host] or { regions = {} }
        Skin.parts[host] = own
        own.regions[parts.fill] = true
    end
    Skin.PaintPanel(parts, inset, C.field, 0.6, C.cardRim, Kit.PixelSize(inset))
end
