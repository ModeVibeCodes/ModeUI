local _, addon = ...

-- The look (docs/DESIGN_LANGUAGE.md, "Mode-Obsidian theme"; history in
-- docs/OBSIDIAN.md). Since November 20, 2026 Mode-Obsidian is the only look:
-- the Mode-Blizz look was retired (its art is in archive/mode-blizz/). A
-- profile's `theme` is always "obsidian" (Shared/Runtime/DB.lua sets it; an
-- older profile may still say "blizz" or nothing). Each module may add a part
-- that moves its own settings from the Mode-Blizz defaults to Mode-Obsidian's,
-- once per profile:
--   addon.Themes:Contribute("obsidian", moduleId, function(db) ... end)
-- `db` is the module's settings, already checked by its Initialize. A part
-- runs the first time a profile is checked with the module installed
-- (profile.themeParts[moduleId] remembers it), so whatever the player changes
-- afterwards stays. A part never touches another module's settings.
local T = { parts = {} }
addon.Themes = T

T.DEFAULT = "obsidian"
T.ORDER = { "obsidian" }
-- "blizz" is only read (a profile from before November 20, 2026).
T.labels = { obsidian = "Mode-Obsidian", blizz = "Mode-Blizz" }

function T:Valid(theme) return theme == nil or self.labels[theme] ~= nil end
function T:Label(theme) return self.labels[theme] or self.labels[self.DEFAULT] end

function T:Contribute(theme, moduleId, fn)
    assert(theme == self.DEFAULT, "ModeUI: unknown theme " .. tostring(theme))
    assert(type(moduleId) == "string" and type(fn) == "function", "ModeUI: Themes:Contribute(theme, moduleId, fn).")
    self.parts[theme] = self.parts[theme] or {}
    assert(not self.parts[theme][moduleId], "ModeUI: " .. moduleId .. " already adds to the " .. theme .. " theme")
    self.parts[theme][moduleId] = fn
end

-- Runs a module's part once for a profile (ValidateProfile and a companion's
-- late start call it after the module's own Initialize).
function T:CatchUp(profile, moduleId, db)
    if type(profile) ~= "table" or type(db) ~= "table" then return end
    profile.theme = self.DEFAULT
    if type(profile.themeParts) ~= "table" then profile.themeParts = {} end
    if profile.themeParts[moduleId] == self.DEFAULT then return end
    local part = self.parts[self.DEFAULT] and self.parts[self.DEFAULT][moduleId]
    if not part then return end
    part(db)
    profile.themeParts[moduleId] = self.DEFAULT
end

-- For parts: a border's metal back to its style's own ("default"), so every
-- border draws in the theme's metal (Mode-Obsidian's champagne and soft top
-- row; a layout's Steel or Gunmetal would tint them gray).
function T.DefaultMetal(t, key)
    key = key or "edgeMetal"
    if type(t) == "table" and t[key] ~= nil then t[key] = "default" end
end

-- For parts: a saved color still at its Mode-Blizz default takes the
-- Mode-Obsidian value of the same token (Style/Tone.lua); a color the player
-- chose stays.
function T.SwapColor(t, key, group, role)
    local Style = addon.Style
    if type(t) ~= "table" or type(t[key]) ~= "table" then return end
    local old, new = Style.BlizzTone(group, role), Style.ObsidianTone(group, role)
    if old and new and Style.SameColor(t[key], old) then t[key] = new end
end
