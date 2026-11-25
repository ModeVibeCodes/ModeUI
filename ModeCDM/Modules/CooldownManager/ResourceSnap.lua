local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M then return end

-- Whole pixels (owner's first in-game look, November 18, 2026). At a UI
-- scale that isn't pixel perfect (Blizzard's default) a stand-in sits
-- between physical pixels, and a bar's 1px border rings land on half pixels:
-- faint or gone, specks at the corners (docs/DESIGN_LANGUAGE.md, "Pixel perfect").
-- A bar's frame hangs from its stand-in, nudged by under a pixel so its
-- corner sits on a whole pixel; everything inside is laid out in whole
-- pixels from there (Resources.lua). The stand-in can move by itself (Edit
-- Mode, what it hangs from), so a light check places shown bars again. The
-- cooldown bars' holders (Layout.lua) and the Swing Timer hang the same way.
local Kit, Number, L = addon.Kit, addon.IsNumber, addon.L
local CHECK_EVERY = 0.2 -- seconds between checks

-- The offset that moves `value` (UI units) onto the nearest whole pixel.
local function Nudge(value, px) return math.floor(value / px + 0.5) * px - value end

local function Hang(frame, x, y)
    local mover = frame.snapMover
    frame.snapX, frame.snapY = x, y
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", mover, "TOPLEFT", x, y)
    frame:SetPoint("BOTTOMRIGHT", mover, "BOTTOMRIGHT", x, y)
end

-- Nudges a bar's frame onto whole pixels. The stand-in's place is read from
-- the frame (the frame less its nudge): the stand-in is hidden outside Edit
-- Mode. A place the client doesn't give (nil, or secret) leaves the frame.
function M:SnapResourceFrame(frame)
    if not frame.snapMover then return end
    local px = Kit.PixelSize(frame)
    local left, bottom = frame:GetLeft(), frame:GetBottom()
    if not (Number(left) and Number(bottom) and Number(px, 0.001)) then return end
    local x, y = frame.snapX or 0, frame.snapY or 0
    local nx, ny = Nudge(left - x, px), Nudge(bottom - y, px)
    if math.abs(nx - x) < px / 100 and math.abs(ny - y) < px / 100 then return end
    Hang(frame, nx, ny)
end

-- Hangs `frame` from `mover` (the same size), on whole pixels.
function M:PlaceResourceFrame(frame, mover)
    frame.snapMover = mover
    self.snapped = self.snapped or {}
    self.snapped[frame] = true
    Hang(frame, frame.snapX or 0, frame.snapY or 0)
    self:SnapResourceFrame(frame)
    self:WatchResourcePixels()
end

-- A frame laid out inside another (a bar in a Grouped block) leaves the check.
function M:UnsnapResourceFrame(frame)
    frame.snapMover, frame.snapX, frame.snapY = nil, nil, nil
    if self.snapped then self.snapped[frame] = nil end
end

-- The check: every CHECK_EVERY seconds, each shown frame on its own
-- stand-in (the resource bars, the Cast Bar, the Swing Timer and the cooldown
-- bars' holders). It stops (hides) while the module is off and starts again
-- the next time a bar is placed.
function M:WatchResourcePixels()
    if self.resourceSnapper then self.resourceSnapper:Show(); return end
    local snapper, wait = CreateFrame("Frame"), 0
    snapper:SetScript("OnUpdate", function(frame, elapsed)
        wait = wait + elapsed
        if wait < CHECK_EVERY then return end
        wait = 0
        if not M.active then frame:Hide(); return end
        for snapped in pairs(M.snapped or {}) do
            if snapped.snapMover and snapped:IsShown() then M:SnapResourceFrame(snapped) end
        end
    end)
    self.resourceSnapper = snapper
end

-- Home's Screen line: the screen, the UI scale and whether it's pixel
-- perfect (a whole number of pixels per UI unit: 71.11% at 1080p, 53.33% at
-- 1440p, as ModeUI's UI scale sets it), and what that means for the bars.
function M:ScreenStatus()
    local Plain = addon.Domain.Query.Plain
    local width, height = Plain(GetPhysicalScreenSize)
    local px = Kit.PixelSize(UIParent)
    if not (Number(width, 320, 32768) and Number(height, 200, 32768) and Number(px, 0.01, 10)) then
        return L["The screen size isn't available yet."]
    end
    local scale, per = 768 / (height * px) * 100, 1 / px
    local perfect = 768 * math.max(1, math.floor(height / 1080)) / height * 100
    if math.abs(per - math.floor(per + 0.5)) < 0.01 then
        return string.format(L["%d x %d at UI scale %.2f%%: pixel perfect. Sizes, spacing and 1px edges are exact."], width, height, scale)
    end
    return string.format(L["%d x %d at UI scale %.2f%% (pixel perfect here is %.2f%%). Bars sit on whole pixels, edges stay 1px and sizes round to the pixel, a pixel off at most."],
        width, height, scale, perfect)
end
