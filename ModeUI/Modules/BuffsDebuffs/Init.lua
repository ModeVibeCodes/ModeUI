local _, addon = ...
if not addon.Edition or addon.Edition.name ~= "Forever" then return end

-- Interface > Buffs & Debuffs (docs/BUFFS_DEBUFFS.md): your buffs and debuffs
-- as Mode bars. Buffs and Debuffs stand in for Blizzard's two frames by the
-- minimap; Player Buffs and Player Debuffs take over the Player frame's auras
-- from Unit Frames; up to eight bars of your own. Each bar is one of Blizzard's
-- custom aura containers on the player (the game reads the auras, so bars keep
-- working while auras are secret), shows the kinds of aura you pick, and is
-- placed in ModeUI's Edit Mode, anchored to anything.
-- Files: Init (this), Migrations, Driver, Bars, Blizzard, Placement, Samples,
-- Preview, Blacklist, Settings, SettingsBar.
local L, Style = addon.L, addon.Style
local Tone = Style.Tone
local function Copy(value) return addon.ProfileCodec.Copy(value) end

local M = { title = L["Buffs & Debuffs"], category = "frames", defaultEnabled = false, layout = "split", icon = "Auras",
    configDescription = L["Your buffs and debuffs as Mode bars you filter, size, style and place. Configure outside combat."],
    modeLayout = { decorateOnly = true } }
addon.BuffsDebuffs = M
-- The ID is also the saved-settings key (ModeUIDB profile modules.buffsDebuffs).
addon:RegisterModule("buffsDebuffs", M)

M.SETTINGS_VERSION = 1
-- The four bars every profile has, then custom bars ("custom1"...).
M.FIXED = { "buffs", "debuffs", "playerBuffs", "playerDebuffs" }
M.FIXED_LABELS = { buffs = "Buffs", debuffs = "Debuffs", playerBuffs = "Player Buffs", playerDebuffs = "Player Debuffs" }
M.FIXED_KIND = { buffs = "buffs", debuffs = "debuffs", playerBuffs = "buffs", playerDebuffs = "debuffs" }
M.MAX_CUSTOM = 8
M.MAX_BLACKLIST = 64
function M.ElementId(id) return "buffsDebuffs" .. id:gsub("^%l", string.upper) end
function M.FrameName(id) return "ModeUIBuffsDebuffs" .. id:gsub("^%l", string.upper) .. "Mover" end
-- The four bars are targets any element can anchor to ("ModeUI" tells them
-- from Blizzard's frames in the lists); custom bars join when made.
for _, id in ipairs(M.FIXED) do
    addon.Positioning:AddTarget(M.ElementId(id), L["ModeUI " .. M.FIXED_LABELS[id]], M.FrameName(id))
end

-- The kinds of aura a bar can show, in the order they fill it. A token is an
-- AuraUtil.AuraFilters component (`HELPFUL|<token>`); a later group leaves
-- out what an earlier chosen one shows (`|!<token>`), so an aura shows once.
-- Other kinds use the container's candidate filters: a dispel type
-- (includeDispelTypes), no type (excludeDispelTypes), boss auras (isBossAura)
-- or short ones (maxDuration). All is the whole kind on its own; Weapon
-- Enchants are the container's item enchantments.
M.categories = {
    buffs = {
        { id = "bigdef", label = "Big Defensives", token = "BIG_DEFENSIVE" },
        { id = "extdef", label = "External Defensives", token = "EXTERNAL_DEFENSIVE" },
        { id = "important", label = "Important", token = "IMPORTANT" },
        { id = "hots", label = "Heals Over Time", token = "RAID_IN_COMBAT" },
        { id = "mine", label = "Yours", token = "PLAYER" },
        { id = "cancelable", label = "Cancelable", token = "CANCELABLE" },
        { id = "short", label = "Under a Minute", maxDuration = 60 },
        { id = "all", label = "All Buffs", all = true },
        { id = "enchant", label = "Weapon Enchants", enchant = true },
    },
    debuffs = {
        { id = "cc", label = "Crowd Control", token = "CROWD_CONTROL" },
        { id = "dispellable", label = "Dispellable by You", token = "RAID" },
        { id = "boss", label = "Boss Debuffs", boss = true },
        { id = "Magic", label = "Magic", dispel = "Magic" },
        { id = "Curse", label = "Curse", dispel = "Curse" },
        { id = "Disease", label = "Disease", dispel = "Disease" },
        { id = "Poison", label = "Poison", dispel = "Poison" },
        { id = "Bleed", label = "Bleed", dispel = "Bleed" },
        { id = "other", label = "Other (No Type)", other = true },
        { id = "all", label = "All Debuffs", all = true },
    },
}
M.DISPEL_TYPES = { "Magic", "Curse", "Disease", "Poison", "Bleed" }
M.categoryById = { buffs = {}, debuffs = {} }
for kind, list in pairs(M.categories) do
    for _, category in ipairs(list) do M.categoryById[kind][category.id] = category end
end

-- One bar's settings (owner's picks, November 17, 2026, from the plan canvas:
-- a 1px band everywhere, debuffs colored by type, time text below).
local function Bar(kind, cats, o)
    local bar = { show = true, kind = kind, cats = {}, sort = "default", max = 8, perRow = 8, width = 32, spacing = 4,
        grow = "left", wrap = "down", timer = "below", swipe = true, count = true, tooltip = true, cancel = kind == "buffs",
        edgeStyle = "blizz", edgeMetal = "default", borderSize = 1, byType = kind == "debuffs", glow = "none",
        glowColor = "custom", glowCustomColor = Copy(Tone.auraGlow) }
    for _, id in ipairs(cats) do bar.cats[id] = true end
    for key, value in pairs(o or {}) do bar[key] = value end
    return bar
end
M.Bar = Bar
M.barDefaults = {
    buffs = Bar("buffs", { "all", "enchant" }, { max = 32, perRow = 10 }),
    debuffs = Bar("debuffs", { "all" }, { max = 16, perRow = 10 }),
    playerBuffs = Bar("buffs", { "mine", "important", "hots" }, { max = 12, perRow = 8, width = 24, spacing = 2, timer = "center" }),
    playerDebuffs = Bar("debuffs", { "cc", "dispellable", "boss", "Magic", "Curse", "Disease", "Poison", "Bleed", "other" },
        { max = 8, perRow = 6, width = 30, spacing = 3, timer = "center", edgeStyle = "blizzEmpty" }),
}
-- A new custom bar, and the one every profile starts with (Defensives).
M.customDefaults = Bar("buffs", { "all" }, { max = 8, perRow = 8, width = 36 })
M.firstCustom = { name = "Defensives", bar = Bar("buffs", { "bigdef", "extdef", "important" },
    { max = 4, perRow = 6, width = 40, timer = "center", edgeStyle = "blizzEmpty", glow = "soft" }) }

-- Places (owner's canvas layout): Buffs in Blizzard's Buff Frame spot (its
-- Edit Mode place), Debuffs under them, Player Buffs under the ModeUI Player
-- frame's right end, Player Debuffs above it, Defensives left of center.
local PLAYER = "unitFramesPlayer"
local function At(target, point, relativePoint, x, y)
    return { target = target, placement = "center", point = point, relativePoint = relativePoint, x = x, y = y }
end
M.defaultPositions = {
    buffs = At("frame:BuffFrame", "TOPRIGHT", "TOPRIGHT", 0, 0),
    debuffs = At(M.ElementId("buffs"), "TOPRIGHT", "TOPRIGHT", 4, -147),
    playerBuffs = At(PLAYER, "TOPRIGHT", "BOTTOMRIGHT", -6, -2),
    playerDebuffs = At(PLAYER, "TOPRIGHT", "TOPRIGHT", 2, 131),
}
M.firstCustomPosition = At("screen", "CENTER", "CENTER", -151, 27)
function M.CustomPosition(index) return At("screen", "CENTER", "CENTER", 0, 60 - 50 * ((index - 1) % 6)) end

M.defaults = { settingsVersion = M.SETTINGS_VERSION, bars = {}, customBars = {}, nextCustom = 1,
    -- Owner's picks: Well Fed and Sated hidden.
    blacklist = { 104280, 57724 },
    font = "game", fontMedia = Style.FONT_DEFAULT, outline = false, shadow = true, liftedShadow = false, slug = false,
    textColor = Copy(Tone.textBright), timerColor = Copy(Tone.cooldown) }
for id, bar in pairs(M.barDefaults) do M.defaults.bars[id] = Copy(bar) end

M.ranges = { max = { 1, 32, 1 }, perRow = { 1, 16, 1 }, width = { 16, 56, 1 }, spacing = { 0, 12, 1 }, borderSize = { 1, 2, 1 } }
M.choices = {
    kind = { { id = "buffs", label = "Buffs" }, { id = "debuffs", label = "Debuffs" } },
    sort = { { id = "default", label = "Game Order" }, { id = "time", label = "Time Left" }, { id = "name", label = "Name" } },
    grow = { { id = "right", label = "Right" }, { id = "left", label = "Left" }, { id = "up", label = "Up" }, { id = "down", label = "Down" } },
    wrap = { { id = "down", label = "Down" }, { id = "up", label = "Up" }, { id = "right", label = "Right" }, { id = "left", label = "Left" } },
    timer = { { id = "below", label = "Below" }, { id = "center", label = "On Icon" }, { id = "none", label = "None" } },
    glow = { { id = "none", label = "None" }, { id = "soft", label = "Soft" }, { id = "gcd", label = "Flash" } },
    glowColor = { { id = "type", label = "By Debuff Type" }, { id = "custom", label = "Custom" } },
}
-- Rows grow across the way the icons don't.
M.HORIZONTAL = { left = true, right = true }
function M.WrapChoices(grow)
    local list = {}
    for _, choice in ipairs(M.choices.wrap) do
        if (M.HORIZONTAL[grow] and not M.HORIZONTAL[choice.id]) or (not M.HORIZONTAL[grow] and M.HORIZONTAL[choice.id]) then
            list[#list + 1] = choice
        end
    end
    return list
end
