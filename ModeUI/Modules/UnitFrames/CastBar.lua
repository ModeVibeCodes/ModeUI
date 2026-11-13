local _, addon = ...
local M = addon.UnitFrames
if not M then return end

-- Each frame's cast bar: a second block in the frame's own skin (the same
-- rounded rim, black gap and bar texture) hanging under the bar block (or
-- sitting over it). Its far end lines up with the bar block's, its bar ends
-- where the health bar does, and its portrait end stops just short of the
-- portrait instead of running under it. Cast values can be secret: see
-- Shared/Kit/Cast.lua and Shared/Domain/Cast.lua.
local Kit, Cast = addon.Kit, addon.Domain.Cast
local ONYX, Tint = M.onyx, Kit.Tint
local TIMER_STEP = 0.1
M.CAST_SAMPLE = { text = "Frostbolt", timer = "1.4", value = 0.6 }

function M:BuildCast(f)
    local box = CreateFrame("Frame", nil, f)
    box.rim = Kit.CapRing(box, 0)
    box.gap = box:CreateTexture(nil, "BORDER")
    box.gap:SetTexture(Kit.FLAT)
    -- Masks rounding both ends: the black inside the rim, and the bar.
    box.gapMasks = { LEFT = Kit.EndMask(box), RIGHT = Kit.EndMask(box) }
    box.barMasks = { LEFT = Kit.EndMask(box), RIGHT = Kit.EndMask(box) }
    box.bar = Kit.Bar(box)
    box.icon = box:CreateTexture(nil, "ARTWORK")
    box.textLayer = CreateFrame("Frame", nil, box)
    box.textLayer:SetAllPoints(box)
    box.text, box.timer = Kit.Text(box.textLayer), Kit.Text(box.textLayer)
    for _, text in ipairs({ box.text, box.timer }) do text.lift = Kit.Text(box.textLayer, "ARTWORK") end
    box:Hide()
    f.castBox = box
end

local function Sides(fdb)
    if fdb.portraitSide == "right" then return "RIGHT", "LEFT", -1 end
    return "LEFT", "RIGHT", 1
end

function M:LayoutCast(f, unit)
    local box, g = f.castBox, f.geometry
    if not box or not g then return end
    local fdb, cdb, px = self:FrameDB(unit), self.db[unit].castBar, g.px
    local function Snap(v) return math.max(px, math.floor(v / px + 0.5) * px) end
    local function Round(v) return math.floor(v / px + 0.5) * px end
    local near, far, sign = Sides(fdb)
    local height, gap = Snap(cdb.height), Round(cdb.gap)
    -- Under (or over) the bar block, to its far edge. The portrait end stops
    -- just short of the portrait (owner, November 13, 2026): where the ring's
    -- circle crosses the box's edge nearest the portrait's centre, plus a
    -- 2px gap, rounded out to whole pixels.
    local clear = 0
    if fdb.showPortrait and g.portrait > 0 then
        local radius, edge = g.portrait / 2, g.blockHeight / 2 + gap
        if edge < radius then clear = math.ceil((math.sqrt(radius * radius - edge * edge) + 2 * px) / px) * px end
    end
    box:ClearAllPoints()
    local edge, toward, dy = "TOP", "BOTTOM", -gap
    if cdb.position == "above" then edge, toward, dy = "BOTTOM", "TOP", gap end
    if cdb.fullWidth then
        box:SetPoint(edge .. near, f.panel, toward .. near, sign * clear, dy)
        box:SetPoint(edge .. far, f.panel, toward .. far, 0, dy)
    else
        -- Bar Width, centred under the span Full Width would fill.
        box:SetPoint(edge, f.panel, toward, Round(sign * clear / 2), dy)
        box:SetWidth(Snap(cdb.width))
    end
    box.clear = clear
    box:SetHeight(height + 2 * g.pad)
    box:SetFrameLevel(f.panel:GetFrameLevel())
    -- Like the bar block: straight edges on whole pixels and half-oval ends,
    -- here at both ends. Inside the rim the box is black (the cast track is
    -- opaque); the black and the bar are rounded by end masks.
    local depth = Kit.CapDepth(height + 2 * g.pad, px)
    Kit.PlaceCapRing(box.rim, box, 0, g.border, M.RIM_COLOR, depth, { LEFT = true, RIGHT = true })
    Kit.Inset(box.gap, box, g.border); Tint(box.gap, ONYX.inner, 1)
    for side, mask in pairs(box.gapMasks) do Kit.PlaceEndMask(mask, box, side, depth, g.border, true) end
    for side, mask in pairs(box.barMasks) do Kit.PlaceEndMask(mask, box, side, depth, math.max(0, g.pad - px), true) end
    Kit.AddMasks({ box.gap }, { box.gapMasks.LEFT, box.gapMasks.RIGHT })
    box.depth = depth
    -- The bar runs end to end inside the gap, rounded with it; the icon, if
    -- any, sits where the straight part starts, a hairline of black from the bar.
    local nearInset, farInset = g.pad, g.pad
    local icon, bar = box.icon, box.bar
    icon:ClearAllPoints(); icon:SetSize(height, height); icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if cdb.icon == "near" then
        icon:SetPoint(near, box, near, sign * depth, 0); nearInset = depth + height + px
    elseif cdb.icon == "far" then
        icon:SetPoint(far, box, far, -sign * depth, 0); farInset = depth + height + px
    end
    icon:SetShown(cdb.icon ~= "none")
    bar:ClearAllPoints()
    bar:SetPoint("TOP" .. near, box, "TOP" .. near, sign * nearInset, -g.pad)
    bar:SetPoint("BOTTOM" .. far, box, "BOTTOM" .. far, -sign * farInset, g.pad)
    bar:SetFrameLevel(box:GetFrameLevel() + 1)
    -- The cast bar's own textures (Cast Bar tab).
    Kit.BarForeground(bar, cdb.foregroundTexture, height, px)
    Kit.BarBackground(bar, cdb.backgroundTexture)
    Kit.AddMasks({ bar:GetStatusBarTexture(), bar.bg, bar.sheen }, { box.barMasks.LEFT, box.barMasks.RIGHT })
    box.textLayer:SetFrameLevel(bar:GetFrameLevel() + 2)
    -- Spell name from the left, seconds left on the right, in the frame's font.
    local path, size = self:FontPath(fdb), cdb.fontSize
    for _, entry in ipairs({ { box.text, "LEFT", cdb.showText }, { box.timer, "RIGHT", cdb.showTimer } }) do
        local text, side, shown = entry[1], entry[2], entry[3]
        Kit.Font(text, fdb, size, path, px)
        text:ClearAllPoints(); text:SetPoint(side, bar, side, side == "LEFT" and 4 or -4, 0); text:SetJustifyH(side)
        text:SetShown(shown); Kit.LayoutLift(text, fdb, size, path, px, shown, side)
    end
    box.text:SetPoint("RIGHT", box.timer, "LEFT", -4, 0)
    local c = fdb.textColor
    box.text:SetTextColor(c[1], c[2], c[3], 1); box.timer:SetTextColor(c[1], c[2], c[3], 1)
end

local function Tick(bar)
    bar:SetValue(Cast.Now())
    local box = bar:GetParent()
    if not box.timerOn then return end
    local now = GetTime()
    if now < (box.timerNext or 0) then return end
    box.timerNext = now + TIMER_STEP
    Kit.CastTimer(box.timer, box.info, box.unit)
end

function M:StopCast(f)
    local box = f.castBox
    if not box then return end
    box.info, box.timerOn = nil, nil
    box.bar:SetScript("OnUpdate", nil)
    box:Hide()
end

-- Shows the unit's cast or channel, or hides the bar when it has none.
function M:UpdateCast(unit)
    local f = self.frames and self.frames[unit]
    if not f or not f.castBox then return end
    local cdb = self.db[unit].castBar
    local info = self:FrameOn(unit) and cdb.enabled and Cast.Read(unit)
    if not info then self:StopCast(f); return end
    local box, bar = f.castBox, f.castBox.bar
    box.info, box.unit, box.timerOn, box.timerNext = info, unit, cdb.showTimer, 0
    pcall(bar.SetMinMaxValues, bar, info.startMs, info.endMs)
    Kit.PaintCastBar(bar, info.channel, info.notInterruptible, cdb.color, cdb.lockedColor)
    pcall(Kit.Write, box.text, cdb.showText and info.text or "")
    if not pcall(box.icon.SetTexture, box.icon, info.texture) then box.icon:SetTexture(nil) end
    if not cdb.showTimer then Kit.Write(box.timer, "") end
    box:Show()
    Tick(bar)
    bar:SetScript("OnUpdate", Tick)
end

-- Stand-ins show a sample cast while their cast bar is on.
function M:PaintCastSample(g, unit)
    local box, cdb = g.castBox, self.db[unit].castBar
    if not box then return end
    box:SetShown(cdb.enabled)
    if not cdb.enabled then return end
    local bar = box.bar
    bar:SetMinMaxValues(0, 1); bar:SetValue(self.CAST_SAMPLE.value)
    Kit.PaintCastBar(bar, false, false, cdb.color, cdb.lockedColor)
    Kit.Write(box.text, cdb.showText and self.CAST_SAMPLE.text or "")
    Kit.Write(box.timer, cdb.showTimer and self.CAST_SAMPLE.timer or "")
    box.icon:SetTexture(addon.Domain.Portrait.UNKNOWN_ICON)
end
