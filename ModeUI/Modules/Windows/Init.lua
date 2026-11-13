local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Interface > Windows: Blizzard's UI windows in the Mode look. Each window's
-- border, parchment, portrait, filigree and title art is faded and replaced
-- by a near-black fill inside a crisp 2px border (as the unit frames'), a
-- title strip, Expressway text, and Mode tabs, buttons, fields, dropdowns,
-- scroll bars and window buttons (Shared/Skin). Window Style swaps every
-- window between ModeUI and Blizzard's own look; each window can also be
-- left Blizzard's, given its own look and a scale. The Character window adds
-- a stats display, rarity borders and enchant text (Character*.lua).
-- Windows from load-on-demand Blizzard addons are skinned when they load.
-- Nothing is moved, sized or hidden (Scale aside), so Blizzard keeps opening,
-- closing and placing its windows. See docs/WINDOWS.md.
-- Files: Init (this), Migrations, Driver, Character, CharacterStats,
-- Settings, SettingsCharacter.
local L, Kit = addon.L, addon.Kit
local M = { title = L["Windows"], category = "interface", defaultEnabled = false,
    configDescription = L["Blizzard's windows in the Mode look: dark fill, pixel rim, Expressway titles and Mode controls."],
    modeLayout = { decorateOnly = true } }
addon.Windows = M
addon:RegisterModule("windows", M)

M.VERSION = 2
local function Copy(value) return addon.ProfileCodec.Copy(value) end

-- The windows on Forever (checked against its interface source; see
-- docs/API_COMPATIBILITY.md). `frames` are global names, or a name and a
-- key ("WorldMapFrame.BorderFrame"); `addon` names the load-on-demand
-- Blizzard addon that makes them. Options go to Skin.Window.
M.registry = {
    { id = "character", label = "Character", frames = { "CharacterFrame" },
        options = { fade = { "LeftPaneHost", "RightPaneHost", function(frame) return frame.RightPaneHost and frame.RightPaneHost.StoneBg end } } },
    { id = "spellbook", label = "Spellbook and Talents", frames = { "PlayerSpellsFrame" }, addon = "Blizzard_PlayerSpells" },
    { id = "professions", label = "Professions", frames = { "ProfessionsFrame" }, addon = "Blizzard_Professions" },
    { id = "social", label = "Social", frames = { "FriendsFrame" } },
    { id = "guild", label = "Guild and Communities", frames = { "CommunitiesFrame" }, options = { fadeRows = true } },
    { id = "groupFinder", label = "Group Finder", frames = { "LFGListingFrame", "LFGBrowseFrame" }, addon = "Blizzard_GroupFinder_VanillaStyle" },
    { id = "collections", label = "Collections", frames = { "CollectionsJournal" }, addon = "Blizzard_Collections" },
    { id = "achievements", label = "Achievements", frames = { "AchievementFrame" }, addon = "Blizzard_AchievementUI",
        options = { fadeOwn = true } },
    { id = "worldMap", label = "World Map", frames = { "WorldMapFrame.BorderFrame" }, options = { noFill = true }, noScale = true },
    { id = "quests", label = "Quests and Gossip", frames = { "QuestFrame", "GossipFrame", "QuestLogPopupDetailFrame" } },
    { id = "merchant", label = "Merchant", frames = { "MerchantFrame" } },
    { id = "mail", label = "Mail", frames = { "MailFrame", "OpenMailFrame" } },
    { id = "bank", label = "Bank", frames = { "BankFrame" } },
    { id = "trade", label = "Trade", frames = { "TradeFrame" } },
    { id = "inspect", label = "Inspect", frames = { "InspectFrame" }, addon = "Blizzard_InspectUI" },
    { id = "trainer", label = "Trainer", frames = { "ClassTrainerFrame" }, addon = "Blizzard_TrainerUI" },
    { id = "auctionHouse", label = "Auction House", frames = { "AuctionHouseFrame" }, addon = "Blizzard_AuctionHouseUI" },
    { id = "dressingRoom", label = "Dressing Room", frames = { "DressUpFrame" } },
    { id = "petStable", label = "Pet Stable", frames = { "PetStableFrame" } },
    { id = "raid", label = "Raid", frames = { "RaidParentFrame" } },
    { id = "macros", label = "Macros", frames = { "MacroFrame" }, addon = "Blizzard_MacroUI" },
    { id = "addonList", label = "AddOn List", frames = { "AddonList" } },
    { id = "gameMenu", label = "Game Menu", frames = { "GameMenuFrame" } },
    { id = "settings", label = "Game Settings", frames = { "SettingsPanel" } },
}
M.byId = {}
for _, entry in ipairs(M.registry) do M.byId[entry.id] = entry end

-- Colors: the window fill (#0B0B0D) and its border (the unit frames' rim,
-- #40454C). Version 1's border was the Onyx rim, #25282C (for migration).
M.BACKGROUND_COLOR, M.BORDER_COLOR = Kit.RGB(11, 11, 13), Copy(Kit.onyx.frameRim)
M.OLD_BORDER_COLOR = Copy(Kit.onyx.border)

-- A window's own look (the Windows tab, each window expanded): used instead
-- of the Look tab's when `custom` is on. `scale` applies either way.
M.LOOK = { custom = false, backgroundOpacity = 94, border = true, titleBar = true, scale = 100 }
M.lookRanges = { backgroundOpacity = { 0, 100, 5 }, scale = { 50, 150, 5 } }

-- The Character window's stats display: every stat it can show, in order
-- (CharacterStats.lua reads them). Main Stat is the specialization's primary
-- stat, or the highest of Strength, Agility and Intellect.
M.STATS = {
    { id = "mainStat", label = "Main Stat" }, { id = "strength", label = "Strength" },
    { id = "agility", label = "Agility" }, { id = "stamina", label = "Stamina" },
    { id = "intellect", label = "Intellect" }, { id = "spirit", label = "Spirit" },
    { id = "armor", label = "Armor" }, { id = "attackPower", label = "Attack Power" },
    { id = "rangedAttackPower", label = "Ranged Attack Power" }, { id = "spellPower", label = "Spell Power" },
    { id = "healing", label = "Healing" }, { id = "crit", label = "Crit" }, { id = "spellCrit", label = "Spell Crit" },
    { id = "rangedCrit", label = "Ranged Crit" }, { id = "hit", label = "Hit" }, { id = "spellHit", label = "Spell Hit" },
    { id = "haste", label = "Haste" }, { id = "spellHaste", label = "Spell Haste" },
    { id = "expertise", label = "Expertise" }, { id = "dodge", label = "Dodge" }, { id = "parry", label = "Parry" },
    { id = "block", label = "Block" }, { id = "manaRegen", label = "Mana Regen" },
}
M.statsById = {}
for _, stat in ipairs(M.STATS) do M.statsById[stat.id] = stat end

local windows, looks = {}, {}
for _, entry in ipairs(M.registry) do windows[entry.id] = true; looks[entry.id] = Copy(M.LOOK) end
M.defaults = {
    version = M.VERSION,
    -- ModeUI or Blizzard: every window at once.
    style = "modeui",
    -- Which windows are in the Mode look, and each one's own look.
    windows = windows, looks = looks,
    -- Frame
    backgroundColor = Copy(M.BACKGROUND_COLOR), backgroundOpacity = 94,
    border = true, borderColor = Copy(M.BORDER_COLOR), borderSize = 2, titleBar = true,
    -- Text: titles and tabs at their sizes; Window Text puts every other
    -- text in the window in the font too, at the game's sizes.
    font = "game", fontMedia = "Expressway", titleSize = 13, tabSize = 12, outline = false, shadow = true,
    bodyFont = true,
    -- Controls
    tabs = true, buttons = true, fields = true, scrollBars = true, insets = true, dropdowns = true,
    -- Character window: stats display, rarity borders, enchant text.
    charStats = true, charStatsBackground = true, charStatsAnchor = "TOPLEFT", charStatsX = 8, charStatsY = -8,
    charStatsSize = 12, charStatList = { mainStat = true, stamina = true, armor = true, crit = true, hit = true, haste = true },
    charBorders = true, charBorderSize = 2, charEnchants = true, charEnchantSize = 10,
}
M.colorKeys = { backgroundColor = true, borderColor = true }
M.ranges = { backgroundOpacity = { 0, 100, 5 }, titleSize = { 8, 24, 1 }, tabSize = { 8, 20, 1 }, borderSize = { 1, 4, 1 },
    charStatsX = { -300, 300, 1 }, charStatsY = { -300, 300, 1 }, charStatsSize = { 8, 20, 1 },
    charBorderSize = { 1, 4, 1 }, charEnchantSize = { 8, 16, 1 } }
M.choices = {
    style = { { id = "modeui", label = "ModeUI" }, { id = "blizzard", label = "Blizzard" } },
    charStatsAnchor = { { id = "TOPLEFT" }, { id = "TOP" }, { id = "TOPRIGHT" }, { id = "LEFT" }, { id = "CENTER" },
        { id = "RIGHT" }, { id = "BOTTOMLEFT" }, { id = "BOTTOM" }, { id = "BOTTOMRIGHT" } },
}
-- Settings that only take full effect after a reload when turned off: the
-- Blizzard art (and fonts) they replaced come back with the interface.
M.reloadKeys = { tabs = true, buttons = true, fields = true, scrollBars = true, insets = true, dropdowns = true,
    bodyFont = true }
