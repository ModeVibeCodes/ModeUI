local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M then return end

-- The Cast Bar (CastInit.lua): its stand-in (the Edit Mode element
-- ModeUICastBar) and, on it, the bar: a box (status bar, Comet spark) and
-- the icon's box, each in the resource bars' edge (drawn in pieces, Style.Edge)
-- outside it; the frame hangs on whole pixels (ResourceSnap.lua). Cast values
-- can be secret: the cast's times go only to SetMinMaxValues, its name to
-- SetText, its icon to SetTexture and its interruptibility to
-- SetVertexColorFromBoolean (Shared/Kit/Cast.lua, Shared/Domain/Cast.lua).
local Kit, L, Style = addon.Kit, addon.L, addon.Style
local Tone, Cast, UnitColor = Style.Tone, addon.Domain.Cast, addon.Domain.UnitColor
local PM = addon.PositionManager
local PAD = 4 -- pixels between a text and the end of the bar
local TIMER_STEP = 0.1
M.CAST_SAMPLE = { text = "Frostbolt", timer = "1.4", value = 0.6 }

-- Frames ------------------------------------------------------------------------

function M:NewCastFrame(parent)
    local frame = CreateFrame("Frame", nil, parent)
    local box = CreateFrame("Frame", nil, frame)
    box.bar = Kit.Bar(box)
    box.comet = Style.Comet(box.bar)
    box.edge = Style.Edge(box, M.EDGE, { pieces = true })
    box.bar.castFrame = frame
    frame.box = box
    local icon = CreateFrame("Frame", nil, frame)
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints(icon); icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon.edge = Style.Edge(icon, M.EDGE, { pieces = true })
    frame.icon = icon
    frame.textLayer = CreateFrame("Frame", nil, frame)
    frame.textLayer:SetAllPoints(frame)
    frame.name, frame.timer = Kit.Text(frame.textLayer), Kit.Text(frame.textLayer)
    for _, text in ipairs({ frame.name, frame.timer }) do text.lift = Kit.Text(frame.textLayer, "ARTWORK") end
    return frame
end

-- The bar's width: what it hangs from with Match Width on (Edit Mode), else
-- its own Width; whole pixels. Read fresh outside combat; the last kept.
function M:CastWidth(px)
    local style = self.db.castBar
    local width = style.width
    if style.matchWidth then
        if not addon.InCombat() then
            local live = PM:GetAnchorWidth(self.CAST_ELEMENT)
            self.castAnchorWidth = addon.IsNumber(live, 1, 10000) and live or nil
        end
        width = self.castAnchorWidth or width
    end
    return math.max(px, math.floor(width / px + 0.5) * px)
end

-- Lays a cast frame out at `width` (edges included) and returns its height.
-- The icon (Left or Right) is a square of the bar's height in its own edge,
-- Icon Gap from the bar's edge; the bar takes the rest.
function M:LayoutCastFrame(frame, width, px)
    local style = self.db.castBar
    local function Round(v) return math.floor(v / px + 0.5) * px end
    local h, reach = M.ResourceBarHeight(style, px), M.ResourceReach(style, px)
    local edged, iconOn = style.border ~= "none", style.icon ~= "none"
    local iconOuter = iconOn and h + 2 * reach or 0
    local gap = iconOn and Round(style.iconGap) or 0
    local barWidth = math.max(px, width - iconOuter - gap - 2 * reach)
    local barX = (style.icon == "left" and iconOuter + gap or 0) + reach
    local box, bar = frame.box, frame.box.bar
    box:ClearAllPoints(); box:SetPoint("TOPLEFT", frame, "TOPLEFT", barX, -reach); box:SetSize(barWidth, h)
    box:SetFrameLevel(frame:GetFrameLevel() + 1)
    bar:ClearAllPoints(); bar:SetAllPoints(box); bar:SetFrameLevel(box:GetFrameLevel() + 1)
    Kit.BarForeground(bar, style.barTexture, h, px)
    Kit.BarBackground(bar, style.barBackground, barWidth, h, px)
    local fill = bar:GetStatusBarTexture()
    if fill and fill.ClearTextureSlice then fill:ClearTextureSlice() end
    box.comet:Layout(false, px)
    -- The edge over the spark (its head stands a pixel past the bar).
    box.edge:SetRim(style.edgeSize); box.edge:SetStyle(style.edgeStyle, style.edgeMetal); box.edge:SetShown(edged); box.edge:Layout(); box.edge:SetLevel(3)
    local icon = frame.icon
    icon:SetShown(iconOn)
    if iconOn then
        local x = style.icon == "left" and reach or width - iconOuter + reach
        icon:ClearAllPoints(); icon:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -reach); icon:SetSize(h, h)
        icon:SetFrameLevel(frame:GetFrameLevel() + 1)
        icon.edge:SetRim(style.edgeSize); icon.edge:SetStyle(style.edgeStyle, style.edgeMetal); icon.edge:SetShown(edged); icon.edge:Layout()
    end
    self:LayoutCastTexts(frame, style, px)
    frame.px, frame.barHeight, frame.channel, frame.rimKey = px, h, nil, nil
    return h + 2 * reach
end

-- Spell Name and Timer: each at its anchor on the bar (Left, Center or
-- Right; PAD pixels in from an end), moved by its offsets. Nothing is
-- measured: the name can be secret.
function M:LayoutCastTexts(frame, style, px)
    local look = { outline = style.outline, shadow = style.shadow, slug = style.slug, textColor = style.textColor }
    local path, size = Style.Weighted(Kit.FontPath(style, self.id), "bold"), style.textSize
    local function Snap(v) return math.floor(v / px + 0.5) * px end
    for _, part in ipairs({ { frame.name, "name" }, { frame.timer, "timer" } }) do
        local text, key = part[1], part[2]
        local anchor = style[key .. "Anchor"]
        local dx = (anchor == "LEFT" and PAD * px) or (anchor == "RIGHT" and -PAD * px) or 0
        Kit.Font(text, look, size, path, px)
        text:ClearAllPoints()
        text:SetPoint(anchor, frame.box, anchor, dx + Snap(style[key .. "X"]), Snap(style[key .. "Y"]))
        text:SetJustifyH(anchor)
        text:SetShown(style[key .. "Show"])
        Kit.LayoutLift(text, look, size, path, px, false, anchor)
    end
    frame.textLayer:SetFrameLevel(frame:GetFrameLevel() + 6)
end

-- Paint -------------------------------------------------------------------------

-- Bar Mode Dark: the fill in darkFill; else your class color (Bar Color:
-- Class Color) or Bar Color (Custom).
function M:CastColor()
    local style = self.db.castBar
    local class = style.barColorMode == "class" and UnitColor.PlayerClass("player")
    return class and { class.r, class.g, class.b } or style.barColor
end
function M:CastFillColor()
    return self.db.castBar.barMode == "dark" and Tone.darkFill or self:CastColor()
end
-- The text: Text Color in Color mode; in Dark, Class Color, Bar Color or Custom.
function M:CastTextColor()
    local style = self.db.castBar
    if style.barMode ~= "dark" then return style.textColor end
    if style.darkText == "custom" then return style.darkTextColor end
    if style.darkText == "class" then
        local class = UnitColor.PlayerClass("player")
        if class then return { class.r, class.g, class.b } end
    end
    return style.barColor
end

-- Colors a cast: a channel drains (the bar fills from the right in the
-- background color over the cast color behind it); Not Interruptible takes
-- its own color through SetVertexColorFromBoolean (the flag may be secret).
-- Dark mode shows the Comet head alone. Rim Color and the texts too.
function M:PaintCastFrame(frame, channel, notInterruptible)
    local style, box = self.db.castBar, frame.box
    local bar, color = box.bar, self:CastFillColor()
    local fill, back = bar:GetStatusBarTexture(), Kit.BarBackgroundColor(style.barBackground)
    if bar.SetReverseFill then bar:SetReverseFill(channel) end
    if channel then
        Kit.Tint(fill, back, 1)
        Kit.ColorFromBoolean(bar.bg, notInterruptible, style.lockedColor, color)
    else
        Kit.Tint(bar.bg, back, style.barBackgroundOpacity / 100)
        Kit.ColorFromBoolean(fill, notInterruptible, style.lockedColor, color)
    end
    if frame.channel ~= channel then frame.channel = channel; box.comet:Layout(channel, frame.px) end
    box.comet:SetShown(style.spark)
    box.comet:SetTrail(style.barMode ~= "dark")
    box.comet:SetColor(self:CastColor())
    local tint = (style.rimColor == "bar" and self:CastColor()) or (style.rimColor == "custom" and style.rimCustom) or nil
    local key = tint and string.format("%.3f,%.3f,%.3f", tint[1], tint[2], tint[3]) or "metal"
    if frame.rimKey ~= key then
        frame.rimKey = key
        box.edge:SetTint(tint); frame.icon.edge:SetTint(tint)
    end
    local c = self:CastTextColor()
    frame.name:SetTextColor(c[1], c[2], c[3], 1); frame.timer:SetTextColor(c[1], c[2], c[3], 1)
end

-- A sample cast (Edit Mode and the preview): `value` of 0-1 filled.
function M:PaintCastSample(frame, value)
    local style, bar = self.db.castBar, frame.box.bar
    bar:SetScript("OnUpdate", nil)
    bar:SetMinMaxValues(0, 1); bar:SetValue(value or self.CAST_SAMPLE.value)
    self:PaintCastFrame(frame, false, false)
    Kit.Write(frame.name, self.CAST_SAMPLE.text)
    Kit.Write(frame.timer, style.timerShow and self.CAST_SAMPLE.timer or "")
    frame.icon.texture:SetTexture(addon.Domain.Portrait.UNKNOWN_ICON)
end

-- Running -----------------------------------------------------------------------

local function Tick(bar)
    bar:SetValue(Cast.Now())
    local frame = bar.castFrame
    if not frame.timerOn then return end
    local now = GetTime()
    if now < (frame.timerNext or 0) then return end
    frame.timerNext = now + TIMER_STEP
    Kit.CastTimer(frame.timer, frame.info, "player")
end

-- Show Interrupted: the held bar fades over its last CAST_HOLD_FADE seconds.
local function HoldTick(bar)
    local frame = bar.castFrame
    local left = (frame.heldUntil or 0) - GetTime()
    if left <= 0 then
        frame.heldUntil = nil
        M:UpdateCast()
        return
    end
    frame:SetAlpha(M.db.castBar.opacity / 100 * math.min(1, left / Kit.CAST_HOLD_FADE))
end

function M:StopCast()
    local frame = self.castFrame
    if not frame then return end
    frame.info, frame.timerOn, frame.heldUntil = nil, nil, nil
    frame.box.bar:SetScript("OnUpdate", nil)
    frame:Hide()
end

-- Holds the cast the bar shows as interrupted: full, in the Interrupted
-- color, "Interrupted" for its name. Nothing here reads the cast.
function M:HoldCast()
    local frame, style = self.castFrame, self.db.castBar
    local bar = frame.box.bar
    frame.info, frame.timerOn = nil, nil
    frame.heldUntil = GetTime() + Kit.CAST_HOLD + Kit.CAST_HOLD_FADE
    if bar.SetReverseFill then bar:SetReverseFill(false) end
    bar:SetMinMaxValues(0, 1); bar:SetValue(1)
    Kit.Tint(bar:GetStatusBarTexture(), style.interruptedColor, 1)
    -- A held bar is full: no spark.
    frame.box.comet:SetShown(false)
    Kit.Write(frame.name, INTERRUPTED or L["Interrupted"]); Kit.Write(frame.timer, "")
    frame:SetAlpha(style.opacity / 100)
    bar:SetScript("OnUpdate", HoldTick)
end

-- Shows the player's cast or channel; else, in Edit Mode, a sample; else
-- hides. A held interrupt stays until its fade ends.
function M:UpdateCast()
    local frame = self.castFrame
    if not frame then return end
    local style = self.db.castBar
    local on = self.active == true and style.show
    self:ClaimCast(on)
    if not on then self:StopCast(); return end
    local info = Cast.Read("player")
    if not info then
        if frame.heldUntil then return end
        self:StopCast()
        if self.editing then
            self:PaintCastSample(frame)
            frame:SetAlpha(style.opacity / 100); frame:Show()
        end
        return
    end
    local bar = frame.box.bar
    frame.info, frame.timerOn, frame.timerNext, frame.heldUntil = info, style.timerShow, 0, nil
    pcall(bar.SetMinMaxValues, bar, info.startMs, info.endMs)
    self:PaintCastFrame(frame, info.channel, info.notInterruptible)
    if not pcall(Kit.Write, frame.name, info.text) then Kit.Write(frame.name, "") end
    if not pcall(frame.icon.texture.SetTexture, frame.icon.texture, info.texture) then frame.icon.texture:SetTexture(nil) end
    if not style.timerShow then Kit.Write(frame.timer, "") end
    frame:SetAlpha(style.opacity / 100)
    frame:Show()
    Tick(bar)
    bar:SetScript("OnUpdate", Tick)
end

-- The player's cast events; a client without empowered casts lacks those.
local EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" }
local OPTIONAL = { "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_UPDATE", "UNIT_SPELLCAST_EMPOWER_STOP" }

function M:OnCastEvent(event, _, ...)
    if not self.active then return end
    local frame = self.castFrame
    if frame and frame.info and self.db.castBar.showInterrupted and Kit.CastInterrupted(event, ...) then self:HoldCast(); return end
    self:UpdateCast()
end

function M:SetCastEvents(on)
    local frame = self.castEvents
    if not frame then
        if not on then return end
        frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", function(_, event, ...) self:OnCastEvent(event, ...) end)
        self.castEvents = frame
    end
    if frame.on == on then return end
    frame.on = on
    for _, event in ipairs(EVENTS) do
        if on then frame:RegisterUnitEvent(event, "player") else frame:UnregisterEvent(event) end
    end
    for _, event in ipairs(OPTIONAL) do
        if on then pcall(frame.RegisterUnitEvent, frame, event, "player") else pcall(frame.UnregisterEvent, frame, event) end
    end
end

-- The player's cast bar is this one's while it's on: Unit Frames' Player
-- cast bar steps aside (Kit.PlayerCast) and Blizzard's stays faded
-- (Kit.NativeFade), outside combat; a change in combat waits for its end.
function M:ClaimCast(on)
    on = on and true or false
    if self.castClaimed ~= on then
        self.castClaimed = on
        Kit.PlayerCast.Claim(self.id, on)
    end
    self:SyncCastNative()
end
function M:SyncCastNative()
    local want = self.castClaimed == true
    if self.castFaded == want then return end
    if addon.InCombat() then self.castNativeWaiting = true; return end
    self.castNativeWaiting, self.castFaded = nil, want
    local regions, blizzard = {}, _G.PlayerCastingBarFrame
    if want and Kit.NativeFade.Fadable(blizzard) then regions[blizzard] = true end
    Kit.NativeFade:Sync(self.id, regions)
end

-- Stand-in ------------------------------------------------------------------------

-- Built with the module's other frames on first enable.
function M:BuildCast()
    if self.castFrame then return end
    local style = self.db.castBar
    local mover = CreateFrame("Frame", self.CAST_FRAME, UIParent)
    mover:SetFrameStrata("HIGH")
    mover:SetSize(style.width, style.height)
    mover.fill = mover:CreateTexture(nil, "BACKGROUND", nil, -8)
    mover.fill:SetAllPoints(); mover.fill:SetTexture(Kit.FLAT); Kit.Tint(mover.fill, Kit.palette.accent, 0.18)
    mover:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    self.castMover = mover
    local ok, reason = PM:RegisterElement(self.CAST_ELEMENT, mover, { moduleId = self.id,
        defaultPosition = self.castPosition, anyTarget = true, gapPixels = 1,
        canDrag = function() return self.active == true and self.db.castBar.show end,
        label = L[self.CAST_LABEL] })
    assert(ok, "ModeUI: cast bar position registration failed: " .. tostring(reason))
    PM:SetSizeMatch(self.CAST_ELEMENT, {
        axes = { width = true },
        get = function() return self.db.castBar.matchWidth end,
        set = function(_, on) return self:SetCastOption("matchWidth", on == true) end,
    })
    PM:SetAnchorSizeListener(self.CAST_ELEMENT, function(_, width)
        self.castAnchorWidth = addon.IsNumber(width, 1, 10000) and width or nil
        if self.active then self:LayoutCast() end
    end)
    mover:Hide()
    local frame = self:NewCastFrame(UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetAllPoints(mover)
    frame:Hide()
    self.castFrame = frame
    -- Buff Icons hang above the cast bar now; find it.
    PM:Refresh(true)
end

-- Sizes the stand-in and lays the bar out on whole pixels, then shows the cast.
function M:LayoutCast()
    local frame, mover = self.castFrame, self.castMover
    if not frame then return end
    local style = self.db.castBar
    local px = Kit.PixelSize(mover)
    local width = self:CastWidth(px)
    mover:SetSize(width, M.ResourceBarHeight(style, px) + 2 * M.ResourceReach(style, px))
    self:PlaceResourceFrame(frame, mover)
    self:LayoutCastFrame(frame, width, px)
    self:UpdateCast()
end

-- In ModeUI's Edit Mode the stand-in shows while the bar is on, with a sample.
function M:RenderCastMover()
    local mover = self.castMover
    if not mover then return end
    local show = self.editing == true and self.active == true and self.db.castBar.show
    PM:SetEditable(self.CAST_ELEMENT, show)
    mover:SetShown(show)
    self:UpdateCast()
end

-- A saved Buff Icons place still at its old default (above Essential, where
-- the cast bar sits now) moves above the cast bar (version 8, once).
function M:MoveBuffIconsForCast()
    local positions = addon.db and addon.db.positions
    local place, old = type(positions) == "table" and positions[self.ElementId("buffIcon")], self.OLD_BUFF_ICON_POSITION
    if type(place) == "table" and place.target == old.target and place.placement == old.placement
        and place.x == 0 and place.y == 0 and place.point == nil then
        place.target = self.CAST_ELEMENT
    end
end

-- Everything again: after a settings change, a new scale, on and off.
function M:RefreshCast()
    if not self.castFrame then return end
    if self.active then self:LayoutCast() end
    self:RenderCastMover()
end

-- Status line for the page.
function M:CastStatus()
    if not self.active then return L["Off. Turn the Cooldown Manager on (the switch at the top) to use the cast bar."] end
    if not self.db.castBar.show then return L["This bar is off. Unit Frames' Player cast bar shows your casts."] end
    return L["Shows your casts. Unit Frames' Player cast bar and Blizzard's stay hidden while it's on."]
end
