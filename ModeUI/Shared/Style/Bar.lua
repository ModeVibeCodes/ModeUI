local _, addon = ...
-- The one bar factory (docs/DESIGN_LANGUAGE.md, "Bars"): a StatusBar whose empty
-- part is Mode BG on Slate, whose fill is a Mode texture multiplied by the fill
-- color plus its light overlay, with the 1px fill-end line and the Comet spark.
-- Values may be secret; they only ever reach SetMinMaxValues and SetValue.
local Style = addon.Style
local Tone = Style.Tone

-- Default fill texture per role.
Style.BAR_ROLES = { health = "Matte", healthClass = "Gradient", power = "Gradient", cast = "Cast",
    nameplate = "BG", meter = "Panel", resource = "Button", status = "Matte", timer = "Gradient", aura = "Solid" }


local Bar = {}

-- The fill-end line's look in the theme in use: color, alpha and how many
-- pixels it stays in from the bar's top and bottom. Mode-Blizz: white, the
-- full height (Style.Bar at 70%; module bars at 22%, Kit.FillEdge).
-- Mode-Obsidian: ice white at 85%, 1px in, so it sits inside the border
-- (owner, November 20, 2026).
function Style.FillEnd(alpha)
    if Style.Theme and Style.Theme() == "obsidian" then return Tone.fillEnd, 0.85, 1 end
    return Tone.mono.white, alpha or 0.7, 0
end

-- A bar in `parent`. opts: role (picks the default texture), texture (a key from
-- Style.BAR_TEXTURES), reverse (fills right to left), spark (Comet), endLine
-- (default true).
function Style.Bar(parent, opts)
    opts = opts or {}
    local bar = CreateFrame("StatusBar", nil, parent)
    for name, fn in pairs(Bar) do bar[name] = fn end
    bar.styleRole = opts.role or "health"
    bar.bg = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
    bar.bg:SetAllPoints()
    Style.ApplyAsset(bar.bg, "BG")
    -- Health and power empty parts are semi-transparent; the rest stay solid.
    local role = bar.styleRole
    local see = role == "health" or role == "healthClass" or role == "power"
    Style.Paint(bar.bg, Tone.slate, see and Tone.emptyAlpha or 1)
    bar.lift = bar:CreateTexture(nil, "ARTWORK", nil, 3)
    bar.lift:SetBlendMode("BLEND")
    bar.endClip = CreateFrame("Frame", nil, bar)
    bar.endClip:SetClipsChildren(true)
    bar.endLine = bar.endClip:CreateTexture(nil, "OVERLAY", nil, 2)
    Style.ApplyAsset(bar.endLine, "Solid")
    local endColor, endAlpha = Style.FillEnd(0.7)
    Style.Paint(bar.endLine, endColor, endAlpha)
    bar.trail = bar:CreateTexture(nil, "OVERLAY", nil, 3)
    Style.ApplyAsset(bar.trail, "CometTrail")
    bar.head = bar:CreateTexture(nil, "OVERLAY", nil, 4)
    Style.ApplyAsset(bar.head, "CometHead")
    bar.fillColor = Tone.darkFill
    bar.reverse = opts.reverse and true or false
    bar:SetReverseFill(bar.reverse)
    bar:SetTextureKey(opts.texture or Style.BAR_ROLES[bar.styleRole] or "Matte")
    bar.showEndLine = opts.endLine ~= false
    bar.showSpark = opts.spark and true or false
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    bar:SetScript("OnSizeChanged", function(self) self:LayoutStyle() end)
    bar:LayoutStyle()
    return bar
end

-- Sets a module StatusBar's fill file (a SharedMedia or flat choice, or the
-- unit frames' round point): the one place outside Style.Bar a bar's
-- texture is set, so it draws on the ARTWORK layer under the lift.
function Style.SetBarTexture(bar, path)
    bar:SetStatusBarTexture(path)
    local fill = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if fill and fill.SetDrawLayer then fill:SetDrawLayer("ARTWORK", 0) end
    return fill
end

-- A module's StatusBar (with a `sheen` texture) in a Mode texture that has a
-- lift ("media:Mode Glass" and so on): its base as the fill, multiplied by the
-- bar color, and the white lift over the fill on the sheen, so the light still
-- reads on dark fills ("Bars", Light). False for any other choice.
-- The lift fades with the fill: a module's fill opacity (the alpha it gives
-- SetStatusBarColor) reaches the lift too.
local function FollowFillAlpha(bar, _, _, _, alpha)
    if bar.liftKey and bar.sheen then bar.sheen:SetAlpha(addon.IsNumber(alpha, 0, 1) and alpha or 1) end
end
function Style.ApplyBarLook(bar, choice)
    local asset, key = Style.MediaAsset(choice)
    -- Mode Panel's own file is its base (it has no separate fill).
    if not (asset and asset.lift) then
        if bar.liftKey and bar.sheen then bar.sheen:SetAlpha(1) end
        bar.liftKey = nil
        return false
    end
    if not bar.liftFollows and hooksecurefunc and type(bar.SetStatusBarColor) == "function" then
        bar.liftFollows = true
        hooksecurefunc(bar, "SetStatusBarColor", FollowFillAlpha)
    end
    bar:SetStatusBarTexture(Style.AssetPath(asset.fill or key))
    local fill = bar:GetStatusBarTexture()
    if fill and fill.SetDrawLayer then fill:SetDrawLayer("ARTWORK", 0) end
    local sheen = bar.sheen
    if fill and Style.ApplyAsset(sheen, asset.lift) then
        Style.Paint(sheen, Tone.mono.white)
        sheen:ClearAllPoints()
        sheen:SetPoint("TOPLEFT", fill, "TOPLEFT"); sheen:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
        sheen:Show()
    else
        sheen:Hide()
    end
    bar.liftKey = key
    return true
end

-- Swaps the fill texture (a Style.BAR_TEXTURES key; unknown keys fall back to Matte).
function Bar:SetTextureKey(key)
    local asset = Style.ASSETS[key]
    if not asset or not asset.lsm then key = "Matte"; asset = Style.ASSETS.Matte end
    self.textureKey = key
    local fillKey = asset.fill or key
    self:SetStatusBarTexture(Style.AssetPath(fillKey))
    local fill = self:GetStatusBarTexture()
    -- Like Blizzard's health bars: no texel bias on the fill, pixel snapping kept.
    if fill and fill.SetTexelSnappingBias then fill:SetTexelSnappingBias(0) end
    if asset.lift then
        Style.ApplyAsset(self.lift, asset.lift)
        self.lift:ClearAllPoints()
        self.lift:SetPoint("TOPLEFT", fill, "TOPLEFT")
        self.lift:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
        self.lift:Show()
    else
        self.lift:Hide()
    end
    self:SetFill(self.fillColor)
end

-- The fill color (a token or any { r, g, b }); the Comet trail follows it.
function Bar:SetFill(color, alpha)
    self.fillColor = color
    self:SetStatusBarColor(color[1], color[2], color[3], alpha or 1)
    local trail = Style.Lighten(color, 0.45)
    self.trail:SetVertexColor(trail[1], trail[2], trail[3], 1)
end

-- Fill color from a possibly secret boolean (true / false colors), for states
-- the client hides from addons.
function Bar:SetFillFromBoolean(value, ifTrue, ifFalse)
    local fill = self:GetStatusBarTexture()
    if addon.IsPublic(value) then return self:SetFill(value and ifTrue or ifFalse) end
    if fill and fill.SetVertexColorFromBoolean and CreateColor then
        fill:SetVertexColorFromBoolean(value, CreateColor(ifTrue[1], ifTrue[2], ifTrue[3], 1), CreateColor(ifFalse[1], ifFalse[2], ifFalse[3], 1))
    end
end

function Bar:SetSpark(shown) self.showSpark = shown and true or false; self:LayoutStyle() end

-- The Comet spark on any StatusBar (cast bars built outside Style.Bar): a thin
-- oval head on the fill's leading edge, 1px taller than the bar each way, and
-- a 21px trail behind it in the bar color lightened 45%.
local Comet = {}
Comet.__index = Comet
function Style.Comet(statusBar)
    local comet = setmetatable({ bar = statusBar }, Comet)
    -- Clipped to the bar's ends (1px taller each way, for the head), so at a
    -- cast's start the head never shows outside the bar.
    comet.clip = CreateFrame("Frame", nil, statusBar)
    comet.clip:SetClipsChildren(true)
    comet.trail = comet.clip:CreateTexture(nil, "OVERLAY", nil, 3)
    Style.ApplyAsset(comet.trail, "CometTrail")
    comet.head = comet.clip:CreateTexture(nil, "OVERLAY", nil, 4)
    Style.ApplyAsset(comet.head, "CometHead")
    return comet
end
function Comet:Layout(reverse, px)
    local fill = self.bar:GetStatusBarTexture()
    if not fill then return end
    px = px or Style.Pixel(self.bar)
    self.clip:ClearAllPoints()
    self.clip:SetPoint("TOPLEFT", self.bar, "TOPLEFT", 0, px)
    self.clip:SetPoint("BOTTOMRIGHT", self.bar, "BOTTOMRIGHT", 0, -px)
    self.clip:SetFrameLevel(self.bar:GetFrameLevel() + 1)
    local side = reverse and "LEFT" or "RIGHT"
    self.head:ClearAllPoints()
    self.head:SetPoint("TOP", fill, "TOP" .. side, 0, px)
    self.head:SetPoint("BOTTOM", fill, "BOTTOM" .. side, 0, -px)
    self.head:SetWidth(10 * px)
    self.trail:ClearAllPoints()
    self.trail:SetPoint("TOP" .. side, fill, "TOP" .. side, 0, 0)
    self.trail:SetPoint("BOTTOM" .. side, fill, "BOTTOM" .. side, 0, 0)
    self.trail:SetWidth(21 * px)
    if reverse then self.trail:SetTexCoord(1, 0, 0, 1) else self.trail:SetTexCoord(0, 1, 0, 1) end
end
function Comet:SetColor(color)
    local trail = Style.Lighten(color, 0.45)
    self.trail:SetVertexColor(trail[1], trail[2], trail[3], 1)
end
function Comet:SetShown(shown) self.clip:SetShown(shown) end
-- The trail on or off: a Dark mode cast bar shows the head alone (owner,
-- November 17, 2026: a light trail on a dark fill read odd).
function Comet:SetTrail(shown) self.trail:SetShown(shown ~= false) end
function Bar:SetEndLine(shown) self.showEndLine = shown and true or false; self:LayoutStyle() end

-- The spark end line (docs/DESIGN_LANGUAGE.md, "Bars"): the shield's bright
-- 1px finish line with the Line Glow behind it, on any StatusBar's fill end
-- (a bar riding on another, like incoming heals). Both sit in a clip that
-- follows the fill, so an empty bar (no width) shows no line, and a bar its
-- parent clips off shows none either, without the value being compared.
local EndSpark = {}
EndSpark.__index = EndSpark
function Style.EndSpark(statusBar)
    local spark = setmetatable({ bar = statusBar }, EndSpark)
    spark.clip = CreateFrame("Frame", nil, statusBar)
    spark.clip:SetClipsChildren(true)
    spark.glow = spark.clip:CreateTexture(nil, "OVERLAY", nil, 1)
    Style.ApplyAsset(spark.glow, "LineGlow")
    spark.line = spark.clip:CreateTexture(nil, "OVERLAY", nil, 2)
    Style.ApplyAsset(spark.line, "Solid")
    spark:SetColor(nil)
    return spark
end
-- Lay out after the bar's fill texture is set (a new file may bring a new fill).
function EndSpark:Layout(reverse, px)
    local fill = self.bar:GetStatusBarTexture()
    if not fill then return end
    px = px or Style.Pixel(self.bar)
    self.clip:ClearAllPoints()
    self.clip:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, 0)
    self.clip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0)
    local side = reverse and "LEFT" or "RIGHT"
    self.line:ClearAllPoints()
    self.line:SetPoint("TOP" .. side, fill, "TOP" .. side, 0, 0)
    self.line:SetPoint("BOTTOM" .. side, fill, "BOTTOM" .. side, 0, 0)
    self.line:SetWidth(px)
    self.glow:ClearAllPoints()
    self.glow:SetPoint("TOP", self.line, "TOP", 0, 0)
    self.glow:SetPoint("BOTTOM", self.line, "BOTTOM", 0, 0)
    self.glow:SetWidth(5 * px)
end
-- The glow takes the bar's color lightened 45% (nil: white); the line stays bright.
function EndSpark:SetColor(color)
    local glow = color and Style.Lighten(color, 0.45) or Tone.mono.white
    self.glow:SetVertexColor(glow[1], glow[2], glow[3], 1)
    local line = Tone.finishLine
    self.line:SetVertexColor(line[1], line[2], line[3], 1)
end
function EndSpark:SetShown(shown) self.clip:SetShown(shown and true or false) end

-- Positions the end line and the spark on the fill's leading edge, in whole pixels.
function Bar:LayoutStyle()
    local px = Style.Pixel(self)
    local fill = self:GetStatusBarTexture()
    if not fill then return end
    local side = self.reverse and "LEFT" or "RIGHT"
    local away = self.reverse and "RIGHT" or "LEFT"
    -- The end line lives in a clip that stops 1px short of the bar's end, so a
    -- full bar shows no line without the value being compared.
    self.endClip:ClearAllPoints()
    self.endClip:SetPoint("TOPLEFT", self, "TOPLEFT", self.reverse and px or 0, 0)
    self.endClip:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", self.reverse and 0 or -px, 0)
    local _, _, inset = Style.FillEnd()
    self.endLine:ClearAllPoints()
    self.endLine:SetPoint("TOP" .. side, fill, "TOP" .. side, 0, -inset * px)
    self.endLine:SetPoint("BOTTOM" .. side, fill, "BOTTOM" .. side, 0, inset * px)
    self.endLine:SetWidth(px)
    self.endLine:SetShown(self.showEndLine and not self.showSpark)
    -- Comet: a 10px oval head centered on the edge, 1px taller than the bar
    -- each way, and a 21px trail behind it.
    local spark = self.showSpark
    self.head:SetShown(spark)
    self.trail:SetShown(spark)
    if spark then
        self.head:ClearAllPoints()
        self.head:SetPoint("TOP", fill, "TOP" .. side, 0, px)
        self.head:SetPoint("BOTTOM", fill, "BOTTOM" .. side, 0, -px)
        self.head:SetWidth(10 * px)
        self.trail:ClearAllPoints()
        self.trail:SetPoint("TOP" .. side, fill, "TOP" .. side)
        self.trail:SetPoint("BOTTOM" .. side, fill, "BOTTOM" .. side)
        self.trail:SetWidth(21 * px)
        if self.reverse then self.trail:SetTexCoord(1, 0, 0, 1) else self.trail:SetTexCoord(0, 1, 0, 1) end
    end
    if self.shield then self.shield:Layout() end
    return away
end
