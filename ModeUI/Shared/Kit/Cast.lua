local _, addon = ...
local Kit = addon.Kit

-- Cast bar pieces shared by every module with cast bars. Cast times can be
-- secret, so a bar is never computed in Lua: SetMinMaxValues takes the cast's
-- start and end, and each frame the bar is given the current time
-- (Domain.Cast.Now), which the client clamps and draws.

-- Colors a cast bar (from Kit.Bar). A channel drains instead of filling: the
-- bar fills from the right in the track color over the cast color behind it.
-- Interruptibility may be secret and only picks a color through
-- SetVertexColorFromBoolean (Kit.ColorFromBoolean).
function Kit.PaintCastBar(bar, channel, notInterruptible, color, lockedColor)
    if bar.SetReverseFill then bar:SetReverseFill(channel) end
    local fill, track = bar:GetStatusBarTexture(), Kit.onyx.track
    if channel then
        Kit.Tint(fill, track, 1)
        Kit.ColorFromBoolean(bar.bg, notInterruptible, lockedColor, color)
    else
        Kit.Tint(bar.bg, track, 1)
        Kit.ColorFromBoolean(fill, notInterruptible, lockedColor, color)
    end
end

-- Writes the seconds left of `info` (from Domain.Cast.Read) to `text`: from
-- public cast times, else the cast's duration object (may be secret); empty
-- if neither is readable.
function Kit.CastTimer(text, info, unit)
    if not info then Kit.Write(text, ""); return end
    local Cast = addon.Domain.Cast
    if addon.IsPublic(info.endMs) and type(info.endMs) == "number" then
        Kit.Formatted(text, "%.1f", math.max(0, (info.endMs - Cast.Now()) / 1000))
        return
    end
    local ok, remaining = Cast.Remaining(unit, info.channel)
    if not (ok and pcall(Kit.Formatted, text, "%.1f", remaining)) then Kit.Write(text, "") end
end
