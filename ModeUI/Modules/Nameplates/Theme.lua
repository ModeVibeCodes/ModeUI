local _, addon = ...
local M = addon.Nameplates
if not M then return end

-- Nameplates' part of the Mode-Obsidian theme (docs/DESIGN_LANGUAGE.md,
-- "Mode-Obsidian theme"; Shared/Runtime/Themes.lua): the empty part in
-- Mode-Obsidian Track at 85% and your focus in the Glow. Health keeps its
-- reaction colors (a gameplay meaning). Runs once per profile.
addon.Themes:Contribute("obsidian", "nameplates", function(db)
    for _, kind in ipairs({ "enemy", "friendly" }) do
        local style = db[kind]
        if type(style) == "table" then
            style.backgroundTexture, style.backgroundOpacity = "media:Mode-Obsidian Track", 85
            style.focusStyle = "glow"
            addon.Themes.DefaultMetal(style)
        end
    end
end)
