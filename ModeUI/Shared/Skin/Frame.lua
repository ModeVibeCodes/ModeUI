local _, addon = ...
local Skin, Kit = addon.Skin, addon.Kit

-- A Blizzard window in the Mode look: its border (NineSlice pieces, or the
-- older corner and edge textures), parchment, portrait, title art and glow
-- are faded; ModeUI draws the Mode window (docs/DESIGN_LANGUAGE.md,
-- "Windows and panels"): a Graphite panel in Mode Panel, the `window` edge
-- on its own layer above the window's children, a Mode Title strip over a
-- line, and restyles the title, close and maximize/minimize buttons, insets,
-- list rows, text and the controls inside (Controls.lua, Extras.lua). Works
-- for PortraitFrameTemplate, ButtonFrameTemplate(Minimizable),
-- DefaultPanelTemplate, BasicFrameTemplate and Forever's Character frame, by
-- their keys. `style`:
--   alpha (the panel's opacity), border (bool: the edge), titleBar (bool), path,
--   titleSize, tabSize, outline, shadow, bodyFont (bool),
--   controls = { Button, Field, Tab, SideTab, RightSideTab, Dropdown,
--   ScrollBar, Inset = bool }
-- `options` (per window): noFill (the World Map draws under its border
-- frame), fade (extra frames whose own textures are faded), fadeOwn (fade
-- every texture directly on the window), fadeRows (fade list rows' strips).
local M, Style = Skin.mode, addon.Style
local Snap, Fade = Skin.Snap, Skin.Fade
Skin.TITLE_HEIGHT, Skin.CLOSE_SIZE, Skin.CLOSE_INSET = 22, 18, 2
local ART = { "Bg", "TopTileStreaks", "PortraitContainer", "portrait", "FrameGlow", "TitleBg",
    "TopLeftCorner", "TopRightCorner", "TopBorder", "BotLeftCorner", "BotRightCorner", "BottomBorder",
    "LeftBorder", "RightBorder", "InsetBg", "InsetBorderTop", "InsetBorderBottom", "InsetBorderLeft",
    "InsetBorderRight", "InsetBorderTopLeft", "InsetBorderTopRight", "InsetBorderBottomLeft", "InsetBorderBottomRight" }
local HEADER_ART = { "LeftBG", "RightBG", "CenterBG" }
-- Decoration found anywhere inside a window: gold filigree and bars, inset
-- border pieces, tiled backgrounds of lists and column headers.
local DECOR = { "TopFiligree", "BottomFiligree", "TopTileStreaks", "InsetBorderTopLeft", "InsetBorderTopRight",
    "InsetBorderBottomLeft", "InsetBorderBottomRight", "InsetBorderTop", "InsetBorderBottom", "InsetBorderLeft",
    "InsetBorderRight" }
-- (WatermarkFrame: the Guild roster's emblem behind the names.)
local DECOR_FRAMES = { "FilligreeOverlay", "PortraitOverlay", "WatermarkFrame" }
local SCAN_DEPTH = 6
-- The border's frame sits above everything Blizzard stacks on a window (its
-- NineSlice at 500, tabs and buttons at 510).
local EDGE_LIFT = 520

-- The window's title text, by template.
function Skin.TitleOf(frame)
    local container = frame.TitleContainer
    if container and container.TitleText then return container.TitleText end
    if frame.TitleText then return frame.TitleText end
    if frame.Header and frame.Header.Text then return frame.Header.Text end
    if frame.NineSlice and frame.NineSlice.Text then return frame.NineSlice.Text end
    return nil
end

function Skin.CloseOf(frame)
    local name = frame.GetName and frame:GetName()
    return frame.CloseButton or frame.ClosePanelButton or (name and _G[name .. "CloseButton"]) or nil
end

local function IsTexture(region) return region and region.GetObjectType and region:GetObjectType() == "Texture" end

-- Decoration on any frame inside a window (and the window itself).
local function FadeDecor(frame)
    for _, key in ipairs(DECOR) do if IsTexture(frame[key]) then Fade(frame[key]) end end
    for _, key in ipairs(DECOR_FRAMES) do if frame[key] then Skin.FadeTextures(frame[key]) end end
    -- A tiled list background (the Guild list's blue menu, a column header's rock).
    if IsTexture(frame.Bg) then Fade(frame.Bg) end
    if frame.ColumnDisplay then Fade(frame.ColumnDisplay.Background); Fade(frame.ColumnDisplay.TopTileStreaks) end
    -- Inset border pieces under any name (InsetBorderTop2 on the Guild pages).
    for key, region in pairs(frame) do
        if type(key) == "string" and key:find("^InsetBorder") and IsTexture(region) then Fade(region) end
    end
end

local function FadeArt(frame, options)
    Skin.FadeNineSlice(frame.NineSlice)
    for _, key in ipairs(ART) do Fade(frame[key]) end
    FadeDecor(frame)
    -- The Game Menu's dialog border and header art.
    if frame.Border then Skin.FadeNineSlice(frame.Border); Fade(frame.Border.Bg) end
    if frame.Header then for _, key in ipairs(HEADER_ART) do Fade(frame.Header[key]) end end
    if options.fadeOwn then Skin.FadeTextures(frame) end
    for _, extra in ipairs(options.fade or {}) do
        local holder = type(extra) == "function" and extra(frame) or frame[extra]
        -- A texture is faded itself; a frame has its own textures faded.
        if holder and holder.GetRegions then Skin.FadeTextures(holder) elseif holder then Fade(holder) end
    end
end

-- Panel, edge and title strip (docs/DESIGN_LANGUAGE.md, "Windows and
-- panels"): the Graphite panel in Mode Panel to the window's edges (at the
-- window's Background Opacity), the `window` edge outside them (1px Steel
-- Sheen, a black gap, shadow and drop) on its own frame above everything the
-- window stacks, and a Mode Title strip in Graphite raised over a 1px line.
-- Called again whenever the look changes.
function Skin.PaintWindow(frame, style)
    local parts = Skin.parts[frame]
    if not parts or not parts.face then return end
    local px = Kit.PixelSize(frame)
    local options = parts.options or {}
    Skin.PaintBox(parts, frame, "Panel", style.fill or M.panel, options.noFill and 0 or style.alpha, style.border ~= false)
    local title = Skin.TitleOf(frame)
    local strip, divider = parts.strip, parts.divider
    local showStrip = style.titleBar and title ~= nil
    local height = Snap(Skin.TITLE_HEIGHT, px)
    strip:ClearAllPoints()
    strip:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    strip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    strip:SetHeight(height)
    Style.Paint(strip, M.title, options.noFill and style.alpha or 1)
    local width = frame:GetWidth()
    if addon.IsNumber(width, 1) then Style.TileCoords(strip, "Title", width, height, px) end
    divider:ClearAllPoints()
    divider:SetPoint("TOPLEFT", strip, "BOTTOMLEFT", 0, 0)
    divider:SetPoint("TOPRIGHT", strip, "BOTTOMRIGHT", 0, 0)
    divider:SetHeight(px)
    Style.Paint(divider, M.line)
    strip:SetShown(showStrip); divider:SetShown(showStrip)
    if title then
        Skin.Font(title, Style.Weighted(style.path, "semibold"), style.titleSize, style.outline, style.shadow, px)
        Skin.Ink(title, M.heading)
        -- A portrait window's title sits 5 px under its container's top, off
        -- center for the portrait. With the strip it's centered on the strip,
        -- clear of the window buttons on both sides. (Blizzard's SetTitle only
        -- sets text, so the anchors stay.) Header and dialog titles keep theirs.
        local own = (frame.TitleContainer and title == frame.TitleContainer.TitleText) or title == frame.TitleText
        if own and showStrip then
            local buttons = Skin.MaxMinOf(frame) and 2 or 1
            local clear = Snap(buttons * (Skin.CLOSE_SIZE + Skin.CLOSE_INSET) + Skin.CLOSE_INSET + 4, px)
            title:ClearAllPoints()
            title:SetPoint("LEFT", strip, "LEFT", clear, 0)
            title:SetPoint("RIGHT", strip, "RIGHT", -clear, 0)
            title:SetJustifyH("CENTER")
        end
    end
end

-- The close button sits Close Inset inside the window's top-right corner,
-- centered on the title strip (the edge is outside the window); the
-- maximize/minimize pair just left of it. Anchoring: outside combat only for
-- protected windows.
function Skin.PlaceClose(frame, close)
    if addon.InCombat() and frame.IsProtected and frame:IsProtected() then return false end
    local px = Kit.PixelSize(frame)
    local size, inset = Snap(Skin.CLOSE_SIZE, px), Snap(Skin.CLOSE_INSET, px)
    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -inset)
    close:SetSize(size, size)
    local holder = Skin.MaxMinOf(frame)
    if holder then Skin.MaxMin(holder, close) end
    return true
end

-- Skins the window and everything recognisable inside it. Safe to call again
-- (each show): pieces are made once and controls already skinned are only
-- repainted.
function Skin.Window(frame, style, options)
    options = options or {}
    FadeArt(frame, options)
    local parts = Skin.Box(frame, "window", { level = EDGE_LIFT })
    parts.options = options
    if not parts.strip then
        parts.strip = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
        parts.divider = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
        Style.ApplyAsset(parts.strip, "Title"); Style.ApplyAsset(parts.divider, "Solid")
        parts.regions[parts.strip], parts.regions[parts.divider] = true, true
    end
    Skin.PaintWindow(frame, style)
    if frame.Inset and style.controls.Inset then Skin.Inset(frame.Inset) end
    local close = Skin.CloseOf(frame)
    if close then Skin.Close(close); Skin.PlaceClose(frame, close) end
    Skin.Scan(frame, frame, style, 0)
    -- A window's own extra parts (the Character window's stats pane).
    if options.after then options.after(frame, style) end
    if style.bodyFont then
        local skip = {}
        local title = Skin.TitleOf(frame)
        if title then skip[title] = true end
        Skin.Texts(frame, style.path, skip)
    end
end

-- Walks the window's children for controls to skin, SCAN_DEPTH levels deep.
-- Forbidden frames are skipped; nothing is read from them.
function Skin.Scan(window, frame, style, depth)
    if depth > SCAN_DEPTH or not frame.GetChildren then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        local forbidden = child.IsForbidden and child:IsForbidden()
        if not forbidden then
            local kind = Skin.Kind(child)
            -- Right side tabs hang directly off a window (the Guild window's);
            -- icon check buttons deeper inside are left alone.
            -- (or off a tab holder on it: the Character window's sidebar tabs).
            local holder = child:GetParent()
            if kind == "RightSideTab" and holder ~= window and not (holder and holder:GetParent() == window) then kind = nil end
            if kind and style.controls[kind] then
                Skin.Control(window, child, kind, style)
            elseif child ~= Skin.CloseOf(window) and child ~= Skin.MaxMinOf(window) then
                FadeDecor(child)
                -- An inset frame (InsetFrameTemplate): a border and a background, no title.
                if style.controls.Inset and child.NineSlice and child.Bg and not Skin.TitleOf(child) then Skin.Inset(child) end
                if Skin.IsScrollBox(child) then
                    local options = (Skin.parts[window] and Skin.parts[window].options) or {}
                    Skin.WatchList(child, function(row) Skin.Row(row, style, options.fadeRows) end)
                end
                Skin.Scan(window, child, style, depth + 1)
            end
        end
    end
end

-- Tabs hanging under the window get their bar on top; tabs sitting above
-- content get it underneath.
local function TabSide(window, tab)
    local _, tabY = tab:GetCenter()
    local _, windowY = window:GetCenter()
    if addon.IsNumber(tabY) and addon.IsNumber(windowY) and tabY > windowY then return "bottom" end
    return "top"
end

function Skin.Control(window, control, kind, style)
    if kind == "Button" then Skin.Button(control, style)
    elseif kind == "Field" then Skin.Field(control, style)
    elseif kind == "Tab" then Skin.Tab(control, style, TabSide(window, control))
    elseif kind == "SideTab" then Skin.SideTab(control, style)
    elseif kind == "RightSideTab" then Skin.RightSideTab(control)
    elseif kind == "Dropdown" then Skin.Dropdown(control, style)
    elseif kind == "ScrollBar" then Skin.ScrollBar(control) end
end
