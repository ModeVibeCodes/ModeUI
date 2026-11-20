local _, addon = ...
local M = addon.UnitFrames
if not M then return end

-- Unit Frames' part of the Mode-Obsidian theme (docs/DESIGN_LANGUAGE.md,
-- "Mode-Obsidian theme"; Shared/Runtime/Themes.lua): dark health (darkFill in
-- Mode-FG over Mode-BG at 85%), the same track under power
-- and casts, names in the solid class or reaction color, the portrait ring in
-- the class color, and the Prism glow on mouseover (always on the Focus
-- frame). Runs once per profile; the player's later changes stay.
local TRACK, FILL = "media:Mode-BG", "media:Mode-FG"
addon.Themes:Contribute("obsidian", "unitFrames", function(db)
    for _, unit in ipairs(M.units) do
        local fdb = db[unit]
        if type(fdb) == "table" then
            fdb.healthColorMode = "default"
            fdb.foregroundTexture, fdb.backgroundTexture, fdb.barBackgroundOpacity = FILL, TRACK, 85
            fdb.powerBackgroundTexture, fdb.powerBackgroundOpacity = TRACK, 85
            fdb.nameColorMode = "class"
            fdb.portraitRing = "class"
            fdb.prismGlow = unit == "focus" and "always" or "hover"
            addon.Themes.DefaultMetal(fdb)
            addon.Themes.DefaultMetal(fdb, "portraitRingMetal")
            if type(fdb.castBar) == "table" then fdb.castBar.backgroundTexture = TRACK end
        end
    end
end)
