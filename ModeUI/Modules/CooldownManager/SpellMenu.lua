local _, addon = ...
local M = addon.CooldownManager
if not M then return end

-- The preview's spell menu. Clicking a spell in the settings preview opens
-- the Spells tab and a menu beside it: Show on This Bar, then a switch for
-- each glow the bar has (Proc, Active and Off Cooldown on cooldown icons;
-- Buff on buff icons), all off to begin with, each with a > button that
-- opens its popout (GlowPopout.lua) to set that glow's look; Copy, Paste and
-- Apply to Bar for the spell's settings; on a custom bar Earlier, Later and
-- Remove from Bar. It stays open while the page scrolls and closes on a
-- click anywhere but it, its popout and its icon, the close button, or
-- combat. While it's open the spell previews its glow.
local W, T, L = addon.ConfigWidgets, addon.InterfaceTheme, addon.L
local Cooldowns = addon.Domain.Cooldowns
local WIDTH, PAD, LINE = 304, 14, 28
local INNER = WIDTH - 2 * PAD

local function Check(menu, label, kind)
    local box = W.Button(menu, "", 24, 24, "checkbox")
    box.text = W.Label(menu, label, nil, 0, 0, INNER - 70, T.text)
    box:SetScript("OnClick", function()
        local id = M:PreviewViewer()
        M:SetSpellSwitch(id, menu.key, kind, not M:SpellSwitch(id, menu.key, kind))
        M:RefreshSpellMenu()
    end)
    box.kind = kind
    -- A glow's > opens its popout.
    if kind ~= "hide" then
        box.more = W.Button(menu, ">", 28, 24, "secondary")
        box.more:SetScript("OnClick", function() M:ToggleGlowPopout(kind, box.more) end)
    end
    return box
end

local function Action(menu, label, width, fn)
    local button = W.Button(menu, label, width, 26, "secondary")
    button:SetScript("OnClick", function() fn(M:PreviewViewer(), menu.key); M:RefreshSpellMenu() end)
    return button
end

-- A click anywhere outside the menu (and its icon) closes it.
local function OnEvent(menu, event)
    if event == "PLAYER_REGEN_DISABLED" then menu:Hide(); return end
    local popout = M.glowPopout
    local over = menu:IsMouseOver() or (menu.anchor and menu.anchor:IsMouseOver())
        or (popout and popout:IsShown() and popout:IsMouseOver())
        -- Picking a glow's color in Blizzard's color picker keeps them open.
        or (ColorPickerFrame and ColorPickerFrame:IsShown() and ColorPickerFrame:IsMouseOver())
    if not (addon.IsPublic(over) and over) then menu:Hide() end
end

function M:SpellMenu()
    if self.spellMenu then return self.spellMenu end
    local menu = CreateFrame("Frame", "ModeUICooldownSpellMenu", UIParent)
    menu:SetSize(WIDTH, 200); menu:SetFrameStrata("TOOLTIP"); menu:SetFrameLevel(200)
    menu:SetClampedToScreen(true); menu:EnableMouse(true); menu:Hide()
    W.Texture(menu, "Window"); W.Texture(menu, "BorderSilver", "BORDER")
    menu.title = W.Label(menu, "", nil, PAD, -12, INNER - 34, T.secondary)
    menu.close = W.Button(menu, "X", 24, 24, "secondary")
    menu.close:SetPoint("TOPRIGHT", -10, -8)
    menu.close:SetScript("OnClick", function() menu:Hide() end)
    menu.section = W.Label(menu, L["This Spell"], nil, PAD, -40, INNER, T.muted)
    menu.showBox = Check(menu, L["Show on This Bar"], "hide")
    menu.glowBoxes = {}
    for _, kind in ipairs(M.glowKinds) do menu.glowBoxes[kind] = Check(menu, L[M.glowLabels[kind]], kind) end
    menu.copy = Action(menu, L["Copy"], 84, function(id, key) M:CopySpell(id, key) end)
    menu.paste = Action(menu, L["Paste"], 84, function(id, key) M:PasteSpell(id, key) end)
    menu.apply = Action(menu, L["Apply to Bar"], INNER - 176, function(id, key) M:ApplySpellToViewer(id, key) end)
    menu.earlier = Action(menu, L["Earlier"], 84, function(id, key) M:MoveEntry(id, key, -1) end)
    menu.later = Action(menu, L["Later"], 84, function(id, key) M:MoveEntry(id, key, 1) end)
    menu.remove = Action(menu, L["Remove from Bar"], INNER - 176, function(id, key) M:RemoveEntry(id, key); menu:Hide() end)
    menu.more = W.Button(menu, L["Glow Defaults"], INNER, 26, "secondary")
    menu.more:SetScript("OnClick", function() menu:Hide(); M:JumpTo(M:IsBuff(M:PreviewViewer()) and "buffGlows" or "glows") end)
    menu:SetScript("OnEvent", OnEvent)
    menu:SetScript("OnShow", function()
        for _, event in ipairs({ "GLOBAL_MOUSE_DOWN", "PLAYER_REGEN_DISABLED" }) do
            if not menu:IsEventRegistered(event) then menu:RegisterEvent(event) end
        end
    end)
    menu:SetScript("OnHide", function()
        menu:UnregisterAllEvents()
        if M.glowPopout then M.glowPopout:Hide() end
        local view = menu.view
        menu.view, menu.key, menu.anchor = nil, nil, nil
        if view then view.menuKey = nil; view.Refresh() end
    end)
    self.spellMenu = menu
    return menu
end

-- To the left of the icon, level with it; the screen edge pushes it back in.
local function Place(menu, anchor)
    menu:SetScale(anchor:GetEffectiveScale() / UIParent:GetEffectiveScale())
    menu:ClearAllPoints()
    menu:SetPoint("RIGHT", anchor, "LEFT", -8, 0)
end

function M:OpenSpellMenu(view, key, anchor)
    if not key then return end
    if self.picker then self.picker:Hide() end
    local menu = self:SpellMenu()
    menu.view, menu.key, menu.anchor = view, key, anchor
    view.menuKey = key
    Place(menu, anchor)
    menu:Show()
    self:RefreshSpellMenu()
    view.Refresh()
end

-- The spell's (or item's) name, else its ID.
function M:SpellLabel(key)
    if self.IsItemEntry(key) then return self:ItemLabel(key) end
    local spell = self:SpellOf(key)
    return (spell and Cooldowns.SpellName(spell)) or string.format(L["Spell %s"], key)
end

-- Lays the menu out for the bar: its glows' switches, then the copy row,
-- then (custom bars) the order row, then the way to the glow settings.
function M:RefreshSpellMenu()
    local menu = self.spellMenu
    if not menu or not menu:IsShown() or not menu.key then return end
    local id = self:PreviewViewer()
    local style, glows = self.db[id], {}
    for _, kind in ipairs(self:Glows(id)) do glows[kind] = true end
    menu.title:SetText(self:SpellLabel(menu.key))
    -- A custom spell or item names its ID; its icon is ModeUI's own.
    local section = L["This Spell"]
    if self.IsItemEntry(menu.key) then section = string.format(L["Item · ID %s"], menu.key:sub(2))
    elseif self.IsSpellEntry(menu.key) then section = string.format(L["Custom spell · ID %s"], menu.key:sub(2)) end
    menu.section:SetText(section)
    local y = -58
    local function Line(box, shown)
        box:SetShown(shown); box.text:SetShown(shown)
        if not shown then return end
        box:ClearAllPoints(); box:SetPoint("TOPLEFT", PAD, y)
        box.text:ClearAllPoints(); box.text:SetPoint("TOPLEFT", PAD + 34, y - 4)
        y = y - LINE
    end
    Line(menu.showBox, true)
    menu.showBox:SetSelected(not self:SpellSwitch(id, menu.key, "hide"))
    for _, kind in ipairs(self.glowKinds) do
        local box = menu.glowBoxes[kind]
        local shown = glows[kind] == true
        Line(box, shown)
        box.more:SetShown(shown)
        if shown then
            box:SetSelected(self:SpellSwitch(id, menu.key, kind))
            box.more:ClearAllPoints(); box.more:SetPoint("TOPRIGHT", -PAD, y + LINE)
            box.more:SetSelected(self.glowPopout ~= nil and self.glowPopout:IsShown() and self.glowPopout.kind == kind)
        end
    end
    local function Row(buttons, shown)
        local x = PAD
        for _, button in ipairs(buttons) do
            button:SetShown(shown)
            if shown then button:ClearAllPoints(); button:SetPoint("TOPLEFT", x, y - 4); x = x + button:GetWidth() + 4 end
        end
        if shown then y = y - 34 end
    end
    Row({ menu.copy, menu.paste, menu.apply }, true)
    local custom = self:Custom(id)
    Row({ menu.earlier, menu.later, menu.remove }, custom ~= nil)
    if custom then
        local first, last = custom.entries[1] == menu.key, custom.entries[#custom.entries] == menu.key
        menu.earlier:SetEnabled(not first); menu.later:SetEnabled(not last)
    end
    menu.paste:SetEnabled(self.spellClipboard ~= nil)
    local anyGlow = next(glows) ~= nil
    menu.more:SetShown(anyGlow)
    if anyGlow then menu.more:ClearAllPoints(); menu.more:SetPoint("TOPLEFT", PAD, y - 8); y = y - 38 end
    menu:SetHeight(-y + 14)
    self:RefreshGlowPopout()
end
