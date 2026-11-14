local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- The aura manager's declarations: groups, what each shows, and defaults.
-- Each group picks which auras it shows (a game filter string, plus a dispel
-- type or a spell list kept by the game through candidate filters, so no
-- secret aura field is compared) and where, with its own icon look. Groups on
-- the same anchor and place continue in one row, in M.auraGroups' order.
local Kit = addon.Kit
local RGB = Kit.RGB
local function Copy(value) return addon.ProfileCodec.Copy(value) end

-- Buffs, then debuffs: Dispellable by You first, then Blizzard's own
-- categories (each dispel type, crowd control, the rest).
M.buffGroups = { "heals", "buffs", "defensives", "tracked1", "tracked2", "tracked3" }
M.debuffGroups = { "dispellable", "magic", "curse", "disease", "poison", "bleed", "crowdControl", "otherDebuffs" }
M.auraGroups = {}
for _, group in ipairs(M.buffGroups) do M.auraGroups[#M.auraGroups + 1] = group end
for _, group in ipairs(M.debuffGroups) do M.auraGroups[#M.auraGroups + 1] = group end
M.auraGroupLabels = { heals = "Healing Buffs", buffs = "Group Buffs", defensives = "Defensives",
    tracked1 = "Tracked Buffs 1", tracked2 = "Tracked Buffs 2", tracked3 = "Tracked Buffs 3",
    dispellable = "Dispellable by You", magic = "Magic", curse = "Curse", disease = "Disease", poison = "Poison",
    bleed = "Bleed", crowdControl = "Crowd Control", otherDebuffs = "Other Debuffs" }
M.HELPFUL = {}
for _, group in ipairs(M.buffGroups) do M.HELPFUL[group] = true end
-- Tracked Buffs: the buffs you add with + (owner, November 13, 2026: like the
-- Cooldown Manager's bars), kept by the game through includeSpellIDs, which
-- it allows for helpful auras on group members. Other buff groups leave them
-- out (excludeSpellIDs), so a tracked buff shows once.
M.TRACKED = { tracked1 = true, tracked2 = true, tracked3 = true }
M.MAX_TRACKED_SPELLS = 24
-- The dispel type each debuff group keeps (includeDispelTypes); Other Debuffs
-- keeps the rest (excludeDispelTypes).
M.groupDispelType = { magic = "Magic", curse = "Curse", disease = "Disease", poison = "Poison", bleed = "Bleed" }
local function TypeFilters()
    return { { id = "notMine", label = "Ones You Can't Dispel", filters = { "HARMFUL|!RAID" } },
        { id = "all", label = "All", filters = { "HARMFUL" } } }
end
local function Tracked()
    return { { id = "all", label = "From Anyone", filters = { "HELPFUL" } }, { id = "mine", label = "Yours", filters = { "HELPFUL|PLAYER" } } }
end
-- Which auras: each choice is one or more filter strings, shown one after
-- another (AuraUtil.AuraFilters; RAID_IN_COMBAT is what Blizzard's raid
-- frames show in combat: heals over time and short buffs).
M.auraFilters = {
    heals = {
        { id = "all", label = "All Healing Buffs", filters = { "HELPFUL|RAID_IN_COMBAT" } },
        { id = "mine", label = "Your Healing Buffs", filters = { "HELPFUL|PLAYER|RAID_IN_COMBAT" } },
    },
    buffs = {
        { id = "group", label = "Group Buffs", filters = { "HELPFUL|!RAID_IN_COMBAT" } },
        { id = "cast", label = "Ones You Can Cast", filters = { "HELPFUL|RAID|!RAID_IN_COMBAT" } },
        { id = "mine", label = "Yours", filters = { "HELPFUL|PLAYER|!RAID_IN_COMBAT" } },
        { id = "all", label = "All", filters = { "HELPFUL" } },
    },
    defensives = {
        { id = "both", label = "Big and External", filters = { "HELPFUL|EXTERNAL_DEFENSIVE", "HELPFUL|BIG_DEFENSIVE" } },
        { id = "external", label = "External Defensives", filters = { "HELPFUL|EXTERNAL_DEFENSIVE" } },
        { id = "big", label = "Big Defensives", filters = { "HELPFUL|BIG_DEFENSIVE" } },
        { id = "important", label = "Important", filters = { "HELPFUL|IMPORTANT" } },
    },
    tracked1 = Tracked(), tracked2 = Tracked(), tracked3 = Tracked(),
    dispellable = {
        { id = "mine", label = "Dispellable by You", filters = { "HARMFUL|RAID" } },
        { id = "group", label = "Dispellable by Your Group", filters = { "HARMFUL|RAID_PLAYER_DISPELLABLE" } },
    },
    magic = TypeFilters(), curse = TypeFilters(), disease = TypeFilters(), poison = TypeFilters(), bleed = TypeFilters(),
    crowdControl = { { id = "all", label = "Crowd Control", filters = { "HARMFUL|CROWD_CONTROL" } } },
    otherDebuffs = {
        { id = "raid", label = "Raid Frame Debuffs", filters = { "HARMFUL|RAID_IN_COMBAT" } },
        { id = "all", label = "All Without a Type", filters = { "HARMFUL" } },
        { id = "mine", label = "Yours", filters = { "HARMFUL|PLAYER" } },
    },
    -- The debuffs the dispel overlay reacts to (Highlights and Overlay tab).
    dispel = {
        { id = "mine", label = "Ones You Can Dispel", filters = { "HARMFUL|RAID" } },
        { id = "group", label = "Ones Your Group Can Dispel", filters = { "HARMFUL|RAID_PLAYER_DISPELLABLE" } },
        { id = "any", label = "Any With a Type", filters = { "HARMFUL" } },
    },
}
-- One group: shown or not, which auras, where (an anchor on or past the bars,
-- the way it grows, an offset, how many and per row) and how its icons look:
-- width and height, border (by type, Mode, custom or none) and its size, and a
-- glow (off by default) colored by type or a color of its own. Tracked groups
-- also keep their spell IDs (`spells`).
local function Group(show, filter, anchor, place, grow, width, height, max)
    return { show = show, filter = filter, anchor = anchor, place = place, grow = grow, x = 0, y = 0, width = width,
        height = height, max = max, perRow = max, spacing = 1, border = "type", borderSize = 1,
        borderColor = Copy(Kit.BORDER_COLOR), timer = true, timerText = false, count = true, tooltip = true,
        glow = "none", glowColor = "type", glowCustomColor = RGB(255, 209, 92) }
end
M.auraDefaults = {
    heals = Group(true, "all", "BOTTOMRIGHT", "inside", "left", 16, 12, 3),
    buffs = Group(false, "group", "TOPRIGHT", "inside", "left", 14, 10, 3),
    defensives = Group(true, "both", "CENTER", "inside", "right", 20, 16, 1),
    -- Debuffs: one row at the inside bottom left, Dispellable by You first.
    dispellable = Group(true, "mine", "BOTTOMLEFT", "inside", "right", 18, 14, 3),
    crowdControl = Group(false, "all", "LEFT", "outside", "left", 24, 20, 1),
    otherDebuffs = Group(true, "raid", "BOTTOMLEFT", "inside", "right", 18, 14, 2),
}
for group in pairs(M.groupDispelType) do M.auraDefaults[group] = Group(true, "notMine", "BOTTOMLEFT", "inside", "right", 18, 14, 2) end
for group in pairs(M.TRACKED) do
    M.auraDefaults[group] = Group(true, "all", "TOPRIGHT", "inside", "left", 14, 10, 4)
    M.auraDefaults[group].spells = {}
end
M.auraRanges = { x = { -80, 80, 1 }, y = { -80, 80, 1 }, width = { 8, 48, 1 }, height = { 8, 48, 1 }, max = { 1, 10, 1 },
    perRow = { 1, 10, 1 }, spacing = { 0, 8, 1 }, borderSize = { 1, 3, 1 } }
M.growChoices = { { id = "right", label = "Right" }, { id = "left", label = "Left" }, { id = "up", label = "Up" },
    { id = "down", label = "Down" } }
M.defaults.auras = Copy(M.auraDefaults)
