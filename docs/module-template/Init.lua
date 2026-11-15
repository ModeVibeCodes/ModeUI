local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Interface > Example: shows the current target's name above the middle of
-- the screen. Replace this paragraph with what the module does and why.
-- Files: Init (this), Driver, Settings.
local L = addon.L
local M = { title = L["Example"], category = "interface", defaultEnabled = false,
    configDescription = L["Shows your target's name above the middle of the screen."],
    -- The settings window shape (docs/DESIGN_LANGUAGE.md, "Settings window"):
    -- "page" keeps the sidebar; "split" (modules with a live preview) opens
    -- beside the preview. icon: a Style.ICONS name for the sidebar and rail.
    layout = "page", icon = "Windows",
    -- The page keeps its own sections; the Mode layer restyles headings.
    modeLayout = { decorateOnly = true } }
addon.Example = M
-- The ID is also the saved-settings key (ModeUIDB profile modules.example);
-- never change it once released.
addon:RegisterModule("example", M)

M.defaults = { showTarget = true, scale = 100 }
M.ranges = { scale = { 50, 200 } }

local Public, Number = addon.IsPublic, addon.IsNumber

-- Fills defaults and validates. Profile validation runs this on detached
-- copies, so it touches nothing but `db`. Error on bad data; never reset it.
-- A later change to these settings adds a migration here (see Unit Frames'
-- Migrations.lua), keyed by a version number stored in `db`.
function M.Initialize(db)
    for key, default in pairs(M.defaults) do
        if db[key] == nil then db[key] = default end
        assert(Public(db[key]) and type(db[key]) == type(default), "Invalid example setting: " .. key)
    end
    for key, range in pairs(M.ranges) do
        assert(Number(db[key], range[1], range[2]), "Invalid example range: " .. key)
    end
end
