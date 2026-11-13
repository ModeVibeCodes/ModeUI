local _, addon = ...

-- ModeUI keeps one account-wide settings table. Unknown keys are preserved and
-- invalid data stops startup instead of being reset.
local SCHEMA_VERSION = 1
local defaults = {
    schemaVersion = SCHEMA_VERSION,
    window = { x = 0, y = 0 },
    -- Shared media defaults read by the Mode widgets and the unit frames'
    -- "Use Global Setting" choices. ModeUI has no page to change them yet.
    globalMedia = { font = "game", texture = "default", border = "thin", overrides = {} },
    modules = {},
    positions = {},
}

local function Copy(value) return addon.ProfileCodec.Copy(value) end

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

-- Play The Game Tools carried these unit frames before ModeUI. The first time
-- ModeUI starts (no saved unit frame settings yet), copy the active PTG
-- profile's unit frame settings and positions. PTGToolsDB is only read.
local function ImportFromPlayTheGameTools(db)
    if db.importedFrom ~= nil or db.modules.unitFrames ~= nil then return end
    db.importedFrom = "none"
    local root = PTGToolsDB
    if type(root) ~= "table" or type(root.profiles) ~= "table" then return end
    local selection = type(root.accountSelection) == "table" and root.accountSelection or nil
    local name = selection and selection.activeProfile or root.defaultProfile
    local profile = type(name) == "string" and root.profiles[name]
    local modules = type(profile) == "table" and profile.modules
    local frames = type(modules) == "table" and modules.unitFrames
    if type(frames) ~= "table" then return end
    local ok, copy = pcall(Copy, frames)
    if not ok or type(copy) ~= "table" then return end
    -- Only keep a copy that passes ModeUI's own validation and migration.
    if not addon.UnitFrames or not pcall(addon.UnitFrames.Initialize, copy) then return end
    db.modules.unitFrames = copy
    local positions = type(profile.positions) == "table" and profile.positions or {}
    for _, id in ipairs({ "unitFramesPlayer", "unitFramesTarget" }) do
        if type(positions[id]) == "table" and db.positions[id] == nil then
            local okPosition, position = pcall(Copy, positions[id])
            if okPosition then db.positions[id] = position end
        end
    end
    db.importedFrom = "PlayTheGameTools:" .. name
end

function addon:InitializeDatabase()
    if ModeUIDB == nil then ModeUIDB = {} end
    assert(type(ModeUIDB) == "table", "ModeUIDB must be a table; settings were not reset.")
    local db = ModeUIDB
    assert(db.schemaVersion == nil or db.schemaVersion == SCHEMA_VERSION, "ModeUI: unsupported database version; settings were not reset.")
    ApplyDefaults(db, defaults, "ModeUIDB")
    for _, key in ipairs({ "x", "y" }) do
        local value = db.window[key]
        assert(type(value) == "number" and value == value and math.abs(value) < math.huge, "ModeUI: invalid window position.")
    end
    ImportFromPlayTheGameTools(db)
    self.db = db
    return db
end
