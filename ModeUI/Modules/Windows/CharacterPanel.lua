local _, addon = ...
local M = addon.Windows
if not M then return end

-- The Character window's own parts in the Onyx look (with its ModeUI style),
-- after Skin.Window has done the frame (Forever's Camelot paper doll):
--   Stats pane    the right pane's class art, stone, inside frame, scroll
--                 line and framedivider are faded; an Onyx field fills the
--                 pane, a one-pixel divider separates it from the model.
--   Categories    "General", "Primary Attributes"...: Blizzard's ornate
--                 title bar faded, an Onyx strip with a one-pixel rim, the
--                 title in white.
--   Stat rows     Blizzard's alternating stripe kept (it shows and hides it
--                 itself) but desaturated to a faint Onyx gray; labels in
--                 the Mode label gray, values as Blizzard colors them.
--   Top strip     the rock strip behind the level line, faded, with a
--                 one-pixel divider under it.
--   Pane button   the right pane's page arrow as a Mode glyph button.
-- Rows are made by Blizzard's ScrollBox as the pane scrolls; each one is
-- styled when Blizzard fills it (Skin.WatchList).
local Kit, Skin = addon.Kit, addon.Skin
local C = Skin.mode
local Fade = Skin.Fade
local STRIPE = Skin.mode.thumb

local function Line(host, key, layer)
    local parts = Skin.parts[host] or { regions = {} }
    Skin.parts[host] = parts
    if not parts[key] then
        parts[key] = host:CreateTexture(nil, layer or "ARTWORK", nil, 7)
        parts[key]:SetTexture(Kit.FLAT)
        parts.regions[parts[key]] = true
    end
    return parts[key]
end

-- A row of the stats list: a category header or a stat line.
function M:SkinStatRow(row)
    local px = Kit.PixelSize(row)
    if row.Title then
        Fade(row.Background)
        local parts = Skin.Box(row, "card")
        local box = parts.box
        if not box then
            box = row:CreateTexture(nil, "BACKGROUND", nil, -8)
            box:SetAlpha(0)
            parts.box, parts.regions[box] = box, true
        end
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -Skin.Snap(8, px))
        box:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, Skin.Snap(6, px))
        Skin.PaintBox(parts, box, "Matte", C.card, 1, true)
        row.Title:SetTextColor(C.heading[1], C.heading[2], C.heading[3], 1)
    elseif row.Label then
        local stripe = row.Background
        if stripe and stripe.SetDesaturated then
            stripe:SetDesaturated(true)
            stripe:SetVertexColor(STRIPE[1], STRIPE[2], STRIPE[3], 0.35)
        end
        row.Label:SetTextColor(C.label[1], C.label[2], C.label[3], 1)
    end
    local path = Kit.FontPath(self.db, self.id)
    for _, key in ipairs({ "Title", "Label", "Value" }) do Skin.Face(row[key], path) end
end

-- The pane button: a glyph pointing the way the pane will go.
local function PaintToggle(button)
    local parts = Skin.parts[button]
    local pane = CharacterFrame and CharacterFrame.RightPaneHost
    if not (parts and parts.icon and parts.icon.SetRotation) then return end
    local open = pane and pane:IsShown() == true
    parts.icon:SetRotation(open and -math.pi / 2 or math.pi / 2)
end

-- The level line ("Level 37 Rogue") in the Ivory accent; the class name keeps
-- the class color Blizzard writes into the text. Painted again after each
-- PaperDollFrame_SetLevel (it only sets the text, but a reload of the font
-- object would bring Blizzard's gold back).
local function InkLevel()
    local text = _G.CharacterLevelText
    if text and M.active and M:IsModeUI(M.byId.character) then Skin.Ink(text, addon.Style.Tone.ivory) end
end

function M:SkinCharacterPanel(frame)
    InkLevel()
    Skin.Once(Skin, "characterLevel", function()
        if type(_G.PaperDollFrame_SetLevel) == "function" then hooksecurefunc("PaperDollFrame_SetLevel", InkLevel) end
    end)
    local right = frame.RightPaneHost
    if right then
        -- Every texture on the pane and its own frames (the stats box's class
        -- art, inside frame and scroll line; the framedivider holder).
        Skin.FadeTextures(right)
        for _, child in ipairs({ right:GetChildren() }) do Skin.FadeTextures(child) end
        local parts = Skin.parts[right] or { regions = {} }
        Skin.parts[right] = parts
        if not parts.field then
            parts.field = right:CreateTexture(nil, "BACKGROUND", nil, -7)
            parts.field:SetTexture(Kit.FLAT)
            parts.field:SetAllPoints(right)
            parts.regions[parts.field] = true
        end
        Kit.Tint(parts.field, C.field, 0.6)
        local divider = Line(right, "divider")
        local px = Kit.PixelSize(right)
        divider:ClearAllPoints()
        divider:SetPoint("TOPLEFT", right, "TOPLEFT", 0, 0)
        divider:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 0, 0)
        divider:SetWidth(px)
        Kit.Tint(divider, C.cardRim, 1)
    end
    local pane = CharacterStatsPaneScrollBox
    local box = pane and pane.ScrollBox
    if box and Skin.IsScrollBox(box) then Skin.WatchList(box, function(row) self:SkinStatRow(row) end) end
    -- The rock strip behind the level line.
    local strip = PaperDollFrame and PaperDollFrame.TopBackgroundStripHost
    if strip then
        Skin.FadeTextures(strip)
        Fade(strip.TopBackgroundStrip); Fade(strip.TopBackgroundStripBottomEdge)
        local line = Line(strip, "divider")
        line:ClearAllPoints()
        line:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 0, 0)
        line:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT", 0, 0)
        line:SetHeight(Kit.PixelSize(strip))
        Kit.Tint(line, C.cardRim, 1)
    end
    local toggle = frame.RightPaneToggleButton
    if toggle then
        Skin.GlyphButton(toggle, "ModeChevron")
        Skin.Once(toggle, "paneToggle", function()
            toggle:HookScript("OnClick", function() PaintToggle(toggle) end)
            toggle:HookScript("OnShow", function() PaintToggle(toggle) end)
        end)
        PaintToggle(toggle)
    end
end
