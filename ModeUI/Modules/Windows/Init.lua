local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Interface > Windows: Blizzard's UI windows in the Mode look. Each window's
-- border, parchment, portrait and title art is faded and replaced by a
-- near-black fill inside a one-pixel rim, a title strip, Expressway titles,
-- and Mode tabs, buttons, fields, scroll bars and close buttons (Shared/Skin).
-- Windows from load-on-demand Blizzard addons are skinned when they load.
-- Each window can be left out. Nothing is moved, resized or hidden, so
-- Blizzard keeps opening, closing and placing its windows. See docs/WINDOWS.md.
-- Files: Init (this), Migrations, Driver, Settings.
local L, Kit = addon.L, addon.Kit
local M = { title = L["Windows"], category = "interface", defaultEnabled = false,
    configDescription = L["Blizzard's windows in the Mode look: dark fill, pixel rim, Expressway titles and Mode controls."],
    modeLayout = { decorateOnly = true } }
addon.Windows = M
addon:RegisterModule("windows", M)

M.VERSION = 1
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
    { id = "guild", label = "Guild and Communities", frames = { "CommunitiesFrame" } },
    { id = "groupFinder", label = "Group Finder", frames = { "LFGListingFrame", "LFGBrowseFrame" }, addon = "Blizzard_GroupFinder_VanillaStyle" },
    { id = "collections", label = "Collections", frames = { "CollectionsJournal" }, addon = "Blizzard_Collections" },
    { id = "achievements", label = "Achievements", frames = { "AchievementFrame" }, addon = "Blizzard_AchievementUI",
        options = { fadeOwn = true } },
    { id = "worldMap", label = "World Map", frames = { "WorldMapFrame.BorderFrame" }, options = { noFill = true } },
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

-- Colors: the window fill (#0B0B0D) and its rim (the Onyx rim, #25282C).
M.BACKGROUND_COLOR, M.BORDER_COLOR = Kit.RGB(11, 11, 13), Copy(Kit.onyx.border)

local windows = {}
for _, entry in ipairs(M.registry) do windows[entry.id] = true end
M.defaults = {
    version = M.VERSION,
    -- Which windows are skinned.
    windows = windows,
    -- Frame
    backgroundColor = Copy(M.BACKGROUND_COLOR), backgroundOpacity = 94,
    border = true, borderColor = Copy(M.BORDER_COLOR), titleBar = true,
    -- Text
    font = "game", fontMedia = "Expressway", titleSize = 13, tabSize = 12, outline = false, shadow = true,
    -- Controls
    tabs = true, buttons = true, fields = true, scrollBars = true, insets = true,
}
M.colorKeys = { backgroundColor = true, borderColor = true }
M.ranges = { backgroundOpacity = { 0, 100, 5 }, titleSize = { 8, 24, 1 }, tabSize = { 8, 20, 1 } }
-- Settings that only take full effect after a reload when turned off: the
-- Blizzard art they faded comes back with the interface.
M.reloadKeys = { tabs = true, buttons = true, fields = true, scrollBars = true, insets = true }
