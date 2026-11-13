local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Interface > Tooltip: Blizzard's tooltips in the Mode look, placed from
-- ModeUI's Edit Mode. Blizzard's tooltip border and background (its
-- NineSlice) are faded; ModeUI draws an Onyx fill inside a crisp border
-- (the item's quality color, a player's class color, or the rim color),
-- sets every line in the Mode face, and restyles the health bar under unit
-- tooltips. The main tooltip's default spot is ModeUI's Tooltip anchor
-- (moved in Edit Mode) or the cursor, so Blizzard's own tooltip placement
-- (its Edit Mode HUD Tooltip) no longer applies. Hide in Combat keeps it
-- away while fighting (Shift shows it). See docs/TOOLTIP.md.
-- Files: Init (this), Skin, Driver, Settings.
local L, Kit = addon.L, addon.Kit
local M = { title = L["Tooltip"], category = "interface", defaultEnabled = false,
    configDescription = L["Tooltips in the Mode look, placed in Edit Mode, optionally hidden in combat."],
    modeLayout = { decorateOnly = true } }
addon.Tooltip = M
addon:RegisterModule("tooltip", M)

M.VERSION = 1
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

M.defaults = {
    version = M.VERSION,
    -- Look
    backgroundColor = Kit.RGB(11, 11, 13), backgroundOpacity = 92,
    border = true, borderColor = Copy(Kit.onyx.frameRim), borderSize = 2,
    qualityBorder = true, classBorder = true,
    -- Text
    font = "game", fontMedia = "Expressway", headerSize = 14, textSize = 12, outline = false, shadow = true,
    -- Health bar under unit tooltips.
    healthBar = true, healthHeight = 6, healthColor = Copy(Kit.palette.green),
    -- Position: the Edit Mode anchor ("anchor") or the cursor; the tooltip
    -- grows away from Anchor Point of the anchor.
    position = "anchor", anchorPoint = "BOTTOMRIGHT", scale = 100,
    -- Combat
    hideInCombat = false, shiftShows = true,
}
M.colorKeys = { backgroundColor = true, borderColor = true, healthColor = true }
M.ranges = { backgroundOpacity = { 0, 100, 5 }, borderSize = { 1, 4, 1 }, headerSize = { 8, 24, 1 }, textSize = { 8, 20, 1 },
    healthHeight = { 2, 16, 1 }, scale = { 50, 150, 5 } }
M.choices = {
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

-- Fills defaults and validates. Profile validation runs this on detached
-- copies, so it touches nothing but `db`. Errors on bad data; never resets it.
-- A later change adds a migration here, keyed by db.version.
function M.Initialize(db)
    if db.version == nil then db.version = M.VERSION end
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
