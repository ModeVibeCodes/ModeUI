local _, addon = ...
local M = addon.Windows
if not M then return end

-- The Character window's equipment slots (Forever's Camelot paper doll):
--   Rarity borders  a crisp square border round each slot, Border Size
--                   thick, in the item's quality color (Uncommon and up;
--                   lower qualities and empty slots take the window's rim
--                   color). Blizzard's own quality ring is faded.
--   Enchant text    a short line beside the slot, inside the model area:
--                   right of the left column, left of the right column,
--                   above the weapons. A permanent enchant comes first; a
--                   weapon without one shows its temporary enhancement (a
--                   poison, oil or stone). Under the name, the stat it gives.
-- Enchants have no name API: the text is the item tooltip's line (the
-- permanent enchant line type, or the timed line of a temporary one), read
-- through C_TooltipInfo. Stats come from the line itself ("+15 Agility",
-- "(+8 Damage)"), or for a few well-known proc enchants and poisons, from a
-- short English table. Nothing here is protected: slots are plain buttons.
-- The stats display is CharacterStats.lua.
local L, Kit, Skin, Events = addon.L, addon.Kit, addon.Skin, addon.Events
local Public, Number = addon.IsPublic, addon.IsNumber
local C = Skin.colors
local TEXT_WIDTH, TEXT_GAP = 110, 6

-- Slot name (CharacterXSlot), its column, and for weapons the Enum.WeaponSlot.
M.SLOTS = {
    { "Head", "left" }, { "Neck", "left" }, { "Shoulder", "left" }, { "Back", "left" }, { "Chest", "left" },
    { "Shirt", "left" }, { "Tabard", "left" }, { "Wrist", "left" },
    { "Hands", "right" }, { "Waist", "right" }, { "Legs", "right" }, { "Feet", "right" },
    { "Finger0", "right" }, { "Finger1", "right" }, { "Trinket0", "right" }, { "Trinket1", "right" },
    { "MainHand", "bottom", 0 }, { "SecondaryHand", "bottom", 1 }, { "Ranged", "bottom", 2 },
}
-- The stat a few well-known proc enchants and poisons give (English names).
M.KNOWN_ENCHANTS = {
    ["Crusader"] = "+100 Str proc, heals", ["Fiery Weapon"] = "Fire damage proc", ["Lifestealing"] = "Life drain proc",
    ["Icy Chill"] = "Frost slow proc", ["Unholy Weapon"] = "Shadow damage proc", ["Demonslaying"] = "Demon stun proc",
    ["Instant Poison"] = "Nature damage proc", ["Deadly Poison"] = "Nature damage over time",
    ["Crippling Poison"] = "Slows movement", ["Mind-numbing Poison"] = "Slows casting", ["Wound Poison"] = "Reduces healing",
}
local ABBREVIATIONS = {
    { "Spell Damage and Healing", "SP" }, { "Attack Power", "AP" }, { "Spell Power", "SP" }, { "Healing Spells", "Healing" },
    { "Critical Strike", "Crit" }, { "Strength", "Str" }, { "Agility", "Agi" }, { "Intellect", "Int" },
    { "Stamina", "Sta" }, { "Spirit", "Spi" }, { "Defense", "Def" }, { "Damage", "Dmg" },
    { "[Mm]ana every 5 [Ss]ec%.?", "MP5" }, { "[Mm]ana per 5 [Ss]ec%.?", "MP5" },
}

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local results = { pcall(fn, ...) }
    if not results[1] then return nil end
    return select(2, unpack(results))
end
local function Clean(text) return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", ""):gsub("%s+$", "")) end
-- A Lua pattern from a format string like "Enchanted: %s".
local function Pattern(format)
    if type(format) ~= "string" then return nil end
    local escaped = format:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    return "^" .. escaped:gsub("%%s", "(.+)"):gsub("%%d", "%%d+") .. "$"
end
function M.ShortStat(text)
    for _, pair in ipairs(ABBREVIATIONS) do text = text:gsub(pair[1], pair[2]) end
    return text
end

-- The enchant's name and its stat, from its tooltip text.
function M.SummarizeEnchant(name)
    if name:find("^[%+%-]?%d") then return M.ShortStat(name), nil end
    local base, inner = name:match("^(.-)%s*%((.-)%)$")
    if inner and inner:find("%d") then return base, M.ShortStat(inner) end
    for known, stat in pairs(M.KNOWN_ENCHANTS) do
        if name:sub(1, #known) == known then return name, stat end
    end
    local left, right = name:match("^(.-)%s+%-%s+(.+)$")
    if right and right:find("%d") then return left, M.ShortStat(right) end
    return name, nil
end

local function TooltipLines(slotID)
    if not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then return nil end
    local data = Call(C_TooltipInfo.GetInventoryItem, "player", slotID)
    if type(data) == "table" and type(data.lines) == "table" then return data.lines end
    return nil
end

-- { name, stat, kind = "permanent" | "temporary" } for a slot, or nil.
function M:EnchantOf(slotID, weaponSlot)
    local lines = TooltipLines(slotID)
    if not lines then return nil end
    local types = Enum and Enum.TooltipDataLineType
    local permanent = types and types.ItemEnchantmentPermanent
    local enchanted = Pattern(ENCHANTED_TOOLTIP_LINE)
    for _, line in ipairs(lines) do
        local text = line.leftText
        if permanent and line.type == permanent and Public(text) and type(text) == "string" and text ~= "" then
            text = Clean(text)
            text = (enchanted and text:match(enchanted)) or text:match("^[^:]+:%s*(.+)$") or text
            local name, stat = M.SummarizeEnchant(text)
            return { name = name, stat = stat, kind = "permanent" }
        end
    end
    if weaponSlot == nil then return nil end
    local info = C_Item and C_Item.GetWeaponEnchantInfo and Call(C_Item.GetWeaponEnchantInfo, weaponSlot)
    if type(info) == "table" and info.hasEnchant == false then return nil end
    -- The timed line: "Instant Poison VI (30 min)".
    for _, line in ipairs(lines) do
        local text = line.leftText
        if Public(text) and type(text) == "string" and (types == nil or line.type == nil or line.type == types.None) then
            local found = Clean(text):match("^(.-) %(%d+ [%a%.]+%)")
            if found and found ~= "" then
                local name, stat = M.SummarizeEnchant(found)
                return { name = name, stat = stat, kind = "temporary" }
            end
        end
    end
    if type(info) == "table" and info.hasEnchant == true then return { name = L["Enhanced"], kind = "temporary" } end
    return nil
end

-- The item's quality color, or nil below Uncommon (and for empty slots).
local function QualityColor(slotID)
    local quality = Call(GetInventoryItemQuality, "player", slotID)
    if not Number(quality, 2, 20) then return nil end
    local r, g, b = Call(C_Item and C_Item.GetItemQualityColor, quality)
    if Number(r) and Number(g) and Number(b) then return { r, g, b } end
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color and Number(color.r) then return { color.r, color.g, color.b } end
    return nil
end

M.slotParts = setmetatable({}, { __mode = "k" })
local function SlotParts(slot)
    local parts = M.slotParts[slot]
    if parts then return parts end
    local holder = CreateFrame("Frame", nil, slot)
    holder:EnableMouse(false)
    holder:SetAllPoints(slot)
    parts = { holder = holder, rim = Kit.Rim(holder, "OVERLAY", 7),
        name = holder:CreateFontString(nil, "OVERLAY"), stat = holder:CreateFontString(nil, "OVERLAY") }
    M.slotParts[slot] = parts
    return parts
end

local function SlotID(slot, name)
    local id = slot.GetID and slot:GetID()
    if Number(id, 1, 30) then return id end
    local info = C_PaperDollInfo and C_PaperDollInfo.GetInventorySlotInfo or GetInventorySlotInfo
    id = Call(info, name .. "Slot")
    return Number(id, 1, 30) and id or nil
end

-- Places the enchant lines for a slot's column.
local function PlaceText(parts, slot, side, px)
    local name, stat = parts.name, parts.stat
    name:ClearAllPoints(); stat:ClearAllPoints()
    local gap = Skin.Snap(TEXT_GAP, px)
    local two = stat:IsShown()
    if side == "bottom" then
        name:SetJustifyH("CENTER"); stat:SetJustifyH("CENTER")
        local lowest = two and stat or name
        lowest:SetPoint("BOTTOM", slot, "TOP", 0, gap)
        if two then name:SetPoint("BOTTOM", stat, "TOP", 0, px) end
    else
        local left = side == "left"
        local point, relative = left and "LEFT" or "RIGHT", left and "RIGHT" or "LEFT"
        local x = left and gap or -gap
        name:SetJustifyH(point); stat:SetJustifyH(point)
        if two then
            name:SetPoint("BOTTOM" .. point, slot, relative, x, px)
            stat:SetPoint("TOP" .. point, slot, relative, x, 0)
        else
            name:SetPoint(point, slot, relative, x, 0)
        end
    end
    name:SetWidth(TEXT_WIDTH); stat:SetWidth(TEXT_WIDTH)
end

function M:PaintSlot(slot, entry)
    local db = self.db
    local parts = SlotParts(slot)
    local px = Kit.PixelSize(slot)
    local slotID = SlotID(slot, entry[1])
    -- Rarity border.
    local color = slotID and QualityColor(slotID)
    local thickness = Skin.Snap(db.charBorderSize, px)
    Kit.PlaceRim(parts.rim, parts.holder, db.charBorders and thickness or 0, 0, color or db.borderColor, 1)
    if db.charBorders then Skin.Fade(slot.IconBorder) elseif slot.IconBorder then slot.IconBorder:SetAlpha(1) end
    if self:IsModeUI(self.byId.character) and slot.BorderFrame then Skin.FadeTextures(slot.BorderFrame) end
    -- Enchant text.
    local enchant = db.charEnchants and slotID and self:EnchantOf(slotID, entry[3]) or nil
    local path, size = Kit.FontPath(db, self.id), db.charEnchantSize
    Skin.Font(parts.name, path, size, db.outline, true, px)
    Skin.Font(parts.stat, path, math.max(8, size - 1), db.outline, true, px)
    local accent = enchant and enchant.kind == "temporary" and Kit.palette.green or C.accent
    parts.name:SetTextColor(accent[1], accent[2], accent[3], 1)
    parts.stat:SetTextColor(C.label[1], C.label[2], C.label[3], 1)
    parts.name:SetText(enchant and enchant.name or "")
    parts.stat:SetText(enchant and enchant.stat or "")
    parts.name:SetShown(enchant ~= nil)
    parts.stat:SetShown(enchant ~= nil and enchant.stat ~= nil)
    PlaceText(parts, slot, entry[2], px)
    parts.holder:Show()
end

function M:CharacterShown() return CharacterFrame and CharacterFrame:IsVisible() == true end

-- Everything on the Character window, from the settings and the gear worn.
function M:CharacterRefresh()
    self.characterPending = false
    if not self.active then return end
    self:PaintStats()
    for _, entry in ipairs(self.SLOTS) do
        local slot = _G["Character" .. entry[1] .. "Slot"]
        if slot and slot.GetObjectType then self:PaintSlot(slot, entry) end
    end
end

-- Many events arrive together (a gear swap fires several, auras tick in
-- combat); one refresh runs a tenth of a second later, only while the
-- window is open.
function M:QueueCharacter()
    if self.characterPending or not self:CharacterShown() then return end
    self.characterPending = true
    C_Timer.After(0.1, function() if self.characterPending then self:CharacterRefresh() end end)
end

local EVENTS = { "PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED", "UNIT_STATS", "UNIT_AURA", "COMBAT_RATING_UPDATE",
    "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER", "UNIT_DAMAGE", "UNIT_SPELL_HASTE", "SPELL_POWER_CHANGED",
    "WEAPON_ENCHANT_CHANGED", "PLAYER_SPECIALIZATION_CHANGED" }
M.characterEvents = {}

function M:CharacterEnable()
    for _, event in ipairs(EVENTS) do
        pcall(Events.On, Events, self.characterEvents, event, function(_, unit)
            if unit == nil or unit == "player" or type(unit) ~= "string" then self:QueueCharacter() end
        end)
    end
    for _, frame in ipairs({ CharacterFrame, PaperDollFrame }) do
        if frame and frame.HookScript then
            Skin.Once(frame, "modeCharacter", function()
                frame:HookScript("OnShow", function() if self.active then self:CharacterRefresh() end end)
            end)
        end
    end
    self:CharacterRefresh()
end

function M:CharacterDisable()
    Events:OffAll(self.characterEvents)
    if self.statsFrame then self.statsFrame:Hide() end
    for _, parts in pairs(self.slotParts) do parts.holder:Hide() end
end
