local _, addon = ...
local M = addon.UnitFrames
if not M then return end

-- Blizzard's own unit frames. They keep running so pets, class resources,
-- target auras and cast bars still work; ModeUI fades their art and releases
-- their clicks while a ModeUI frame that replaces them is on with Hide
-- Blizzard set. Nothing is reparented and no events are unregistered.
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
-- Blizzard's Target of Target debuff icons take the mouse for their tooltips
-- (TargetofTargetDebuffFrameTemplate, enableMouse), so a faded one lets go too.
local DEBUFFS = 4
local Number = M.Number

local function Fade(self, region, hidden)
    if hidden then
        local alpha = region:GetAlpha()
        if self.nativeAlpha[region] == nil then self.nativeAlpha[region] = Number(alpha, 0, 1) and alpha or 1 end
        self.nativeHidden[region] = true
        if not self.nativeHooks[region] and hooksecurefunc then
            self.nativeHooks[region] = true
            -- Blizzard may restore alpha later; keep the region faded while hidden.
            hooksecurefunc(region, "SetAlpha", function(r)
                if self.nativeHidden[r] and not self.fading then
                    self.fading = true; r:SetAlpha(0); self.fading = false
                end
            end)
        end
        self.fading = true; region:SetAlpha(0); self.fading = false
    else
        self.nativeHidden[region] = nil
        region:SetAlpha(self.nativeAlpha[region] or 1); self.nativeAlpha[region] = nil
    end
end

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

local function Faded(region) return type(region) == "table" and region.SetAlpha and region.GetAlpha end
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
    for region in pairs(self.nativeHidden) do if not faded[region] then Fade(self, region, false) end end
    for region in pairs(faded) do if not self.nativeHidden[region] then Fade(self, region, true) end end
    for frame in pairs(self.nativeMouse) do if not released[frame] then Release(self, frame, false) end end
    for frame in pairs(released) do if self.nativeMouse[frame] == nil then Release(self, frame, true) end end
end
