local _, addon = ...
local Skin, Kit = addon.Skin, addon.Kit

-- A Blizzard window in the Mode look: its border (NineSlice pieces, or the
-- older corner and edge textures), parchment, portrait, title art and glow
-- are faded; ModeUI draws a near-black fill inside a one-pixel rim, a title
-- strip with a divider, and restyles the title, close button, insets and the
-- controls inside (Controls.lua). Works for PortraitFrameTemplate,
-- ButtonFrameTemplate, DefaultPanelTemplate, BasicFrameTemplate and Forever's
-- Character frame, by their keys. `style`:
--   fill, alpha, rim, border (bool), titleBar (bool), path, titleSize,
--   tabSize, outline, shadow, controls = { Button, Field, Tab, SideTab,
--   ScrollBar = bool }
-- `options` (per window): noFill (the World Map draws under its border
-- frame), fade (extra frames whose own textures are faded), fadeOwn (fade
-- every texture directly on the window).
local C = Skin.colors
local Snap, Fade = Skin.Snap, Skin.Fade
Skin.TITLE_HEIGHT, Skin.CLOSE_SIZE, Skin.CLOSE_INSET = 22, 18, 2
local ART = { "Bg", "TopTileStreaks", "PortraitContainer", "portrait", "FrameGlow", "TitleBg",
    "TopLeftCorner", "TopRightCorner", "TopBorder", "BotLeftCorner", "BotRightCorner", "BottomBorder",
    "LeftBorder", "RightBorder", "InsetBg", "InsetBorderTop", "InsetBorderBottom", "InsetBorderLeft",
    "InsetBorderRight", "InsetBorderTopLeft", "InsetBorderTopRight", "InsetBorderBottomLeft", "InsetBorderBottomRight" }
local HEADER_ART = { "LeftBG", "RightBG", "CenterBG" }
local SCAN_DEPTH = 6

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

local function FadeArt(frame, options)
    Skin.FadeNineSlice(frame.NineSlice)
    for _, key in ipairs(ART) do Fade(frame[key]) end
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

-- Fill, rim and title strip. Called again whenever the look changes.
function Skin.PaintWindow(frame, style)
    local parts = Skin.parts[frame]
    if not parts or not parts.fill then return end
    local px = Kit.PixelSize(frame)
    local options = parts.options or {}
    local rim = style.border and px or 0
    Skin.PaintPanel(parts, frame, style.fill, options.noFill and 0 or style.alpha, style.rim, rim)
    local title = Skin.TitleOf(frame)
    local strip, divider = parts.strip, parts.divider
    local showStrip = style.titleBar and title ~= nil
    local height = Snap(Skin.TITLE_HEIGHT, px)
    strip:ClearAllPoints()
    strip:SetPoint("TOPLEFT", frame, "TOPLEFT", rim, -rim)
    strip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -rim, -rim)
    strip:SetHeight(height)
    Kit.Tint(strip, C.card, options.noFill and style.alpha or 1)
    divider:ClearAllPoints()
    divider:SetPoint("TOPLEFT", strip, "BOTTOMLEFT", 0, 0)
    divider:SetPoint("TOPRIGHT", strip, "BOTTOMRIGHT", 0, 0)
    divider:SetHeight(px)
    Kit.Tint(divider, C.cardRim, 1)
    strip:SetShown(showStrip); divider:SetShown(showStrip)
    if title then
        Skin.Font(title, style.path, style.titleSize, style.outline, style.shadow, px)
        title:SetTextColor(C.heading[1], C.heading[2], C.heading[3], 1)
        -- A portrait window's title sits 5 px under its container's top, off
        -- center for the portrait. With the strip it's centered on the strip,
        -- clear of the close button on both sides. (Blizzard's SetTitle only
        -- sets text, so the anchors stay.) Header and dialog titles keep theirs.
        local own = (frame.TitleContainer and title == frame.TitleContainer.TitleText) or title == frame.TitleText
        if own and showStrip then
            local clear = Snap(Skin.CLOSE_SIZE + 2 * Skin.CLOSE_INSET + 4, px)
            title:ClearAllPoints()
            title:SetPoint("LEFT", strip, "LEFT", clear, 0)
            title:SetPoint("RIGHT", strip, "RIGHT", -clear, 0)
            title:SetJustifyH("CENTER")
        end
    end
end

-- The close button sits Close Inset inside the rim's top-right corner,
-- centered on the title strip. Anchoring: outside combat only.
function Skin.PlaceClose(frame, close)
    if addon.InCombat() and frame.IsProtected and frame:IsProtected() then return false end
    local px = Kit.PixelSize(frame)
    local size, inset = Snap(Skin.CLOSE_SIZE, px), Snap(Skin.CLOSE_INSET, px) + px
    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -inset)
    close:SetSize(size, size)
    return true
end

-- Skins the window and everything recognisable inside it. Safe to call again
-- (each show): pieces are made once and controls already skinned are only
-- repainted.
function Skin.Window(frame, style, options)
    options = options or {}
    FadeArt(frame, options)
    local parts = Skin.Panel(frame, "BACKGROUND", -8)
    parts.options = options
    if not parts.strip then
        parts.strip = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
        parts.divider = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
        parts.strip:SetTexture(Kit.FLAT); parts.divider:SetTexture(Kit.FLAT)
        parts.regions[parts.strip], parts.regions[parts.divider] = true, true
    end
    Skin.PaintWindow(frame, style)
    if frame.Inset then Skin.Inset(frame.Inset) end
    local close = Skin.CloseOf(frame)
    if close then Skin.Close(close); Skin.PlaceClose(frame, close) end
    Skin.Scan(frame, frame, style, 0)
end

-- Walks the window's children for controls to skin, SCAN_DEPTH levels deep.
-- Forbidden frames are skipped; nothing is read from them.
function Skin.Scan(window, frame, style, depth)
    if depth > SCAN_DEPTH or not frame.GetChildren then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        local forbidden = child.IsForbidden and child:IsForbidden()
        if not forbidden then
            local kind = Skin.Kind(child)
            if kind and style.controls[kind] then
                Skin.Control(window, child, kind, style)
            elseif child ~= Skin.CloseOf(window) then
                -- An inset frame (InsetFrameTemplate): a border and a background, no title.
                if style.controls.Inset and child.NineSlice and child.Bg and not Skin.TitleOf(child) then Skin.Inset(child) end
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
    elseif kind == "ScrollBar" then Skin.ScrollBar(control) end
end
