local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- Cast bars. Cast times can be secret, so the bar is never computed in Lua:
-- SetMinMaxValues takes the cast's start and end, and every frame the bar is
-- given the current time, which the client clamps and draws.
-- A channel drains instead of filling: the bar fills from the right in the
-- track color over the cast color behind it, so the colored part shrinks.
-- Interruptibility may be secret and only picks a color through
-- SetVertexColorFromBoolean (see Kit.ColorFromBoolean).
--
-- Options: the spell icon (Left, Right, outside either side, or None), the spell name, the cast's
-- target (the caster's current target, in its class color for players) on a
-- line past the bar, and a timer with the seconds left. The timer is worked out
-- from public cast times, or read from the cast's duration object while the
-- times are secret (Domain/Cast); if neither is readable it stays empty.
--
-- An interrupted cast stays on the bar, full, in the Interrupted color and
-- with "Interrupted" for its spell name, then fades: the hold Blizzard's own
-- cast bars play (CastingBarFrameAnimsTemplate HoldFadeOutAnim, 1s and a 0.3s
-- fade).
local Kit, Domain, Style = addon.Kit, addon.Domain, addon.Style
local RIM = Style.EDGE_PRESETS.frameThin.rim
local Cast, UnitColor = Domain.Cast, Domain.UnitColor
local TIMER_STEP = 0.1
M.CAST_HOLD, M.CAST_HOLD_FADE = Kit.CAST_HOLD, Kit.CAST_HOLD_FADE
-- The timer's room on a line it shares with the spell name, in font sizes.
M.CAST_TIMER_EMS = 2.5

local function Snap(value, px) return math.max(px, math.floor(value / px + 0.5) * px) end

-- Builds the timer and target texts; called from BuildPlate.
function M:BuildCastTexts(plate, LiftedText)
    plate.castTimer, plate.castTarget = LiftedText(plate.textLayer), LiftedText(plate.textLayer)
end

-- The cast texts: spell name, timer and target, each with its switch, anchor
-- and offsets. Left, Center and Right sit inside the bar; Top and Bottom
-- anchors sit outside it.
M.castTexts = {
    { key = "castText", show = "castShowText", region = "castText" },
    { key = "castTimer", show = "castShowTimer", region = "castTimer" },
    { key = "castTarget", show = "castShowTarget", region = "castTarget" },
}

-- Room the cast texts outside the bar take: on the side toward the health
-- bar (near) and away from it (far), one text line each when used.
function M:CastTextRoom(plate)
    local db, px = self:Style(plate), plate.px or 1
    local line, farSide = Snap(db.castFontSize + 2, px), db.castAnchor == "TOP" and "^TOP" or "^BOTTOM"
    local near, far = 0, 0
    for _, text in ipairs(M.castTexts) do
        local anchor = db[text.key .. "Anchor"]
        if db[text.show] and (anchor:find("^TOP") or anchor:find("^BOTTOM")) then
            if anchor:find(farSide) then far = line else near = line end
        end
    end
    return near, far
end

-- Icon, bar and texts inside the cast box; called from LayoutPlate.
function M:LayoutCast(plate)
    local db, px, path = self:Style(plate), plate.px or 1, plate.fontPath
    local icon, inner, inset = plate.castIcon, Snap(db.castHeight, px), RIM * px
    local side = db.castIcon
    local ix, iy = math.floor(db.castIconX / px + 0.5) * px, math.floor(db.castIconY / px + 0.5) * px
    icon:ClearAllPoints(); icon:SetSize(inner, inner)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    plate.cast:ClearAllPoints()
    if side == "OUTLEFT" or side == "OUTRIGHT" then
        -- Outside the box, as tall as the box.
        local full = plate.castBox:GetHeight()
        icon:SetSize(full, full)
        if side == "OUTLEFT" then icon:SetPoint("RIGHT", plate.castBox, "LEFT", -2 * px + ix, iy)
        else icon:SetPoint("LEFT", plate.castBox, "RIGHT", 2 * px + ix, iy) end
        plate.cast:SetPoint("TOPLEFT", plate.castBox, "TOPLEFT", inset, -inset)
        plate.cast:SetPoint("BOTTOMRIGHT", plate.castBox, "BOTTOMRIGHT", -inset, inset)
    elseif side == "RIGHT" then
        icon:SetPoint("TOPRIGHT", plate.castBox, "TOPRIGHT", -inset + ix, -inset + iy)
        plate.cast:SetPoint("TOPLEFT", plate.castBox, "TOPLEFT", inset, -inset)
        plate.cast:SetPoint("BOTTOMRIGHT", plate.castBox, "BOTTOMRIGHT", -inset - inner - px, inset)
    elseif side == "LEFT" then
        icon:SetPoint("TOPLEFT", plate.castBox, "TOPLEFT", inset + ix, -inset + iy)
        plate.cast:SetPoint("TOPLEFT", plate.castBox, "TOPLEFT", inset + inner + px, -inset)
        plate.cast:SetPoint("BOTTOMRIGHT", plate.castBox, "BOTTOMRIGHT", -inset, inset)
    else
        plate.cast:SetPoint("TOPLEFT", plate.castBox, "TOPLEFT", inset, -inset)
        plate.cast:SetPoint("BOTTOMRIGHT", plate.castBox, "BOTTOMRIGHT", -inset, inset)
    end
    icon:SetShown(side ~= "none")
    -- The Comet spark rides the fill's leading edge (a channel's on its left).
    plate.comet:Layout(plate.casting == "channel", px)
    local size = db.castFontSize
    -- Cast texts in Urbanist Bold (another font keeps its one weight).
    local bold = Style.Weighted(path, "bold")
    local function Place(text, justify, shown)
        Kit.Font(text, db, size, bold, px)
        text:SetJustifyH(justify)
        Kit.LayoutLift(text, db, size, bold, px, shown, justify)
        text:SetShown(shown)
    end
    local line, boxWidth = Snap(size + 2, px), plate.castBox:GetWidth()
    local function Round(v) return math.floor(v / px + 0.5) * px end
    for _, entry in ipairs(M.castTexts) do
        local text, anchor = plate[entry.region], db[entry.key .. "Anchor"]
        local h = anchor:find("LEFT") and "LEFT" or anchor:find("RIGHT") and "RIGHT" or ""
        local dx, dy = Round(db[entry.key .. "X"]), Round(db[entry.key .. "Y"])
        text:ClearAllPoints()
        if anchor:find("^TOP") then
            text:SetPoint("BOTTOM" .. h, plate.castBox, "TOP" .. h, dx, px + dy); text:SetWidth(boxWidth)
        elseif anchor:find("^BOTTOM") then
            text:SetPoint("TOP" .. h, plate.castBox, "BOTTOM" .. h, dx, -px + dy); text:SetWidth(boxWidth)
        else
            local point = h == "" and "CENTER" or h
            local x = h == "LEFT" and 2 * px or h == "RIGHT" and -2 * px or 0
            text:SetPoint(point, plate.cast, point, x + dx, dy)
            text:SetWidth(math.max(px, plate.cast:GetWidth() - 4 * px))
        end
        text:SetHeight(line)
        Place(text, h == "" and "CENTER" or h, db[entry.show])
    end
    -- A spell name on the left and a timer on the right, both inside, share the
    -- line: the name stops short of the room the timer takes. The timer text
    -- spans the bar and may be secret (so it can't be measured); its room comes
    -- from the font size, wide enough for "00.0".
    if db.castShowTimer and db.castTextAnchor == "LEFT" and db.castTimerAnchor == "RIGHT" then
        local room = Snap(size * M.CAST_TIMER_EMS, px)
        local right = -2 * px + Round(db.castTimerX) - room - 2 * px
        plate.castText:SetPoint("RIGHT", plate.cast, "RIGHT", right, Round(db.castTextY))
    end
end

local function Tick(bar)
    bar:SetValue(Cast.Now())
    local plate = bar.plate
    if not plate or not plate.timerOn then return end
    local now = GetTime()
    if now < (plate.timerNext or 0) then return end
    plate.timerNext = now + TIMER_STEP
    M:UpdateCastTimer(plate)
end

-- Colors, text and icon for a cast; shared with the preview.
function M:PaintCast(plate, style, channel, notInterruptible, text, texture)
    Kit.PaintCastBar(plate.cast, channel, notInterruptible, style.castColor, style.castLockedColor)
    pcall(Kit.Write, plate.castText, style.castShowText and text or "")
    if not pcall(plate.castIcon.SetTexture, plate.castIcon, texture) then plate.castIcon:SetTexture(nil) end
    plate.casting = channel and "channel" or "cast"
    plate.comet:Layout(channel, plate.px)
    plate.comet:SetColor(style.castColor)
    plate.comet:SetShown(true)
    plate.castBox:Show()
end

-- The target line: a name (may be secret) and its color, or nothing.
function M:PaintCastTarget(plate, name, color)
    local db = self:Style(plate)
    if not db.castShowTarget or name == nil then Kit.Write(plate.castTarget, ""); return end
    pcall(Kit.Write, plate.castTarget, name)
    local c = color or db.textColor
    plate.castTarget:SetTextColor(c[1], c[2], c[3], 1)
end

function M:UpdateCastTarget(plate)
    local unit = plate.unit
    if not unit or not plate.castInfo then return end
    -- A secret name always means a target; a public one is a name or nil.
    local token = unit .. "target"
    local ok, name = addon.Domain.Query.Call(UnitName, token)
    if not ok or (addon.IsPublic(name) and (name == nil or name == "")) then self:PaintCastTarget(plate, nil); return end
    local class = UnitColor.PlayerClass(token)
    self:PaintCastTarget(plate, name, class and { class.r, class.g, class.b })
end

-- Seconds left: from public times, else the duration object; may be secret.
function M:UpdateCastTimer(plate) Kit.CastTimer(plate.castTimer, plate.castInfo, plate.unit) end

-- The bar and the spell name (the only text a held bar shows) fade together.
local function HoldAlpha(plate, alpha)
    plate.castBox:SetAlpha(alpha); plate.castText:SetAlpha(alpha); plate.castText.lift:SetAlpha(alpha)
end

local function HoldTick(bar)
    local plate = bar.plate
    local left = (plate.castHeldUntil or 0) - GetTime()
    if left <= 0 then M:StopCast(plate); return end
    HoldAlpha(plate, math.min(1, left / M.CAST_HOLD_FADE))
end

-- Holds the cast the bar shows as interrupted. Nothing here reads the cast.
function M:HoldCast(plate)
    local style, bar = self:Style(plate), plate.cast
    plate.casting, plate.castInfo, plate.timerOn = "held", nil, nil
    plate.castHeldUntil = GetTime() + M.CAST_HOLD + M.CAST_HOLD_FADE
    if bar.SetReverseFill then bar:SetReverseFill(false) end
    bar:SetMinMaxValues(0, 1); bar:SetValue(1)
    Kit.Tint(bar:GetStatusBarTexture(), style.castInterruptedColor, 1)
    Kit.Tint(bar.bg, Style.Tone.slate, 1)
    -- A held bar is full: no spark.
    plate.comet:SetShown(false)
    Kit.Write(plate.castText, style.castShowText and (INTERRUPTED or "Interrupted") or "")
    Kit.Write(plate.castTimer, ""); Kit.Write(plate.castTarget, "")
    HoldAlpha(plate, 1)
    bar:SetScript("OnUpdate", HoldTick)
end

-- Cast events: `...` is the payload after the unit (castGUID, spellID, ...);
-- what counts as an interrupt is shared (Kit.CastInterrupted).
function M:OnCastEvent(plate, event, ...)
    if plate.castInfo and Kit.CastInterrupted(event, ...) then self:HoldCast(plate); return end
    self:UpdateCast(plate)
end

function M:UpdateCast(plate)
    local unit, style = plate.unit, self:Style(plate)
    local info = unit and style.showCastBar and not plate.nameOnly and Cast.Read(unit)
    -- The stop event that follows an interrupt leaves the held bar alone.
    if not info and plate.casting == "held" and unit and style.showCastBar and not plate.nameOnly then return end
    if not info then self:StopCast(plate); return end
    local bar = plate.cast
    bar.plate, plate.castInfo, plate.timerOn, plate.timerNext = plate, info, style.castShowTimer, 0
    plate.castHeldUntil = nil
    HoldAlpha(plate, 1)
    pcall(bar.SetMinMaxValues, bar, info.startMs, info.endMs)
    self:PaintCast(plate, style, info.channel, info.notInterruptible, info.text, info.texture)
    self:UpdateCastTarget(plate)
    Tick(bar)
    bar:SetScript("OnUpdate", Tick)
end

function M:StopCast(plate)
    plate.casting, plate.castInfo, plate.timerOn, plate.castHeldUntil = nil, nil, nil, nil
    plate.cast:SetScript("OnUpdate", nil)
    HoldAlpha(plate, 1)
    -- The cast texts sit on the plate's text layer, not in the cast box, so
    -- hiding the box leaves them drawn: clear them, or the last spell name
    -- stays under the plate (and follows it to the next unit it shows).
    Kit.Write(plate.castText, ""); Kit.Write(plate.castTarget, ""); Kit.Write(plate.castTimer, "")
    plate.castBox:Hide()
end
