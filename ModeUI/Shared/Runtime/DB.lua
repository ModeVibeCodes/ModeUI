local _, addon = ...

-- ModeUIDB holds account data plus named profiles of ModeUI settings:
--   ModeUIDB = { schemaVersion = 2, activeProfile = "Default", pendingProfile = nil,
--                profiles = { Default = { modules = {}, positions = {}, globalMedia = {} } },
--                window = { x, y }, importedFrom, mediaRegistry, optimizationOriginals }
-- Unknown keys are preserved, and invalid data stops startup instead of being reset.
local SCHEMA_VERSION = 2
local D = {}
addon.Database = D

-- Account-wide keys; everything else in a schema 1 table belonged to the profile.
D.accountKeys = { schemaVersion = true, profiles = true, activeProfile = true, pendingProfile = true,
    failedProfile = true, window = true, importedFrom = true, mediaRegistry = true, optimizationOriginals = true,
    -- Built-in layouts already made into a profile once (Shared/Runtime/Layouts.lua).
    builtLayouts = true,
    -- Themes the first start already set up, and the profile that was active
    -- before (Shared/Runtime/Themes.lua).
    builtThemes = true, previousProfile = true }
D.accountDefaults = { window = { x = 0, y = 0 }, profiles = {}, optimizationOriginals = {}, builtLayouts = {}, builtThemes = {} }
D.profileDefaults = {
    -- Shared media read by the Mode widgets and the unit frames' "Use Global
    -- Setting" choices. ModeUI has no page to change them yet.
    globalMedia = { font = "game", texture = "default", border = "thin", overrides = {} },
    modules = {},
    positions = {},
    -- Edit Mode's Match Width and Match Height picks (Placement/SizeMatch.lua).
    sizeMatches = {},
    -- The typeface step this profile's fonts are at (see Typeface below).
    typeface = 3,
    -- The look (docs/DESIGN_LANGUAGE.md, "Mode-Obsidian theme"): "blizz" or
    -- "obsidian", and the modules whose part of that theme already ran
    -- (Shared/Runtime/Themes.lua).
    theme = "blizz",
    themeParts = {},
}
-- The keys a profile may contain (import/export accept nothing else).
D.profileKeys = { globalMedia = true, modules = true, positions = true, sizeMatches = true, typeface = true, theme = true,
    themeParts = true }

-- Typeface step 2 (November 15, 2026, the owner's decision): the Mode font is
-- "Mode" (Expressway when the client has it, else Geist; Style/Fonts.lua).
-- Every saved font still at the old default, "Mode Geist", becomes "Mode",
-- in every module's settings (a spell's own text look included); a font the
-- player picked stays. Runs after the modules' own migrations, which may
-- have just moved an older default to "Mode Geist".
-- Typeface step 3 (November 15, 2026, Phase 8): the bundled Lato is gone
-- (decision 4), so a saved "ModeUI Lato" becomes "Mode" too, and a global
-- interface font still at Lato goes back to the default.
local OLD_TYPEFACES = { ["Mode Geist"] = 2, ["ModeUI Lato"] = 3 }
local function Typeface(node, depth, from)
    if type(node) ~= "table" or depth > 12 then return end
    for key, value in pairs(node) do
        local step = key == "fontMedia" and OLD_TYPEFACES[value]
        if step and step > from then node[key] = addon.Style.FONT_DEFAULT
        elseif type(value) == "table" then Typeface(value, depth + 1, from) end
    end
end
D.DEFAULT_PROFILE = "Default"

local function Copy(value) return addon.ProfileCodec.Copy(value) end
D.Copy = Copy

local function ApplyDefaults(target, source, path)
    for key, value in pairs(source) do
        if target[key] == nil then
            target[key] = Copy(value)
        elseif type(value) == "table" then
            assert(type(target[key]) == "table", "ModeUI: invalid saved setting " .. path .. "." .. key .. "; settings were not reset.")
            ApplyDefaults(target[key], value, path .. "." .. key)
        end
    end
end

-- A detached, normalized copy of a profile, or nil and a reason. Every
-- registered module fills its defaults and validates its own settings.
function D:ValidateProfile(source)
    local ok, result = pcall(function()
        assert(type(source) == "table", "Profile must be a table.")
        local profile = Copy(source)
        local typeface = profile.typeface
        assert(typeface == nil or typeface == 1 or typeface == 2 or typeface == 3, "Invalid typeface step.")
        assert(addon.Themes:Valid(profile.theme), "Invalid theme.")
        assert(profile.themeParts == nil or type(profile.themeParts) == "table", "Invalid theme parts.")
        ApplyDefaults(profile, self.profileDefaults, "profile")
        for _, id in ipairs(addon.moduleOrder) do
            local module = addon.modules[id]
            if profile.modules[id] == nil then profile.modules[id] = {} end
            local db = profile.modules[id]
            assert(type(db) == "table", "Invalid module settings: " .. id)
            if db.enabled == nil then db.enabled = module.defaultEnabled ~= false end
            assert(type(db.enabled) == "boolean", "Invalid module enable state: " .. id)
            if module.alwaysOn then db.enabled = true end
            -- Adopt(db, modules): a module that takes over settings another
            -- module kept (Buffs & Debuffs, the Player frame's auras from
            -- Unit Frames) reads them here, by saved key, before its own
            -- validation. It writes only its own `db`, once.
            if module.Adopt then module.Adopt(db, profile.modules) end
            if module.Initialize then module.Initialize(db) end
            -- The module's part of the profile's theme, once (Themes.lua).
            addon.Themes:CatchUp(profile, id, db)
        end
        assert(type(profile.positions) == "table", "Invalid positions.")
        assert(addon.PositionManager.ValidSizeMatches(profile.sizeMatches), "Invalid size matches.")
        local from = typeface or 1
        if from < 3 then
            Typeface(profile.modules, 0, from)
            if profile.globalMedia.font == "media:ModeUI Lato" then profile.globalMedia.font = "game" end
            profile.typeface = 3
        end
        return profile
    end)
    if ok then return result end
    return nil, tostring(result):gsub("^[^:]*:%d+: ", ""):sub(1, 240)
end

-- A profile from defaults, in the active profile's theme (a new profile
-- made while Mode-Obsidian is in use is Mode-Obsidian too).
function D:NewProfile()
    local theme = type(addon.db) == "table" and addon.db.theme or nil
    return self:ValidateProfile({ theme = theme ~= "blizz" and theme or nil })
end

-- Schema 1 kept one flat settings table; it becomes the Default profile.
local function MigrateV1(root)
    local profile = {}
    for key, value in pairs(root) do
        if not D.accountKeys[key] then profile[key] = value end
    end
    for key in pairs(profile) do root[key] = nil end
    root.profiles = { [D.DEFAULT_PROFILE] = profile }
    root.activeProfile = D.DEFAULT_PROFILE
end

-- Copies one module's settings and position keys from a PTG profile into db.
-- Only a copy that passes ModeUI's own validation and migration is kept.
local function ImportModule(id, module, profile, db)
    local source = type(profile.modules) == "table" and profile.modules[id]
    if type(source) ~= "table" or type(module.Initialize) ~= "function" then return false end
    local ok, copy = pcall(Copy, source)
    if not ok or type(copy) ~= "table" or not pcall(module.Initialize, copy) then return false end
    db.modules = type(db.modules) == "table" and db.modules or {}
    db.modules[id] = copy
    db.positions = type(db.positions) == "table" and db.positions or {}
    local positions = type(profile.positions) == "table" and profile.positions or {}
    for _, key in ipairs(type(module.ptgImport.positions) == "table" and module.ptgImport.positions or {}) do
        if type(positions[key]) == "table" and db.positions[key] == nil then
            local okPosition, position = pcall(Copy, positions[key])
            if okPosition then db.positions[key] = position end
        end
    end
    return true
end

-- Play The Game Tools carried some modules before ModeUI (Unit Frames). A
-- module that declares `ptgImport = { positions = { ... } }` in its Init.lua
-- is copied once, the first time ModeUI starts with none of those modules
-- saved yet: its settings from the active PTG profile (same module ID) and
-- the listed position keys. PTGToolsDB is only read.
local function ImportFromPlayTheGameTools(root, db)
    if root.importedFrom ~= nil then return end
    local importing = {}
    for _, id in ipairs(addon.moduleOrder) do
        if type(addon.modules[id].ptgImport) == "table" then
            if type(db.modules) == "table" and db.modules[id] ~= nil then return end
            importing[#importing + 1] = id
        end
    end
    root.importedFrom = "none"
    local ptg = PTGToolsDB
    if type(ptg) ~= "table" or type(ptg.profiles) ~= "table" then return end
    local selection = type(ptg.accountSelection) == "table" and ptg.accountSelection or nil
    local name = selection and selection.activeProfile or ptg.defaultProfile
    local profile = type(name) == "string" and ptg.profiles[name]
    if type(profile) ~= "table" then return end
    local imported = false
    for _, id in ipairs(importing) do
        if ImportModule(id, addon.modules[id], profile, db) then imported = true end
    end
    if imported then root.importedFrom = "PlayTheGameTools:" .. name end
end

function addon:InitializeDatabase()
    if ModeUIDB == nil then ModeUIDB = {} end
    assert(type(ModeUIDB) == "table", "ModeUIDB must be a table; settings were not reset.")
    local root = ModeUIDB
    local version = root.schemaVersion
    assert(version == nil or version == 1 or version == SCHEMA_VERSION, "ModeUI: unsupported database version; settings were not reset.")
    -- A fresh account (no saved settings at all) starts in Mode-Obsidian.
    local fresh = root.profiles == nil and version == nil and next(root) == nil
    if root.profiles == nil then MigrateV1(root) end
    root.schemaVersion = SCHEMA_VERSION
    ApplyDefaults(root, D.accountDefaults, "ModeUIDB")
    for _, key in ipairs({ "x", "y" }) do
        local value = root.window[key]
        assert(type(value) == "number" and value == value and math.abs(value) < math.huge, "ModeUI: invalid window position.")
    end
    for name in pairs(root.profiles) do
        assert(addon.Profiles:Name(name) == name, "ModeUI: invalid profile name; settings were not reset.")
    end
    if next(root.profiles) == nil then root.profiles[D.DEFAULT_PROFILE] = {} end
    if not root.profiles[root.activeProfile] then
        root.activeProfile = root.profiles[D.DEFAULT_PROFILE] and D.DEFAULT_PROFILE or addon.Profiles:List(root)[1]
    end

    -- A profile chosen last session applies now; a broken one leaves the
    -- current profile in place and is reported rather than retried forever.
    local status
    local requested = root.pendingProfile
    root.pendingProfile = nil
    if requested ~= nil and requested ~= root.activeProfile then
        if root.profiles[requested] and D:ValidateProfile(root.profiles[requested]) then
            root.activeProfile, root.failedProfile = requested, nil
            status = "Switched to " .. requested .. "."
        else
            root.failedProfile = requested
            status = "Profile " .. tostring(requested) .. " could not be loaded; kept " .. root.activeProfile .. "."
        end
    end
    -- The first start with themes: Mode-Obsidian (Shared/Runtime/Themes.lua).
    addon.Themes:Seed(root, fresh)
    local active = root.profiles[root.activeProfile]
    if type(active) == "table" then ImportFromPlayTheGameTools(root, active) end
    local profile, reason = D:ValidateProfile(active)
    assert(profile, "ModeUI: profile " .. root.activeProfile .. " is invalid (" .. tostring(reason) .. "); settings were not reset.")
    root.profiles[root.activeProfile] = profile
    self.root, self.db = root, profile
    -- The theme's tokens, now that the profile is checked (Style/Tone.lua).
    addon.Style.ApplyTheme(profile.theme)
    self.Profiles.status = status
    return profile
end
