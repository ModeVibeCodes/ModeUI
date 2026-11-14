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

local function RGB(r, g, b, a) return { r / 255, g / 255, b / 255, a or 1 } end

-- Mode: near-black graphite surfaces and a cyan accent. This is the only
-- settings theme ModeUI ships. The November 2026 redesign (owner-approved
-- mockup): settings sit on cards (card, cardBorder; ModeCard texture), controls
-- are fields with a one-pixel rim (field, rim), and the accent marks what is
-- chosen (primary; accentFill behind a selected segment).
-- Colors follow the owner's Layout tab design (November 13, 2026): a cooler
-- near-black with cards #121316 on a #1E2024 rim, fields #0E0F11 on #2A2D32,
-- labels #C4C8CE over values #8A8F96, and a #22262B selected segment.
local MODE = {
    primary = RGB(0, 240, 255), accentFill = RGB(34, 38, 43),
    enabled = RGB(127, 219, 151), danger = RGB(255, 90, 95),
    off = RGB(184, 184, 191), unavailable = RGB(102, 102, 110),
    highlight = RGB(244, 244, 245), ink = RGB(11, 11, 13),
    background = RGB(11, 11, 13), pageBackground = RGB(11, 11, 13),
    sidebar = RGB(11, 11, 13), navSelected = RGB(22, 24, 28),
    card = RGB(18, 19, 22), cardBorder = RGB(30, 32, 36), panel = RGB(18, 19, 22),
    field = RGB(14, 15, 17), surface = RGB(18, 19, 22), hover = RGB(34, 38, 43),
    rim = RGB(42, 45, 50), line = RGB(30, 32, 36), lineStrong = RGB(74, 79, 86),
    -- Switch and slider tracks.
    track = RGB(42, 45, 50), trackRim = RGB(58, 62, 68),
    text = RGB(228, 228, 228), heading = RGB(242, 242, 242),
    secondary = RGB(196, 200, 206), muted = RGB(138, 143, 150), faint = RGB(110, 115, 122),
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
    -- titles (page), section tabs and headings (section), card titles (card),
    -- sidebar captions, uppercase (group), setting labels (body), help (small)
    -- and the ModeUI wordmark in the header (brand, 7 px above section).
    spacing = addon.Theme.spacing,
    fontSize = { small = 12, body = 13, group = 12, card = 19, section = 14, brand = 21, page = 24, display = 24 },
}
for key, color in pairs(MODE) do addon.InterfaceTheme[key] = Copy(color) end

-- Kept for callers shared with Play The Game Tools; ModeUI only has "mode".
function addon:ResolveInterfaceTheme() return "mode" end
function addon:ApplyInterfaceTheme()
    self.appliedInterfaceTheme = "mode"
    return "mode"
end
