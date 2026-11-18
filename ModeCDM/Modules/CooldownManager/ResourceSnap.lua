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
-- Mode, what it hangs from), so a light check places shown bars again.
local Kit, Number = addon.Kit, addon.IsNumber
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
    Hang(frame, frame.snapX or 0, frame.snapY or 0)
    self:SnapResourceFrame(frame)
    self:WatchResourcePixels()
end

-- A frame laid out inside another (a bar in a Grouped block) leaves the check.
function M:UnsnapResourceFrame(frame) frame.snapMover, frame.snapX, frame.snapY = nil, nil, nil end

-- The check: every CHECK_EVERY seconds, each shown bar on its own stand-in
-- (the resource bars and the Cast Bar).
function M:WatchResourcePixels()
    if self.resourceSnapper then return end
    local snapper, wait = CreateFrame("Frame"), 0
    snapper:SetScript("OnUpdate", function(_, elapsed)
        wait = wait + elapsed
        if wait < CHECK_EVERY then return end
        wait = 0
        if not (M.active and M.resourceFrames) then return end
        for _, id in ipairs(M.resources) do
            local frame = M.resourceFrames[id]
            if frame and frame.snapMover and frame:IsShown() then M:SnapResourceFrame(frame) end
        end
        local cast = M.castFrame
        if cast and cast.snapMover and cast:IsShown() then M:SnapResourceFrame(cast) end
    end)
    self.resourceSnapper = snapper
end
