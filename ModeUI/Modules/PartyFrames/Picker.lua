local _, addon = ...
local M = addon.PartyFrames
if not M then return end

-- Tracked Buffs (owner, November 13, 2026: like the Cooldown Manager's bars):
-- click + on a tracked group, click a buff, and it joins that group, shown
-- with that group's settings. The list holds the buffs on you and your party
-- now (read out of combat, when their spell IDs are public), plus a Spell ID
-- field for any other. The group's own buffs sit at the top; clicking one
-- takes it out. A buff joins one tracked group at a time (adding it to
-- another moves it). The picker closes on a click elsewhere, its close button,
-- or combat.
local W, T, L, Kit = addon.ConfigWidgets, addon.InterfaceTheme, addon.L, addon.Kit
local Auras, Spells = addon.Domain.Auras, addon.Domain.Cooldowns
local WIDTH, PAD, SIZE, GAP, COLUMNS = 320, 14, 32, 6, 8
local INNER = WIDTH - 2 * PAD
local function Copy(value) return addon.ProfileCodec.Copy(value) end

-- Adds a spell to a tracked group (taking it out of the others). Returns ok
-- and a message.
function M:AddTrackedSpell(group, id)
    if not self.TRACKED[group] then return false, L["Pick a Tracked Buffs group."] end
    if not self:CanConfigure() then return false, L["Not in combat."] end
    if not addon.IsNumber(id, 1, 10000000) or id ~= math.floor(id) or not Spells.SpellName(id) then return false, L["No spell has that ID."] end
    local spells = Copy(self.db.auras[group].spells)
    for _, held in ipairs(spells) do if held == id then return false, L["That buff is in this group already."] end end
    if #spells >= self.MAX_TRACKED_SPELLS then return false, L["This group is full."] end
    for other in pairs(self.TRACKED) do
        if other ~= group then
            local list, kept = self.db.auras[other].spells, {}
            for _, held in ipairs(list) do if held ~= id then kept[#kept + 1] = held end end
            if #kept ~= #list then self:SetAuraOption(other, "spells", kept) end
        end
    end
    spells[#spells + 1] = id
    if not self:SetAuraOption(group, "spells", spells) then return false, L["That buff can't be added."] end
    return true, string.format(L["Added %s."], Spells.SpellName(id))
end
function M:RemoveTrackedSpell(group, id)
    if not self.TRACKED[group] or not self:CanConfigure() then return false end
    local kept = {}
    for _, held in ipairs(self.db.auras[group].spells) do if held ~= id then kept[#kept + 1] = held end end
    return self:SetAuraOption(group, "spells", kept)
end

-- Buffs on you and your party now, each once: { id, icon, name }.
function M:BuffCandidates()
    local list, seen = {}, {}
    for _, unit in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
        if addon.Domain.Query.Truthy(UnitExists, unit) then
            for _, aura in ipairs(Auras.List(unit, "HELPFUL", 40)) do
                local id = Auras.Field(aura, "spellId")
                if addon.IsNumber(id) and not seen[id] then
                    seen[id] = true
                    list[#list + 1] = { id = id, icon = Spells.SpellIcon(id), name = Spells.SpellName(id) or tostring(id) }
                end
            end
        end
    end
    return list
end

local function OnEvent(picker, event)
    if event == "PLAYER_REGEN_DISABLED" then picker:Hide(); return end
    local over = picker:IsMouseOver() or (picker.anchor and picker.anchor:IsMouseOver())
    if not (addon.IsPublic(over) and over) then picker:Hide() end
end

function M:Picker()
    if self.picker then return self.picker end
    local picker = CreateFrame("Frame", "ModeUIPartyBuffPicker", UIParent)
    picker:SetSize(WIDTH, 200); picker:SetFrameStrata("TOOLTIP"); picker:SetFrameLevel(200)
    picker:SetClampedToScreen(true); picker:EnableMouse(true); picker:Hide()
    W.Texture(picker, "Window"); W.Texture(picker, "BorderSilver", "BORDER")
    picker.title = W.Label(picker, "", nil, PAD, -12, INNER - 34, T.secondary)
    picker.close = W.Button(picker, "X", 24, 24, "secondary")
    picker.close:SetPoint("TOPRIGHT", -10, -8)
    picker.close:SetScript("OnClick", function() picker:Hide() end)
    picker.hover = W.Label(picker, "", nil, PAD, -36, INNER, T.muted)
    picker.inLabel = W.Label(picker, L["In this group (click to take out)"], nil, PAD, -58, INNER, T.muted)
    picker.addLabel = W.Label(picker, L["On you and your party (click to add)"], nil, PAD, 0, INNER, T.muted)
    picker.empty = W.Label(picker, L["No buffs to show. Add one by its spell ID below."], nil, PAD, 0, INNER, T.muted)
    picker.empty:SetWordWrap(true)
    picker.byId = CreateFrame("Frame", nil, picker)
    picker.byId:SetSize(INNER, 48)
    W.Label(picker.byId, L["Spell ID"], nil, 0, 0, INNER, T.muted)
    local field = CreateFrame("Frame", nil, picker.byId)
    field:SetPoint("TOPLEFT", 0, -18); field:SetSize(140, 28)
    picker.idInput = W.TextInput(field, 140, L["e.g. 12345"], 9)
    picker.idAdd = W.Button(picker.byId, L["Add"], 60, 28, "secondary")
    picker.idAdd:SetPoint("TOPLEFT", 148, -18)
    picker.idResult = W.Label(picker.byId, "", nil, 214, -24, INNER - 214, T.muted)
    local function Add()
        local id = tonumber((picker.idInput:GetText() or ""):match("^%s*(%d+)%s*$") or "")
        local ok, message = M:AddTrackedSpell(picker.group, id)
        if ok then picker.idInput:SetText("") end
        picker.idResult:SetText(message)
        M:RefreshPicker(true)
    end
    picker.idInput.onEnter = Add
    picker.idAdd:SetScript("OnClick", Add)
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
    Kit.PlaceRim(button.rim, button, 1, 0, Kit.BORDER_COLOR, 1)
    button.highlight = W.Fill(button, T.primary, "OVERLAY", 0, 0.2)
    button.highlight:Hide()
    button:SetScript("OnEnter", function() button.highlight:Show(); picker.hover:SetText(button.where) end)
    button:SetScript("OnLeave", function() button.highlight:Hide(); picker.hover:SetText("") end)
    button:SetScript("OnClick", function()
        if button.held then M:RemoveTrackedSpell(picker.group, button.spell)
        else M:AddTrackedSpell(picker.group, button.spell) end
        M:RefreshPicker()
    end)
    picker.buttons[index] = button
    return button
end

-- Opens the picker for a tracked group under `anchor`.
function M:OpenPicker(group, anchor)
    if not self.TRACKED[group] or not self:CanConfigure() then return false end
    local picker = self:Picker()
    if picker.group ~= group then picker.idResult:SetText(""); picker.idInput:SetText("") end
    picker.group, picker.anchor = group, anchor
    picker:SetScale(anchor:GetEffectiveScale() / UIParent:GetEffectiveScale())
    picker:ClearAllPoints(); picker:SetPoint("TOP", anchor, "BOTTOM", 0, -8)
    picker:Show()
    self:RefreshPicker()
    return true
end

-- Lays out the group's buffs, then the ones to add, then Spell ID.
function M:RefreshPicker(keepResult)
    local picker = self.picker
    if not picker or not picker:IsShown() or not self.TRACKED[picker.group] then return end
    local group = picker.group
    picker.title:SetText(string.format(L["Add to %s"], L[self.auraGroupLabels[group]]))
    local held, inGroup = self.db.auras[group].spells, {}
    for _, id in ipairs(held) do inGroup[id] = true end
    local add = {}
    for _, candidate in ipairs(self:BuffCandidates()) do if not inGroup[candidate.id] then add[#add + 1] = candidate end end
    local index, top = 0, 76
    local function Grid(list, isHeld)
        for i, item in ipairs(list) do
            index = index + 1
            local button = Button(picker, index)
            local id = isHeld and item or item.id
            button.spell, button.held = id, isHeld
            button.icon:SetTexture((isHeld and Spells.SpellIcon(id) or item.icon) or 134400)
            button.where = (isHeld and Spells.SpellName(id) or item.name or tostring(id)) .. " · " .. id
            local column, row = (i - 1) % COLUMNS, math.floor((i - 1) / COLUMNS)
            button:ClearAllPoints(); button:SetPoint("TOPLEFT", PAD + column * (SIZE + GAP), -top - row * (SIZE + GAP))
            button:Show()
        end
        return math.max(1, math.ceil(#list / COLUMNS)) * (SIZE + GAP)
    end
    top = top + Grid(held, true) + 8
    picker.addLabel:ClearAllPoints(); picker.addLabel:SetPoint("TOPLEFT", PAD, -top)
    top = top + 20
    picker.empty:ClearAllPoints(); picker.empty:SetPoint("TOPLEFT", PAD, -top)
    picker.empty:SetShown(#add == 0)
    top = top + (#add == 0 and 32 or Grid(add, false)) + 8
    for i = index + 1, #picker.buttons do picker.buttons[i]:Hide() end
    if not keepResult then picker.idResult:SetText("") end
    picker.byId:ClearAllPoints(); picker.byId:SetPoint("TOPLEFT", PAD, -top)
    picker:SetHeight(top + 60)
end
