local _, addon = ...
local M = addon.Windows
if not M then return end

-- The Character window's stats display: a small block of text over the
-- character model, one line per stat picked on the Character tab (Main Stat,
-- Stamina, Armor, Crit, Hit and Haste by default), label at the left and
-- value at the right. Main Stat is the specialization's primary stat
-- (C_SpecializationInfo / GetSpecializationInfo, as Forever's own paper
-- doll reads it), or the highest of Strength, Agility and Intellect, and its
-- label is cyan. It sits at Stats Anchor of the model, nudged by Offset X
-- and Y, in the Mode face at Stats Text Size, on an optional dark field.
-- Every stat comes from the functions Forever's paper doll calls; they can
-- be secret while unit stats are restricted, and a secret or missing value
-- shows a dash.
local L, Kit, Skin = addon.L, addon.Kit, addon.Skin
local Number = addon.IsNumber
local C = Skin.colors
local WIDTH, PADDING, GAP = 150, 6, 2
local DASH = "-"
-- UnitStat indexes (LE_UNIT_STAT_*).
local STAT_INDEX = { strength = 1, agility = 2, stamina = 3, intellect = 4, spirit = 5 }
local STAT_NAMES = { "Strength", "Agility", "Stamina", "Intellect", "Spirit" }

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local results = { pcall(fn, ...) }
    if not results[1] then return nil end
    return select(2, unpack(results))
end
local function Whole(value) return Number(value) and string.format("%d", math.floor(value + 0.5)) or DASH end
local function Percent(value) return Number(value) and string.format("%.2f%%", value) or DASH end
local function Stat(index) local _, effective = Call(UnitStat, "player", index); return effective end
local function Rating(id)
    local rating = type(id) == "number" and Call(GetCombatRatingBonus, id) or nil
    return Number(rating) and rating or 0
end
-- The best of the spell schools (2 Holy .. 7 Arcane), as the paper doll shows.
local function BestSchool(fn)
    local best
    for school = 2, 7 do
        local value = Call(fn, school)
        if Number(value) and (best == nil or value > best) then best = value end
    end
    return best
end

-- The primary stat's UnitStat index: the specialization's, else the highest.
function M:MainStatIndex()
    local spec = C_SpecializationInfo and Call(C_SpecializationInfo.GetSpecialization)
    if Number(spec, 1, 10) then
        local info = GetSpecializationInfo or (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo)
        local primary = select(6, Call(info, spec, false, false, nil, Call(UnitSex, "player")))
        if Number(primary, 1, 5) then return primary end
    end
    local best, index = nil, 1
    for _, i in ipairs({ 1, 2, 4 }) do
        local value = Stat(i)
        if Number(value) and (best == nil or value > best) then best, index = value, i end
    end
    return index
end

-- label, value text for one stat.
local READ = {
    mainStat = function(self) local i = self:MainStatIndex(); return L[STAT_NAMES[i]], Whole(Stat(i)) end,
    armor = function() local _, effective = Call(UnitArmor, "player"); return nil, Whole(effective) end,
    attackPower = function()
        local base, plus, minus = Call(UnitAttackPower, "player")
        return nil, Number(base) and Whole(base + (Number(plus) and plus or 0) + (Number(minus) and minus or 0)) or DASH
    end,
    rangedAttackPower = function()
        local base, plus, minus = Call(UnitRangedAttackPower, "player")
        return nil, Number(base) and Whole(base + (Number(plus) and plus or 0) + (Number(minus) and minus or 0)) or DASH
    end,
    spellPower = function() return nil, Whole(BestSchool(GetSpellBonusDamage)) end,
    healing = function() return nil, Whole(Call(GetSpellBonusHealing)) end,
    crit = function() return nil, Percent(Call(GetCritChance)) end,
    spellCrit = function() return nil, Percent(BestSchool(GetSpellCritChance)) end,
    rangedCrit = function() return nil, Percent(Call(GetRangedCritChance)) end,
    hit = function()
        local modifier = Call(GetHitModifier)
        if not Number(modifier) then return nil, DASH end
        return nil, Percent(modifier + Rating(CR_HIT_MELEE))
    end,
    spellHit = function()
        local modifier = Call(GetSpellHitModifier)
        if not Number(modifier) then return nil, DASH end
        return nil, Percent(modifier + Rating(CR_HIT_SPELL))
    end,
    haste = function() return nil, Percent(Call(GetMeleeHaste)) end,
    spellHaste = function() return nil, Percent(Call(UnitSpellHaste, "player")) end,
    expertise = function() return nil, Whole(Call(GetExpertise)) end,
    dodge = function() return nil, Percent(Call(GetDodgeChance)) end,
    parry = function() return nil, Percent(Call(GetParryChance)) end,
    block = function() return nil, Percent(Call(GetBlockChance)) end,
    -- Mana per five seconds while casting.
    manaRegen = function() local _, casting = Call(GetManaRegen); return nil, Number(casting) and Whole(casting * 5) or DASH end,
}
for id, index in pairs(STAT_INDEX) do READ[id] = function() return nil, Whole(Stat(index)) end end

function M:StatText(id)
    local read, stat = READ[id], self.statsById[id]
    if not read or not stat then return nil end
    local label, value = read(self)
    return label or L[stat.label], value or DASH
end

-- Where the block hangs: the character model, or the paper doll.
local function Host() return CharacterModelScene or (PaperDollFrame and PaperDollFrame.ModelScene) or PaperDollFrame end

function M:BuildStats()
    if self.statsFrame then return self.statsFrame end
    local parent = PaperDollFrame or CharacterFrame
    if not parent then return nil end
    local frame = CreateFrame("Frame", "ModeUICharacterStats", parent)
    frame:EnableMouse(false)
    frame.parts = Skin.Panel(frame, "BACKGROUND", -8)
    frame.lines = {}
    self.statsFrame = frame
    return frame
end

local function Line(frame, index)
    local line = frame.lines[index]
    if line then return line end
    line = { label = frame:CreateFontString(nil, "OVERLAY"), value = frame:CreateFontString(nil, "OVERLAY") }
    line.label:SetJustifyH("LEFT"); line.value:SetJustifyH("RIGHT")
    frame.lines[index] = line
    return line
end

-- Fills and places the block from the settings; hidden with Stats off.
function M:PaintStats()
    local db = self.db
    local frame = self.statsFrame or (self.active and db.charStats and self:BuildStats())
    if not frame then return end
    local host = Host()
    if not (self.active and db.charStats and host) then frame:Hide(); return end
    local px = Kit.PixelSize(frame)
    local size, path = db.charStatsSize, Kit.FontPath(db, self.id)
    local row = Skin.Snap(size + 4, px)
    local main = self:MainStatIndex()
    local count = 0
    for _, stat in ipairs(self.STATS) do
        if db.charStatList[stat.id] then
            local label, value = self:StatText(stat.id)
            count = count + 1
            local line = Line(frame, count)
            for _, text in ipairs({ line.label, line.value }) do
                Skin.Font(text, path, size, db.outline, true, px)
                text:ClearAllPoints()
            end
            local y = -(PADDING + (count - 1) * (row + GAP))
            line.label:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, y)
            line.value:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING, y)
            line.label:SetHeight(row); line.value:SetHeight(row)
            line.label:SetText(label); line.value:SetText(value)
            -- The main stat is cyan, on its own line or on its attribute's.
            local isMain = stat.id == "mainStat" or (STAT_INDEX[stat.id] == main and not db.charStatList.mainStat)
            local color = isMain and C.accent or C.label
            line.label:SetTextColor(color[1], color[2], color[3], 1)
            line.value:SetTextColor(C.heading[1], C.heading[2], C.heading[3], 1)
            line.label:Show(); line.value:Show()
        end
    end
    for index = count + 1, #frame.lines do frame.lines[index].label:Hide(); frame.lines[index].value:Hide() end
    frame:SetSize(Skin.Snap(WIDTH, px), Skin.Snap(2 * PADDING + count * row + math.max(0, count - 1) * GAP, px))
    frame:ClearAllPoints()
    local anchor = db.charStatsAnchor
    frame:SetPoint(anchor, host, anchor, db.charStatsX, db.charStatsY)
    local level = host:GetFrameLevel()
    if Number(level) then frame:SetFrameLevel(level + 60) end
    Skin.PaintPanel(frame.parts, frame, C.field, db.charStatsBackground and 0.7 or 0, C.fieldRim, db.charStatsBackground and px or 0)
    frame:SetShown(count > 0)
end
