local _, addon = ...
local M = addon.CooldownManager
if not M then return end

-- The + slot's list (custom bars, Essential and Utility), as grids of
-- icons in up to three sections:
--   Tracked in Blizzard CDM  what the bar can take from Blizzard's Cooldown
--       Manager (Essential and Utility cooldowns for a Cooldown Bar and for
--       Essential and Utility themselves, Tracked Buffs and Bars for a Buff
--       Bar); clicking adds it (a spell on another bar moves). A spell
--       removed from this bar shows here too; clicking brings it back.
--   Not in Blizzard CDM  every other spell the game has for your class and
--       spec there, learned or not, grayed. On a cooldown bar clicking one
--       adds it as a custom spell (its own icon, shown while you know it); a
--       buff can only show once Blizzard's Cooldown Manager tracks it.
--   Items in Your Bags  (cooldown bars) what you carry with a Use: effect.
-- Then, on cooldown bars, Spell ID (a spell you know) and Item ID fields.
-- "Cooldown bars" here: Cooldown Bars, Essential and Utility.
-- Pointing at an icon names it and says what a click does. It stays open to
-- add several, and closes on a click elsewhere, the close button, or combat.
local W, T, L, Kit = addon.ConfigWidgets, addon.InterfaceTheme, addon.L, addon.Kit
local Cooldowns = addon.Domain.Cooldowns
local SIZE, GAP, COLUMNS, PAD = 36, 6, 8, 14
local INNER = COLUMNS * SIZE + (COLUMNS - 1) * GAP
local WIDTH = INNER + 2 * PAD
local CATEGORIES = { cooldown = { "Essential", "Utility" }, buff = { "TrackedBuff", "TrackedBar" } }
local HINT = "Point at an icon to see what it is"

local function OnEvent(picker, event)
    if event == "PLAYER_REGEN_DISABLED" then picker:Hide(); return end
    local over = picker:IsMouseOver() or (picker.anchor and picker.anchor:IsMouseOver())
    if not (addon.IsPublic(over) and over) then picker:Hide() end
end

-- A labeled ID field with its Add button; add(text) returns ok and a message.
local function IdRow(picker, label, add)
    local row = CreateFrame("Frame", nil, picker)
    row:SetSize(INNER, 48)
    W.Label(row, label, nil, 0, 0, INNER, T.muted)
    local field = CreateFrame("Frame", nil, row)
    field:SetPoint("TOPLEFT", 0, -18); field:SetSize(140, 28)
    row.input = W.TextInput(field, 140, L["e.g. 12345"], 9)
    row.add = W.Button(row, L["Add"], 60, 28, "secondary")
    row.add:SetPoint("TOPLEFT", 148, -18)
    local function Add()
        local ok, message = add(row.input:GetText())
        if ok then row.input:SetText("") end
        picker.idResult:SetText(message)
        M:RefreshPicker(true)
    end
    row.input.onEnter = Add
    row.add:SetScript("OnClick", Add)
    return row
end

function M:Picker()
    if self.picker then return self.picker end
    local picker = CreateFrame("Frame", "ModeUICooldownPicker", UIParent)
    picker:SetSize(WIDTH, 200); picker:SetFrameStrata("TOOLTIP"); picker:SetFrameLevel(200)
    picker:SetClampedToScreen(true); picker:EnableMouse(true); picker:Hide()
    W.Texture(picker, "Window"); W.Texture(picker, "BorderSilver", "BORDER")
    picker.title = W.Label(picker, "", nil, PAD, -12, INNER - 34, T.secondary)
    picker.close = W.Button(picker, "X", 24, 24, "secondary")
    picker.close:SetPoint("TOPRIGHT", -10, -8)
    picker.close:SetScript("OnClick", function() picker:Hide() end)
    picker.hover = W.Label(picker, "", nil, PAD, -36, INNER, T.text)
    picker.headings = {}
    for i, text in ipairs({ "Tracked in Blizzard CDM", "Not in Blizzard CDM", "Items in Your Bags" }) do
        picker.headings[i] = W.Label(picker, L[text], nil, PAD, 0, INNER, T.muted)
    end
    picker.empty = W.Label(picker, L["Nothing tracked here yet: add spells in Blizzard's Cooldown Manager (Open CDM)."], nil, PAD, 0, INNER, T.muted)
    picker.empty:SetWordWrap(true)
    picker.cdm = W.Button(picker, L["Open CDM"], 120, 26, "secondary")
    picker.cdm:SetPoint("BOTTOMLEFT", PAD, 12)
    picker.cdm:SetScript("OnClick", function() picker:Hide(); M:OpenCooldownSettings() end)
    picker.spellRow = IdRow(picker, L["Spell ID"], function(text)
        local ok, result = M:AddCustomSpell(picker.barId, text)
        return ok, ok and string.format(L["Added %s."], M:SpellLabel("s" .. result)) or result
    end)
    picker.itemRow = IdRow(picker, L["Item ID"], function(text)
        local ok, result = M:AddCustomItem(picker.barId, text)
        return ok, ok and string.format(L["Added %s."], M:SpellLabel("i" .. result)) or result
    end)
    -- Back-compat names for the Spell ID field.
    picker.idInput, picker.idAdd = picker.spellRow.input, picker.spellRow.add
    picker.idResult = W.Label(picker, "", nil, PAD, 0, INNER, T.muted)
    picker.idResult:SetWordWrap(true)
    picker.buttons = {}
    picker:SetScript("OnEvent", OnEvent)
    picker:SetScript("OnShow", function()
        for _, event in ipairs({ "GLOBAL_MOUSE_DOWN", "PLAYER_REGEN_DISABLED" }) do
            if not picker:IsEventRegistered(event) then picker:RegisterEvent(event) end
        end
    end)
    picker:SetScript("OnHide", function() picker:UnregisterAllEvents(); picker.anchor = nil end)
    self.picker = picker
    return picker
end

local function Button(picker, index)
    local button = picker.buttons[index]
    if button then return button end
    button = CreateFrame("Button", nil, picker)
    button:SetSize(SIZE, SIZE)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 1, -1); button.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.rim = Kit.Rim(button, "BACKGROUND")
    Kit.PlaceRim(button.rim, button, 1, 0, Kit.onyx.border, 1)
    button.highlight = W.Fill(button, T.primary, "OVERLAY", 0, 0.2)
    button.highlight:Hide()
    button:SetScript("OnEnter", function()
        button.highlight:SetShown(button.add ~= nil)
        picker.hover:SetText(button.where)
    end)
    button:SetScript("OnLeave", function() button.highlight:Hide(); picker.hover:SetText(L[HINT]) end)
    button:SetScript("OnClick", function()
        if not button.add then return end
        local ok, message = button.add()
        if ok then picker.idResult:SetText("") elseif type(message) == "string" then picker.idResult:SetText(message) end
        M:RefreshPicker(not ok)
    end)
    picker.buttons[index] = button
    return button
end

function M:OpenPicker(view, anchor)
    local id = self:PreviewViewer()
    if not self:TakesEntries(id) then return false end
    local picker = self:Picker()
    if self.spellMenu then self.spellMenu:Hide() end
    if picker.barId ~= id then
        picker.idResult:SetText(""); picker.spellRow.input:SetText(""); picker.itemRow.input:SetText("")
    end
    picker.barId, picker.anchor, picker.view = id, anchor, view
    picker:SetScale(anchor:GetEffectiveScale() / UIParent:GetEffectiveScale())
    picker:ClearAllPoints(); picker:SetPoint("TOP", anchor, "BOTTOM", 0, -8)
    picker:Show()
    self:RefreshPicker()
    return true
end

-- Your class's spells for the bar that Blizzard's Cooldown Manager doesn't
-- show in any of its viewers now, without those on the bar already:
-- { key, spell, known }.
function M:UntrackedCandidates(id)
    local list, here, tracked = {}, {}, {}
    if not self:TakesEntries(id) then return list end
    for _, key in ipairs(self:Entries(id)) do here[key] = true end
    for viewer in pairs(Cooldowns.VIEWERS) do
        for _, item in ipairs(self:Items(viewer)) do
            local key = self:SpellKey(item)
            if key then tracked[key] = true end
        end
    end
    for _, entry in ipairs(Cooldowns.ClassCooldowns(CATEGORIES[self:TakesOwn(id) and "cooldown" or "buff"])) do
        local key = string.format("%d", entry.cooldownID)
        if not tracked[key] and not here[key] and not here["s" .. entry.spellID] then
            list[#list + 1] = { key = key, spell = entry.spellID, known = entry.known }
        end
    end
    -- Your racials, on a bar that doesn't show them already.
    if self:TakesOwn(id) then
        for _, key in ipairs(self:RacialKeys()) do
            if not here[key] then list[#list + 1] = { key = key, spell = tonumber(key:sub(2)), known = true } end
        end
    end
    return list
end

-- The grids, top to bottom; returns the y below them.
local function Section(picker, heading, list, y, used, Fill)
    heading:SetShown(#list > 0)
    if #list == 0 then return y end
    heading:ClearAllPoints(); heading:SetPoint("TOPLEFT", PAD, y)
    y = y - 18
    for i, entry in ipairs(list) do
        local button = Button(picker, used + i)
        Fill(button, entry)
        local column, row = (i - 1) % COLUMNS, math.floor((i - 1) / COLUMNS)
        button:ClearAllPoints(); button:SetPoint("TOPLEFT", PAD + column * (SIZE + GAP), y - row * (SIZE + GAP))
        button:Show()
    end
    return y - math.ceil(#list / COLUMNS) * (SIZE + GAP) - 6
end

function M:RefreshPicker(keepResult)
    local picker = self.picker
    if not picker or not picker:IsShown() or not self:HasBar(picker.barId) then return end
    local id = picker.barId
    if not self:TakesEntries(id) then picker:Hide(); return end
    local cooldownBar = self:TakesOwn(id)
    local tracked = {}
    -- What shows elsewhere, and what was removed from this bar.
    for _, candidate in ipairs(self:Candidates(id)) do
        if candidate.owner ~= id or self:SpellSwitch(id, candidate.key, "hide") then tracked[#tracked + 1] = candidate end
    end
    picker.title:SetText(string.format(L["Add to %s"], self:Label(id)))
    picker.hover:SetText(L[HINT])
    local y, used = -58, 0
    y = Section(picker, picker.headings[1], tracked, y, used, function(button, candidate)
        button.icon:SetTexture(candidate.icon or 134400)
        local back = candidate.owner == id
        local other = not back and candidate.owner ~= candidate.source
        button.icon:SetDesaturated(other or back); button.icon:SetAlpha(back and 0.6 or 1)
        button.key = candidate.key
        if back then
            button.where = string.format(L["%s · removed from this bar (shows again)"], candidate.name)
            button.add = function() return M:SetSpellSwitch(id, candidate.key, "hide", false) end
        else
            button.where = other and string.format(L["%s · on %s (moves here)"], candidate.name, self:Label(candidate.owner))
                or string.format(L["%s · in %s"], candidate.name, self:Label(candidate.owner))
            button.add = function() return M:AddEntry(id, candidate.key) end
        end
    end)
    used = used + #tracked
    picker.empty:SetShown(#tracked == 0)
    if #tracked == 0 then
        picker.empty:ClearAllPoints(); picker.empty:SetPoint("TOPLEFT", PAD, y)
        y = y - 34
    end
    local untracked = self:UntrackedCandidates(id)
    y = Section(picker, picker.headings[2], untracked, y, used, function(button, entry)
        button.icon:SetTexture(Cooldowns.SpellIcon(entry.spell) or 134400)
        button.icon:SetDesaturated(true); button.icon:SetAlpha(entry.known and 0.75 or 0.4)
        button.key = cooldownBar and "s" .. entry.spell or entry.key
        local name = Cooldowns.SpellName(entry.spell) or string.format(L["Spell %s"], entry.spell)
        local state = entry.known and L["Not in Blizzard CDM"] or L["Not in Blizzard CDM · not learned"]
        if cooldownBar then
            button.where = string.format(L["%s · %s · adds as a custom spell"], name, state)
            button.add = function() return M:AddCustomSpell(id, entry.spell, true) end
        else
            button.where = string.format(L["%s · %s · track it there to add it"], name, state)
            button.add = nil
        end
    end)
    used = used + #untracked
    local items = cooldownBar and self:ItemCandidates(id) or {}
    y = Section(picker, picker.headings[3], items, y, used, function(button, item)
        button.icon:SetTexture(item.icon or 134400)
        button.icon:SetDesaturated(false); button.icon:SetAlpha(1)
        button.where = string.format(L["%s · item"], item.name)
        button.key, button.add = item.key, function() return M:AddCustomItem(id, item.id) end
    end)
    used = used + #items
    for index = used + 1, #picker.buttons do picker.buttons[index]:Hide(); picker.buttons[index].add = nil end
    picker.cdm:SetEnabled(self:CanOpenCooldownSettings())
    if not keepResult then picker.idResult:SetText("") end
    -- Spells and items by ID: Cooldown Bars only.
    for _, row in ipairs({ picker.spellRow, picker.itemRow }) do
        row:SetShown(cooldownBar)
        if cooldownBar then row:ClearAllPoints(); row:SetPoint("TOPLEFT", PAD, y - 2); y = y - 54 end
    end
    picker.idResult:ClearAllPoints(); picker.idResult:SetPoint("TOPLEFT", PAD, y)
    picker.idResult:SetShown(cooldownBar)
    if cooldownBar then y = y - 30 end
    picker:SetHeight(-y + 46)
    if picker.view then picker.view.Refresh() end
end
