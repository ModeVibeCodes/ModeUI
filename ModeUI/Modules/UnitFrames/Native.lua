local _, addon = ...
local M = addon.UnitFrames
if not M then return end

-- Blizzard's own unit frames. They keep running so pets, class resources,
-- target auras and cast bars still work; ModeUI fades their art and releases
-- their clicks while a ModeUI frame that replaces them is on with Hide
-- Blizzard set. Nothing is reparented and no events are unregistered. The
-- fade is shared (Shared/Kit/Native.lua, Kit.NativeFade), so ModeCDM's Cast
-- Bar can keep Blizzard's Player cast bar faded too.
--
-- `parts` are the frame's art children (faded; the frame keeps running); a
-- frame without parts fades whole. `also` are whole frames that sit on it and
-- would otherwise float on their own: Blizzard's Target of Target and Target
-- of Focus are children of the Target and Focus frames, so they fade with them
-- (Blizzard_UnitFrame TargetFrameMixin:CreateTargetofTarget). The Focus frame
-- is built from the Target frame's template, so it has the same parts.
local TARGET_PARTS = { "TargetFrameContainer", "TargetFrameContent" }
M.native = {
    player = { frame = "PlayerFrame", parts = { "PlayerFrameContainer", "PlayerFrameContent" } },
    target = { frame = "TargetFrame", parts = TARGET_PARTS, also = { "TargetFrameToT" } },
    targettarget = { frame = "TargetFrameToT" },
    focus = { frame = "FocusFrame", parts = TARGET_PARTS, also = { "FocusFrameToT" } },
    focustarget = { frame = "FocusFrameToT" },
}
M.nativeCast = { player = "PlayerCastingBarFrame", target = "TargetFrameSpellBar", focus = "FocusFrameSpellBar" }
-- Blizzard's Target of Target debuff icons take the mouse for their tooltips
-- (TargetofTargetDebuffFrameTemplate, enableMouse), so a faded one lets go too.
local DEBUFFS = 4
local Faded = addon.Kit.NativeFade.Fadable

local function Release(self, frame, released)
    if not frame.EnableMouse then return end
    if released then
        -- Remember whether it took the mouse, to give that back (true if unknown).
        local was = frame.IsMouseEnabled and frame:IsMouseEnabled()
        if not addon.IsPublic(was) or type(was) ~= "boolean" then was = true end
        self.nativeMouse[frame] = was
        frame:EnableMouse(false)
    else
        frame:EnableMouse(self.nativeMouse[frame]); self.nativeMouse[frame] = nil
    end
end

-- A whole frame (a Target of Target): faded, and it and its debuffs let go of the mouse.
local function Whole(name, faded, released)
    local frame = _G[name]
    if not Faded(frame) then return end
    faded[frame], released[frame] = true, true
    for i = 1, DEBUFFS do
        local debuff = _G[name .. "Debuff" .. i]
        if type(debuff) == "table" then released[debuff] = true end
    end
end
-- What one ModeUI frame hides: faded regions and frames whose clicks it releases.
local function Collect(spec, faded, released)
    local native = _G[spec.frame]
    if type(native) ~= "table" then return end
    if not spec.parts then Whole(spec.frame, faded, released); return end
    released[native] = true
    for _, key in ipairs(spec.parts) do
        if Faded(native[key]) then faded[native[key]] = true end
    end
    for _, name in ipairs(spec.also or {}) do Whole(name, faded, released) end
end

-- Matches Blizzard's frames to the ModeUI frames now on: a region stays faded
-- while any frame that hides it wants it hidden. Outside combat only, because
-- the native frames are protected.
function M:SyncNative()
    local faded, released = {}, {}
    for unit, spec in pairs(self.native) do
        if self:FrameOn(unit) and self.db[unit].hideBlizzard then Collect(spec, faded, released) end
    end
    -- Blizzard's combo points (Camelot ComboFrame, pinned to the Target frame's
    -- portrait) give way to ModeUI's while they are on.
    -- Blizzard's cast bars give way to a frame's own: the Player's
    -- (PlayerCastingBarFrame) and the Target and Focus spell bars, which
    -- TargetFrameMixin:CreateSpellbar names <frame>SpellBar.
    for unit, name in pairs(self.nativeCast) do
        local cast = self.db[unit].castBar
        if self:FrameOn(unit) and cast.enabled and cast.hideBlizzard and Faded(_G[name]) then faded[_G[name]] = true end
    end
    local combo = self.db.comboPoints
    if self:FrameOn("target") and combo.enabled and combo.hideBlizzard and Faded(_G.ComboFrame) then faded[_G.ComboFrame] = true end
    addon.Kit.NativeFade:Sync("unitFrames", faded)
    for frame in pairs(self.nativeMouse) do if not released[frame] then Release(self, frame, false) end end
    for frame in pairs(released) do if self.nativeMouse[frame] == nil then Release(self, frame, true) end end
end
