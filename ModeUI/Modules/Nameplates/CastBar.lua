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
local Kit, Cast = addon.Kit, addon.Domain.Cast
local ONYX = Kit.onyx

local function Tick(bar) bar:SetValue(Cast.Now()) end

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
    pcall(Kit.Write, plate.castText, text)
    if not pcall(plate.castIcon.SetTexture, plate.castIcon, texture) then plate.castIcon:SetTexture(nil) end
    plate.casting = channel and "channel" or "cast"
    plate.castBox:Show()
end

function M:UpdateCast(plate)
    local unit, style = plate.unit, self:Style(plate)
    local info = unit and style.showCastBar and not plate.nameOnly and Cast.Read(unit)
    if not info then self:StopCast(plate); return end
    local bar = plate.cast
    pcall(bar.SetMinMaxValues, bar, info.startMs, info.endMs)
    self:PaintCast(plate, style, info.channel, info.notInterruptible, info.text, info.texture)
    Tick(bar)
    bar:SetScript("OnUpdate", Tick)
end

function M:StopCast(plate)
    plate.casting = nil
    plate.cast:SetScript("OnUpdate", nil)
    plate.castBox:Hide()
end
