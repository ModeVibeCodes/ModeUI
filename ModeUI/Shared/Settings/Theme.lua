local _, addon = ...

-- Gameplay palette used by edit overlays, position highlights and a few shared
-- widgets (carried over from Play The Game Tools unchanged).
addon.Theme = {
    primary = { 128 / 255, 239 / 255, 128 / 255, 1 }, -- #80EF80
    secondary = { 230 / 255, 184 / 255, 1, 1 },      -- #E6B8FF
    surface = { 104 / 255, 104 / 255, 104 / 255, 1 }, -- #686868
    background = { 0.075, 0.082, 0.09, 1 },
    panel = { 0.105, 0.114, 0.122, 1 },
    text = { 0.94, 0.95, 0.95, 1 },
    muted = { 0.72, 0.75, 0.77, 1 },
    ink = { 0.06, 0.08, 0.065, 1 },
    spacing = { small = 8, medium = 16, large = 24 },
}

local function RGB(r, g, b, a) return { r / 255, g / 255, b / 255, a or 1 } end

-- Mode: near-black graphite surfaces and a cyan accent. This is the only
-- settings theme ModeUI ships. The November 2026 redesign (owner-approved
-- mockup): settings sit on cards (card, cardBorder; ModeCard texture), controls
-- are fields with a one-pixel rim (field, rim), and the accent marks what is
-- chosen (primary; accentFill behind a selected segment).
local MODE = {
    primary = RGB(0, 240, 255), accentFill = RGB(10, 58, 64),
    enabled = RGB(127, 219, 151), danger = RGB(255, 90, 95),
    off = RGB(184, 184, 191), unavailable = RGB(102, 102, 110),
    highlight = RGB(244, 244, 245), ink = RGB(11, 11, 13),
    background = RGB(11, 11, 13), pageBackground = RGB(11, 11, 13),
    sidebar = RGB(16, 16, 19), navSelected = RGB(29, 29, 33),
    card = RGB(23, 23, 26), cardBorder = RGB(38, 38, 43), panel = RGB(23, 23, 26),
    field = RGB(32, 32, 36), surface = RGB(32, 32, 36), hover = RGB(42, 42, 47),
    rim = RGB(48, 48, 54), line = RGB(38, 38, 43), lineStrong = RGB(179, 179, 179),
    -- Switch and slider tracks.
    track = RGB(42, 42, 48), trackRim = RGB(58, 58, 66),
    text = RGB(228, 228, 231), heading = RGB(228, 228, 231),
    secondary = RGB(184, 184, 191), muted = RGB(154, 154, 162), faint = RGB(110, 110, 118),
}

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
    -- One spacing scale and one font scale for every settings surface: page
    -- titles (page), section tabs and headings (section), card titles and
    -- sidebar captions, uppercase (group), setting labels (body), help (small).
    spacing = addon.Theme.spacing,
    fontSize = { small = 12, body = 13, group = 11, section = 14, page = 20, display = 20 },
}
for key, color in pairs(MODE) do addon.InterfaceTheme[key] = Copy(color) end

-- Kept for callers shared with Play The Game Tools; ModeUI only has "mode".
function addon:ResolveInterfaceTheme() return "mode" end
function addon:ApplyInterfaceTheme()
    self.appliedInterfaceTheme = "mode"
    return "mode"
end
