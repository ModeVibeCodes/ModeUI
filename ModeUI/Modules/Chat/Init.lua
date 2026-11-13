local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Interface > Chat: Blizzard's chat windows in the Mode look. Each window gets
-- a near-black fill and a one-pixel rim, Expressway text, glass tabs that fade
-- when the mouse leaves, one compartment for the chat buttons and a matching
-- edit box. When nobody uses the chat it eases down to Idle Opacity. ModeUI
-- restyles Blizzard's own frames and never sends, reads or filters messages.
-- See docs/CHAT.md.
-- Files: Init (this), Migrations, Driver, Window, Tabs, Buttons, Fade, Settings.
local L, Kit = addon.L, addon.Kit
local M = { title = L["Chat"], category = "interface", defaultEnabled = false,
    configDescription = L["Chat windows in the Mode look: dark fill, glass tabs, a button compartment and an idle fade."],
    modeLayout = { decorateOnly = true } }
addon.Chat = M
addon:RegisterModule("chat", M)

M.VERSION = 1
local function Copy(value) return addon.ProfileCodec.Copy(value) end

-- Colors: the window fill (#0B0B0D), its rim (the Onyx rim, #25282C) and the
-- edit box field (#0E0F11 on #2A2D32), as in the settings window.
M.BACKGROUND_COLOR, M.BORDER_COLOR = Kit.RGB(11, 11, 13), Copy(Kit.onyx.border)
M.FIELD_COLOR, M.FIELD_RIM = Kit.RGB(14, 15, 17), Kit.RGB(42, 45, 50)
-- The glass tab: a dark frosted fill, a faint light rim and a soft sheen.
M.GLASS_COLOR = Kit.RGB(18, 19, 22)

-- Pixel layout, in screen pixels: tab height and side padding, the gap
-- between tabs, the compartment's button size, the edit box height and its
-- gap under the window, and the text inset inside the window.
M.TAB_HEIGHT, M.TAB_PADDING, M.TAB_GAP = 22, 12, 2
M.BUTTON_SIZE, M.EDIT_HEIGHT, M.EDIT_GAP, M.TEXT_INSET = 20, 24, 4, 6
-- Fades: how long a fade takes, and how often the idle check runs.
M.FADE_SECONDS, M.TICK_SECONDS = 0.6, 0.1

M.defaults = {
    version = M.VERSION,
    -- Text: the face for every chat window; each window keeps the Font Size
    -- picked in its tab's menu (Blizzard saves it per window).
    font = "game", fontMedia = "Expressway", outline = false, shadow = true,
    -- Window
    backgroundColor = Copy(M.BACKGROUND_COLOR), backgroundOpacity = 72,
    border = true, borderColor = Copy(M.BORDER_COLOR),
    -- Tabs
    glassTabs = true, tabFontSize = 13, unselectedTabOpacity = 55, awayTabOpacity = 0,
    -- Buttons
    buttons = "compartment", scrollBar = false,
    -- Idle fade
    idleFade = true, idleOpacity = 40, idleDelay = 8, wakeOnWhisper = true,
}

M.colorKeys = { backgroundColor = true, borderColor = true }
M.ranges = { backgroundOpacity = { 0, 100, 5 }, tabFontSize = { 8, 20, 1 },
    unselectedTabOpacity = { 0, 100, 5 }, awayTabOpacity = { 0, 100, 5 },
    idleOpacity = { 0, 100, 5 }, idleDelay = { 2, 60, 1 } }
M.choices = {
    buttons = { { id = "compartment", label = "Compartment" }, { id = "hidden", label = "Hidden" } },
}
