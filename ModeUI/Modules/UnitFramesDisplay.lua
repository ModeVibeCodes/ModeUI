local _, addon = ...
local M = addon.UnitFrames
if not M then return end
local Number, P, ONYX = M.Number, M.palette, M.onyx
local Kit, Domain = addon.Kit, addon.Domain
local UnitColor, Portrait = Domain.UnitColor, Domain.Portrait
local FLAT = Kit.FLAT
local CIRCLE_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local Tint, Lighten, Scale, Gradient = Kit.Tint, Kit.Lighten, Kit.Scale, Kit.Gradient
local Write = Kit.Write
M.Lighten = Lighten

-- Mirrored by portrait side: the portrait caps the outer end.
local function Sides(fdb)
    if fdb.portraitSide == "right" then return "RIGHT", "LEFT", -1 end
    return "LEFT", "RIGHT", 1
end

-- Text font: Expressway (registered by Media from an installed AyijeUI or
-- EllesmereUI copy) falls back to the bundled ModeUI Lato when unavailable.
function M:FontPath(fdb)
    local media = addon.Media
    if fdb.fontMedia == "Expressway" and not media:GetFont("Expressway") then
        return media:GetFont("ModeUI Lato") or media.gameFont
    end
    return media:GetDisplayFont({ font = fdb.font, fontMedia = fdb.fontMedia }, false, self.id)
end

-- One physical pixel in this frame's units (Blizzard's PixelUtil factor over
-- the frame's effective scale); 1 when the client cannot report it.
function M:PixelSize(f) return Kit.PixelSize(f) end

-- The Onyx frame: a round portrait caps the outer end of one rounded bar
-- block. Pixel perfect: every size is whole physical pixels (2px slate rim,
-- 2px black gap, 1px hairline between health and power) and the frame is an
-- even number of pixels each way, so its centre anchor stays on the grid.
M.RIM, M.GAP, M.HAIRLINE = 2, 2, 1
function M:Geometry(fdb, px)
    local g, p = {}, px or 1
    local function Snap(v) return math.max(p, math.floor(v / p + 0.5) * p) end
    local function Odd(v) return math.floor(v / p + 0.5) % 2 == 1 end
    g.px = p
    g.border, g.line, g.gap = self.RIM * p, self.GAP * p, self.HAIRLINE * p
    g.pad = g.border + g.line
    g.healthHeight, g.powerHeight = Snap(fdb.healthHeight), Snap(fdb.powerHeight)
    local bars = g.healthHeight + (fdb.showPower and g.gap + g.powerHeight or 0)
    g.blockHeight = bars + 2 * g.pad
    if Odd(g.blockHeight) then g.healthHeight, g.blockHeight, bars = g.healthHeight + p, g.blockHeight + p, bars + p end
    -- The portrait is Portrait Size % of the bar block's height (150: the bars
    -- are ~2/3 of it), an even pixel count so both centre on whole pixels.
    g.portrait = fdb.showPortrait and math.floor(g.blockHeight * fdb.portraitScale / 100 / (2 * p) + 0.5) * 2 * p or 0
    g.height = math.max(g.blockHeight, g.portrait)
    g.blockY = (g.height - g.blockHeight) / 2
    g.portraitY = (g.height - g.portrait) / 2
    local r = g.portrait / 2
    g.blockStart = r -- the bar block starts under the portrait's centre
    if g.portrait > 0 then
        -- Bars start where the portrait's dark inner disc crosses their top
        -- edge (less 1px), so the circle's curve meets them with no gap.
        local disc, half = r - g.border, bars / 2
        local chord = disc > half and math.sqrt(disc * disc - half * half) or 0
        g.inset = r + math.max(0, math.floor(chord / p) * p - p)
    else
        g.inset = g.pad
    end
    -- How far the portrait's inner disc reaches over the bars at their middle;
    -- text on the portrait side is pushed in by this much.
    g.tuck = g.portrait > 0 and math.max(0, r + (r - g.border) - g.inset) or 0
    g.width = g.inset + Snap(fdb.barWidth) + g.pad
    if Odd(g.width) then g.width = g.width + p end
    g.barsTop = g.blockY + g.pad
    return g
end

-- The suite's text style (see Shared/Kit/Text.lua).
M.LIFT_PIXELS, M.LIFT_ALPHA = Kit.LIFT_PIXELS, Kit.LIFT_ALPHA
local Bar, Text, Circle, Inset, Rounded = Kit.Bar, Kit.Text, Kit.Circle, Kit.Inset, Kit.Rounded

-- One face for both the secure button and its Edit Mode/preview stand-in.
-- Bar block: slate rim fill, black gap inset by the rim, then the bars. The
-- portrait sits above the block, so its full ring is drawn over the bar's end.
function M:BuildFace(f)
    f.panel = CreateFrame("Frame", nil, f)
    f.panel.fill = f.panel:CreateTexture(nil, "BACKGROUND", nil, 0)
    f.panel.border = f.panel:CreateTexture(nil, "BORDER")
    f.health, f.power = Bar(f.panel), Bar(f.panel)
    local p = CreateFrame("Frame", nil, f)
    f.portrait = p
    p.ring = Circle(p, "BACKGROUND", 0)
    p.innerEdge = Circle(p, "BACKGROUND", 1)
    p.back = Circle(p, "BACKGROUND", 2)
    p.icon = p:CreateTexture(nil, "ARTWORK")
    if p.CreateMaskTexture then
        p.mask = p:CreateMaskTexture()
        p.mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        p.icon:AddMaskTexture(p.mask)
    end
    f.textLayer = CreateFrame("Frame", nil, f)
    f.textLayer:SetAllPoints()
    f.nameText, f.levelText, f.healthText, f.powerText = Text(f.textLayer), Text(f.textLayer), Text(f.textLayer), Text(f.textLayer)
    for _, text in ipairs({ f.nameText, f.levelText, f.healthText, f.powerText }) do text.lift = Text(f.textLayer, "ARTWORK") end
end

local function SetName(f, text, color)
    Write(f.nameText, text); f.nameText:SetTextColor(color[1], color[2], color[3], 1)
end

local Font, LayoutLift = Kit.Font, Kit.LayoutLift

function M:BarTexture(fdb)
    if fdb.texture == "satin" then return addon.Media:GetTexture("UnitFrameBar") or FLAT, false end
    if fdb.texture == "mode" then return FLAT, true end
    return addon.Media:GetStatusBar(fdb.texture, self.id) or FLAT, false
end

function M:ApplyLayout(f, unit)
    local fdb = self:FrameDB(unit)
    -- Scale first: the pixel size depends on the frame's effective scale.
    f:SetScale(fdb.scale / 100)
    local g = self:Geometry(fdb, self:PixelSize(f))
    f.geometry = g
    local near, far, sign = Sides(fdb)
    f:SetSize(g.width, g.height)
    local panel = f.panel
    panel:ClearAllPoints()
    panel:SetPoint("TOP" .. near, f, "TOP" .. near, sign * g.blockStart, -g.blockY)
    panel:SetPoint("BOTTOM" .. far, f, "BOTTOM" .. far, 0, g.blockY)
    panel.fill:ClearAllPoints(); panel.fill:SetAllPoints()
    Rounded(panel.fill, "UnitFrameFrame"); Tint(panel.fill, ONYX.border, 1)
    -- The black gap sits exactly one rim in; the bars sit inside it, so it
    -- also shows as the hairline between health and power.
    Rounded(panel.border, "UnitFrameFrameInner")
    panel.border:ClearAllPoints()
    panel.border:SetPoint("TOPLEFT", panel, "TOPLEFT", g.border, -g.border)
    panel.border:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -g.border, g.border)
    Tint(panel.border, ONYX.inner, 1)

    local h, pw = f.health, f.power
    h:ClearAllPoints()
    h:SetPoint("TOP" .. near, f, "TOP" .. near, sign * g.inset, -g.barsTop)
    h:SetPoint("TOP" .. far, f, "TOP" .. far, -sign * g.pad, -g.barsTop)
    h:SetHeight(g.healthHeight)
    pw:ClearAllPoints()
    pw:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -g.gap); pw:SetPoint("TOPRIGHT", h, "BOTTOMRIGHT", 0, -g.gap)
    pw:SetHeight(g.powerHeight); pw:SetShown(fdb.showPower)
    local texture, sheen = self:BarTexture(fdb)
    for _, bar in ipairs({ h, pw }) do
        bar:SetStatusBarTexture(texture)
        -- Keep the colored fill above the opaque track on every client.
        local fill = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
        if fill and fill.SetDrawLayer then fill:SetDrawLayer("ARTWORK", 0) end
        bar.bg:SetTexture(FLAT); Tint(bar.bg, ONYX.track, 1)
        bar.sheen:SetTexture(FLAT)
        bar.sheen:SetHeight(math.max(g.px, math.floor((bar == h and g.healthHeight or g.powerHeight) / (2 * g.px)) * g.px))
        Gradient(bar.sheen, { 1, 1, 1, 0.12 }, { 1, 1, 1, 0 }, 0.06)
        bar.sheen:SetShown(sheen)
    end
    f.textLayer:SetFrameLevel(h:GetFrameLevel() + 3)

    -- Round portrait above the block: full ring, black gap, dark backing, image.
    local p = f.portrait
    p:SetShown(g.portrait > 0)
    if g.portrait > 0 then
        p:ClearAllPoints(); p:SetPoint("TOP" .. near, f, "TOP" .. near, 0, -g.portraitY); p:SetSize(g.portrait, g.portrait)
        p:SetFrameLevel(h:GetFrameLevel() + 1)
        p.ring:ClearAllPoints(); p.ring:SetAllPoints(p)
        Inset(p.innerEdge, p, g.border); Tint(p.innerEdge, ONYX.inner, 1)
        Inset(p.back, p, g.pad); Tint(p.back, ONYX.track, 1)
        p.icon:ClearAllPoints(); p.icon:SetPoint("TOPLEFT", g.pad, -g.pad); p.icon:SetPoint("BOTTOMRIGHT", -g.pad, g.pad)
        if p.mask then
            p.mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            p.mask:ClearAllPoints(); p.mask:SetAllPoints(p.icon)
        end
    end
    f.textLayer:SetFrameLevel(math.max(h:GetFrameLevel(), p:GetFrameLevel()) + 2)

    -- Bar text on the portrait side clears the portrait's curve; each text
    -- then moves by its own X/Y offset.
    local function SideText(text, bar, position, dx, dy)
        text:ClearAllPoints()
        local x = position == "LEFT" and 4 or position == "RIGHT" and -4 or 0
        if position == near then x = x + sign * g.tuck end
        text:SetPoint(position, bar, position, x + dx, dy); text:SetJustifyH(position)
    end
    local path = self:FontPath(fdb)
    Font(f.nameText, fdb, fdb.nameFontSize, path, g.px); Font(f.levelText, fdb, fdb.levelFontSize, path, g.px)
    Font(f.healthText, fdb, fdb.healthFontSize, path, g.px); Font(f.powerText, fdb, fdb.powerFontSize, path, g.px)
    local hx, hy = fdb.healthTextOffsetX, fdb.healthTextOffsetY
    local lx, ly = fdb.levelOffsetX, fdb.levelOffsetY
    f.healthText:SetShown(fdb.healthText ~= "none")
    -- Level stays in the health bar beside the health text, read level first:
    -- "31 54%" right-aligned, "33 76%" from the left. A Target mirroring the
    -- Player reads health first ("54% 31"), the exact mirror image, so a level
    -- moved by its offset never lands on the health text. Alone, or beside
    -- centred text, the level sits at the bar's right.
    local level = fdb.levelStyle ~= "none"
    local position = fdb.healthTextPosition
    local grouped = level and fdb.healthText ~= "none" and position ~= "CENTER"
    local healthFirst = fdb.mirrored == true
    f.levelText:ClearAllPoints(); f.nameText:ClearAllPoints()
    if grouped and (position == "LEFT") ~= healthFirst then
        -- The level is the outer text, at the bar's edge; the health text sits inside it.
        SideText(f.levelText, h, position, hx + lx, hy + ly)
        f.healthText:ClearAllPoints()
        if position == "LEFT" then
            f.healthText:SetPoint("LEFT", f.levelText, "RIGHT", 6 - lx, -ly); f.healthText:SetJustifyH("LEFT")
        else
            f.healthText:SetPoint("RIGHT", f.levelText, "LEFT", -6 - lx, -ly); f.healthText:SetJustifyH("RIGHT")
        end
    else
        SideText(f.healthText, h, position, hx, hy)
        if grouped and position == "RIGHT" then
            f.levelText:SetPoint("RIGHT", f.healthText, "LEFT", -6 + lx, ly); f.levelText:SetJustifyH("RIGHT")
        elseif grouped then
            f.levelText:SetPoint("LEFT", f.healthText, "RIGHT", 6 + lx, ly); f.levelText:SetJustifyH("LEFT")
        elseif level then
            SideText(f.levelText, h, "RIGHT", lx, ly)
        end
    end
    if level then local c = fdb.levelColor; f.levelText:SetTextColor(c[1], c[2], c[3], 1) end
    f.levelText:SetShown(level)
    -- Plain name (no sheen or texture) in the accent, class or custom color.
    local nx, ny = fdb.nameOffsetX, fdb.nameOffsetY
    if fdb.namePosition == "bar" then
        local align = fdb.nameAlign
        f.nameText:SetPoint(align, h, align, (align == "LEFT" and 4 or align == "RIGHT" and -4 or 0) + nx, ny)
        f.nameText:SetJustifyH(align)
        f.nameText:SetWidth(fdb.barWidth * 0.6)
    else
        -- Above the frame, aligned over the bars, kept clear of the portrait.
        local clear = g.tuck > 0 and g.tuck + 4 or 0
        f.nameText:SetPoint("BOTTOMLEFT", h, "TOPLEFT", (near == "LEFT" and clear or 0) + nx, g.pad + 3 + ny)
        f.nameText:SetPoint("BOTTOMRIGHT", h, "TOPRIGHT", (near == "RIGHT" and -clear or 0) + nx, g.pad + 3 + ny)
        f.nameText:SetJustifyH(fdb.nameAlign)
    end
    f.nameText:SetShown(fdb.showName)
    SideText(f.powerText, pw, fdb.powerTextPosition, fdb.powerTextOffsetX, fdb.powerTextOffsetY)
    f.powerText:SetShown(fdb.showPower and fdb.powerText ~= "none")
    LayoutLift(f.nameText, fdb, fdb.nameFontSize, path, g.px, fdb.showName, fdb.nameAlign)
    LayoutLift(f.levelText, fdb, fdb.levelFontSize, path, g.px, level, "CENTER")
    LayoutLift(f.healthText, fdb, fdb.healthFontSize, path, g.px, fdb.healthText ~= "none", position)
    LayoutLift(f.powerText, fdb, fdb.powerFontSize, path, g.px, fdb.showPower and fdb.powerText ~= "none", fdb.powerTextPosition)
    self:PaintRing(f, unit)
end

function M:CreateDisplay()
    if self.displayCreated then return end
    self.displayCreated = true
    for _, unit in ipairs(self.units) do
        local label = self.labels[unit]
        local b = CreateFrame("Button", "ModeUI" .. label .. "UnitFrame", UIParent, "SecureUnitButtonTemplate")
        b.unit = unit
        b:SetAttribute("unit", unit); b:SetAttribute("*type1", "target"); b:SetAttribute("*type2", "togglemenu")
        b:RegisterForClicks("AnyUp"); b:SetFrameStrata("MEDIUM"); b:Hide()
        b:SetScript("OnEnter", function(button)
            if GameTooltip_SetDefaultAnchor then GameTooltip_SetDefaultAnchor(GameTooltip, button) end
            if GameTooltip and GameTooltip.SetUnit then GameTooltip:SetUnit(unit); GameTooltip:Show() end
        end)
        b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        self:BuildFace(b)
        b:SetPoint("CENTER", UIParent, "CENTER", self.defaultPositions[unit].x, self.defaultPositions[unit].y)
        self.frames[unit] = b
        self:CreateGhost(unit)
    end
end

-- Position Manager refuses protected frames, so Edit Mode moves a plain stand-in
-- and the secure button copies its anchor outside combat.
function M:CreateGhost(unit)
    local label = self.labels[unit]
    local g = CreateFrame("Frame", "ModeUI" .. label .. "UnitFramePreview", UIParent)
    g.unit, g.ghost = unit, true
    g:SetFrameStrata("HIGH")
    self:BuildFace(g)
    self:ApplyLayout(g, unit)
    -- Registration measures the frame via GetCenter, which is nil until it has an anchor;
    -- the Position Manager then moves it to the saved position.
    local default = self.defaultPositions[unit]
    g:SetPoint("CENTER", UIParent, "CENTER", default.x, default.y)
    g:Show()
    local ok, reason = addon.PositionManager:RegisterElement(self.elementIds[unit], g, { moduleId = self.id,
        defaultPosition = self.defaultPositions[unit], allowedTargets = { "screen" },
        canDrag = function() return self:FrameOn(unit) end,
        onPositionChanged = function() self:SyncPosition(unit) end })
    assert(ok, "ModeUI: unit frame position registration failed: " .. tostring(reason))
    g:Hide()
    self.ghosts[unit] = g
end

function M:SyncPosition(unit)
    local b, g = self.frames[unit], self.ghosts[unit]
    if not b or not g then return end
    if InCombatLockdown() then self.pending = true; return end
    local count = g:GetNumPoints()
    if not Number(count, 1, 10) then return end
    local px = self:PixelSize(b)
    local function Snap(v) return Number(v, -100000, 100000) and math.floor(v / px + 0.5) * px or v end
    b:ClearAllPoints()
    for i = 1, count do
        local point, relative, relativePoint, x, y = g:GetPoint(i)
        b:SetPoint(point, relative or UIParent, relativePoint, Snap(x), Snap(y))
    end
end

function M:RenderGhosts()
    if not self.ghosts then return end
    for _, unit in ipairs(self.units) do
        local g = self.ghosts[unit]
        if g then
            local show = (self.editing or self.previewing) and self:FrameOn(unit)
            if show then self:ApplyLayout(g, unit); self:PaintSample(g, unit) end
            g:SetShown(show and true or false)
        end
    end
end

-- Blends a class/reaction color toward white by the frame's Class Color
-- Softness (pastel; 0 keeps the original color).
function M:Soften(color, fdb)
    if not color then return nil end
    local t = fdb.classSoftness / 100
    if t <= 0 then return color end
    return Lighten(color, t)
end
local REACTION_COLORS = { hostile = P.hostile, neutral = P.neutral, friendly = P.green }
-- Class color for players (or Mode reaction colors when allowed), softened by
-- the frame's Class Color Softness, else nil. `fdb` defaults to the unit's frame.
function M:IdentityColor(unit, reactionOnly, fdb)
    fdb = fdb or self:FrameDB(unit)
    if not reactionOnly then
        local color = UnitColor.PlayerClass(unit)
        if color then return self:Soften({ color.r, color.g, color.b }, fdb) end
    end
    local reaction = UnitColor.Reaction(unit)
    if reaction == "tapped" then return P.tapped end
    if reaction then return self:Soften(REACTION_COLORS[reaction], fdb) end
end
-- Edit Mode/preview stand-ins show the player's own class, and an enemy for others.
function M:SampleIdentity(unit, fdb)
    return unit == "player" and self:IdentityColor("player", false, fdb) or self:Soften(P.hostile, fdb)
end

function M:HealthColor(unit, identity)
    local fdb = self:FrameDB(unit)
    local mode = fdb.healthColorMode
    if mode == "custom" then return fdb.healthColor end
    if mode == "class" then return identity or self:IdentityColor(unit) or ONYX.health end
    return ONYX.health
end
function M:NameColor(unit, identity)
    local fdb = self:FrameDB(unit)
    local mode = fdb.nameColorMode
    if mode == "custom" then return fdb.nameColor end
    if mode == "class" then return identity or self:IdentityColor(unit) or self.ACCENT end
    return self.nameAccents[mode] or self.ACCENT
end

-- Portrait ring: Class Gradient (light top, pastel class/reaction color, deeper
-- bottom), Default (the frame's slate rim) or Custom.
function M:PaintRing(f, unit)
    local fdb = self:FrameDB(unit)
    local ring, mode = f.portrait.ring, fdb.portraitRing
    if mode == "custom" then Gradient(ring, fdb.portraitRingColor, fdb.portraitRingColor); return end
    local color = mode == "class" and (f.ghost and self:SampleIdentity(unit, fdb) or self:IdentityColor(unit))
    if not color then Gradient(ring, ONYX.border, ONYX.border); return end
    Gradient(ring, Lighten(color, 0.35), Scale(color, 0.72))
end

function M:PaintPortrait(f, unit, sampleUnit)
    local fdb = self:FrameDB(unit)
    if not fdb.showPortrait then return end
    Portrait.Apply(f.portrait.icon, sampleUnit or unit, fdb.portraitStyle)
end

function M:PaintSample(g, unit)
    local fdb = self:FrameDB(unit)
    local identity = self:SampleIdentity(unit, fdb)
    local color = self:HealthColor(unit, identity)
    g.health:SetStatusBarColor(color[1], color[2], color[3])
    g.health:SetMinMaxValues(0, 100); g.health:SetValue(75)
    local power = fdb.powerColorMode == "custom" and fdb.powerColor or P.mana
    g.power:SetMinMaxValues(0, 100); g.power:SetValue(60); g.power:SetStatusBarColor(power[1], power[2], power[3])
    SetName(g, self.labels[unit] .. " Frame", self:NameColor(unit, identity))
    Write(g.levelText, "60")
    local mode = fdb.healthText
    Write(g.healthText, mode == "current" and "3,450" or mode == "both" and "3,450 · 75%" or "75%")
    local pmode = fdb.powerText
    Write(g.powerText, pmode == "current" and "1,200" or pmode == "both" and "1,200 · 60%" or "60%")
    if fdb.showPortrait then
        if unit == "player" then self:PaintPortrait(g, unit, "player") else Portrait.SetIcon(g.portrait.icon, Portrait.UNKNOWN_ICON) end
    end
end

local Health, Power, Name, Level = Domain.Health, Domain.Power, Domain.Name, Domain.Level

function M:UpdateHealth(unit)
    local f = self.frames and self.frames[unit]
    if not f or not self:FrameOn(unit) then return end
    local okMax, max, okValue, value = Health.Read(unit)
    if okMax then pcall(f.health.SetMinMaxValues, f.health, 0, max) end
    if okValue then pcall(f.health.SetValue, f.health, value) end
    local color = self:HealthColor(unit)
    f.health:SetStatusBarColor(color[1], color[2], color[3])
    local mode = self:FrameDB(unit).healthText
    if mode == "none" then return end
    local state = Health.State(unit)
    if state then Write(f.healthText, state)
    else Kit.ValueText(f.healthText, mode, Health.Percent, unit, okValue, value) end
end

function M:UpdatePower(unit)
    local f = self.frames and self.frames[unit]
    local fdb = self:FrameDB(unit)
    if not f or not self:FrameOn(unit) or not fdb.showPower then return end
    local powerType, token, okMax, max, okValue, value = Power.Read(unit)
    if okMax then pcall(f.power.SetMinMaxValues, f.power, 0, max) end
    if okValue then pcall(f.power.SetValue, f.power, value) end
    local color = fdb.powerColorMode == "custom" and fdb.powerColor
        or Power.Color(token)
    f.power:SetStatusBarColor(color[1], color[2], color[3])
    Kit.ValueText(f.powerText, fdb.powerText, function(u, curve) return Power.Percent(u, powerType, curve) end,
        unit, okValue, value)
end

function M:UpdatePortrait(unit)
    local f = self.frames and self.frames[unit]
    if not f or not self:FrameOn(unit) then return end
    self:PaintPortrait(f, unit); self:PaintRing(f, unit)
end

function M:UpdateText(unit)
    local f, fdb = self.frames[unit], self:FrameDB(unit)
    if fdb.showName then
        SetName(f, Name.Get(unit), self:NameColor(unit))
    end
    if fdb.levelStyle ~= "none" then
        Write(f.levelText, Level.Text(unit))
    end
end

function M:Update(unit)
    local f = self.frames and self.frames[unit]
    if not f or not self:FrameOn(unit) or not Portrait.Exists(unit) then return end
    self:UpdateText(unit); self:UpdateHealth(unit); self:UpdatePower(unit); self:UpdatePortrait(unit)
end
function M:UpdateAll() for _, unit in ipairs(self.units) do self:Update(unit) end end
