local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M then return end

-- Bar Style (owner, November 24, 2026): the default look for bars. New bars
-- and new profiles follow it; an existing bar follows it group by group (the
-- bar's `follow` table: size, border, background, cooldown, text, glows,
-- fill). Following writes the Bar Style's values into the bar's own settings,
-- so everything that draws a bar reads the bar's table as before; changing a
-- followed value on a bar's page makes that group Custom (Driver.lua,
-- SetOption). The resource bars and the Cast Bar follow its border and text.
-- Settings version 12 (MigrateV12, below). See docs/COOLDOWN_MANAGER.md.
local Mode = addon.Style
local Tone, Number, Public = Mode.Tone, addon.IsNumber, addon.IsPublic
local function Copy(value) return addon.ProfileCodec.Copy(value) end

-- The owner's Bar Style (the workbench, November 24, 2026): 38 x 30 and
-- 32 x 26 icons, one shared shadow pixel between them, Mode-Border in
-- Gunmetal, amber outlined cooldown numbers, brand gold proc glows.
local base = M.styleDefaults.essential
M.barStyleDefaults = {
    largeWidth = 38, largeHeight = 30, smallWidth = 32, smallHeight = 26, spacing = -1,
    border = "mode", edgeStyle = "obsidian", edgeMetal = "gunmetal", edgeSize = 1, edgeColor = Copy(Tone.emptyRim),
    backgroundColor = Copy(base.backgroundColor), backgroundOpacity = base.backgroundOpacity,
    desaturate = true, swipeColor = Copy(base.swipeColor), swipeOpacity = base.swipeOpacity, showEdge = false,
    showBling = true, showFlash = true, rangeTint = true, auraSwipe = false,
    font = base.font, fontMedia = base.fontMedia, outline = true, shadow = true, slug = true,
    cooldownColor = Copy(Tone.cooldown), countColor = Copy(Tone.textBright), nameColor = Copy(Tone.textBright),
    durationColor = Copy(Tone.textBright),
    -- Text sizes at the role's height; a taller or shorter icon scales them.
    cooldownSize = 14, cooldownSizeSmall = 12, countSize = 10, countSizeSmall = 10, barTextSize = 10,
    procGlow = "mode", procColor = Copy(Tone.brand), procPulse = false,
    activeGlow = base.activeGlow, activeColor = Copy(base.activeColor), activePulse = base.activePulse,
    readyGlow = base.readyGlow, readyColor = Copy(base.readyColor), readyPulse = base.readyPulse,
    readyMode = base.readyMode, readyDuration = base.readyDuration,
    buffGlow = base.buffGlow, buffColor = Copy(base.buffColor), buffPulse = base.buffPulse,
    glowLines = base.glowLines, glowThickness = base.glowThickness,
    barTexture = base.barTexture, barColorMode = base.barColorMode, barColor = Copy(base.barColor),
    barBackground = base.barBackground, barBackgroundOpacity = base.barBackgroundOpacity, showSpark = base.showSpark,
}

-- The groups, in page order, and the bar keys each covers. Size and the text
-- sizes are worked out per bar (its role and height), the rest copied.
M.styleGroups = { "size", "border", "background", "cooldown", "text", "glows", "fill" }
M.styleGroupLabels = { size = "Size", border = "Border", background = "Background", cooldown = "Cooldown",
    text = "Text", glows = "Starting Glow Look", fill = "Bar Fill" }
local COPIED = {
    border = { "border", "edgeStyle", "edgeMetal", "edgeSize", "edgeColor" },
    background = { "backgroundColor", "backgroundOpacity" },
    cooldown = { "desaturate", "swipeColor", "swipeOpacity", "showEdge", "showBling", "showFlash", "rangeTint", "auraSwipe" },
    text = { "font", "fontMedia", "outline", "shadow", "slug", "cooldownColor", "countColor", "nameColor", "durationColor" },
    glows = { "procGlow", "procColor", "procPulse", "activeGlow", "activeColor", "activePulse", "readyGlow", "readyColor",
        "readyPulse", "readyMode", "readyDuration", "buffGlow", "buffColor", "buffPulse", "glowLines", "glowThickness" },
    fill = { "barTexture", "barColorMode", "barColor", "barBackground", "barBackgroundOpacity", "showSpark" },
}
M.styleGroupCopied = COPIED
-- Which group a bar key belongs to (a change to it makes that group Custom).
M.styleKeyGroup = { width = "size", height = "size", spacing = "size",
    cooldownSize = "text", countSize = "text", nameSize = "text", durationSize = "text" }
for group, keys in pairs(COPIED) do for _, key in ipairs(keys) do M.styleKeyGroup[key] = group end end

-- The resource bars and the Cast Bar: their border (Rim Color back to the
-- metal) and their font.
M.playerStyleGroups = { "border", "text" }
local PLAYER_COPIED = { border = { "border", "edgeStyle", "edgeMetal", "edgeSize" }, text = { "font", "fontMedia", "outline", "shadow", "slug" } }
M.playerKeyGroup = { rimColor = "border", rimCustom = "border" }
for group, keys in pairs(PLAYER_COPIED) do for _, key in ipairs(keys) do M.playerKeyGroup[key] = group end end

-- A bar's kind in `db`: a viewer ID, or a custom bar's "cooldown"/"buff"
-- with its entry.
local function Kind(db, id)
    if M.viewerSpecs[id] then return id end
    for _, bar in ipairs(type(db.customBars) == "table" and db.customBars or {}) do
        if type(bar) == "table" and bar.id == id then return bar.kind, bar end
    end
end
-- Icons come Large (Essential, Utility, Cooldown Bars) or Small (Tracked
-- Buffs, Buff Bars); Tracked Bars have no icon size of their own.
local function Role(db, id)
    local kind = Kind(db, id)
    if kind == "buffBar" or kind == nil then return nil end
    return (kind == "buffIcon" or kind == "buff") and "small" or "large"
end
function M:SizeRole(id) return Role(self.db, id) end
M.StyleRole = Role

-- The groups a bar can follow.
local function Groups(db, id)
    -- Tracked Bars: Size is their Spacing only (a bar's length is its own).
    if Kind(db, id) == "buffBar" then return { "size", "border", "background", "text", "fill" } end
    return { "size", "border", "background", "cooldown", "text", "glows" }
end
function M:StyleGroups(id) return Groups(self.db, id) end
function M:Follows(id, group)
    local style = self.db[id]
    return type(style) == "table" and type(style.follow) == "table" and style.follow[group] == true
end

local function Scaled(size, height, ref) return math.max(6, math.min(32, math.floor(size * height / ref + 0.5))) end

-- The values group `group` gives bar `id` (a table of key = value).
local function Values(db, id, group, style)
    local bs, out = db.barStyle, {}
    if group == "size" then
        local role = Role(db, id)
        if role then out.width, out.height = bs[role .. "Width"], bs[role .. "Height"] end
        out.spacing = bs.spacing
        return out
    end
    for _, key in ipairs(COPIED[group] or {}) do out[key] = Copy(bs[key]) end
    if group == "text" then
        local role = Role(db, id)
        if role == nil then
            out.nameSize, out.durationSize, out.countSize = bs.barTextSize, bs.barTextSize, bs.barTextSize
        else
            local small, height = role == "small", style.height
            local ref = small and bs.smallHeight or bs.largeHeight
            out.cooldownSize = Scaled(small and bs.cooldownSizeSmall or bs.cooldownSize, height, ref)
            out.countSize = Scaled(small and bs.countSizeSmall or bs.countSize, height, ref)
        end
    end
    return out
end

local function Same(a, b)
    if type(a) == "table" and type(b) == "table" then return Mode.SameColor(a, b) and a[4] == b[4] end
    return a == b
end
-- Whether bar `id` already looks like group `group` of the Bar Style.
local function Matches(db, id, group)
    local style = db[id]
    for key, value in pairs(Values(db, id, group, style)) do if not Same(style[key], value) then return false end end
    return true
end

-- Writes every followed group of bar `id` into its settings (size first:
-- the text sizes follow the height).
function M.ApplyBarStyle(db, id)
    local style = db[id]
    if type(style) ~= "table" or type(style.follow) ~= "table" or type(db.barStyle) ~= "table" then return end
    for _, group in ipairs(M.styleGroups) do
        if style.follow[group] then
            for key, value in pairs(Values(db, id, group, style)) do style[key] = value end
        end
    end
end
-- The resource bars' and the Cast Bar's followed groups.
function M.ApplyPlayerStyle(db, style)
    if type(style) ~= "table" or type(style.follow) ~= "table" or type(db.barStyle) ~= "table" then return end
    for _, group in ipairs(M.playerStyleGroups) do
        if style.follow[group] then
            for _, key in ipairs(PLAYER_COPIED[group]) do style[key] = Copy(db.barStyle[key]) end
            if group == "border" then style.rimColor = "metal" end
        end
    end
end
-- Every bar in `db`, by its follow tables.
local function PlayerStyles(db)
    local list = {}
    for _, id in ipairs(M.resources or {}) do if type(db.resources) == "table" then list[#list + 1] = db.resources[id] end end
    list[#list + 1] = db.castBar
    return list
end
local function BarIds(db)
    local ids = {}
    for _, viewer in ipairs(M.viewers) do ids[#ids + 1] = viewer end
    for _, bar in ipairs(type(db.customBars) == "table" and db.customBars or {}) do
        if type(bar) == "table" and type(bar.id) == "string" then ids[#ids + 1] = bar.id end
    end
    return ids
end
function M.ApplyBarStyleAll(db)
    for _, id in ipairs(BarIds(db)) do M.ApplyBarStyle(db, id) end
    for _, style in ipairs(PlayerStyles(db)) do M.ApplyPlayerStyle(db, style) end
end

-- A new bar's follow table: every group it has (a default bar keeps its
-- own shape, so it doesn't follow Size).
function M.NewFollow(db, id)
    local follow, _, bar = {}, Kind(db, id)
    for _, group in ipairs(Groups(db, id)) do follow[group] = true end
    if bar and bar.preset ~= nil then follow.size = false end
    return follow
end

-- Version 11 -> 12 (owner, November 24, 2026). A new profile follows the Bar
-- Style everywhere. An existing one keeps every bar's look except its border
-- and text, which take the Bar Style (a border set to None stays off); any
-- other group follows only where the bar already matches it, so nothing
-- else changes on screen.
function M.MigrateV12(db, fresh)
    db.barStyle = Copy(M.barStyleDefaults)
    if not fresh then
        -- Background and Bar Fill start from what the bars use now.
        if type(db.essential) == "table" then
            db.barStyle.backgroundColor = Copy(db.essential.backgroundColor)
            db.barStyle.backgroundOpacity = db.essential.backgroundOpacity
        end
        if type(db.buffBar) == "table" then
            for _, key in ipairs(COPIED.fill) do db.barStyle[key] = Copy(db.buffBar[key]) end
        end
    end
    for _, id in ipairs(BarIds(db)) do
        local style = db[id]
        if type(style) == "table" then
            local follow = M.NewFollow(db, id)
            if not fresh then
                for group in pairs(follow) do
                    if group == "border" then follow.border = style.border ~= "none"
                    elseif group ~= "text" then follow[group] = Matches(db, id, group) end
                end
            end
            style.follow = follow
            M.ApplyBarStyle(db, id)
        end
    end
    for _, style in ipairs(PlayerStyles(db)) do
        if type(style) == "table" then
            style.follow = { border = fresh or style.border ~= "none", text = true }
            M.ApplyPlayerStyle(db, style)
        end
    end
end

-- Validation (Migrations.lua, Initialize): the Bar Style's values, and each
-- bar's follow table (groups it can follow, true or false; none yet: all
-- Custom). Bad data stops startup; nothing is reset.
local function Set(list)
    local set = {}
    for _, item in ipairs(list) do set[type(item) == "table" and item.id or item] = true end
    return set
end
local GLOW = Set(M.glowStyles)
local CHOICES = { border = Set(M.choices.border), edgeStyle = Set(M.choices.edgeStyle), edgeMetal = Set(M.choices.edgeMetal),
    procGlow = GLOW, activeGlow = GLOW, readyGlow = GLOW, buffGlow = GLOW, readyMode = Set(M.choices.readyMode),
    barColorMode = Set(M.choices.barColorMode) }
local TEXT = { 6, 32, 1 }
local RANGES = { largeWidth = M.sizeRanges.icon.width, largeHeight = M.sizeRanges.icon.height,
    smallWidth = M.sizeRanges.icon.width, smallHeight = M.sizeRanges.icon.height, spacing = M.ranges.spacing,
    edgeSize = { 1, 2, 1 }, backgroundOpacity = M.ranges.backgroundOpacity, swipeOpacity = M.ranges.swipeOpacity,
    cooldownSize = TEXT, cooldownSizeSmall = TEXT, countSize = TEXT, countSizeSmall = TEXT, barTextSize = TEXT,
    readyDuration = M.ranges.readyDuration, glowLines = M.ranges.glowLines, glowThickness = M.ranges.glowThickness,
    barBackgroundOpacity = M.ranges.barBackgroundOpacity }
M.barStyleRanges = RANGES
local function Whole(value, range) return Number(value, range[1], range[2]) and value == math.floor(value) end
local function Color(value)
    for i = 1, 3 do if not Number(value[i], 0, 1) then return false end end
    return value[4] == nil or Number(value[4], 0, 1)
end
local function ValidFollow(follow, groups, id)
    assert(Public(follow) and type(follow) == "table", "Invalid cooldown manager Bar Style follow: " .. id)
    local allowed = Set(groups)
    for group, value in pairs(follow) do
        assert(allowed[group] and type(value) == "boolean", "Invalid cooldown manager Bar Style follow: " .. id .. "." .. tostring(group))
    end
end
function M.ValidateBarStyle(db)
    local bs = db.barStyle
    assert(Public(bs) and type(bs) == "table", "Invalid cooldown manager Bar Style")
    for key, default in pairs(M.barStyleDefaults) do
        if bs[key] == nil then bs[key] = Copy(default) end
        local value = bs[key]
        local ok = Public(value) and type(value) == type(default)
        if ok and type(default) == "table" then ok = Color(value) end
        if ok and RANGES[key] then ok = Whole(value, RANGES[key]) end
        if ok and CHOICES[key] then ok = CHOICES[key][value] == true end
        if ok and (key == "barTexture" or key == "barBackground") then ok = addon.Kit.ValidBarTexture(value, key == "barTexture") end
        assert(ok, "Invalid cooldown manager Bar Style setting: " .. key)
    end
    for _, id in ipairs(BarIds(db)) do
        local style = db[id]
        if type(style) == "table" then
            if style.follow == nil then style.follow = {} end
            ValidFollow(style.follow, Groups(db, id), id)
        end
    end
    for _, style in ipairs(PlayerStyles(db)) do
        if type(style) == "table" then
            if style.follow == nil then style.follow = {} end
            ValidFollow(style.follow, M.playerStyleGroups, "player")
        end
    end
end
