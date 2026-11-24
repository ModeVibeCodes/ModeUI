local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M then return end

-- Swing Timer (owner, November 24, 2026; Forever only): your auto-attack
-- swings from Forever's own swing timer API (C_SwingTimer, PLAYER_SWING:
-- each swing's duration and type), as a Player Bar in the resource bars'
-- look. A lane for the main hand (or ranged), one for the off hand while you
-- swing it; the fill runs from one swing to the next, tinted while the target
-- is out of auto-attack range. Saved in db.swing, added without a version
-- step; it exists only where the client has the API (M.caps.swingTimer), so
-- a client without it keeps the settings and shows nothing. SwingTimer.lua
-- runs it; SwingSettings.lua is its page.
local L = addon.L
local Public, Number = addon.IsPublic, addon.IsNumber
local Style = addon.Style
local Tone = Style.Tone
local function Copy(value) return addon.ProfileCodec.Copy(value) end

M.SWING_LABEL = "Swing Timer"
M.SWING_ELEMENT = "cooldownManagerSwingTimer"
M.SWING_FRAME = "ModeUISwingTimer"
-- Enum.PlayerSwingType on Forever: MainHand 0, OffHand 1, Ranged 2.
M.SWING_TYPES = { main = 0, off = 1, ranged = 2 }
-- Its Edit Mode target is added when the module starts, where the client has the API (Driver.lua).
function M:AddSwingTarget()
    if self.caps.swingTimer then addon.Positioning:AddTarget(self.SWING_ELEMENT, L[self.SWING_LABEL], self.SWING_FRAME) end
end
-- Under the resource bars' stack (Health holds its place while off).
M.swingPosition = { target = M.ResourceElementId("health"), placement = "below", x = 0, y = 0 }

M.swingDefaults = {
    show = true, width = 300, height = 4, matchWidth = true,
    border = "mode", edgeStyle = "obsidian", edgeMetal = "default", edgeSize = 1, rimColor = "metal", rimCustom = Copy(Tone.ivory),
    barTexture = "media:Mode-FG", barColorMode = "class", barColor = Copy(Tone.ivory),
    barBackground = "media:Mode-BG", barBackgroundOpacity = M.RESOURCE_EMPTY,
    -- The off hand's own lane, ranged swings (Hunters), the out-of-range tint.
    offHand = true, ranged = true, rangeTint = true,
    timerShow = false, textSize = 10, textColor = Copy(Tone.textBright),
    font = "game", fontMedia = Style.FONT_DEFAULT, outline = false, shadow = true, slug = true,
    opacity = 100,
}
M.swingIdentityKeys = { show = true, width = true, height = true, matchWidth = true }
M.swingColorKeys = { rimCustom = true, barColor = true, textColor = true }
M.swingRanges = { width = { 40, 600, 1 }, height = { 2, 24, 1 }, edgeSize = { 1, 2, 1 }, barBackgroundOpacity = { 0, 100, 5 },
    textSize = { 6, 32, 1 }, opacity = { 10, 100, 5 } }
M.swingChoices = {
    border = { { id = "mode", label = "Mode" }, { id = "none", label = "None" } },
    edgeStyle = Style.EdgeStyleChoices(), edgeMetal = Style.EdgeMetalChoices(),
    rimColor = { { id = "metal", label = "Metal" }, { id = "bar", label = "Bar Color" }, { id = "custom", label = "Custom" } },
    barColorMode = { { id = "class", label = "Class Color" }, { id = "custom", label = "Custom" } },
}

local function Whole(value, range) return Number(value, range[1], range[2]) and value == math.floor(value) end
-- Fills in and checks db.swing (Parts.lua). Bad data stops with an error;
-- nothing is reset.
function M.ValidateSwing(db)
    -- A new one follows the Bar Style's border and font (BarStyle.lua).
    if db.swing == nil then db.swing = Copy(M.swingDefaults); db.swing.follow = { border = true, text = true } end
    local style = db.swing
    assert(Public(style) and type(style) == "table", "Invalid swing timer settings")
    for key, default in pairs(M.swingDefaults) do
        if style[key] == nil then style[key] = Copy(default) end
        local value = style[key]
        assert(Public(value) and type(value) == type(default), "Invalid swing timer setting: " .. key)
        if M.swingColorKeys[key] then
            for i = 1, 3 do assert(Number(value[i], 0, 1), "Invalid swing timer color: " .. key) end
        end
    end
    for key, range in pairs(M.swingRanges) do assert(Whole(style[key], range), "Invalid swing timer range: " .. key) end
    for key, list in pairs(M.swingChoices) do
        local ok = false
        for _, item in ipairs(list) do if item.id == style[key] then ok = true end end
        assert(ok, "Invalid swing timer choice: " .. key)
    end
    assert(addon.Kit.ValidBarTexture(style.barTexture, true), "Invalid swing timer texture")
    assert(addon.Kit.ValidBarTexture(style.barBackground, false), "Invalid swing timer background")
end
