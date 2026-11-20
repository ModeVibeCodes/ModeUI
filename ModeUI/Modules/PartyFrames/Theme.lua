local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- Party Frames' part of the Mode-Obsidian theme (docs/DESIGN_LANGUAGE.md,
-- "Mode-Obsidian theme"; Shared/Runtime/Themes.lua): dark health (darkFill in
-- Mode-Obsidian over Mode-Obsidian Track at 85%), the same track under power,
-- Backlit dispels (the gradient rising from the bottom), and the Prism glow
-- on mouseover and focus in place of the white mouse tint. Runs once per
-- profile; the player's later changes stay.
local TRACK = "media:Mode-Obsidian Track"
addon.Themes:Contribute("obsidian", "partyFrames", function(db)
    db.healthColorMode = "default"
    db.foregroundTexture, db.backgroundTexture, db.backgroundOpacity = "media:Mode-Obsidian", TRACK, 85
    db.powerBackgroundTexture, db.powerBackgroundOpacity = TRACK, 85
    db.dispelFrom = "bottom"
    db.hoverGlow, db.focusGlow, db.hoverHighlight = true, true, false
    addon.Themes.DefaultMetal(db)
end)
