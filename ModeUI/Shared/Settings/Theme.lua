local _, addon = ...

-- Gameplay palette used by edit overlays, position highlights and a few shared
-- widgets (carried over from Play The Game Tools unchanged).
addon.Theme = {
    primary = { 128 / 255, 239 / 255, 128 / 255, 1 }, -- #80EF80
    -- Edit Mode names each movable frame in volt green, readable on any scene.
    volt = { 204 / 255, 1, 0, 1 },                    -- #CCFF00
    secondary = { 230 / 255, 184 / 255, 1, 1 },      -- #E6B8FF
    surface = { 104 / 255, 104 / 255, 104 / 255, 1 }, -- #686868
    background = { 0.075, 0.082, 0.09, 1 },
    panel = { 0.105, 0.114, 0.122, 1 },
    text = { 0.94, 0.95, 0.95, 1 },
    muted = { 0.72, 0.75, 0.77, 1 },
    ink = { 0.06, 0.08, 0.065, 1 },
    spacing = { small = 8, medium = 16, large = 24 },
}

-- Mode: the settings window in the Mode design language
-- (docs/DESIGN_LANGUAGE.md, "Settings window"): Graphite surfaces, Ivory as
-- the accent, Celadon and Rosewood for on and off, 1px black separators. Every
-- color is a Style.Tone token.
local Style = addon.Style
local Tone, G = Style.Tone, Style.Tone.graphite
local function C(color, alpha) return { color[1], color[2], color[3], alpha or 1 } end
-- Built from the tokens as they are now (Mode-Obsidian, set at load; Palette()
-- again whenever the look is applied, Style.OnThemeApplied below).
local function Palette() return {
    primary = C(Tone.ivory), accentFill = C(Style.Mix(Tone.ivory, G.raised, 0.12)),
    -- Flat rims of the Ivory and Rosewood buttons: their color 70% toward black.
    primaryRim = C(Style.Mix(Tone.ivory, G.void, 0.3)), dangerRim = C(Style.Mix(Tone.rosewood, G.void, 0.3)),
    enabled = C(Tone.celadon), danger = C(Tone.rosewood),
    off = C(Tone.rosewood), unavailable = C(G.rimStrong),
    highlight = C(G.white), ink = C(Tone.mono.panel), onInk = C(Tone.celadonInk),
    background = C(G.panel), pageBackground = C(G.panel),
    sidebar = C(G.panel), navSelected = C(Style.Mix(G.white, G.panel, 0.06)),
    previewPane = C(G.base),
    card = C(G.raised), cardBorder = C(G.line), panel = C(G.panel), header = C(G.raised),
    field = C(G.panel), surface = C(G.raised), hover = C(G.track), button = C(Style.Mix(G.line, G.track, 0.5)),
    rim = C(G.rim), line = C(G.void), lineStrong = C(G.rim),
    -- Slide toggle and rail slider.
    track = C(G.rim), trackRim = C(G.rimStrong), toggleTrack = C(Style.Mix(G.base, G.void, 0.5)),
    toggleOn = C(Tone.celadon), toggleOff = C(Tone.rosewoodDeep), toggleIdle = C(G.muted),
    text = C(G.text), heading = C(G.white),
    secondary = C(G.secondary), muted = C(G.muted), faint = C(Style.Mix(G.muted, G.rimStrong, 0.5)),
} end
local MODE = Palette()

addon.InterfaceThemes = {
    order = { "mode" },
    default = "mode",
    mode = { label = "Mode", palette = MODE },
}

local function Copy(color) return { color[1], color[2], color[3], color[4] or 1 } end

-- Settings files hold addon.InterfaceTheme and its color tables as upvalues, so
-- the palette is installed here, before any of them load.
addon.InterfaceTheme = {
    id = "mode",
    blizzardArt = false,
    -- One font scale for every settings surface (the artifact's sizes): page
    -- titles 18, section tabs and headings 12, card titles 11 uppercase, sidebar
    -- captions 10 uppercase, labels 12, values and help 11, the Mode wordmark
    -- 22 in Mode Script (a script's lowercase runs small, so it sits larger).
    spacing = addon.Theme.spacing,
    fontSize = { small = 11, body = 12, group = 10, card = 11, section = 12, brand = 22, page = 18, display = 18 },
}
for key, color in pairs(MODE) do addon.InterfaceTheme[key] = Copy(color) end

-- A theme (docs/DESIGN_LANGUAGE.md, "Mode-Obsidian theme") changes the
-- tokens after load: the palette's colors change in place, since settings
-- files hold its tables as upvalues.
Style.OnThemeApplied(function()
    for key, color in pairs(Palette()) do
        MODE[key] = color
        local live = addon.InterfaceTheme[key]
        if type(live) == "table" then live[1], live[2], live[3], live[4] = color[1], color[2], color[3], color[4] or 1
        else addon.InterfaceTheme[key] = Copy(color) end
    end
end)

-- Kept for callers shared with Play The Game Tools; ModeUI only has "mode".
function addon:ResolveInterfaceTheme() return "mode" end
function addon:ApplyInterfaceTheme()
    self.appliedInterfaceTheme = "mode"
    return "mode"
end
