local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Interface > Minimap: Blizzard's minimap as a rounded rectangle in the Mode
-- look (owner's design, November 14, 2026): 8 px corners, 16 px wider than
-- tall, a Bold border round the map and Thin borders round the button tiles
-- inside it, clock above zone at the bottom, the group-finder eye in the
-- bottom-left corner, and other addons' minimap buttons in a box of their
-- own. Blizzard's Minimap frame moves onto a ModeUI holder placed in Edit
-- Mode; its round art, zone text and zoom buttons wait under a hidden frame.
-- The game draws the map square, so a rectangle is a mask that crops the top
-- and bottom (one mask per size, difference and corner choice; see
-- tools/build_minimap_masks.lua). Turning the module off asks for a reload,
-- which gives Blizzard's minimap back. See docs/MINIMAP.md.
-- Files: Init (this), Adopt, Shape, Text, Tiles, Container, Driver,
-- Settings, SettingsWidgets.
local L, Kit = addon.L, addon.Kit
local M = { title = L["Minimap"], category = "interface", defaultEnabled = false,
    modeLayout = { decorateOnly = true } }
addon.Minimap = M
addon:RegisterModule("minimap", M)

M.VERSION = 1
local function Copy(value) return addon.ProfileCodec.Copy(value) end
local Public, Number = addon.IsPublic, addon.IsNumber

-- Mask lists; tools/build_minimap_masks.lua makes a file for every
-- combination.
M.SIZE_MIN, M.SIZE_MAX, M.SIZE_STEP = 140, 280, 4
M.RADII = { square = 0, small = 4, medium = 8, large = 12 }
function M.MaskPath(size, difference, corners)
    return string.format("%sMinimap\\Mask-%d-%d-%d", addon.Media.textureBase, size, difference, M.RADII[corners])
end
-- Borders in physical pixels: ModeUI's Thin and Mode, and Bold and Heavy
-- for the map (owner, November 14, 2026).
M.BORDER_PIXELS = { thin = 1, mode = 2, bold = 3, heavy = 4 }
-- Border colors: the Mode rim (Kit.BORDER_COLOR), Onyx, black, Mode Slate,
-- the accent, or the player's class color.
M.BORDER_COLORS = { rim = Kit.BORDER_COLOR, onyx = Kit.onyx.border, black = { 0, 0, 0 }, slate = Kit.onyx.slate,
    accent = Kit.palette.accent }
-- Zone text by the zone's PvP type, in Mode tones; White otherwise.
M.ZONE_COLORS = { friendly = Kit.palette.green, contested = Kit.palette.neutral, hostile = Kit.palette.hostile,
    arena = Kit.palette.hostile, combat = Kit.palette.hostile, sanctuary = Kit.palette.accent }
M.WHITE = { 0.95, 0.95, 0.95 }
-- Button tiles: size and inset from the map's edge (UI units), the gap
-- between two tiles in one corner, and the tile fill (the unit frames'
-- health color).
M.TILE_SIZE, M.TILE_INSET, M.TILE_GAP = 20, 5, 4
M.TILE_FILL, M.TILE_ALPHA = Kit.onyx.health, 0.92
-- Blizzard's buttons that get a tile, in settings order.
M.BUTTONS = { "tracking", "calendar", "mail", "expansion" }
M.BUTTON_LABELS = { tracking = "Tracking", calendar = "Calendar", mail = "New Mail", expansion = "Expansion Button" }
M.CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }

-- Edit Mode: the map (with the bar below it, when shown), the group-finder
-- eye and the addon button box. The map's own frame is a target too, so the
-- eye sits in its corner whatever the text layout.
M.ELEMENT_ID, M.QUEUE_ID, M.BUTTONS_ID = "modeMinimap", "modeMinimapQueue", "modeMinimapButtons"
M.MAP_TARGET = "modeMinimapMap"
addon.Positioning:AddTarget(M.ELEMENT_ID, L["Minimap"], "ModeUIMinimapMover")
addon.Positioning:AddTarget(M.MAP_TARGET, L["Minimap Map"], "ModeUIMinimapMap")
addon.Positioning:AddTarget(M.BUTTONS_ID, L["Addon Buttons"], "ModeUIMinimapButtonsMover")
M.DEFAULT_POSITION = { target = "screen", placement = "center", point = "TOPRIGHT", relativePoint = "TOPRIGHT", x = -20, y = -24 }
M.QUEUE_POSITION = { target = M.MAP_TARGET, placement = "center", point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT",
    x = M.TILE_INSET, y = M.TILE_INSET }
M.BUTTONS_POSITION = { target = M.ELEMENT_ID, placement = "below", x = 0, y = -6 }

M.defaults = {
    version = M.VERSION,
    -- Shape: width, how much taller than wide it isn't, corners.
    size = 200, difference = 16, corners = "medium",
    -- Border: round the map (and the addon button box), round the tiles.
    border = "bold", buttonBorder = "thin", borderColor = "rim",
    -- Text: layout, zone color, clock, coordinates.
    textLayout = "map", zoneColor = "pvp", clock = true, coords = true, clockFormat = "24", textSize = 13,
    font = "game", fontMedia = "Expressway",
    -- Blizzard's buttons on tiles: shown and corner each.
    buttons = {
        tracking = { shown = true, corner = "TOPLEFT" }, calendar = { shown = true, corner = "TOPRIGHT" },
        mail = { shown = true, corner = "BOTTOMRIGHT" }, expansion = { shown = false, corner = "BOTTOMRIGHT" },
    },
    -- Other addons' buttons.
    addonButtons = "always", matchWidth = true, buttonSize = 22, buttonSpacing = 2,
    -- Zoom and visibility.
    wheelZoom = true, zoomReset = 10, opacity = 100, combatOpacity = 100,
}
M.ranges = { size = { M.SIZE_MIN, M.SIZE_MAX, M.SIZE_STEP }, textSize = { 10, 18, 1 }, buttonSize = { 16, 32, 1 },
    buttonSpacing = { 1, 6, 1 }, opacity = { 20, 100, 5 }, combatOpacity = { 20, 100, 5 } }
M.choices = {
    difference = { { id = 0, label = "0" }, { id = 8, label = "8 px" }, { id = 16, label = "16 px" } },
    corners = { { id = "square", label = "Square" }, { id = "small", label = "Small" }, { id = "medium", label = "Medium" },
        { id = "large", label = "Large" } },
    border = { { id = "thin", label = "Thin" }, { id = "mode", label = "Mode" }, { id = "bold", label = "Bold" },
        { id = "heavy", label = "Heavy" } },
    buttonBorder = { { id = "thin", label = "Thin" }, { id = "mode", label = "Mode" } },
    borderColor = { { id = "rim", label = "Mode Rim" }, { id = "onyx", label = "Onyx" }, { id = "black", label = "Black" },
        { id = "slate", label = "Mode Slate" }, { id = "accent", label = "Accent" }, { id = "class", label = "Class Color" } },
    textLayout = { { id = "map", label = "On Map" }, { id = "bar", label = "Bar Below" }, { id = "hover", label = "On Hover" } },
    zoneColor = { { id = "pvp", label = "PvP Status" }, { id = "white", label = "White" } },
    clockFormat = { { id = "24", label = "24 Hour" }, { id = "12", label = "12 Hour" } },
    addonButtons = { { id = "always", label = "Always" }, { id = "mouseover", label = "Mouseover" }, { id = "hidden", label = "Hidden" } },
    zoomReset = { { id = 0, label = "Off" }, { id = 10, label = "10 s" }, { id = 30, label = "30 s" } },
}
local ALLOWED = {}
for key, list in pairs(M.choices) do
    local set = {}
    for _, item in ipairs(list) do set[item.id] = true end
    ALLOWED[key] = set
end
local CORNER_SET = {}
for _, corner in ipairs(M.CORNERS) do CORNER_SET[corner] = true end

-- Fills defaults and validates. Profile validation runs this on detached
-- copies, so it touches nothing but `db`. Errors on bad data; never resets it.
function M.Initialize(db)
    if db.version == nil then db.version = M.VERSION end
    assert(db.version == M.VERSION, "Invalid minimap settings version")
    for key, default in pairs(M.defaults) do
        if db[key] == nil then db[key] = Copy(default) end
        assert(Public(db[key]) and type(db[key]) == type(default), "Invalid minimap setting: " .. key)
    end
    for key, r in pairs(M.ranges) do
        assert(Number(db[key], r[1], r[2]) and db[key] == math.floor(db[key]), "Invalid minimap range: " .. key)
    end
    assert((db.size - M.SIZE_MIN) % M.SIZE_STEP == 0, "Invalid minimap size step")
    for key, allowed in pairs(ALLOWED) do assert(allowed[db[key]], "Invalid minimap choice: " .. key) end
    for _, name in ipairs(M.BUTTONS) do
        local entry = db.buttons[name]
        if entry == nil then entry = Copy(M.defaults.buttons[name]); db.buttons[name] = entry end
        assert(Public(entry) and type(entry) == "table" and type(entry.shown) == "boolean" and CORNER_SET[entry.corner],
            "Invalid minimap button: " .. name)
    end
end
