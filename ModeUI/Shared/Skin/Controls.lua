local _, addon = ...
local Skin, Kit = addon.Skin, addon.Kit

-- Blizzard's shared controls in the Mode look, each recognised by the keys
-- its template gives it (Forever's SharedUIPanelTemplates, TabSystem,
-- MinimalScrollBar and WowTrimScrollBar):
--   Button       Left/Middle/Right art (UIPanelButtonTemplate; Left/Center/Right
--                in ThreeSliceButtonTemplate, the Game Menu's): a Mode
--                Button face in the `control` edge, Ivory on hover
--   Field        an edit box with Left/Middle/Right art (InputBoxTemplate,
--                SearchBoxTemplate): a Graphite base in the `control` edge,
--                Ivory with focus
--   Tab          LeftActive/MiddleActive/RightActive (PanelTabButtonTemplate,
--                TabSystemButtonTemplate): text; the chosen tab Ivory with a
--                two-pixel Ivory bar on its window side
--   SideTab      SelectedTexture + Icon + Background (LargeSideTabButton):
--                a Mode Button face in the `control` edge, Ivory when checked
--   RightSideTab Icon + a checked texture, no Background (RightSideTabTemplate:
--                Guild's Chat, Roster, Benefits and Info tabs): as SideTab
--   Dropdown     WowStyle1/2DropdownTemplate (Background + Arrow) or the legacy
--                UIDropDownMenuTemplate (Left/Middle/Right + Button): a field
--                with a chevron (Extras.lua)
--   Close        the close button: a `control` box with a thin cross
--   ScrollBar    Track.Thumb + Back/Forward: a slim Graphite track and thumb
--   Inset        an inset frame's NineSlice and Bg: a Graphite base in the
--                `card` edge
-- Blizzard re-sets these textures' atlases on state changes but never their
-- alpha, so faded art stays faded. `style` carries the font:
-- { path, size, outline, shadow, tabSize }; the colors are Skin.mode's.
local M, Style = Skin.mode, addon.Style
local Snap, Fade = Skin.Snap, Skin.Fade
-- (ThreeSliceButtonTemplate, the Game Menu's buttons, names its middle Center.)
local BUTTON_ART = { "Left", "Middle", "Center", "Right", "LeftDisabled", "MiddleDisabled", "RightDisabled" }
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
    -- (The Guild chat's edit box names its middle piece Mid.)
    if kind == "EditBox" and frame.Left and frame.Right and (frame.Middle or frame.Mid) then return "Field" end
    -- WowStyle dropdowns are DropdownButton intrinsics; GetObjectType may
    -- answer "Button", so the keys and DropdownButtonMixin's methods decide.
    if (kind == "DropdownButton" or kind == "Button") and frame.Arrow and frame.Background
        and (kind == "DropdownButton" or frame.SetupMenu or frame.OpenMenu) then return "Dropdown" end
    if kind == "Frame" and frame.Left and frame.Middle and frame.Right and frame.Button and frame.Text then return "Dropdown" end
    -- LargeSideTabButtonTemplate (the Character window's mode tabs) is a Frame.
    if kind == "Frame" and frame.SelectedTexture and frame.Icon and frame.Background then return "SideTab" end
    if kind == "Button" or kind == "CheckButton" or kind == "DropdownButton" then
        if frame.LeftActive and frame.MiddleActive and frame.RightActive then return "Tab" end
        if frame.SelectedTexture and frame.Icon and frame.Background then return "SideTab" end
        if kind == "CheckButton" and frame.Icon and not frame.Background and frame.GetCheckedTexture
            and frame:GetCheckedTexture() then return "RightSideTab" end
        if frame.Left and (frame.Middle or frame.Center) and frame.Right and Text(frame) then return "Button" end
    end
    return nil
end

local function Parts(frame, preset) return Skin.Box(frame, preset) end

-- Buttons: a Mode Button face in Graphite raised inside the `control` edge;
-- hover lights its outer line Ivory. Disabled, the text goes muted.
function Skin.Button(button, style)
    for _, key in ipairs(BUTTON_ART) do Fade(button[key]) end
    FadeStates(button)
    local parts = Parts(button, "control")
    parts.px, parts.style = Kit.PixelSize(button), style
    Skin.Once(button, "buttonHover", function()
        button:HookScript("OnEnter", function() parts.hovered = true; Skin.PaintField(button) end)
        button:HookScript("OnLeave", function() parts.hovered = false; Skin.PaintField(button) end)
    end)
    local text = Text(button)
    if text then Skin.Font(text, Style.Weighted(style.path, "semibold"), nil, style.outline, style.shadow, parts.px) end
    Skin.PaintField(button)
end

-- Fields: an edit box on a Graphite base inside the `control` edge; focus
-- lights its outer line Ivory.
function Skin.Field(edit, style)
    for _, key in ipairs({ "Left", "Middle", "Mid", "Right" }) do Fade(edit[key]) end
    local parts = Parts(edit, "control")
    local px = Kit.PixelSize(edit)
    parts.px, parts.field = px, true
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

-- A button's or field's look now: Ivory outer line while hovered or focused.
function Skin.PaintField(frame)
    local parts = Skin.parts[frame]
    if not parts or not parts.face then return end
    local focused = frame.HasFocus and frame:HasFocus() == true
    local enabled = not frame.IsEnabled or frame:IsEnabled() ~= false
    local lit = enabled and (focused or parts.hovered)
    if parts.field then
        Skin.PaintBox(parts, parts.box or frame, "Solid", M.field, 1, true, lit and "accent" or nil)
    else
        Skin.PaintBox(parts, frame, "Button", M.face, 1, true, lit and "accent" or nil)
        Skin.Ink(Text(frame), enabled and M.text or M.muted)
    end
end

-- Tabs: text tabs; the chosen one in Ivory with a 2px Ivory bar on its
-- window side, the others muted. `side` is "top" for tabs hanging under a
-- window (bar on top) or "bottom" for tabs sitting above one.
function Skin.Tab(tab, style, side)
    for _, key in ipairs(TAB_ART) do Fade(tab[key]) end
    local parts = Skin.parts[tab] or { regions = {} }
    Skin.parts[tab] = parts
    local px = Kit.PixelSize(tab)
    parts.px, parts.side, parts.style = px, side or "top", style
    if not parts.bar then
        parts.bar = tab:CreateTexture(nil, "ARTWORK", nil, 7)
        Style.ApplyAsset(parts.bar, "Solid")
        parts.regions[parts.bar] = true
    end
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
    if not parts or not parts.bar then return end
    local selected = Shown(tab.LeftActive) or Shown(tab.MiddleActive)
    local px = parts.px or 1
    local bar, text = parts.bar, Text(tab)
    bar:ClearAllPoints()
    -- The bar hugs the label: as wide as its text, 3px off it on the
    -- window side (under the text for tabs above the content, over it for
    -- tabs hanging under a window). Without a label it spans the tab.
    local below = parts.side == "bottom"
    local gap = Snap(3, px)
    if text then
        local edge, from = below and "TOP" or "BOTTOM", below and "BOTTOM" or "TOP"
        bar:SetPoint(edge .. "LEFT", text, from .. "LEFT", 0, below and -gap or gap)
        bar:SetPoint(edge .. "RIGHT", text, from .. "RIGHT", 0, below and -gap or gap)
    else
        local edge, inset = below and "BOTTOM" or "TOP", Snap(8, px)
        local y = below and Snap(6, px) or -Snap(4, px)
        bar:SetPoint(edge .. "LEFT", tab, edge .. "LEFT", inset, y)
        bar:SetPoint(edge .. "RIGHT", tab, edge .. "RIGHT", -inset, y)
    end
    bar:SetHeight(Snap(2, px))
    Style.Paint(bar, M.accent)
    bar:SetShown(selected)
    local style = parts.style
    if text and style then
        Skin.Font(text, Style.Weighted(style.path, "semibold"), style.tabSize, style.outline, style.shadow, px)
        Skin.Ink(text, selected and M.accent or M.muted)
    end
end

-- Side tabs (and right side tabs, Extras.lua): a Mode Button face inside the
-- `control` edge; checked, the face is the chosen tone; hovered or checked,
-- the outer line is Ivory.
function Skin.SideTab(tab, style)
    Fade(tab.Background); Fade(tab.SelectedTexture); Fade(tab.HighlightTexture); Fade(tab.TabGlow)
    local parts = Parts(tab, "control")
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
    if not parts or not parts.face then return end
    -- SidePanelTabButtonMixin shows SelectedTexture when checked (it may
    -- have no GetChecked); the texture is faded, but its shown state stays.
    local checked = (tab.GetChecked and Public(tab:GetChecked()) == true) or Shown(tab.SelectedTexture)
    Skin.PaintBox(parts, tab, "Button", checked and M.chosen or M.face, 1, true, (checked or parts.hovered) and "accent" or nil)
end

-- A window button with a Mode glyph (ModeClose, ModeMinimize, ModeMaximize):
-- Blizzard's art faded, a Mode Button face inside the `control` edge, the
-- glyph in Graphite secondary; hover lights the glyph and the outer line
-- Ivory. Placing it is anchoring, so the caller does it outside combat.
function Skin.GlyphButton(button, glyph)
    FadeStates(button)
    Fade(button.Border)
    local parts = Parts(button, "control")
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
    Skin.PaintBox(parts, button, "Button", M.face, 1, true, parts.hovered and "accent" or nil)
    Style.Paint(parts.icon, parts.hovered and M.accent or M.label)
end

-- Scroll bars: Blizzard's track, thumb and arrows faded; a 4 px Graphite
-- track and thumb down the middle. The arrows stay clickable.
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
        Style.ApplyAsset(own.track, "Solid"); Style.ApplyAsset(own.thumb, "Solid")
    end
    own.track:ClearAllPoints()
    own.track:SetPoint("TOP", track, "TOP", 0, 0); own.track:SetPoint("BOTTOM", track, "BOTTOM", 0, 0)
    own.track:SetWidth(width)
    Style.Paint(own.track, M.track)
    own.thumb:ClearAllPoints()
    own.thumb:SetPoint("TOP", thumb, "TOP", 0, 0); own.thumb:SetPoint("BOTTOM", thumb, "BOTTOM", 0, 0)
    own.thumb:SetWidth(width)
    Style.Paint(own.thumb, M.thumb)
end

-- An inset: Blizzard's inset border and background faded; a card: a Mode
-- Matte face in Graphite raised (a step lighter than the window) inside the
-- `card` edge. Some insets sit ABOVE the
-- content they frame (the Guild roster's InsetFrame is raised to level 100
-- over its rows), so the face is drawn on the inset's parent, under the
-- content; the edge (on its own frame) only frames it.
function Skin.Inset(inset)
    Skin.FadeNineSlice(inset.NineSlice); Fade(inset.Bg)
    local host = inset:GetParent() or inset
    local parts = Skin.Box(inset, "card", { faceHost = host, sublevel = -7 })
    Skin.PaintBox(parts, inset, "Matte", M.card, 1, true)
end
