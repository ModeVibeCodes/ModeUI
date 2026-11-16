local _, addon = ...
local M = addon.Tooltip
if not M then return end

-- What a tooltip shows decides its colors:
--   Border      the edge's rim: an item's quality color (Quality Border), a
--               player's class color (Class Border), else the edge's steel.
--   Name        line 1: a player's in their class color, an NPC's by
--               reaction (hostile, neutral, friendly; gray once tapped by
--               someone else), or Custom, or Blizzard's.
--   Class       a player's class line ("Rogue") in the class color.
--   Level       the level number on the level line ("Level 33 Orc") in its
--               difficulty color (red well above you, orange, yellow, green,
--               gray below), or the whole line in Custom.
--   Quest       quest titles and objective lines in Quest Color.
-- The game keeps some units' identity from addons: their token, name and
-- class come back secret, and then nothing is colored for them. Line text is
-- only read when it's public, and only compared, never measured.
local Kit = addon.Kit
local Public, Number = addon.IsPublic, addon.IsNumber

-- fn(...) under pcall, all its returns kept (nils between them too; Lua 5.1).
local function Pack(...) return { n = select("#", ...), ... } end
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local results = Pack(pcall(fn, ...))
    if not results[1] then return nil end
    return unpack(results, 2, results.n)
end
local function Text(line)
    local text = line and line.GetText and line:GetText()
    if text ~= nil and Public(text) and type(text) == "string" then return text end
    return nil
end
local function Paint(line, color) if line and color then line:SetTextColor(color[1], color[2], color[3], 1) end end
local function Hex(color)
    return string.format("%02x%02x%02x", math.floor(color[1] * 255 + 0.5), math.floor(color[2] * 255 + 0.5), math.floor(color[3] * 255 + 0.5))
end

function M:ClassColor(class)
    if not (Public(class) and type(class) == "string") then return nil end
    local color = (C_ClassColor and Call(C_ClassColor.GetClassColor, class)) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
    if color and Number(color.r) then return { color.r, color.g, color.b } end
    return nil
end

-- The unit a tooltip shows, when the game lets addons see it.
function M:UnitOf(tooltip)
    if not tooltip.GetUnit then return nil end
    local _, unit = Call(tooltip.GetUnit, tooltip)
    if unit ~= nil and Public(unit) and type(unit) == "string" then return unit end
    return nil
end

-- An NPC's reaction color: gray once tapped by someone else.
function M:ReactionColor(unit)
    if Call(UnitIsTapDenied, unit) == true then return addon.Style.Tone.reaction.tapped end
    local reaction = Call(UnitReaction, unit, "player")
    if not Number(reaction) then return nil end
    if reaction <= 3 then return self.db.hostileColor end
    if reaction == 4 then return self.db.neutralColor end
    return self.db.friendlyColor
end

-- A level's difficulty color, from Blizzard's own when it has one.
function M:LevelColor(unit)
    local level = Call(UnitLevel, unit)
    if not Number(level) then return nil end
    if level < 0 then return { 1, 0.1, 0.1 } end
    local color = Call(GetCreatureDifficultyColor, level) or Call(GetQuestDifficultyColor, level)
    if type(color) == "table" and Number(color.r) then return { color.r, color.g, color.b } end
    local mine = Call(UnitLevel, "player")
    if not Number(mine) then return nil end
    local diff = level - mine
    if diff >= 5 then return { 1, 0.1, 0.1 } elseif diff >= 3 then return { 1, 0.5, 0.25 }
    elseif diff >= -2 then return { 1, 0.82, 0 } elseif diff >= -8 then return { 0.25, 0.75, 0.25 } end
    return { 0.5, 0.5, 0.5 }
end

-- The rim color for what the tooltip shows, or nil for the edge's steel.
function M:ContentColor(tooltip)
    local db = self.db
    if db.qualityBorder and tooltip.GetItem then
        local _, link, id = Call(tooltip.GetItem, tooltip)
        local quality
        if Number(id) then quality = Call(C_Item and C_Item.GetItemQualityByID, id) end
        if not Number(quality) and Public(link) and type(link) == "string" then
            quality = select(3, Call(C_Item and C_Item.GetItemInfo or GetItemInfo, link))
        end
        if Number(quality, 1, 20) then
            local r, g, b = Call(C_Item and C_Item.GetItemQualityColor, quality)
            if Number(r) and Number(g) and Number(b) then return { r, g, b } end
        end
    end
    local unit = db.classBorder and self:UnitOf(tooltip)
    if unit and Call(UnitIsPlayer, unit) == true then
        local _, class = Call(UnitClass, unit)
        return self:ClassColor(class)
    end
    return nil
end

local QUEST_TYPES = { "QuestObjective", "QuestTitle", "QuestPlayer" }

-- Colors the lines of a tooltip from what it shows; `data` (tooltip data,
-- when Blizzard passes it) marks the quest lines.
function M:ColorLines(tooltip, data)
    local db = self.db
    local lines = self:Lines(tooltip)
    local unit = self:UnitOf(tooltip)
    if unit and lines[1] then
        local player = Call(UnitIsPlayer, unit) == true
        local className, class = Call(UnitClass, unit)
        local classColor = player and self:ClassColor(class) or nil
        local name
        if player then
            name = db.playerNameColor == "class" and classColor or (db.playerNameColor == "custom" and db.playerNameCustom)
        else
            name = db.npcNameColor == "reaction" and self:ReactionColor(unit) or (db.npcNameColor == "custom" and db.npcNameCustom)
        end
        Paint(lines[1].left, name or nil)
        local levelWord = (type(LEVEL) == "string" and LEVEL or "Level") .. " "
        local publicClass = Public(className) and type(className) == "string" and className or nil
        for index = 2, #lines do
            local line = lines[index].left
            local text = Text(line)
            if text and player and publicClass and text == publicClass and db.classTextColor ~= "blizzard" then
                Paint(line, db.classTextColor == "class" and classColor or db.classTextCustom)
            elseif text and text:sub(1, #levelWord) == levelWord and db.levelColor ~= "blizzard" then
                if db.levelColor == "custom" then Paint(line, db.levelCustom)
                else
                    local color = self:LevelColor(unit)
                    -- Only the number: "Level |cff..33|r Orc (Player)".
                    if color and not text:find("|c", 1, true) then
                        local colored = levelWord .. "|cff" .. Hex(color) .. "%1|r"
                        line:SetText((text:gsub("^" .. levelWord:gsub("(%W)", "%%%1") .. "(%S+)", colored, 1)))
                    end
                end
            end
        end
    end
    if db.questText and type(data) == "table" and type(data.lines) == "table" then
        local types = Enum and Enum.TooltipDataLineType
        local quest = {}
        for _, key in ipairs(QUEST_TYPES) do if types and types[key] then quest[types[key]] = true end end
        for index, info in ipairs(data.lines) do
            local wanted = info.leftText
            if quest[info.type] and Public(wanted) and type(wanted) == "string" and wanted ~= "" then
                -- The line at the same place, or the one showing that text.
                local pair = lines[index]
                local found = pair and Text(pair.left) == wanted and pair.left
                if not found then
                    for _, other in ipairs(lines) do if Text(other.left) == wanted then found = other.left; break end end
                end
                Paint(found, db.questColor)
            end
        end
    end
end
