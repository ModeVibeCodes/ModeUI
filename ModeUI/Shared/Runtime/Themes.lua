local _, addon = ...

-- Themes (docs/DESIGN_LANGUAGE.md, "Mode-Obsidian theme"; plan and log in
-- docs/OBSIDIAN.md). A profile's `theme` is "blizz" (Mode-Blizz: every
-- profile without the key) or "obsidian". Style draws borders, tokens and
-- the typeface by the active profile's theme; each module may add a part
-- that sets its own defaults for a theme, once per profile:
--   addon.Themes:Contribute("obsidian", moduleId, function(db) ... end)
-- `db` is the module's settings, already checked by its Initialize. A part
-- runs the first time a profile with that theme is checked with the module
-- installed (profile.themeParts[moduleId] remembers it), so whatever the
-- player changes afterwards stays. A part never touches another module's
-- settings.
local T = { parts = {}, labels = {} }
addon.Themes = T

T.DEFAULT = "blizz"
T.ORDER = { "obsidian", "blizz" }
T.labels = { blizz = "Mode-Blizz", obsidian = "Mode-Obsidian" }
-- The profile the first start makes (a copy of the active profile).
T.PROFILE_NAME = "Mode-Obsidian"

function T:Valid(theme) return theme == nil or self.labels[theme] ~= nil end
function T:Label(theme) return self.labels[theme] or self.labels[self.DEFAULT] end

function T:Contribute(theme, moduleId, fn)
    assert(self.labels[theme] and theme ~= self.DEFAULT, "ModeUI: unknown theme " .. tostring(theme))
    assert(type(moduleId) == "string" and type(fn) == "function", "ModeUI: Themes:Contribute(theme, moduleId, fn).")
    self.parts[theme] = self.parts[theme] or {}
    assert(not self.parts[theme][moduleId], "ModeUI: " .. moduleId .. " already adds to the " .. theme .. " theme")
    self.parts[theme][moduleId] = fn
end

-- Runs a module's part for the profile's theme once (ValidateProfile and a
-- companion's late start call it after the module's own Initialize).
function T:CatchUp(profile, moduleId, db)
    local theme = type(profile) == "table" and profile.theme
    if theme == nil or theme == self.DEFAULT or type(db) ~= "table" then return end
    if type(profile.themeParts) ~= "table" then profile.themeParts = {} end
    if profile.themeParts[moduleId] == theme then return end
    local part = self.parts[theme] and self.parts[theme][moduleId]
    if not part then return end
    part(db)
    profile.themeParts[moduleId] = theme
end

-- The first start with themes (once per account, root.builtThemes): a fresh
-- account's only profile takes Mode-Obsidian; an account that has profiles
-- gets a copy of its active profile, "Mode-Obsidian", in the theme, made
-- active, and keeps the old one as it was (the owner's guard against
-- wanting to go back). Runs before the active profile is checked.
local function UniqueName(root, base)
    if not root.profiles[base] then return base end
    local index = 2
    while root.profiles[base .. " (" .. index .. ")"] do index = index + 1 end
    return base .. " (" .. index .. ")"
end
function T:Seed(root, fresh)
    if type(root.builtThemes) ~= "table" then root.builtThemes = {} end
    if root.builtThemes.obsidian then return end
    root.builtThemes.obsidian = true
    local source = root.activeProfile
    local profile = root.profiles[source]
    if type(profile) ~= "table" then return end
    if fresh then
        profile.theme = "obsidian"
        self.seeded = { to = source }
        return
    end
    if profile.theme == "obsidian" then return end
    local ok, copy = pcall(addon.ProfileCodec.Copy, profile)
    if ok and type(copy) == "table" then
        copy.theme, copy.themeParts = "obsidian", {}
        copy = addon.Database:ValidateProfile(copy)
    else copy = nil end
    if not copy then
        -- Kept as it was; tried again at the next start.
        root.builtThemes.obsidian = nil
        self.seeded = { failed = source }
        return
    end
    local name = UniqueName(root, self.PROFILE_NAME)
    root.profiles[name] = copy
    root.activeProfile = name
    root.previousProfile = source
    self.seeded = { from = source, to = name }
end

-- Says once, after login, what the first start did and how to go back.
function T:Announce()
    local seeded = self.seeded
    if not seeded then return end
    self.seeded = nil
    if seeded.failed then
        addon:PrintAction("Mode-Obsidian couldn't be set up from " .. seeded.failed .. "; kept it as it was.", "themes")
    elseif seeded.from then
        addon:PrintAction("New look: Mode-Obsidian. Your settings were copied to the profile " .. seeded.to
            .. ". To go back, choose " .. seeded.from .. " in /modeui, Profiles, and reload.", "themes")
    end
end
addon.Events:On(T, "PLAYER_LOGIN", function() T:Announce() end)

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
