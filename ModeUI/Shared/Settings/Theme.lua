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
-- settings theme ModeUI ships. Grays were darkened toward black on November 12,
-- 2026 (owner); settings are grouped on soft-bordered cards (card, cardBorder)
-- drawn with the ModeFlat texture, and the accent marks what matters.
local MODE = {
    primary = RGB(0, 240, 255), enabled = RGB(127, 219, 151),
    off = RGB(179, 179, 179), unavailable = RGB(114, 114, 114),
    highlight = RGB(212, 212, 212), ink = RGB(16, 16, 18),
    sidebar = RGB(20, 20, 22), field = RGB(30, 30, 33),
    background = RGB(24, 24, 26), panel = RGB(30, 30, 33),
    pageBackground = RGB(22, 22, 24),
    surface = RGB(34, 34, 37), hover = RGB(40, 40, 44),
    card = RGB(29, 29, 32), cardBorder = RGB(42, 42, 46),
    line = RGB(42, 42, 46), lineStrong = RGB(179, 179, 179),
    text = RGB(212, 212, 212), heading = RGB(212, 212, 212),
    secondary = RGB(179, 179, 179), muted = RGB(160, 160, 160),
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
    -- One spacing scale and one font scale for every settings surface.
    spacing = addon.Theme.spacing,
    fontSize = { small = 11, body = 12, group = 13, section = 15, page = 18, display = 20 },
}
for key, color in pairs(MODE) do addon.InterfaceTheme[key] = Copy(color) end

-- Kept for callers shared with Play The Game Tools; ModeUI only has "mode".
function addon:ResolveInterfaceTheme() return "mode" end
function addon:ApplyInterfaceTheme()
    self.appliedInterfaceTheme = "mode"
    return "mode"
end
