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

function M:UpdateCast(plate)
    local unit = plate.unit
    local info = unit and self.db.showCastBar and Cast.Read(unit)
    if not info then self:StopCast(plate); return end
    local bar, db = plate.cast, self.db
    pcall(bar.SetMinMaxValues, bar, info.startMs, info.endMs)
    if bar.SetReverseFill then bar:SetReverseFill(info.channel) end
    local fill = bar:GetStatusBarTexture()
    if info.channel then
        Kit.Tint(fill, ONYX.track, 1)
        Kit.ColorFromBoolean(bar.bg, info.notInterruptible, db.castLockedColor, db.castColor)
    else
        Kit.Tint(bar.bg, ONYX.track, 1)
        Kit.ColorFromBoolean(fill, info.notInterruptible, db.castLockedColor, db.castColor)
    end
    pcall(Kit.Write, plate.castText, info.text)
    if not pcall(plate.castIcon.SetTexture, plate.castIcon, info.texture) then plate.castIcon:SetTexture(nil) end
    plate.casting = info.channel and "channel" or "cast"
    plate.castBox:Show()
    Tick(bar)
    bar:SetScript("OnUpdate", Tick)
end

function M:StopCast(plate)
    plate.casting = nil
    plate.cast:SetScript("OnUpdate", nil)
    plate.castBox:Hide()
end
