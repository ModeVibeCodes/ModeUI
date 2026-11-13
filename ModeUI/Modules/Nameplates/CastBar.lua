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
-- Options: the spell icon (Left, Right or Hidden), the spell name, the cast's
-- target (the caster's current target, in its class color for players) on a
-- line past the bar, and a timer with the seconds left. The timer is worked out
-- from public cast times, or read from the cast's duration object while the
-- times are secret (Domain/Cast); if neither is readable it stays empty.
local Kit, Domain = addon.Kit, addon.Domain
local Cast, UnitColor = Domain.Cast, Domain.UnitColor
local ONYX = Kit.onyx
local TIMER_STEP = 0.1

local function Snap(value, px) return math.max(px, math.floor(value / px + 0.5) * px) end

-- Builds the timer and target texts; called from BuildPlate.
function M:BuildCastTexts(plate, LiftedText)
    plate.castTimer, plate.castTarget = LiftedText(plate.textLayer), LiftedText(plate.textLayer)
end

-- Height of the target line under (or over) the cast bar, 0 when it's off.
function M:CastTargetHeight(plate)
    local db, px = self:Style(plate), plate.px or 1
    return db.castShowTarget and Snap(db.castFontSize + 2, px) or 0
end

-- Icon, bar and texts inside the cast box; called from LayoutPlate.
function M:LayoutCast(plate)
    local db, px, path = self:Style(plate), plate.px or 1, plate.fontPath
    local icon, inner, inset = plate.castIcon, Snap(db.castHeight, px), 2 * px
    local side = db.castIcon
    icon:ClearAllPoints(); icon:SetSize(inner, inner)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    plate.cast:ClearAllPoints()
    if side == "RIGHT" then
        icon:SetPoint("TOPRIGHT", plate.castBox, "TOPRIGHT", -inset, -inset)
        plate.cast:SetPoint("TOPLEFT", plate.castBox, "TOPLEFT", inset, -inset)
        plate.cast:SetPoint("BOTTOMRIGHT", icon, "BOTTOMLEFT", -px, 0)
    elseif side == "LEFT" then
        icon:SetPoint("TOPLEFT", plate.castBox, "TOPLEFT", inset, -inset)
        plate.cast:SetPoint("TOPLEFT", icon, "TOPRIGHT", px, 0)
        plate.cast:SetPoint("BOTTOMRIGHT", plate.castBox, "BOTTOMRIGHT", -inset, inset)
    else
        plate.cast:SetPoint("TOPLEFT", plate.castBox, "TOPLEFT", inset, -inset)
        plate.cast:SetPoint("BOTTOMRIGHT", plate.castBox, "BOTTOMRIGHT", -inset, inset)
    end
    icon:SetShown(side ~= "none")
    local size = db.castFontSize
    local function Place(text, justify, shown)
        Kit.Font(text, db, size, path, px)
        text:SetJustifyH(justify)
        Kit.LayoutLift(text, db, size, path, px, shown, justify)
        text:SetShown(shown)
    end
    plate.castTimer:ClearAllPoints(); plate.castTimer:SetPoint("RIGHT", plate.cast, "RIGHT", -2 * px, 0)
    Place(plate.castTimer, "RIGHT", db.castShowTimer)
    plate.castText:ClearAllPoints(); plate.castText:SetPoint("LEFT", plate.cast, "LEFT", 2 * px, 0)
    if db.castShowTimer then plate.castText:SetPoint("RIGHT", plate.castTimer, "LEFT", -2 * px, 0)
    else plate.castText:SetPoint("RIGHT", plate.cast, "RIGHT", -2 * px, 0) end
    Place(plate.castText, "LEFT", db.castShowText)
    -- The target line sits past the cast bar, away from the health bar.
    local target, above = plate.castTarget, db.castAnchor == "TOP"
    target:ClearAllPoints()
    if above then target:SetPoint("BOTTOM", plate.castBox, "TOP", 0, px)
    else target:SetPoint("TOP", plate.castBox, "BOTTOM", 0, -px) end
    target:SetWidth(plate.castBox:GetWidth())
    target:SetHeight(self:CastTargetHeight(plate))
    Place(target, "CENTER", db.castShowTarget)
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
    local bar = plate.cast
    if bar.SetReverseFill then bar:SetReverseFill(channel) end
    local fill = bar:GetStatusBarTexture()
    if channel then
        Kit.Tint(fill, ONYX.track, 1)
        Kit.ColorFromBoolean(bar.bg, notInterruptible, style.castLockedColor, style.castColor)
    else
        Kit.Tint(bar.bg, ONYX.track, 1)
        Kit.ColorFromBoolean(fill, notInterruptible, style.castLockedColor, style.castColor)
    end
    pcall(Kit.Write, plate.castText, style.castShowText and text or "")
    if not pcall(plate.castIcon.SetTexture, plate.castIcon, texture) then plate.castIcon:SetTexture(nil) end
    plate.casting = channel and "channel" or "cast"
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
    if not unit or not plate.casting then return end
    -- A secret name always means a target; a public one is a name or nil.
    local token = unit .. "target"
    local ok, name = addon.Domain.Query.Call(UnitName, token)
    if not ok or (addon.IsPublic(name) and (name == nil or name == "")) then self:PaintCastTarget(plate, nil); return end
    local class = UnitColor.PlayerClass(token)
    self:PaintCastTarget(plate, name, class and { class.r, class.g, class.b })
end

-- Seconds left: from public times, else the duration object; may be secret.
function M:UpdateCastTimer(plate)
    local info = plate.castInfo
    if not info then Kit.Write(plate.castTimer, ""); return end
    local now = Cast.Now()
    if addon.IsPublic(info.endMs) and type(info.endMs) == "number" then
        Kit.Formatted(plate.castTimer, "%.1f", math.max(0, (info.endMs - now) / 1000))
        return
    end
    local ok, remaining = Cast.Remaining(plate.unit, info.channel)
    if not (ok and pcall(Kit.Formatted, plate.castTimer, "%.1f", remaining)) then Kit.Write(plate.castTimer, "") end
end

function M:UpdateCast(plate)
    local unit, style = plate.unit, self:Style(plate)
    local info = unit and style.showCastBar and not plate.nameOnly and Cast.Read(unit)
    if not info then self:StopCast(plate); return end
    local bar = plate.cast
    bar.plate, plate.castInfo, plate.timerOn, plate.timerNext = plate, info, style.castShowTimer, 0
    pcall(bar.SetMinMaxValues, bar, info.startMs, info.endMs)
    self:PaintCast(plate, style, info.channel, info.notInterruptible, info.text, info.texture)
    self:UpdateCastTarget(plate)
    Tick(bar)
    bar:SetScript("OnUpdate", Tick)
end

function M:StopCast(plate)
    plate.casting, plate.castInfo, plate.timerOn = nil, nil, nil
    plate.cast:SetScript("OnUpdate", nil)
    Kit.Write(plate.castTarget, ""); Kit.Write(plate.castTimer, "")
    plate.castBox:Hide()
end
