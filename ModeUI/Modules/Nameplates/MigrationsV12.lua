local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- Version 11 -> 12, the nameplates pass (owner, November 23, 2026;
-- docs/NAMEPLATES.md, "Settings versions"). A value still equal to its old
-- default takes the new one; anything the player picked stays. Called from
-- Initialize (Migrations.lua) on detached copies too, so nothing here touches
-- frames.
local function Copy(value) return addon.ProfileCodec.Copy(value) end
local Style = addon.Style
local Same, Legacy = Style.SameColor, Style.LEGACY

function M.MigrateV11(db)
    for _, kind in ipairs(M.kinds) do
        local style, defaults = db[kind], M.styleDefaults[kind]
        if type(style) == "table" and addon.IsPublic(style) then
            -- Every Mode cast bar: the old amber and gray take light blue and orange-red.
            if Same(style.castColor, Legacy.palette.neutral) then style.castColor = Copy(defaults.castColor) end
            if Same(style.castLockedColor, Legacy.palette.tapped) then style.castLockedColor = Copy(defaults.castLockedColor) end
        end
    end
end
