local _, addon = ...
local M = addon.Windows
if not M then return end

-- The Character window's stats display: a small block of text over the
-- character model, one line per stat picked on the Character tab (Main Stat,
-- Stamina, Armor, Crit, Hit and Haste by default), label at the left in the
-- stat's color (Stat Colors) and value at the right in white. Main Stat is
-- the specialization's primary stat (C_SpecializationInfo /
-- GetSpecializationInfo, as Forever's own paper doll reads it), or the
-- highest of Strength, Agility and Intellect, in its attribute's color. It
-- sits at Stats Anchor of the model area between the slot columns (never
-- over a slot: offsets are kept inside it, and the block is never wider than
-- it), nudged by Offset X and Y, in the Mode face at Stats Text Size, on an
-- optional dark field. Every stat comes from the functions Forever's paper
-- doll calls; they can be secret while unit stats are restricted, and a
-- secret or missing value shows a dash.
local L, Kit, Skin = addon.L, addon.Kit, addon.Skin
local Number = addon.IsNumber
local C = Skin.mode
local WIDTH, PADDING, GAP, VALUE_WIDTH = 150, 6, 2, 64
local DASH = "-"
-- UnitStat indexes (LE_UNIT_STAT_*).
local STAT_INDEX = { strength = 1, agility = 2, stamina = 3, intellect = 4, spirit = 5 }
local STAT_NAMES = { "Strength", "Agility", "Stamina", "Intellect", "Spirit" }

-- fn(...) under pcall, all its returns kept (nils between them too; Lua 5.1).
local function Pack(...) return { n = select("#", ...), ... } end
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local results = Pack(pcall(fn, ...))
    if not results[1] then return nil end
    return unpack(results, 2, results.n)
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

-- The model area: between the left slot column's right edge and the right
-- column's left edge, from the top of the head slot to the bottom of the
-- wrist slot (above the weapons), less Area Gap on every side. Every Stats
-- Anchor is a point of this area, so the block never reaches a slot.
local AREA_GAP = 6
function M:StatsArea()
    if self.statsArea then return self.statsArea end
    local head, wrist, hands = CharacterHeadSlot, CharacterWristSlot, CharacterHandsSlot
    local parent = PaperDollFrame or CharacterFrame
    if not (parent and head and wrist and hands) then return CharacterModelScene or parent end
    local area = CreateFrame("Frame", nil, parent)
    area:EnableMouse(false)
    area:SetPoint("TOPLEFT", head, "TOPRIGHT", AREA_GAP, 0)
    area:SetPoint("TOPRIGHT", hands, "TOPLEFT", -AREA_GAP, 0)
    area:SetPoint("BOTTOMLEFT", wrist, "BOTTOMRIGHT", AREA_GAP, 0)
    self.statsArea = area
    return area
end

function M:BuildStats()
    if self.statsFrame then return self.statsFrame end
    local parent = PaperDollFrame or CharacterFrame
    if not parent then return nil end
    local frame = CreateFrame("Frame", "ModeUICharacterStats", parent)
    frame:EnableMouse(false)
    frame.parts = Skin.Box(frame, "card")
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

-- A stat's label color; Main Stat takes its attribute's.
function M:StatColor(id, main)
    if id == "mainStat" then id = ({ "strength", "agility", "stamina", "intellect", "spirit" })[main] or "strength" end
    return self.db.charStatColors[id] or self.STAT_COLORS[id] or C.label
end

-- The offset that keeps a `size`-long block inside an `room`-long area for an
-- anchor on its low edge (LEFT/BOTTOM: 0..spare), high edge (RIGHT/TOP:
-- -spare..0) or middle (-spare/2..spare/2).
local function Clamp(offset, edge, room, size)
    if not (Number(room) and room > 0) then return offset end
    local spare = math.max(0, room - size)
    local low, high = 0, spare
    if edge == "high" then low, high = -spare, 0 elseif edge == "middle" then low, high = -spare / 2, spare / 2 end
    return math.max(low, math.min(high, offset))
end

-- Fills and places the block from the settings; hidden with Stats off.
function M:PaintStats()
    local db = self.db
    local frame = self.statsFrame or (self.active and db.charStats and self:BuildStats())
    if not frame then return end
    local area = self:StatsArea()
    if not (self.active and db.charStats and area) then frame:Hide(); return end
    local px = Kit.PixelSize(frame)
    local size, path = db.charStatsSize, Kit.FontPath(db, self.id)
    local row = Skin.Snap(size + 4, px)
    local main = self:MainStatIndex()
    -- As wide as the area allows, up to WIDTH.
    local room = area.GetWidth and area:GetWidth()
    local width = Skin.Snap(WIDTH, px)
    if Number(room) and room > 0 then width = math.min(width, Skin.Snap(room, px)) end
    local count = 0
    for _, stat in ipairs(self.STATS) do
        if db.charStatList[stat.id] then
            local label, value = self:StatText(stat.id)
            count = count + 1
            local line = Line(frame, count)
            for _, text in ipairs({ line.label, line.value }) do
                Skin.Font(text, path, size, db.outline, true, px)
                text:ClearAllPoints()
                text:SetWordWrap(false)
            end
            local y = -(PADDING + (count - 1) * (row + GAP))
            line.label:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, y)
            -- Values get a fixed column at the right; labels the rest.
            line.label:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(PADDING + VALUE_WIDTH), y)
            line.value:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING, y)
            line.value:SetPoint("TOPLEFT", frame, "TOPRIGHT", -(PADDING + VALUE_WIDTH), y)
            line.label:SetHeight(row); line.value:SetHeight(row)
            line.label:SetText(label); line.value:SetText(value)
            local color = self:StatColor(stat.id, main)
            line.label:SetTextColor(color[1], color[2], color[3], 1)
            line.value:SetTextColor(C.heading[1], C.heading[2], C.heading[3], 1)
            line.label:Show(); line.value:Show()
        end
    end
    for index = count + 1, #frame.lines do frame.lines[index].label:Hide(); frame.lines[index].value:Hide() end
    local height = Skin.Snap(2 * PADDING + count * row + math.max(0, count - 1) * GAP, px)
    frame:SetSize(width, height)
    -- Offsets are kept inside the area, whatever the anchor.
    local anchor = db.charStatsAnchor
    local horizontal = anchor:find("LEFT") and "low" or (anchor:find("RIGHT") and "high" or "middle")
    local vertical = anchor:find("BOTTOM") and "low" or (anchor:find("TOP") and "high" or "middle")
    local x = Clamp(db.charStatsX, horizontal, room, width)
    local y = Clamp(db.charStatsY, vertical, area.GetHeight and area:GetHeight(), height)
    frame:ClearAllPoints()
    frame:SetPoint(anchor, area, anchor, x, y)
    local host = CharacterModelScene or area
    local level = host:GetFrameLevel()
    if Number(level) then frame:SetFrameLevel(level + 60) end
    Skin.PaintBox(frame.parts, frame, "FG", C.field, db.charStatsBackground and 0.7 or 0, db.charStatsBackground)
    frame:SetShown(count > 0)
end
