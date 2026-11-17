local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Interface > Tooltip: Blizzard's tooltips in the Mode design language,
-- placed from ModeUI's Edit Mode. Blizzard's tooltip border and background
-- (its NineSlice) are faded; ModeUI makes each tooltip a Mode window (Mode
-- Panel in Graphite, the `window` edge inside it, its rim in the item's
-- quality color or a player's class color), sets every line in the Mode
-- typeface (the first in SemiBold), and colors names, class, level and quest
-- lines. Blizzard's
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

-- Version 5 (November 15, 2026, Phase 7): the Mode design language. The
-- border is the Mode window edge, so Rounded, Mode Gradient, Border Color and
-- Border Size go; values still at version 4's defaults (the fill, reaction
-- colors, Expressway) follow.
M.VERSION = 5
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

-- The fill: Graphite panel, as every Mode window. Text colors: reactions in
-- the gameplay tones (never softened), quest lines in the quest tone.
-- Earlier defaults, for migrations, are in Migrations.lua and Style.LEGACY.
local Tone = addon.Style.Tone
M.BACKGROUND_COLOR = Copy(Tone.graphite.panel)
M.HOSTILE_COLOR, M.NEUTRAL_COLOR, M.FRIENDLY_COLOR = Copy(Tone.reaction.hostile), Copy(Tone.reaction.neutral), Copy(Tone.reaction.friendly)
M.QUEST_COLOR = Copy(Tone.quest)

M.defaults = {
    version = M.VERSION,
    -- Look: a Mode window. Border shows its edge; Quality Border and Class
    -- Border color the edge's rim (no class color by default, owner,
    -- November 13, 2026).
    backgroundColor = Copy(M.BACKGROUND_COLOR), backgroundOpacity = 92,
    border = true, qualityBorder = true, classBorder = false,
    -- Border Style and Border Metal (docs/DESIGN_LANGUAGE.md, "Choosing a
    -- border"): Mode-Thin in its own metal, Steel (owner, November 17, 2026).
    edgeStyle = "thin", edgeMetal = "default",
    -- Size: the tooltip's least width, extra room around the text, scale.
    minWidth = 0, padding = 0, scale = 100,
    -- Text
    font = "game", fontMedia = addon.Style.FONT_DEFAULT, headerSize = 14, textSize = 12, outline = false, shadow = true,
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
M.colorKeys = { backgroundColor = true, playerNameCustom = true, npcNameCustom = true, hostileColor = true,
    neutralColor = true, friendlyColor = true, classTextCustom = true, levelCustom = true, questColor = true }
M.ranges = { backgroundOpacity = { 0, 100, 5 }, headerSize = { 8, 24, 1 }, textSize = { 8, 20, 1 },
    scale = { 50, 150, 5 }, minWidth = { 0, 400, 10 }, padding = { 0, 20, 1 } }
M.choices = {
    playerNameColor = { { id = "class", label = "Class" }, { id = "custom", label = "Custom" }, { id = "blizzard", label = "Blizzard" } },
    npcNameColor = { { id = "reaction", label = "Reaction" }, { id = "custom", label = "Custom" }, { id = "blizzard", label = "Blizzard" } },
    classTextColor = { { id = "class", label = "Class" }, { id = "custom", label = "Custom" }, { id = "blizzard", label = "Blizzard" } },
    levelColor = { { id = "difficulty", label = "Difficulty" }, { id = "custom", label = "Custom" }, { id = "blizzard", label = "Blizzard" } },
    position = { { id = "anchor", label = "Anchor" }, { id = "cursor", label = "Cursor" } },
    anchorPoint = { { id = "TOPLEFT" }, { id = "TOP" }, { id = "TOPRIGHT" }, { id = "LEFT" }, { id = "CENTER" },
        { id = "RIGHT" }, { id = "BOTTOMLEFT" }, { id = "BOTTOM" }, { id = "BOTTOMRIGHT" } },
    edgeStyle = addon.Style.EdgeStyleChoices(),
    edgeMetal = addon.Style.EdgeMetalChoices(),
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
        if Same(db.backgroundColor, addon.Style.LEGACY.windowFill) then db.backgroundColor = Copy(Kit.onyx.health) end
        db.healthBar, db.healthHeight, db.healthColor = nil, nil, nil
        db.version = 2
    end
    -- Version 3: a border still at version 2's defaults (2px, class colored)
    -- turns 1px and plain.
    if db.version == 2 then
        if db.borderSize == 2 then db.borderSize = 1 end
        if db.classBorder == true then db.classBorder = false end
        db.version = 3
    end
    -- Version 4: a fill still at the old health color (#1C1E21) takes #131212.
    if db.version == 3 then
        if Kit.IsOldOnyxHealth(db.backgroundColor) then db.backgroundColor = Copy(Kit.onyx.health) end
        db.version = 4
    end
    -- Version 5 (Phase 7): the Mode design language. The border is the Mode
    -- window edge, so its shape and color settings go; a fill still at
    -- #131212, reactions still at version 4's colors and Expressway follow.
    if db.version == 4 then
        db.rounded, db.gradient, db.borderColor, db.borderSize = nil, nil, nil, nil
        if Same(db.backgroundColor, Kit.onyx.health) then db.backgroundColor = Copy(M.BACKGROUND_COLOR) end
        if Same(db.hostileColor, Kit.palette.hostile) then db.hostileColor = Copy(M.HOSTILE_COLOR) end
        if Same(db.neutralColor, addon.Style.LEGACY.tooltipNeutral) then db.neutralColor = Copy(M.NEUTRAL_COLOR) end
        if Same(db.friendlyColor, Kit.palette.green) then db.friendlyColor = Copy(M.FRIENDLY_COLOR) end
        if db.fontMedia == "Expressway" then db.fontMedia = addon.Style.FONT_DEFAULT end
        db.version = 5
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
