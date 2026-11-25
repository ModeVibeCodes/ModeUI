local _, addon = ...
local M = addon.Optimizations
if not M then return end

-- Reading and writing game settings (CVars), remembering the game's own value
-- so it can be put back, and detecting the screen for the UI scale.
local Number, Read = addon.IsNumber, addon.Domain.Query.Read

-- Game settings --------------------------------------------------------------

function M:GetCVar(name)
    local value = C_CVar and Read(C_CVar.GetCVar, name)
    if value == nil and type(GetCVar) == "function" then value = Read(GetCVar, name) end
    if type(value) == "string" then return value end
end

-- Writes a game setting the client lets addons change; reports what happened.
function M:WriteCVar(name, value)
    value = tostring(value)
    local current = self:GetCVar(name)
    if current == nil then return false, "Not available in this client." end
    -- Already so: nothing to write, even where the game locks the setting
    -- (putting back Forever's secure useUiScale, which ModeUI never changed).
    local a, b = tonumber(current), tonumber(value)
    if current == value or (a and b and math.abs(a - b) < 0.001) then return true end
    if C_CVar and C_CVar.GetCVarInfo then
        local _, _, _, _, locked, secure, readOnly = Read(C_CVar.GetCVarInfo, name)
        if locked == true or secure == true or readOnly == true then return false, "The game doesn't allow addons to change this." end
    end
    local set = C_CVar and C_CVar.SetCVar or SetCVar
    if type(set) ~= "function" or Read(set, name, value) == false then return false, "The game didn't accept this setting." end
    local result = self:GetCVar(name)
    a = tonumber(result)
    if result == value or (a and b and math.abs(a - b) < 0.001) then return true end
    return false, "The game kept " .. tostring(result) .. "."
end

-- want ~= nil: remember the game's value once, then set want.
-- want == nil: put back the remembered value, if ModeUI changed it.
function M:Manage(name, want)
    local originals = addon.root.optimizationOriginals
    if want ~= nil then
        if originals[name] == nil then
            local current = self:GetCVar(name)
            if current == nil then return false, "Not available in this client." end
            originals[name] = current
        end
        return self:WriteCVar(name, want)
    end
    local original = originals[name]
    if original == nil then return true, "untouched" end
    local ok, reason = self:WriteCVar(name, original)
    if ok then originals[name] = nil; return true, "restored" end
    return false, reason
end

-- Detection ------------------------------------------------------------------

function M:Resolution()
    local width, height = Read(GetPhysicalScreenSize)
    if Number(width, 320, 32768) and Number(height, 200, 32768) then return width, height end
end

-- Pixel perfect: a whole number of screen pixels per UI unit, the UI being
-- 768 units tall. One pixel per unit up to 2159 pixels tall (1080p: 71.11%,
-- 1440p: 53.33%); two from 2160 (4K: 71.11%, as at 1080p), so the interface
-- stays a readable size. Returns the scale in percent, the screen's height
-- and the pixels per unit; nil while the game can't report the screen.
function M:SuggestedScale()
    local _, height = self:Resolution()
    if not height then return end
    local per = math.max(1, math.floor(height / 1080))
    local scale = 768 * per / height * 100
    if scale < self.ranges.uiScale[1] or scale > self.ranges.uiScale[2] then
        scale = math.max(self.ranges.uiScale[1], math.min(self.ranges.uiScale[2], scale))
    end
    return scale, height, per
end
function M:RecommendedScale() return (self:SuggestedScale()) end

-- 1080p Size (owner, November 24, 2026): the interface the size it is on a
-- 1080p screen, on any screen: 1080 UI units tall, 71.11%. On 1080p and 4K
-- that is pixel perfect too; on 1440p a UI unit is 1.33 pixels, and ModeUI's
-- borders and bars still land on whole pixels (Kit.PixelSize, Style.SnapEdges).
M.SIZE_1080 = 768 / 1080 * 100
-- The scale the General page's card offers: 1080p Size while that's the
-- choice, else Pixel Perfect. Returns the scale, the screen's height and the mode.
function M:ScreenScale()
    local scale, height = self:SuggestedScale()
    if not scale then return end
    if self.db.scaleMode == "size1080" then return self.SIZE_1080, height, "size1080" end
    return scale, height, "auto"
end

function M:DesiredScale()
    if self.db.scaleMode == "auto" then return self:RecommendedScale() end
    if self.db.scaleMode == "size1080" then return self:SuggestedScale() and self.SIZE_1080 or nil end
    return self.db.uiScale
end
