local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Interface > Chat: Blizzard's chat windows in the Mode design language
-- (docs/DESIGN_LANGUAGE.md). Each window is a Mode window (Mode Panel in
-- Graphite, the `window` edge inside it), the Mode typeface, Mode tabs
-- resting on the edge (the selected one raised and Ivory, the others
-- tucked), one compartment for the chat buttons, the edit box joined to the
-- window, and a slim scroll bar. When nobody uses the chat
-- it eases down to Idle Opacity and the tabs to Tabs When Idle. ModeUI
-- restyles Blizzard's own frames and never sends, reads or filters messages.
-- See docs/CHAT.md.
-- Files: Init (this), Migrations, Driver, Window, Tabs, Buttons, Fade, Settings.
local L, Kit = addon.L, addon.Kit
local M = { title = L["Chat"], category = "interface", defaultEnabled = false,
    configDescription = L["Chat windows in the Mode look: Graphite windows, Mode tabs, a button compartment and an idle fade."],
    modeLayout = { decorateOnly = true } }
addon.Chat = M
addon:RegisterModule("chat", M)

-- Version 4 (November 13, 2026): the window takes ModeUI's standard border,
-- as the damage meter windows do (owner); Border, Border Size and Border
-- Color are retired.
-- Version 5 (November 13, 2026): the health color moved to #131212; a fill
-- still at the old #1C1E21 follows.
-- Version 6 (November 15, 2026, Phase 7): the Mode design language. A fill
-- still at #131212 moves to Graphite panel; a face still at "Expressway"
-- moves to the Mode typeface (Expressway when installed, else Geist).
M.VERSION = 6
local function Copy(value) return addon.ProfileCodec.Copy(value) end

-- The window fill: Graphite panel, as every Mode window. Earlier defaults,
-- kept only so migrations recognize a fill never changed: version 1's
-- #0B0B0D (Style.LEGACY.windowFill), version 2's Mode Slate, versions 3-5's
-- Onyx health (#1C1E21, then #131212).
M.BACKGROUND_COLOR = Copy(addon.Style.Tone.graphite.panel)

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
    font = "game", fontMedia = addon.Style.FONT_DEFAULT, outline = false, shadow = true,
    -- Window
    backgroundColor = Copy(M.BACKGROUND_COLOR), backgroundOpacity = 60,
    -- The window's border (docs/DESIGN_LANGUAGE.md, "Choosing a border"):
    -- Mode-Thin in its own metal (owner, November 17, 2026). Tabs, buttons and
    -- the field keep their `control` edge. New keys: filled from these defaults.
    edgeStyle = "thin", edgeMetal = "default",
    -- Edit box: inside the edge at the bottom or top, or below the window.
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
    edgeStyle = addon.Style.EdgeStyleChoices(),
    edgeMetal = addon.Style.EdgeMetalChoices(),
}
