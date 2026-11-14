local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Interface > Bags: every bag in one Mode window. The backpack, the
-- equipped bags, the reagent bag and the keyring show together on one grid
-- of slots in the Mode look, with a search box, Clean Up (the game's own bag
-- sort), a view order (Bag Order, Quality, Type, Name) and the money and free
-- slots. Blizzard keeps deciding when bags open and close (B, the bag bar,
-- vendors, mail, the bank, Esc): ModeUI's window follows Blizzard's bag
-- frames, which wait under a hidden ModeUI frame while the module is on. The
-- slots are Blizzard's own item buttons (ContainerFrameItemButtonTemplate),
-- so clicks, using items (in combat too), dragging, splitting stacks and
-- tooltips stay Blizzard's code. See docs/BAGS.md.
-- Files: Init (this), Driver, Blizzard, Window, Slots, Layout, Settings.
local L, Kit = addon.L, addon.Kit
local M = { title = L["Bags"], category = "interface", defaultEnabled = false,
    configDescription = L["Every bag in one Mode window, with search, Clean Up and a sorted view."],
    modeLayout = { decorateOnly = true } }
addon.Bags = M
-- The ID is the saved-settings key (ModeUIDB profile modules.bags); never
-- change it once released.
addon:RegisterModule("bags", M)

-- Version 2 (November 13, 2026): the health color moved to #131212; a window
-- or title bar still at the old #1C1E21 follows.
M.VERSION = 2
local function Copy(value) return addon.ProfileCodec.Copy(value) end
local Public, Number = addon.IsPublic, addon.IsNumber

-- Edit Mode: the window's stand-in, and where it starts (Blizzard's bag
-- corner, the screen's bottom right above the action bars).
M.ELEMENT_ID = "modeBags"
M.DEFAULT_POSITION = { target = "screen", placement = "center", point = "BOTTOMRIGHT", relativePoint = "BOTTOMRIGHT", x = -60, y = 110 }

-- Colors: the window in the unit frames' health color (as chat, meters and
-- tooltips), slots like the action bars' (a near-black textured fill in a
-- dark rim), quest items in the Mode quest orange.
M.SLOT_COLOR, M.QUEST_COLOR = Kit.RGB(4, 4, 4), Kit.RGB(255, 177, 47)

M.defaults = {
    version = M.VERSION,
    -- Layout: columns of slots, their size and gaps, the room inside the
    -- window, its scale and the corner it grows from (it stays put there).
    columns = 12, slotSize = 38, spacing = 4, padding = 8, scale = 100, growFrom = "BOTTOMRIGHT",
    -- What shows: bags apart, the reagent bag and the keyring in their own
    -- sections, and the view order ("bags": as they lie in the bags).
    splitBags = false, reagentSection = true, keyring = true, sortMode = "bags",
    -- Window
    backgroundColor = Copy(Kit.onyx.health), backgroundOpacity = 95, borderColor = Copy(Kit.BORDER_COLOR), corner = 6,
    showTitle = true, headerColor = Copy(Kit.onyx.health), titleSize = 13,
    showSearch = true, showMoney = true, showFreeSlots = true, locked = false,
    -- Slots
    slotColor = Copy(M.SLOT_COLOR), slotOpacity = 75, slotBorderColor = Copy(Kit.onyx.border), slotBorderSize = 2,
    qualityBorders = true, qualityMinimum = "uncommon", questBorders = true, questColor = Copy(M.QUEST_COLOR),
    fadeJunk = true, junkCoin = true, newItems = true, itemLevel = true, itemLevelColor = "quality",
    -- Text
    font = "game", fontMedia = "Expressway", countSize = 12, levelSize = 11, outline = true,
}
M.colorKeys = { backgroundColor = true, borderColor = true, headerColor = true, slotColor = true, slotBorderColor = true, questColor = true }
M.ranges = { columns = { 4, 24, 1 }, slotSize = { 24, 64, 1 }, spacing = { 0, 12, 1 }, padding = { 0, 24, 1 }, scale = { 50, 200, 5 },
    backgroundOpacity = { 0, 100, 5 }, corner = { 2, 16, 1 }, titleSize = { 8, 20, 1 }, slotOpacity = { 0, 100, 5 },
    slotBorderSize = { 0, 4, 1 }, countSize = { 8, 20, 1 }, levelSize = { 8, 20, 1 } }
M.choices = {
    growFrom = { { id = "TOPLEFT", label = "Top Left" }, { id = "TOPRIGHT", label = "Top Right" },
        { id = "BOTTOMLEFT", label = "Bottom Left" }, { id = "BOTTOMRIGHT", label = "Bottom Right" } },
    sortMode = { { id = "bags", label = "Bag Order" }, { id = "quality", label = "Quality" }, { id = "type", label = "Type" },
        { id = "name", label = "Name" } },
    qualityMinimum = { { id = "poor", label = "Poor" }, { id = "common", label = "Common" }, { id = "uncommon", label = "Uncommon" },
        { id = "rare", label = "Rare" }, { id = "epic", label = "Epic" } },
    itemLevelColor = { { id = "quality", label = "Quality" }, { id = "white", label = "White" } },
}
-- Item qualities (Enum.ItemQuality): Poor 0, Common 1, Uncommon 2, Rare 3, Epic 4.
M.QUALITY = { poor = 0, common = 1, uncommon = 2, rare = 3, epic = 4 }
local ALLOWED = {}
for key, list in pairs(M.choices) do
    local set = {}
    for _, item in ipairs(list) do set[item.id] = true end
    ALLOWED[key] = set
end

-- Migrates, fills defaults and validates. Profile validation runs this on
-- detached copies, so it touches nothing but `db`. Errors on bad data; never
-- resets it.
function M.Initialize(db)
    if db.version == nil then db.version = M.VERSION end
    if db.version == 1 then
        for _, key in ipairs({ "backgroundColor", "headerColor" }) do
            if Kit.IsOldOnyxHealth(db[key]) then db[key] = Copy(Kit.onyx.health) end
        end
        db.version = 2
    end
    assert(db.version == M.VERSION, "Invalid bags settings version")
    for key, default in pairs(M.defaults) do
        if db[key] == nil then db[key] = Copy(default) end
        assert(Public(db[key]) and type(db[key]) == type(default), "Invalid bags setting: " .. key)
        if M.colorKeys[key] then
            for i = 1, 3 do assert(Number(db[key][i], 0, 1), "Invalid bags color: " .. key) end
        end
    end
    for key, r in pairs(M.ranges) do
        assert(Number(db[key], r[1], r[2]) and db[key] == math.floor(db[key]), "Invalid bags range: " .. key)
    end
    for key, allowed in pairs(ALLOWED) do assert(allowed[db[key]], "Invalid bags choice: " .. key) end
end
