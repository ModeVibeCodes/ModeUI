local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Interface > Tooltip: Blizzard's tooltips in the Mode look, placed from
-- ModeUI's Edit Mode. Blizzard's tooltip border and background (its
-- NineSlice) are faded; ModeUI draws a rounded Onyx box (the unit frames'
-- health color, in Mode Gradient) inside a rounded rim (the item's quality
-- color, a player's class color, or the rim color), sets every line in the
-- Mode face, and colors names, class, level and quest lines. Blizzard's
-- health bar under unit tooltips is hidden. The main tooltip's default spot
-- is ModeUI's Tooltip anchor (moved and attached in Edit Mode) or the
-- cursor, kept on the screen, so Blizzard's own tooltip placement (its Edit
-- Mode HUD Tooltip) no longer applies. Hide in Combat keeps it away while
-- fighting (Shift shows it). See docs/TOOLTIP.md.
-- Files: Init (this), Skin, Colors, Driver, Settings.
local L, Kit = addon.L, addon.Kit
local M = { title = L["Tooltip"], category = "interface", defaultEnabled = false,
    configDescription = L["Tooltips in the Mode look, placed in Edit Mode, optionally hidden in combat."],
    modeLayout = { decorateOnly = true } }
addon.Tooltip = M
addon:RegisterModule("tooltip", M)

M.VERSION = 2
local function Copy(value) return addon.ProfileCodec.Copy(value) end
local Public, Number = addon.IsPublic, addon.IsNumber

-- Blizzard's tooltips that get the look (GameTooltip is the one placed and
-- hidden in combat; the others are item links, comparisons and lists).
M.TOOLTIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "ItemRefShoppingTooltip1",
    "ItemRefShoppingTooltip2", "GameNoHeaderTooltip", "GameSmallHeaderTooltip", "FriendsTooltip" }
-- Edit Mode: the anchor's ID, and where it starts (Blizzard's default
-- spot, the screen's bottom right above the action bars).
M.ELEMENT_ID = "modeTooltip"
M.DEFAULT_POSITION = { target = "screen", placement = "center", point = "BOTTOMRIGHT", relativePoint = "BOTTOMRIGHT", x = -90, y = 110 }
M.MOVER_WIDTH, M.MOVER_HEIGHT = 200, 64

-- The fill: the unit frames' default health color (Onyx #1C1E21), as the
-- chat and the meters (owner, November 13, 2026). Version 1 used #0B0B0D.
M.BACKGROUND_COLOR, M.OLD_BACKGROUND_COLOR = Copy(Kit.onyx.health), Kit.RGB(11, 11, 13)
-- Text colors: reactions in the Mode palette, quest lines a vivid
-- yellow-orange.
M.HOSTILE_COLOR, M.NEUTRAL_COLOR, M.FRIENDLY_COLOR = Copy(Kit.palette.hostile), Kit.RGB(255, 209, 64), Copy(Kit.palette.green)
M.QUEST_COLOR = Kit.RGB(255, 177, 47)

M.defaults = {
    version = M.VERSION,
    -- Look: a rounded box in Mode Gradient (Rounded off: square corners).
    backgroundColor = Copy(M.BACKGROUND_COLOR), backgroundOpacity = 92, gradient = true, rounded = true,
    border = true, borderColor = Copy(Kit.onyx.frameRim), borderSize = 2,
    qualityBorder = true, classBorder = true,
    -- Size: the tooltip's least width, extra room around the text, scale.
    minWidth = 0, padding = 0, scale = 100,
    -- Text
    font = "game", fontMedia = "Expressway", headerSize = 14, textSize = 12, outline = false, shadow = true,
    -- Text colors. Modes: a player's name and class line by class, an NPC's
    -- name by reaction, the level by difficulty; "custom" uses the color
    -- beside it; "blizzard" leaves Blizzard's.
    playerNameColor = "class", playerNameCustom = { 1, 1, 1 },
    npcNameColor = "reaction", npcNameCustom = { 1, 1, 1 },
    hostileColor = Copy(M.HOSTILE_COLOR), neutralColor = Copy(M.NEUTRAL_COLOR), friendlyColor = Copy(M.FRIENDLY_COLOR),
    classTextColor = "class", classTextCustom = { 1, 1, 1 },
    levelColor = "difficulty", levelCustom = { 1, 1, 1 },
    questText = true, questColor = Copy(M.QUEST_COLOR),
    -- Position: the Edit Mode anchor ("anchor") or the cursor; the tooltip
    -- grows away from Anchor Point of the anchor.
    position = "anchor", anchorPoint = "BOTTOMRIGHT",
    -- Combat
    hideInCombat = false, shiftShows = true,
}
M.colorKeys = { backgroundColor = true, borderColor = true, playerNameCustom = true, npcNameCustom = true, hostileColor = true,
    neutralColor = true, friendlyColor = true, classTextCustom = true, levelCustom = true, questColor = true }
M.ranges = { backgroundOpacity = { 0, 100, 5 }, borderSize = { 1, 4, 1 }, headerSize = { 8, 24, 1 }, textSize = { 8, 20, 1 },
    scale = { 50, 150, 5 }, minWidth = { 0, 400, 10 }, padding = { 0, 20, 1 } }
M.choices = {
    playerNameColor = { { id = "class", label = "Class" }, { id = "custom", label = "Custom" }, { id = "blizzard", label = "Blizzard" } },
    npcNameColor = { { id = "reaction", label = "Reaction" }, { id = "custom", label = "Custom" }, { id = "blizzard", label = "Blizzard" } },
    classTextColor = { { id = "class", label = "Class" }, { id = "custom", label = "Custom" }, { id = "blizzard", label = "Blizzard" } },
    levelColor = { { id = "difficulty", label = "Difficulty" }, { id = "custom", label = "Custom" }, { id = "blizzard", label = "Blizzard" } },
    position = { { id = "anchor", label = "Anchor" }, { id = "cursor", label = "Cursor" } },
    anchorPoint = { { id = "TOPLEFT" }, { id = "TOP" }, { id = "TOPRIGHT" }, { id = "LEFT" }, { id = "CENTER" },
        { id = "RIGHT" }, { id = "BOTTOMLEFT" }, { id = "BOTTOM" }, { id = "BOTTOMRIGHT" } },
}
local ALLOWED = {}
for key, list in pairs(M.choices) do
    local set = {}
    for _, item in ipairs(list) do set[item.id] = true end
    ALLOWED[key] = set
end

local function Same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for i = 1, 3 do if not (Number(a[i]) and math.abs(a[i] - b[i]) < 1e-6) then return false end end
    return true
end

-- Migrates, fills defaults and validates. Profile validation runs this on
-- detached copies, so it touches nothing but `db`. Errors on bad data; never
-- resets it. Version 2 (November 13, 2026, per the owner): the fill moves to
-- the health color if it was still version 1's default; the health bar is
-- gone, and its settings with it.
function M.Initialize(db)
    if db.version == nil then db.version = M.VERSION end
    if db.version == 1 then
        if Same(db.backgroundColor, M.OLD_BACKGROUND_COLOR) then db.backgroundColor = Copy(M.BACKGROUND_COLOR) end
        db.healthBar, db.healthHeight, db.healthColor = nil, nil, nil
        db.version = 2
    end
    assert(db.version == M.VERSION, "Invalid tooltip settings version")
    for key, default in pairs(M.defaults) do
        if db[key] == nil then db[key] = Copy(default) end
        assert(Public(db[key]) and type(db[key]) == type(default), "Invalid tooltip setting: " .. key)
        if M.colorKeys[key] then
            for i = 1, 3 do assert(Number(db[key][i], 0, 1), "Invalid tooltip color: " .. key) end
        end
    end
    for key, r in pairs(M.ranges) do
        assert(Number(db[key], r[1], r[2]) and db[key] == math.floor(db[key]), "Invalid tooltip range: " .. key)
    end
    for key, allowed in pairs(ALLOWED) do assert(allowed[db[key]], "Invalid tooltip choice: " .. key) end
end
