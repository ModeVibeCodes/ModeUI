local _, addon = ...
local T, W = addon.InterfaceTheme, addon.ConfigWidgets
local Paint = W.Paint

-- Stock interface artwork for the Blizzard theme. These are long-standing
-- shared client files (the same ones the stock panel button, tooltip, dialog,
-- checkbox and input box templates draw). Every consumer keeps its flat
-- drawing underneath or as the fallback when a file is refused.
local ART = {
    buttonUp = "Interface\\Buttons\\UI-Panel-Button-Up",
    buttonDown = "Interface\\Buttons\\UI-Panel-Button-Down",
    buttonDisabled = "Interface\\Buttons\\UI-Panel-Button-Disabled",
    buttonHighlight = "Interface\\Buttons\\UI-Panel-Button-Highlight",
    checkbox = "Interface\\Buttons\\UI-CheckBox-Up",
    checkboxHighlight = "Interface\\Buttons\\UI-CheckBox-Highlight",
    check = "Interface\\Buttons\\UI-CheckBox-Check",
    checkDisabled = "Interface\\Buttons\\UI-CheckBox-Check-Disabled",
    input = "Interface\\Common\\Common-Input-Border",
    sliderThumb = "Interface\\Buttons\\UI-SliderBar-Button-Horizontal",
    rowHighlight = "Interface\\QuestFrame\\UI-QuestLogTitleHighlight",
    dialogBackground = "Interface\\DialogFrame\\UI-DialogBox-Background",
    dialogBorder = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tooltipBackground = "Interface\\Tooltips\\UI-Tooltip-Background",
    tooltipBorder = "Interface\\Tooltips\\UI-Tooltip-Border",
}
W.BlizzardArt = ART

-- Left/middle/right slices of a stock 3-slice texture. Returns nil when the
-- client refuses the file so callers keep their flat drawing.
local SLICE_KEYS = { "left", "middle", "right" }
local function ThreeSlice(frame, layer, file, edge, coords)
    local parts = {}
    for index, name in ipairs(SLICE_KEYS) do
        local texture = frame:CreateTexture(nil, layer)
        parts[name] = texture
        if texture:SetTexture(file) == false then
            for _, key in ipairs(SLICE_KEYS) do if parts[key] then parts[key]:Hide() end end
            return nil
        end
        local c = coords[index]
        texture:SetTexCoord(c[1], c[2], c[3], c[4])
    end
    parts.left:SetPoint("TOPLEFT"); parts.left:SetPoint("BOTTOMLEFT"); parts.left:SetWidth(edge)
    parts.right:SetPoint("TOPRIGHT"); parts.right:SetPoint("BOTTOMRIGHT"); parts.right:SetWidth(edge)
    parts.middle:SetPoint("TOPLEFT", parts.left, "TOPRIGHT", 0, 0); parts.middle:SetPoint("BOTTOMRIGHT", parts.right, "BOTTOMLEFT", 0, 0)
    function parts:SetFile(path) for _, key in ipairs(SLICE_KEYS) do self[key]:SetTexture(path) end end
    function parts:SetAlpha(alpha) for _, key in ipairs(SLICE_KEYS) do self[key]:SetAlpha(alpha) end end
    return parts
end
W.ThreeSlice = ThreeSlice
local BUTTON_SLICES = { { 0, 0.09375, 0, 0.6875 }, { 0.09375, 0.53125, 0, 0.6875 }, { 0.53125, 0.625, 0, 0.6875 } }
local INPUT_SLICES = { { 0, 0.0625, 0, 0.625 }, { 0.0625, 0.9375, 0, 0.625 }, { 0.9375, 1, 0, 0.625 } }
W.BUTTON_SLICES, W.INPUT_SLICES = BUTTON_SLICES, INPUT_SLICES

-- Native backdrop on the frame itself, so it draws beneath the frame's own
-- children. Plain frames receive the documented BackdropTemplateMixin.
-- "dialog" is the stock dialog border; anything else is the stock tooltip
-- edge over an opaque panel fill.
function W.BlizzardBackdrop(frame, kind)
    if not frame.SetBackdrop then
        if type(Mixin) ~= "function" or type(BackdropTemplateMixin) ~= "table" then return false end
        Mixin(frame, BackdropTemplateMixin)
        if frame.OnBackdropSizeChanged then frame:HookScript("OnSizeChanged", frame.OnBackdropSizeChanged) end
    end
    local dialog = kind == "dialog"
    -- Theme artwork is set directly: Global Border/Texture belong to module
    -- displays and would replace the stock dialog and tooltip edges here.
    local ok = pcall(frame.SetBackdrop, frame, {
        -- The dialog owner draws its own opaque canvas and stone (Window.lua).
        bgFile = not dialog and ART.tooltipBackground or nil,
        edgeFile = dialog and ART.dialogBorder or ART.tooltipBorder,
        tile = true, tileSize = dialog and 32 or 16, edgeSize = dialog and 32 or 16,
        insets = dialog and { left = 11, right = 12, top = 12, bottom = 11 } or { left = 4, right = 4, top = 4, bottom = 4 },
    })
    if not ok then return false end
    if dialog then
        frame:SetBackdropColor(1, 1, 1, 1)
    else
        frame:SetBackdropColor(T.panel[1], T.panel[2], T.panel[3], T.panel[4])
        frame:SetBackdropBorderColor(T.lineStrong[1], T.lineStrong[2], T.lineStrong[3], 1)
    end
    frame.blizzardBackdrop = kind
    return true
end

-- Flat skin. Every legacy art key resolves to solid fills and hairlines, so
-- callers that still name a key keep working without bundled artwork.
local SKIN = {
    Window = { fill = "panel", line = "lineStrong" },
    Header = { fill = "surface" },
    Sidebar = { fill = "sidebar" },
    RaisedPanel = { fill = "panel" },
    InsetPanel = { fill = "surface" },
    BorderSilver = { line = "lineStrong" },
    InputField = { fill = "field", line = "lineStrong", focus = true },
    AccentMint = { fill = "line" },
    AccentLavender = { fill = "line" },
    UnderlineMint = { fill = "primary" },
    AtelierEdge = { fill = "line" },
    RoundMarker = { fill = "highlight" },
    ScrollThumb = { fill = "highlight" },
    SliderThumb = { fill = "highlight" },
    SliderTrack = { fill = "line" },
    AtelierFocus = { clear = true },
    AtelierBloom = { clear = true },
    AtelierSelection = { clear = true },
    ReadyCheck = { clear = true },
}
W.Skin = SKIN

-- Mode input fields: a rounded field with a one-pixel rim that turns accent
-- while the input owns keyboard focus. Returns the fill with an outline handle.
local function ModeInputField(frame, layer)
    local box = W.Box(frame, "ModeFlat", layer or "BACKGROUND")
    local rim = T.rim
    local function Draw() box:SetColors(T.field, rim) end
    local texture = box.fill
    texture.outline = {
        SetColor = function(_, color) rim = color; Draw() end,
        SetShown = function(_, shown) box:SetShown(shown) end,
    }
    Draw()
    if frame.HookScript and frame.HasFocus then
        frame:HookScript("OnEditFocusGained", function() rim = T.primary; Draw() end)
        frame:HookScript("OnEditFocusLost", function() rim = T.rim; Draw() end)
    end
    return texture
end

function W.Texture(frame, key, layer, inset, alpha)
    local skin = assert(SKIN[key], "ModeUI: unknown texture " .. tostring(key))
    if key == "InputField" and not T.blizzardArt then return ModeInputField(frame, layer) end
    if T.blizzardArt then
        -- Window surfaces take the stock tooltip backdrop; their silver edge is
        -- then already drawn. Without a backdrop both keep the flat drawing.
        if (key == "Window" and (frame.blizzardBackdrop or W.BlizzardBackdrop(frame, "tooltip")))
            or (key == "BorderSilver" and frame.blizzardBackdrop) then
            return W.Fill(frame, T.background, layer, inset, 0)
        end
    end
    local texture
    if skin.fill or skin.clear then
        texture = W.Fill(frame, skin.fill and T[skin.fill] or T.background, layer, inset, skin.clear and 0 or alpha)
    else
        -- Outline-only keys return an invisible anchor region for callers.
        texture = W.Fill(frame, T.background, layer, inset, 0)
    end
    if skin.line then
        texture.outline = W.Outline(frame, T[skin.line], skin.fill and "BORDER" or layer, inset, alpha)
    end
    if key == "InputField" and T.blizzardArt then
        local art = ThreeSlice(frame, "BORDER", ART.input, 8, INPUT_SLICES)
        if art then
            -- The stock input border replaces the hairline and its focus tint;
            -- a square fill would poke out past its rounded ends.
            texture.outline:SetShown(false)
            Paint(texture, T.field, 0)
            texture.blizzardArt = art
            return texture
        end
    end
    if skin.focus and frame.HookScript and frame.HasFocus then
        -- Inputs show an accent hairline while they own keyboard focus.
        frame:HookScript("OnEditFocusGained", function() texture.outline:SetColor(T.primary, 0.85) end)
        frame:HookScript("OnEditFocusLost", function() texture.outline:SetColor(T[skin.line]) end)
    end
    return texture
end
