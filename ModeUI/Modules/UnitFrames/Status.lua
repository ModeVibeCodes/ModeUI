local _, addon = ...
local M = addon.UnitFrames
if not M then return end

-- Status on the portrait: round badges on the ring's corners (rested, Player
-- only; combat, any frame), a red ring while the unit is in combat, and on the
-- Player a pulsing red halo while something you haven't targeted has pulled
-- you (Domain.Status.PulledUnawares). Badges are plain frames on the
-- portrait, so they show and hide in combat. Rest and combat state are plain
-- booleans on Forever; nothing secret is read.
local Kit, Status = addon.Kit, addon.Domain.Status
local ONYX, Tint = M.onyx, Kit.Tint
-- Corner angles around the portrait's centre; a right-hand portrait mirrors
-- them so the badges stay on its outer side.
local ANGLE = { topLeft = 135, topRight = 45, bottomLeft = 225, bottomRight = 315 }
local MIRROR = { topLeft = "topRight", topRight = "topLeft", bottomLeft = "bottomRight", bottomRight = "bottomLeft" }
local REST_COLOR = M.ACCENT -- Sky, like the names

local function Badge(parent, iconKey)
    local badge = CreateFrame("Frame", nil, parent)
    badge.rim = Kit.Circle(badge, "BACKGROUND", 0)
    badge.back = Kit.Circle(badge, "BACKGROUND", 1)
    badge.icon = badge:CreateTexture(nil, "ARTWORK")
    addon.Media:ApplyTexture(badge.icon, iconKey)
    badge:Hide()
    return badge
end

function M:BuildStatus(f)
    local p = f.portrait
    f.restBadge, f.combatBadge = Badge(p, "UnitFrameRested"), Badge(p, "UnitFrameCombat")
    -- The pulse: a red disc just larger than the ring, behind it, fading in and out.
    p.halo = Kit.Circle(p, "BACKGROUND", -1)
    p.halo:Hide()
    if p.halo.CreateAnimationGroup then
        local pulse = p.halo:CreateAnimationGroup()
        local fade = pulse:CreateAnimation("Alpha")
        fade:SetFromAlpha(0.15); fade:SetToAlpha(0.9); fade:SetDuration(0.55)
        pulse:SetLooping("BOUNCE")
        p.haloPulse = pulse
    end
end

local function Corner(sdb, fdb, key)
    local corner = sdb[key]
    if sdb.mirror and fdb.portraitSide == "right" then corner = MIRROR[corner] end
    return corner
end

-- Badge size is an even pixel count and its centre sits on the ring at the
-- corner's angle, snapped, so badges stay on the pixel grid.
function M:LayoutStatus(f, unit)
    local p, g = f.portrait, f.geometry
    if not f.restBadge or not g then return end
    local sdb, fdb, px = self.db[unit].status, self:FrameDB(unit), g.px
    local size = math.max(4 * px, math.floor(sdb.badgeSize / (2 * px) + 0.5) * 2 * px)
    local radius = g.portrait / 2
    for _, entry in ipairs({ { f.restBadge, "restCorner", REST_COLOR }, { f.combatBadge, "combatCorner", sdb.ringColor } }) do
        local badge, key, color = entry[1], entry[2], entry[3]
        local angle = math.rad(ANGLE[Corner(sdb, fdb, key)])
        badge:SetSize(size, size)
        badge:ClearAllPoints()
        badge:SetPoint("CENTER", p, "CENTER", math.floor(math.cos(angle) * radius / px + 0.5) * px,
            math.floor(math.sin(angle) * radius / px + 0.5) * px)
        badge.rim:ClearAllPoints(); badge.rim:SetAllPoints(badge); Tint(badge.rim, ONYX.border, 1)
        Kit.Inset(badge.back, badge, g.border); Tint(badge.back, { 11 / 255, 11 / 255, 13 / 255 }, 1)
        Kit.Inset(badge.icon, badge, g.border + 2 * px); Tint(badge.icon, color, 1)
    end
    p.halo:ClearAllPoints()
    p.halo:SetPoint("TOPLEFT", p, "TOPLEFT", -4 * px, 4 * px)
    p.halo:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 4 * px, -4 * px)
    Tint(p.halo, sdb.ringColor, 1)
end

local function SetPulse(p, on)
    p.halo:SetShown(on)
    if p.haloPulse then
        if on and not p.haloPulse:IsPlaying() then p.haloPulse:Play() elseif not on then p.haloPulse:Stop() end
    end
end

function M:UpdateStatus(unit)
    local f = self.frames and self.frames[unit]
    if not f or not f.restBadge then return end
    local sdb, fdb = self.db[unit].status, self:FrameDB(unit)
    local on = self:FrameOn(unit) and fdb.showPortrait
    local fighting = on and Status.InCombat(unit) or false
    f.restBadge:SetShown(on and unit == "player" and sdb.restIcon and Status.Resting() or false)
    f.combatBadge:SetShown(fighting and sdb.combatIcon or false)
    local red = fighting and sdb.combatRing or false
    if red ~= f.redRing then f.redRing = red; self:PaintRing(f, unit) end
    SetPulse(f.portrait, on and unit == "player" and sdb.pulse and Status.PulledUnawares() or false)
end

-- Stand-ins show where the badges go: rested on the Player, combat on every
-- frame that shows it; the ring keeps its normal color.
function M:PaintStatusSample(g, unit)
    if not g.restBadge then return end
    local sdb, fdb = self.db[unit].status, self:FrameDB(unit)
    g.restBadge:SetShown(fdb.showPortrait and unit == "player" and sdb.restIcon or false)
    g.combatBadge:SetShown(fdb.showPortrait and sdb.combatIcon or false)
    SetPulse(g.portrait, false)
end
