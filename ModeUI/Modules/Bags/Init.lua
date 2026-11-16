local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Interface > Bags: every bag in one Mode window (docs/DESIGN_LANGUAGE.md,
-- "Windows and panels"). The backpack, the equipped bags, the reagent bag
-- and the keyring show together on one grid of Mode slots (wider than tall,
-- in the `group` edge), with a search box, Clean Up (the game's own bag
-- sort), a view order (Bag Order, Quality, Type, Name) and the money and free
-- slots. Blizzard keeps deciding when bags open and close (B, the bag bar,
-- vendors, mail, the bank, Esc): ModeUI's window follows Blizzard's bag
-- frames, which wait under a hidden ModeUI frame while the module is on. The
-- slots are Blizzard's own item buttons (ContainerFrameItemButtonTemplate),
-- so clicks, using items (in combat too), dragging, splitting stacks and
-- tooltips stay Blizzard's code. See docs/BAGS.md.
-- Files: Init (this), Driver, Blizzard, Window, Footer, SortMenu, Slots, Layout, Settings.
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
-- Version 3 (November 15, 2026, Phase 7): the Mode design language. The
-- window's edge and the slots' edges are Mode edges, so Border Color, Corner
-- Radius, Slot Border Color and Slot Border Size go; values still at version
-- 2's defaults follow (the approved probe's 36px slots 3px apart).
M.VERSION = 3
local function Copy(value) return addon.ProfileCodec.Copy(value) end
local Public, Number = addon.IsPublic, addon.IsNumber

-- Edit Mode: the window's stand-in, and where it starts (Blizzard's bag
-- corner, the screen's bottom right above the action bars).
M.ELEMENT_ID = "modeBags"
M.DEFAULT_POSITION = { target = "screen", placement = "center", point = "BOTTOMRIGHT", relativePoint = "BOTTOMRIGHT", x = -60, y = 110 }

-- Colors: the window in Graphite panel with a Graphite raised header (as
-- every Mode window), slots in Mono panel, quest items in the quest tone.
local Tone = addon.Style.Tone
M.BACKGROUND_COLOR, M.HEADER_COLOR = Copy(Tone.graphite.panel), Copy(Tone.graphite.raised)
M.SLOT_COLOR, M.QUEST_COLOR = Copy(Tone.mono.panel), Copy(Tone.quest)

M.defaults = {
    version = M.VERSION,
    -- Layout: columns of slots, their size and gaps, the room inside the
    -- window, its scale and the corner it grows from (it stays put there).
    -- Slots are Slot Size wide and a little shorter (Style.IconHeight).
    columns = 12, slotSize = 36, spacing = 3, padding = 8, scale = 100, growFrom = "BOTTOMRIGHT",
    -- What shows: bags apart, the reagent bag and the keyring in their own
    -- sections, and the view order ("bags": as they lie in the bags).
    splitBags = false, reagentSection = true, keyring = true, sortMode = "bags",
    -- Window
    backgroundColor = Copy(M.BACKGROUND_COLOR), backgroundOpacity = 95,
    showTitle = true, headerColor = Copy(M.HEADER_COLOR), titleSize = 13,
    -- Bag Bar: the equipped bags in the footer, where a new bag can go on.
    showSearch = true, showMoney = true, showFreeSlots = true, showBagBar = true, locked = false,
    -- Slots
    slotColor = Copy(M.SLOT_COLOR), slotOpacity = 100,
    -- Quest Icon: a small quest mark in a quest item's corner.
    qualityBorders = true, qualityMinimum = "uncommon", questBorders = true, questIcon = true, questColor = Copy(M.QUEST_COLOR),
    fadeJunk = true, junkCoin = true, newItems = true, itemLevel = true, itemLevelColor = "quality",
    -- Text
    font = "game", fontMedia = addon.Style.FONT_DEFAULT, countSize = 12, levelSize = 11, outline = true,
}
M.colorKeys = { backgroundColor = true, headerColor = true, slotColor = true, questColor = true }
M.ranges = { columns = { 4, 24, 1 }, slotSize = { 24, 64, 1 }, spacing = { 0, 12, 1 }, padding = { 0, 24, 1 }, scale = { 50, 200, 5 },
    backgroundOpacity = { 0, 100, 5 }, titleSize = { 8, 20, 1 }, slotOpacity = { 0, 100, 5 },
    countSize = { 8, 20, 1 }, levelSize = { 8, 20, 1 } }
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
    -- Version 3 (Phase 7): the Mode design language. The edges are Mode
    -- edges, so their color, corner and size settings go; values still at
    -- version 2's defaults take the new ones; picked values stay.
    if db.version == 2 then
        db.borderColor, db.corner, db.slotBorderColor, db.slotBorderSize = nil, nil, nil, nil
        local Same = addon.Style.SameColor
        if Same(db.backgroundColor, Kit.onyx.health) then db.backgroundColor = Copy(M.BACKGROUND_COLOR) end
        if Same(db.headerColor, Kit.onyx.health) then db.headerColor = Copy(M.HEADER_COLOR) end
        if Same(db.slotColor, addon.Style.LEGACY.bagSlot) then db.slotColor = Copy(M.SLOT_COLOR) end
        if db.slotOpacity == 75 then db.slotOpacity = 100 end
        if db.slotSize == 38 then db.slotSize = 36 end
        if db.spacing == 4 then db.spacing = 3 end
        if db.fontMedia == "Expressway" then db.fontMedia = addon.Style.FONT_DEFAULT end
        db.version = 3
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
