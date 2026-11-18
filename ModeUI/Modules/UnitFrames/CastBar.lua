local _, addon = ...
local M = addon.UnitFrames
if not M then return end

-- Each frame's cast bar (docs/DESIGN_LANGUAGE.md, "Unit frames"): a block in
-- the 1px frameThin border, black inside, 2px under the bar block (or over
-- it). Its far edge lines up with the bar block's and its portrait end starts
-- where the portrait's ring ends; the Comet spark rides the fill's edge. Cast
-- values can be secret: see Shared/Kit/Cast.lua and Shared/Domain/Cast.lua.
local Kit, Cast, Style = addon.Kit, addon.Domain.Cast, addon.Style
local TIMER_STEP = 0.1
M.CAST_SAMPLE = { text = "Frostbolt", timer = "1.4", value = 0.6 }

function M:BuildCast(f)
    local box = CreateFrame("Frame", nil, f)
    -- Black inside the 1px rim; the border covers its own corners.
    box.inner = CreateFrame("Frame", nil, box)
    box.gap = box:CreateTexture(nil, "BORDER")
    Style.ApplyAsset(box.gap, "Solid")
    box.bar = Kit.Bar(box)
    box.comet = Style.Comet(box.bar)
    box.edge = Style.Edge(box.inner, "frameThin")
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
    -- Under (or over) the bar block, to its far edge; with a portrait it
    -- starts where the ring ends (the ring is centred on the block's edge).
    local clear = (fdb.showPortrait and g.portrait > 0) and g.portrait / 2 or 0
    box:ClearAllPoints()
    -- The gap is clear space between the two borders' shadow rings (1px each).
    local away = gap + 2 * px
    local edge, toward, dy = "TOP", "BOTTOM", -away
    if cdb.position == "above" then edge, toward, dy = "BOTTOM", "TOP", away end
    if cdb.fullWidth then
        box:SetPoint(edge .. near, f.panel, toward .. near, sign * clear, dy)
        box:SetPoint(edge .. far, f.panel, toward .. far, 0, dy)
    else
        -- Bar Width, centred under the span Full Width would fill.
        box:SetPoint(edge, f.panel, toward, Round(sign * clear / 2), dy)
        box:SetWidth(Snap(cdb.width))
    end
    box.clear = clear
    -- One pixel of rim (frameThin) round the bar.
    local rim = px
    box:SetHeight(height + 2 * rim)
    box:SetFrameLevel(f.panel:GetFrameLevel())
    box.inner:ClearAllPoints()
    box.inner:SetPoint("TOPLEFT", box, "TOPLEFT", rim, -rim); box.inner:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -rim, rim)
    box.gap:ClearAllPoints(); box.gap:SetAllPoints(box.inner); Style.Paint(box.gap, Style.Tone.shadow)
    local depth = rim
    box.depth = depth
    -- The bar runs end to end inside the rim; the icon, if any, sits at one
    -- end, a pixel of black from the bar.
    local nearInset, farInset = rim, rim
    local icon, bar = box.icon, box.bar
    icon:ClearAllPoints(); icon:SetSize(height, height); icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if cdb.icon == "near" then
        icon:SetPoint(near, box, near, sign * depth, 0); nearInset = depth + height + px
    elseif cdb.icon == "far" then
        icon:SetPoint(far, box, far, -sign * depth, 0); farInset = depth + height + px
    end
    icon:SetShown(cdb.icon ~= "none")
    bar:ClearAllPoints()
    bar:SetPoint("TOP" .. near, box, "TOP" .. near, sign * nearInset, -rim)
    bar:SetPoint("BOTTOM" .. far, box, "BOTTOM" .. far, -sign * farInset, rim)
    bar:SetFrameLevel(box:GetFrameLevel() + 1)
    -- The cast bar's own textures (Cast Bar tab); the empty part on Slate.
    Kit.BarForeground(bar, cdb.foregroundTexture, height, px)
    Kit.BarBackground(bar, cdb.backgroundTexture)
    Kit.Tint(bar.bg, Kit.BarBackgroundColor(cdb.backgroundTexture), 1)
    -- The Comet spark, in the cast color lightened.
    box.comet:Layout(false, px)
    box.comet:SetColor(cdb.color)
    box.edge.holder:SetFrameLevel(bar:GetFrameLevel() + 2)
    box.edge:Layout()
    box.textLayer:SetFrameLevel(box.edge.holder:GetFrameLevel() + 1)
    -- Spell name from the left, seconds left on the right, in the frame's font.
    -- Cast text in Bold when the font is Geist.
    local path, size = addon.Style.Weighted(self:FontPath(fdb), "bold"), cdb.fontSize
    -- The cast bar's own Outline (on by default), so its text reads over the
    -- fill and the spark.
    local style = setmetatable({ outline = cdb.outline or fdb.outline }, { __index = fdb })
    for _, entry in ipairs({ { box.text, "LEFT", cdb.showText }, { box.timer, "RIGHT", cdb.showTimer } }) do
        local text, side, shown = entry[1], entry[2], entry[3]
        Kit.Font(text, style, size, path, px)
        text:ClearAllPoints(); text:SetPoint(side, bar, side, side == "LEFT" and 4 or -4, 0); text:SetJustifyH(side)
        text:SetShown(shown); Kit.LayoutLift(text, style, size, path, px, shown, side)
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

-- Whether another module draws this unit's cast bar now: the Player's steps
-- aside while ModeCDM's Cast Bar is on (Kit.PlayerCast).
function M:CastClaimed(unit) return unit == "player" and Kit.PlayerCast.ClaimedBy(self.id) ~= nil end

-- Shows the unit's cast or channel, or hides the bar when it has none.
function M:UpdateCast(unit)
    local f = self.frames and self.frames[unit]
    if not f or not f.castBox then return end
    local cdb = self.db[unit].castBar
    local info = self:FrameOn(unit) and cdb.enabled and not self:CastClaimed(unit) and Cast.Read(unit)
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
    local shown = cdb.enabled and not self:CastClaimed(unit)
    box:SetShown(shown)
    if not shown then return end
    local bar = box.bar
    bar:SetMinMaxValues(0, 1); bar:SetValue(self.CAST_SAMPLE.value)
    Kit.PaintCastBar(bar, false, false, cdb.color, cdb.lockedColor)
    Kit.Write(box.text, cdb.showText and self.CAST_SAMPLE.text or "")
    Kit.Write(box.timer, cdb.showTimer and self.CAST_SAMPLE.timer or "")
    box.icon:SetTexture(addon.Domain.Portrait.UNKNOWN_ICON)
end
