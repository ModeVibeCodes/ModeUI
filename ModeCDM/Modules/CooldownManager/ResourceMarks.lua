local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M then return end

-- Tick Marks (owner, November 17, 2026): up to three static lines on Power
-- and Alternate Mana at power values you choose (40 Energy), each shown only
-- for its power type, so a Druid's Energy mark hides in Bear Form. A mark
-- sits at value / max of the bar's width. Forever documents the player's
-- maximum power as readable (UnitPowerMax is secret only for units the player
-- doesn't control); should it come secret, the last readable maximum for that
-- power type is kept, and with none known the marks hide. Only the maximum
-- and the saved values are used: the current power is never read here.
local Kit, Public, Number = addon.Kit, addon.IsPublic, addon.IsNumber

-- The marks' textures, over the bar's fill (made as they're needed).
function M:LayoutResourceMarks(frame, id)
    local style = self.db.resources[id]
    local box = frame.boxes[1]
    if not (style.marks and box) then return end
    local layer = box.markLayer
    if not layer then layer = CreateFrame("Frame", nil, box); box.markLayer = layer end
    layer:ClearAllPoints(); layer:SetAllPoints(box.bar)
    layer:SetFrameLevel(box.bar:GetFrameLevel() + 2)
    frame.marks = frame.marks or {}
    for i = 1, self.MARK_SLOTS do
        local mark = frame.marks[i]
        if not mark then mark = layer:CreateTexture(nil, "OVERLAY"); mark:SetTexture(Kit.FLAT); frame.marks[i] = mark end
        Kit.Tint(mark, style.markColor, 1)
        mark:Hide()
    end
    frame.markKey = nil
end

-- Places the marks for the power shown now: `token` (MANA, ENERGY, ...) and
-- its maximum (okMax, max from Domain.Power.ReadType; max may be secret).
-- Placed again only when the power type or its maximum changes.
function M:UpdateResourceMarks(frame, id, token, okMax, max)
    local style = self.db.resources[id]
    if not (style.marks and frame.marks) then return end
    frame.markMax = frame.markMax or {}
    local kind = type(token) == "string" and token or "?"
    if okMax and Public(max) and Number(max, 1) then frame.markMax[kind] = max end
    local top = frame.markMax[kind]
    local key = kind .. ":" .. tostring(top)
    if frame.markKey == key then return end
    frame.markKey = key
    local px, width, bar = frame.px or 1, frame.barWidth or 0, frame.boxes[1].bar
    local thick = style.markWidth * px
    for i, entry in ipairs(style.marks) do
        local mark = frame.marks[i]
        local on = top ~= nil and entry.value > 0 and entry.value < top and (entry.power == "any" or entry.power == kind)
        mark:SetShown(on)
        if on then
            local at = math.floor(width * entry.value / top / px + 0.5) * px
            if style.reverse then at = width - at end
            local x = at - math.floor(style.markWidth / 2) * px
            mark:ClearAllPoints()
            mark:SetPoint("TOPLEFT", bar, "TOPLEFT", x, 0)
            mark:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x, 0)
            mark:SetWidth(thick)
        end
    end
end
