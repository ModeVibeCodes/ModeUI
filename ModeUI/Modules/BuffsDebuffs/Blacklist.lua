local _, addon = ...
local M, W, T, L = addon.BuffsDebuffs, addon.ConfigWidgets, addon.InterfaceTheme, addon.L
if not M then return end

-- The Blacklist tab and its picker: spells no Mode bar shows, sent to the
-- game as excludeSpellIDs on every group. The game honors it for every buff;
-- for your own debuffs only when it never keeps that spell's aura secret
-- (Domain.Auras.NeverSecret), so the picker says which those are. Click
-- + Add or Remove Auras, then click an aura on you now to hide it, or a
-- hidden one to bring it back; any spell can be added by ID. The picker
-- closes on a click elsewhere, its close button, or combat. Opened for a bar
-- (Bars tab, Spells You Add) the same picker holds that bar's own buffs.
local Auras, Spells, Style = addon.Domain.Auras, addon.Domain.Cooldowns, addon.Style
local WIDTH, PAD, SIZE, GAP, COLUMNS = 320, 14, 32, 6, 8
local INNER = WIDTH - 2 * PAD
local QUESTION = 134400 -- the game's question-mark icon

-- How far hiding a spell reaches: every bar, or buff bars only.
function M:BlacklistReach(spellID)
    local never = Auras.NeverSecret(spellID)
    if never then return "all", L["hidden on every bar"] end
    return "buffs", L["hidden as a buff; as your debuff the game may still show it"]
end

function M:AddBlacklistByID(id)
    if not self:CanConfigure() then return false, L["Not in combat."] end
    if not addon.IsNumber(id, 1, 10000000) or id ~= math.floor(id) or not Spells.SpellName(id) then return false, L["No spell has that ID."] end
    if self:IsBlacklisted(id) then return false, L["That spell is hidden already."] end
    if #self.db.blacklist >= self.MAX_BLACKLIST then return false, L["The blacklist is full."] end
    if not self:AddBlacklist(id) then return false, L["That spell can't be added."] end
    return true, string.format(L["Hid %s."], Spells.SpellName(id))
end

-- Spells You Add by ID, for a bar.
function M:AddBarSpellByID(barId, id)
    if not self:CanConfigure() then return false, L["Not in combat."] end
    if not addon.IsNumber(id, 1, 10000000) or id ~= math.floor(id) or not Spells.SpellName(id) then return false, L["No spell has that ID."] end
    if self:HasBarSpell(barId, id) then return false, L["That spell is added already."] end
    if #self.db.bars[barId].spells >= self.MAX_SPELLS then return false, L["The list is full."] end
    if not self:AddBarSpell(barId, id) then return false, L["That spell can't be added."] end
    return true, string.format(L["Added %s."], Spells.SpellName(id))
end

-- What the picker edits: the blacklist, or a bar's Spells You Add.
local function Target(self, picker)
    local bar = picker.target and self.db.bars[picker.target]
    if bar then
        local id = picker.target
        return { held = bar.spells, has = function(spell) return self:HasBarSpell(id, spell) end,
            add = function(spell) return self:AddBarSpell(id, spell) end, remove = function(spell) return self:RemoveBarSpell(id, spell) end,
            byId = function(spell) return self:AddBarSpellByID(id, spell) end, buffsOnly = true }
    end
    return { held = self.db.blacklist, has = function(spell) return self:IsBlacklisted(spell) end,
        add = function(spell) return self:AddBlacklist(spell) end, remove = function(spell) return self:RemoveBlacklist(spell) end,
        byId = function(spell) return self:AddBlacklistByID(spell) end }
end

function M:BuildBlacklistTab(page, c)
    page:Section(L["Blacklist"], nil, false)
    page:Group(L["Blacklist"])
    c.Note("Auras no Mode bar shows. Buffs always stay hidden. Your own debuffs stay hidden only when the game never keeps them secret (Sated and Exhaustion, for example); the picker marks the rest.", 64)
    local row = page:Row(L["Hidden Auras"], 48)
    page.blacklistButton = W.Button(row, L["+ Add or Remove Auras"], 190, 30, "secondary")
    page.blacklistButton:SetPoint("LEFT")
    page.blacklistButton:SetScript("OnClick", function() M:OpenPicker(page.blacklistButton) end)
    page.blacklistCount = W.Label(row, "", nil, 200, -8, 200, T.muted)
    c.Refresh(function()
        local n = #M.db.blacklist
        page.blacklistCount:SetText(n == 0 and L["None hidden"] or string.format(L["%d hidden"], n))
    end)
end

local function OnEvent(picker, event)
    if event == "PLAYER_REGEN_DISABLED" then picker:Hide(); return end
    local over = picker:IsMouseOver() or (picker.anchor and picker.anchor:IsMouseOver())
    if not (addon.IsPublic(over) and over) then picker:Hide() end
end

function M:Picker()
    if self.picker then return self.picker end
    local picker = CreateFrame("Frame", "ModeUIBuffsDebuffsPicker", UIParent)
    picker:SetSize(WIDTH, 200); picker:SetFrameStrata("TOOLTIP"); picker:SetFrameLevel(200)
    picker:SetClampedToScreen(true); picker:EnableMouse(true); picker:Hide()
    W.Texture(picker, "Window"); W.Texture(picker, "BorderSilver", "BORDER")
    picker.title = W.Label(picker, L["Blacklist"], nil, PAD, -12, INNER - 34, T.secondary)
    picker.close = W.Button(picker, "X", 24, 24, "secondary")
    picker.close:SetPoint("TOPRIGHT", -10, -8)
    picker.close:SetScript("OnClick", function() picker:Hide() end)
    picker.hover = W.Label(picker, "", nil, PAD, -36, INNER, T.muted)
    picker.heldLabel = W.Label(picker, L["Hidden (click to show again)"], nil, PAD, -58, INNER, T.muted)
    picker.addLabel = W.Label(picker, L["On you now (click to hide)"], nil, PAD, 0, INNER, T.muted)
    picker.empty = W.Label(picker, L["No auras to show. Add one by its spell ID below."], nil, PAD, 0, INNER, T.muted)
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
        local ok, message = Target(M, picker).byId(id)
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
    Style.CropIcon(button.icon, SIZE - 2, SIZE - 2)
    button.rim = Style.Edge(button, "line", { color = Style.Tone.graphite.rim })
    button.highlight = W.Fill(button, T.primary, "OVERLAY", 0, 0.2)
    button.highlight:Hide()
    button:SetScript("OnEnter", function() button.highlight:Show(); picker.hover:SetText(button.where) end)
    button:SetScript("OnLeave", function() button.highlight:Hide(); picker.hover:SetText("") end)
    button:SetScript("OnClick", function()
        local target = Target(M, picker)
        if button.held then target.remove(button.spell) else target.add(button.spell) end
        M:RefreshPicker()
    end)
    picker.buttons[index] = button
    return button
end

-- Opens the picker under `anchor`: for the blacklist, or for bar `barId`'s
-- Spells You Add.
function M:OpenPicker(anchor, barId)
    if not self:CanConfigure() or (barId ~= nil and not self:HasBar(barId)) then return false end
    local picker = self:Picker()
    picker.anchor, picker.target = anchor, barId
    picker.title:SetText(barId and (L["Spells You Add"] .. " · " .. self:BarLabel(barId)) or L["Blacklist"])
    picker.heldLabel:SetText(barId and L["Added (click to remove)"] or L["Hidden (click to show again)"])
    picker.addLabel:SetText(barId and L["Buffs on you now (click to add)"] or L["On you now (click to hide)"])
    picker:SetScale(anchor:GetEffectiveScale() / UIParent:GetEffectiveScale())
    picker:ClearAllPoints(); picker:SetPoint("TOP", anchor, "BOTTOM", 0, -8)
    picker:Show()
    self:RefreshPicker()
    return true
end

-- Lays out the hidden spells (a Rosewood rim marks one the game may still
-- show as your debuff), then the auras on you to add, then Spell ID.
function M:RefreshPicker(keepResult)
    local picker = self.picker
    if not picker or not picker:IsShown() then return end
    local target = Target(self, picker)
    local held = target.held
    local add = {}
    for _, aura in ipairs(Auras.Spells("player")) do
        if not target.has(aura.id) and not (target.buffsOnly and aura.harmful) then add[#add + 1] = aura end
    end
    local index, top = 0, 76
    local function Grid(list, isHeld)
        for i, item in ipairs(list) do
            index = index + 1
            local button = Button(picker, index)
            local id = isHeld and item or item.id
            button.spell, button.held = id, isHeld
            button.icon:SetTexture((isHeld and Spells.SpellIcon(id)) or item.icon or Spells.SpellIcon(id) or QUESTION)
            local name = Spells.SpellName(id) or tostring(id)
            if isHeld and picker.target then
                button.rim:SetTint(nil)
                button.where = name .. " · " .. id
            elseif isHeld then
                local reach, text = self:BlacklistReach(id)
                button.rim:SetTint(reach == "all" and Style.Tone.celadon or Style.Tone.rosewood)
                button.where = name .. " · " .. id .. " · " .. text
            else
                button.rim:SetTint(nil)
                button.where = name .. " · " .. id .. " · " .. (item.harmful and L["debuff"] or L["buff"])
            end
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
    if self.page then self.page:Refresh() end
end
