local _, addon = ...
local M = addon.CooldownManager
if not M then return end

-- The + slot's list: the spells you track in Blizzard's Cooldown Manager that
-- the custom bar can take (Essential and Utility cooldowns for a Cooldown
-- Bar, Tracked Buffs for a Buff Bar), as a grid of their icons. Pointing at
-- one names it and says where it shows now; clicking adds it to the bar (a
-- spell on another custom bar moves). On a Cooldown Bar, Spell ID adds any
-- spell by its ID instead, tracked or not (Spells.lua). It stays open to add
-- several, and closes on a click elsewhere, the close button, or combat.
-- With nothing to add it says so and offers Open CDM.
local W, T, L, Kit = addon.ConfigWidgets, addon.InterfaceTheme, addon.L, addon.Kit
local WIDTH, PAD, SIZE, GAP, COLUMNS = 320, 14, 36, 6, 7
local INNER = WIDTH - 2 * PAD

local function OnEvent(picker, event)
    if event == "PLAYER_REGEN_DISABLED" then picker:Hide(); return end
    local over = picker:IsMouseOver() or (picker.anchor and picker.anchor:IsMouseOver())
    if not (addon.IsPublic(over) and over) then picker:Hide() end
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
    picker.hover = W.Label(picker, "", nil, PAD, -38, INNER, T.muted)
    picker.empty = W.Label(picker, L["Nothing to add: track spells in Blizzard's Cooldown Manager first."], nil, PAD, -62, INNER, T.muted)
    picker.empty:SetWordWrap(true)
    picker.cdm = W.Button(picker, L["Open CDM"], 120, 26, "secondary")
    picker.cdm:SetPoint("BOTTOMLEFT", PAD, 12)
    picker.cdm:SetScript("OnClick", function() picker:Hide(); M:OpenCooldownSettings() end)
    -- Spell ID: a field, Add, and what happened.
    picker.byId = CreateFrame("Frame", nil, picker)
    picker.byId:SetSize(INNER, 48)
    picker.idLabel = W.Label(picker.byId, L["Spell ID"], nil, 0, 0, INNER, T.muted)
    local field = CreateFrame("Frame", nil, picker.byId)
    field:SetPoint("TOPLEFT", 0, -18); field:SetSize(140, 28)
    picker.idInput = W.TextInput(field, 140, L["e.g. 12345"], 9)
    picker.idAdd = W.Button(picker.byId, L["Add"], 60, 28, "secondary")
    picker.idAdd:SetPoint("TOPLEFT", 148, -18)
    picker.idResult = W.Label(picker.byId, "", nil, 214, -24, INNER - 214, T.muted)
    local function Add()
        local ok, result = M:AddCustomSpell(picker.barId, picker.idInput:GetText())
        if ok then
            picker.idInput:SetText("")
            picker.idResult:SetText(string.format(L["Added %s."], M:SpellLabel("s" .. result)))
        else picker.idResult:SetText(result) end
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
    Kit.PlaceRim(button.rim, button, 1, 0, Kit.onyx.border, 1)
    button.highlight = W.Fill(button, T.primary, "OVERLAY", 0, 0.2)
    button.highlight:Hide()
    button:SetScript("OnEnter", function()
        button.highlight:Show()
        picker.hover:SetText(button.where)
    end)
    button:SetScript("OnLeave", function() button.highlight:Hide(); picker.hover:SetText(L["Click a spell to add it"]) end)
    button:SetScript("OnClick", function()
        if M:AddEntry(picker.barId, button.key) then M:RefreshPicker() end
    end)
    picker.buttons[index] = button
    return button
end

function M:OpenPicker(view, anchor)
    local id = self:PreviewViewer()
    if not self:IsCustom(id) then return false end
    local picker = self:Picker()
    if self.spellMenu then self.spellMenu:Hide() end
    if picker.barId ~= id then picker.idResult:SetText(""); picker.idInput:SetText("") end
    picker.barId, picker.anchor, picker.view = id, anchor, view
    picker:SetScale(anchor:GetEffectiveScale() / UIParent:GetEffectiveScale())
    picker:ClearAllPoints(); picker:SetPoint("TOP", anchor, "BOTTOM", 0, -8)
    picker:Show()
    self:RefreshPicker()
    return true
end

-- Every candidate not already on this bar; spells elsewhere say where.
function M:RefreshPicker(keepResult)
    local picker = self.picker
    if not picker or not picker:IsShown() or not self:HasBar(picker.barId) then return end
    local id = picker.barId
    local custom = self:Custom(id)
    local here = {}
    for _, key in ipairs(custom.entries) do here[key] = true end
    local list = {}
    for _, candidate in ipairs(self:Candidates(id)) do if not here[candidate.key] then list[#list + 1] = candidate end end
    picker.title:SetText(string.format(L["Add to %s"], custom.name))
    picker.hover:SetText(L["Click a spell to add it"])
    for index, candidate in ipairs(list) do
        local button = Button(picker, index)
        button.key = candidate.key
        button.icon:SetTexture(candidate.icon or 134400)
        local other = self:IsCustom(candidate.owner)
        button.icon:SetDesaturated(other)
        button.where = other and string.format(L["%s · on %s (moves here)"], candidate.name, self:Label(candidate.owner))
            or string.format(L["%s · in %s"], candidate.name, self:Label(candidate.owner))
        local column, row = (index - 1) % COLUMNS, math.floor((index - 1) / COLUMNS)
        button:ClearAllPoints(); button:SetPoint("TOPLEFT", PAD + column * (SIZE + GAP), -60 - row * (SIZE + GAP))
        button:Show()
    end
    for index = #list + 1, #picker.buttons do picker.buttons[index]:Hide() end
    picker.empty:SetShown(#list == 0)
    picker.cdm:SetEnabled(self:CanOpenCooldownSettings())
    if not keepResult then picker.idResult:SetText("") end
    local rows = math.max(1, math.ceil(#list / COLUMNS))
    local top = 60 + rows * (SIZE + GAP) + (#list == 0 and 40 or 0)
    -- Spells by ID: Cooldown Bars only.
    local byId = custom.kind == "cooldown"
    picker.byId:SetShown(byId)
    picker.byId:ClearAllPoints(); picker.byId:SetPoint("TOPLEFT", PAD, -top)
    picker:SetHeight(top + (byId and 56 or 0) + 46)
    if picker.view then picker.view.Refresh() end
end
