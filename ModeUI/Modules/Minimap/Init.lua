local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Interface > Minimap: Blizzard's minimap as a rectangle in the Mode design
-- language (owner's design, November 14, 2026, on the Mode edge since
-- November 15): 16 px wider than tall, in the Mode `frame` edge (Map Border
-- Thin or Mode, its rim in Border Color), Mode tiles for Blizzard's buttons
-- inside it, clock above zone at the bottom, the group-finder eye in the
-- bottom-left corner, and other addons' minimap buttons in a tray of Mode
-- tiles of their own. Blizzard's Minimap frame moves onto a ModeUI holder
-- placed in Edit Mode; its round art, zone text and zoom buttons wait under a hidden frame.
-- The game draws the map square, so a rectangle is a mask that crops the top
-- and bottom (one mask per size and difference, square: the edge's rim
-- covers the corners; see tools/build_minimap_masks.lua). Turning the
-- module off asks for a reload, which gives Blizzard's minimap back. See docs/MINIMAP.md.
-- Files: Init (this), Layouts, Adopt, Shape, Text, Tiles, Container, Driver,
-- Settings, SettingsWidgets.
local L, Kit = addon.L, addon.Kit
local M = { title = L["Minimap"], category = "interface", defaultEnabled = false,
    modeLayout = { decorateOnly = true } }
addon.Minimap = M
addon:RegisterModule("minimap", M)

-- Version 2 (November 15, 2026, Phase 7): the Mode edge (owner: "keep what
-- fits"). Map Border is Thin or Mode (Bold and Heavy become Mode), Border
-- Color tints the edge's rim (Onyx becomes the edge's own Gunmetal), and
-- Corners goes (the edge's corners are fixed). Values still at version 1's
-- defaults follow: Expressway, 22 px addon buttons 2 px apart.
M.VERSION = 2
local function Copy(value) return addon.ProfileCodec.Copy(value) end
local Public, Number = addon.IsPublic, addon.IsNumber

-- Mask lists; tools/build_minimap_masks.lua makes a file for every
-- combination.
M.SIZE_MIN, M.SIZE_MAX, M.SIZE_STEP = 140, 280, 4
-- (Square only: the Mode edge's rim covers the map's corners.)
M.RADII = { square = 0 }
function M.MaskPath(size, difference, corners)
    return string.format("%sMinimap\\Mask-%d-%d-%d", addon.Media.textureBase, size, difference, M.RADII[corners])
end
-- The edges' rims in physical pixels: Thin and Mode (the map's `frame`
-- edge and the tiles' `group` edge take either).
local Tone = addon.Style.Tone
M.BORDER_PIXELS = { thin = 1, mode = 2 }
-- Border colors, the rim's tint: none (`rim`: the edge's own lit Border
-- Metal), black, Slate, Ivory, or the player's class color. Each is a swatch
-- color too (`rim`'s swatch shows the metal drawn; this Gunmetal is the class
-- color's fallback).
M.BORDER_COLORS = { rim = Tone.gunmetal.mid, black = Tone.shadow, slate = Tone.slate, accent = Tone.ivory }
-- Zone text by the zone's PvP type, in the gameplay reaction tones
-- (sanctuaries Ivory); White (Text bright) otherwise.
M.ZONE_COLORS = { friendly = Tone.reaction.friendly, contested = Tone.reaction.neutral, hostile = Tone.reaction.hostile,
    arena = Tone.reaction.hostile, combat = Tone.reaction.hostile, sanctuary = Tone.ivory }
M.WHITE = Tone.textBright
-- Button tiles: size and inset from the map's edge (UI units), the gap
-- between two tiles in one corner, and the tile face (a Mode Button face in
-- Mono raised, as the approved probe).
M.TILE_SIZE, M.TILE_INSET, M.TILE_GAP = 20, 5, 4
M.TILE_FILL = Tone.mono.raised
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
    -- Shape: width, and how much taller than wide it isn't.
    size = 200, difference = 16,
    -- Border: the map's edge (and the text bar's), the tiles' edges, their rim color.
    border = "mode", buttonBorder = "thin", borderColor = "rim",
    -- Border Style and Border Metal of every edge here (docs/DESIGN_LANGUAGE.md,
    -- "Choosing a border"): Mode-Blizz in its own metal (owner, November 17, 2026).
    edgeStyle = "obsidian", edgeMetal = "default",
    -- Text: layout, zone color, clock, coordinates.
    textLayout = "map", zoneColor = "pvp", clock = true, coords = true, clockFormat = "24", textSize = 13,
    font = "game", fontMedia = addon.Style.FONT_DEFAULT,
    -- Blizzard's buttons on tiles: shown and corner each.
    buttons = {
        tracking = { shown = true, corner = "TOPLEFT" }, calendar = { shown = true, corner = "TOPRIGHT" },
        mail = { shown = true, corner = "BOTTOMRIGHT" }, expansion = { shown = false, corner = "BOTTOMRIGHT" },
    },
    -- Other addons' buttons.
    -- Addon buttons: tiles Button Size wide and a little shorter, Spacing
    -- apart (their 1px edges inside the gap).
    addonButtons = "always", matchWidth = true, buttonSize = 26, buttonSpacing = 3,
    -- Zoom and visibility.
    wheelZoom = true, zoomReset = 10, opacity = 100, combatOpacity = 100,
}
M.ranges = { size = { M.SIZE_MIN, M.SIZE_MAX, M.SIZE_STEP }, textSize = { 10, 18, 1 }, buttonSize = { 16, 32, 1 },
    buttonSpacing = { 1, 6, 1 }, opacity = { 20, 100, 5 }, combatOpacity = { 20, 100, 5 } }
M.choices = {
    -- Wider Than Tall By: 16 px by default; up to 48 px for a more
    -- rectangular map (owner, November 15, 2026).
    difference = { { id = 0, label = "0" }, { id = 8, label = "8 px" }, { id = 16, label = "16 px" }, { id = 24, label = "24 px" },
        { id = 32, label = "32 px" }, { id = 40, label = "40 px" }, { id = 48, label = "48 px" } },
    border = { { id = "thin", label = "Thin" }, { id = "mode", label = "Mode" } },
    buttonBorder = { { id = "thin", label = "Thin" }, { id = "mode", label = "Mode" } },
    borderColor = { { id = "rim", label = "Metal" }, { id = "black", label = "Black" }, { id = "slate", label = "Slate" },
        { id = "accent", label = "Ivory" }, { id = "class", label = "Class Color" } },
    textLayout = { { id = "map", label = "On Map" }, { id = "bar", label = "Bar Below" }, { id = "hover", label = "On Hover" } },
    zoneColor = { { id = "pvp", label = "PvP Status" }, { id = "white", label = "White" } },
    clockFormat = { { id = "24", label = "24 Hour" }, { id = "12", label = "12 Hour" } },
    addonButtons = { { id = "always", label = "Always" }, { id = "mouseover", label = "Mouseover" }, { id = "hidden", label = "Hidden" } },
    zoomReset = { { id = 0, label = "Off" }, { id = 10, label = "10 s" }, { id = 30, label = "30 s" } },
    edgeStyle = addon.Style.EdgeStyleChoices(),
    edgeMetal = addon.Style.EdgeMetalChoices(),
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
    -- Version 2 (Phase 7): the Mode edge. Bold and Heavy become Mode, Onyx
    -- the edge's own Gunmetal, Corners goes; defaults still at version 1's
    -- follow.
    if db.version == 1 then
        db.corners = nil
        if db.border == "bold" or db.border == "heavy" then db.border = "mode" end
        if db.borderColor == "onyx" then db.borderColor = "rim" end
        if db.fontMedia == "Expressway" then db.fontMedia = addon.Style.FONT_DEFAULT end
        if db.buttonSize == 22 then db.buttonSize = 26 end
        if db.buttonSpacing == 2 then db.buttonSpacing = 3 end
        db.version = 2
    end
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
