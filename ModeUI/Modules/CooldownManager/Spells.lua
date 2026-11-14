local _, addon = ...
local M = addon.CooldownManager
if not M then return end

-- Custom spells: any spell, by its spell ID, on a custom Cooldown Bar, even
-- one you don't track in Blizzard's Cooldown Manager. It gets an icon of
-- ModeUI's own (no Blizzard frame to borrow), saved in the bar's spells as
-- "s<spell ID>" beside the cooldown IDs, laid out, skinned and styled like
-- every other icon on the bar. Shown only while you know the spell (or what
-- replaces it now). Items ("i<item ID>", Items.lua) use the same icons.
--
-- Secret-safe by construction: the cooldown and recharge come as duration
-- objects (C_Spell.GetSpellCooldownDuration/GetSpellChargeDuration) that go
-- straight to the icon's Cooldown (SetCooldownFromDurationObject), which
-- also draws the numbers; the charge count may be secret and only goes to
-- SetText. Whether the spell is cooling (gray, off-cooldown glow) comes from
-- C_Spell.GetSpellCooldown's never-secret isActive and isOnGCD; procs from
-- SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE. Glows that need Blizzard's own
-- tracking (Active, Buff) don't light on custom spells.
local L, Cooldowns, Public = addon.L, addon.Domain.Cooldowns, addon.IsPublic
local NOT_USABLE, NO_POWER = { 0.4, 0.4, 0.4 }, { 0.5, 0.5, 1 }
M.spellIcons = {} -- bar ID -> { [key] = icon }
M.iconKey = setmetatable({}, { __mode = "k" })
M.iconBar = setmetatable({}, { __mode = "k" })
local function Copy(value) return addon.ProfileCodec.Copy(value) end

function M.IsSpellEntry(key) return type(key) == "string" and key:match("^s%d+$") ~= nil end

-- The spell an entry is about: a custom spell's own ID, or the spell a
-- cooldown ID casts now.
function M:SpellOf(key)
    if self.IsItemEntry(key) then return nil end
    if self.IsSpellEntry(key) then return tonumber(key:sub(2)) end
    return Cooldowns.SpellID(tonumber(key))
end

-- The spell to ask the game about for an entry's cooldown: a custom
-- spell's current override, or the spell a cooldown ID casts now.
function M:CooldownSpell(key)
    local spell = self:SpellOf(key)
    if self.IsSpellEntry(key) and spell then return Cooldowns.Override(spell) end
    return spell
end

-- An item ModeUI made for a custom spell (not one of Blizzard's).
function M:IsOwnIcon(item) return self.iconKey[item] ~= nil end
-- Blizzard's items and ModeUI's own icons alike.
function M:IsLive(item) return self.sourceOf[item] ~= nil or self.iconKey[item] ~= nil end

-- Adds a spell by its ID (a number, or text as typed) to a custom Cooldown
-- Bar: one you know, or (unlearned) one of your class's spells in the + slot's
-- list. Returns true and the spell ID, or false and why.
function M:AddCustomSpell(id, text, classSpell)
    local bar, index = self:Custom(id)
    if not bar or bar.kind ~= "cooldown" then return false, L["Spells by ID go on Cooldown Bars."] end
    if not self:CanConfigure() then return false, L["Not in combat."] end
    local spellID = type(text) == "number" and text or tonumber(type(text) == "string" and text:match("^%s*(%d+)%s*$") or nil)
    if not spellID or not Cooldowns.SpellExists(spellID) then return false, L["No spell has that ID."] end
    -- A spell your character doesn't have would never show (Thistle Tea as a
    -- spell on a priest, say); the item of the same name goes in by Item ID.
    if not classSpell and not Cooldowns.Known(spellID) then return false, L["You don't know that spell. An item? Add it by Item ID."] end
    local key = "s" .. spellID
    for _, entry in ipairs(bar.entries) do if entry == key then return false, L["That spell is on this bar already."] end end
    if #bar.entries >= self.MAX_ENTRIES then return false, L["This bar is full."] end
    local candidate = Copy(self.db)
    local entries = candidate.customBars[index].entries
    entries[#entries + 1] = key
    if not self.CommitBars(self, candidate) then return false, L["That spell can't be added."] end
    return true, spellID
end

-- A custom spell's icon on a bar, made on first use: the parts the skin and
-- text code look for, and a tooltip of the spell.
function M:SpellIcon(id, key)
    local icons = self.spellIcons[id] or {}
    self.spellIcons[id] = icons
    local icon = icons[key]
    if icon then return icon end
    icon = CreateFrame("Frame", nil, self.holders[id] or UIParent)
    icon.Icon = icon:CreateTexture(nil, "ARTWORK")
    icon.Cooldown = CreateFrame("Cooldown", nil, icon)
    if icon.Cooldown.SetHideCountdownNumbers then icon.Cooldown:SetHideCountdownNumbers(false) end
    icon.ChargeCount = CreateFrame("Frame", nil, icon)
    icon.ChargeCount:SetAllPoints()
    icon.ChargeCount.Current = icon.ChargeCount:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    icon:EnableMouse(true)
    icon:SetScript("OnEnter", function(frame)
        local tooltip = _G.GameTooltip
        if not tooltip or type(tooltip.SetSpellByID) ~= "function" then return end
        tooltip:SetOwner(frame, "ANCHOR_RIGHT")
        local item = M.ItemOf(key)
        if item then
            if type(tooltip.SetItemByID) ~= "function" then return end
            tooltip:SetItemByID(item)
        else tooltip:SetSpellByID(Cooldowns.Override(M:SpellOf(key))) end
        tooltip:Show()
    end)
    icon:SetScript("OnLeave", function() if _G.GameTooltip then _G.GameTooltip:Hide() end end)
    icon:Hide()
    icons[key] = icon
    self.iconKey[icon], self.iconBar[icon] = key, id
    return icon
end

-- Icons for spells no longer on their bar (or bars deleted) are put away.
function M:SyncSpellIcons()
    for id, icons in pairs(self.spellIcons) do
        local bar = self:Custom(id)
        local wanted = {}
        for _, key in ipairs(bar and bar.entries or {}) do wanted[key] = true end
        for key, icon in pairs(icons) do
            if not wanted[key] then
                icon:Hide()
                icons[key] = nil
                self.iconKey[icon], self.iconBar[icon] = nil, nil
            end
        end
    end
end

-- A custom bar's own icons (custom spells and items), in its order, split
-- into those to show and spells you don't know (hidden).
function M:SpellIcons(id)
    local list = {}
    local bar = self:Custom(id)
    if not bar or not self.built then return list end
    for _, key in ipairs(bar.entries) do
        if self.IsOwnEntry(key) then
            local icon = self:SpellIcon(id, key)
            if self.IsItemEntry(key) or Cooldowns.Known(self:SpellOf(key)) then list[#list + 1] = icon else icon:Hide() end
        end
    end
    return list
end

-- Brings one icon up to date: picture, cooldown or recharge, charges, the
-- usable tint and the gray.
function M:UpdateSpellIcon(icon)
    local id, key = self.iconBar[icon], self.iconKey[icon]
    local style = id and self.db[id]
    if not style then return end
    if self.IsItemEntry(key) then self:UpdateItemIcon(icon, style); return end
    local spell = Cooldowns.Override(self:SpellOf(key))
    icon.Icon:SetTexture(Cooldowns.SpellIcon(spell) or 134400)
    local cooling = Cooldowns.Cooling(spell)
    local current, max, recharging = Cooldowns.Charges(spell)
    local duration
    if max and recharging and cooling ~= true then duration = Cooldowns.ChargeDuration(spell)
    else duration = Cooldowns.CooldownDuration(spell) end
    local cooldown = icon.Cooldown
    if duration and cooldown.SetCooldownFromDurationObject then pcall(cooldown.SetCooldownFromDurationObject, cooldown, duration) end
    icon.ChargeCount.Current:SetText(max and current or "")
    local usable, noPower = Cooldowns.Usable(spell)
    local tint = (usable == false) and (noPower and NO_POWER or NOT_USABLE) or nil
    icon.Icon:SetVertexColor(tint and tint[1] or 1, tint and tint[2] or 1, tint and tint[3] or 1, 1)
    if style.desaturate then icon.Icon:SetDesaturated(cooling == true) else icon.Icon:SetDesaturated(false) end
end

function M:UpdateSpellIcons()
    if not self.active then return end
    for _, icons in pairs(self.spellIcons) do
        for _, icon in pairs(icons) do self:UpdateSpellIcon(icon) end
    end
end

-- Procs: the game names the spell that lights up (or goes out).
function M:SpellProc(spellID, on)
    if not self.active or not Public(spellID) or type(spellID) ~= "number" then return end
    for _, icons in pairs(self.spellIcons) do
        for key, icon in pairs(icons) do
            local spell = self:SpellOf(key)
            if spell and spell == spellID or spell and Cooldowns.Override(spell) == spellID then
                self.procs[icon] = on or nil
                self:ApplyGlows(icon)
            end
        end
    end
end

-- Every custom spell icon, for switching the module off.
function M:HideSpellIcons()
    for _, icons in pairs(self.spellIcons) do
        for _, icon in pairs(icons) do icon:Hide() end
    end
end
