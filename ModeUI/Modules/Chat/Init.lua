local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Interface > Chat: Blizzard's chat windows in the Mode look. Each window gets
-- the unit frames' health color inside ModeUI's standard border (the unit
-- frames' crisp 2px rim, with round corners), Expressway text, glass tabs resting on the border (the selected one
-- raised, the others tucked), one compartment for the chat buttons, the edit
-- box joined to the window, and a slim scroll bar. When nobody uses the chat
-- it eases down to Idle Opacity and the tabs to Tabs When Idle. ModeUI
-- restyles Blizzard's own frames and never sends, reads or filters messages.
-- See docs/CHAT.md.
-- Files: Init (this), Migrations, Driver, Window, Tabs, Buttons, Fade, Settings.
local L, Kit = addon.L, addon.Kit
local M = { title = L["Chat"], category = "interface", defaultEnabled = false,
    configDescription = L["Chat windows in the Mode look: dark fill, glass tabs, a button compartment and an idle fade."],
    modeLayout = { decorateOnly = true } }
addon.Chat = M
addon:RegisterModule("chat", M)

-- Version 4 (November 13, 2026): the window takes ModeUI's standard border,
-- as the damage meter windows do (owner); Border, Border Size and Border
-- Color are retired.
M.VERSION = 4
local function Copy(value) return addon.ProfileCodec.Copy(value) end

-- Colors: the window fill (the unit frames' default health color, Onyx
-- #1C1E21, as the meters and tooltips), its border (ModeUI's standard border,
-- Kit.BORDER_COLOR: the unit frames' rim, #40454C, locked) and the edit box
-- field (#0E0F11 on #2A2D32), as in the settings window. Version 1 used
-- #0B0B0D and #25282C, version 2 Mode Slate (#44464A) (OLD_* and SLATE, for
-- migration).
M.BACKGROUND_COLOR, M.BORDER_COLOR = Copy(Kit.onyx.health), Copy(Kit.BORDER_COLOR)
M.SLATE_COLOR = Copy(Kit.onyx.slate)
M.OLD_BACKGROUND_COLOR, M.OLD_BORDER_COLOR = Kit.RGB(11, 11, 13), Copy(Kit.onyx.border)
M.FIELD_COLOR, M.FIELD_RIM = Kit.RGB(14, 15, 17), Kit.RGB(42, 45, 50)
-- The glass tab: a dark frosted fill, a faint light rim and a soft sheen.
M.GLASS_COLOR = Kit.RGB(18, 19, 22)

-- Pixel layout, in screen pixels: tab side padding and the gap between
-- tabs, the compartment's button size, the text inset inside the window and
-- the room a shown scroll bar takes at its right. (Tab Height, Edit Box
-- Height and Edit Gap are settings.)
M.TAB_PADDING, M.TAB_GAP = 12, 2
M.BUTTON_SIZE, M.TEXT_INSET, M.SCROLL_GUTTER = 20, 6, 10
-- Fades: how long a fade takes, and how often the idle check runs.
M.FADE_SECONDS, M.TICK_SECONDS = 0.6, 0.1

M.defaults = {
    version = M.VERSION,
    -- Text: the face for every chat window; each window keeps the Font Size
    -- picked in its tab's menu (Blizzard saves it per window).
    font = "game", fontMedia = "Expressway", outline = false, shadow = true,
    -- Window
    backgroundColor = Copy(M.BACKGROUND_COLOR), backgroundOpacity = 60,
    -- Edit box: inside the border at the bottom or top, or below the window.
    editPosition = "bottom", editHeight = 24, editGap = 4,
    -- Tabs: Glass (true) or Solid; others tuck down Tuck Depth. awayTabOpacity
    -- is Tabs When Idle: how visible tabs are once the chat goes idle.
    glassTabs = true, tabHeight = 24, tuckDepth = 3, tabFontSize = 13,
    unselectedTabOpacity = 55, awayTabOpacity = 0,
    -- Buttons
    buttons = "compartment", scrollBar = true,
    -- Idle fade
    idleFade = true, idleOpacity = 40, idleDelay = 8, wakeOnWhisper = true,
}

M.colorKeys = { backgroundColor = true }
M.ranges = { backgroundOpacity = { 0, 100, 5 }, tabFontSize = { 8, 20, 1 },
    editHeight = { 18, 36, 1 }, editGap = { 0, 12, 1 }, tabHeight = { 18, 32, 1 }, tuckDepth = { 0, 8, 1 },
    unselectedTabOpacity = { 0, 100, 5 }, awayTabOpacity = { 0, 100, 5 },
    idleOpacity = { 0, 100, 5 }, idleDelay = { 2, 60, 1 } }
M.choices = {
    buttons = { { id = "compartment", label = "Compartment" }, { id = "hidden", label = "Hidden" } },
    editPosition = { { id = "bottom", label = "Bottom" }, { id = "top", label = "Top" }, { id = "below", label = "Below" } },
}
