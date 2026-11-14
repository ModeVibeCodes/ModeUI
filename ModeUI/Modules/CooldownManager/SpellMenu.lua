local _, addon = ...
local M = addon.CooldownManager
if not M then return end

-- The preview's spell menu. Clicking an icon in the settings preview opens
-- the Spells tab and a menu to the left of the icon: that spell's switches
-- (Show in This Viewer; on Essential and Utility also Proc Glow and Glow When
-- Ready), Copy, Paste and Apply to Viewer for those switches, and a way to
-- the viewer's glow settings. It stays open while the page scrolls and
-- closes on a click anywhere else, the close button, or combat. While it's
-- open the icon previews its glow.
local W, T, L = addon.ConfigWidgets, addon.InterfaceTheme, addon.L
local Cooldowns = addon.Domain.Cooldowns
local WIDTH, PAD = 304, 14
local INNER = WIDTH - 2 * PAD

local function Check(menu, y, label, kind)
    local box = W.Button(menu, "", 24, 24, "checkbox")
    box:SetPoint("TOPLEFT", PAD, y)
    box.text = W.Label(menu, label, nil, PAD + 34, y - 4, INNER - 34, T.text)
    box:SetScript("OnClick", function()
        local viewer = M:PreviewViewer()
        local on = M:SpellSwitch(viewer, menu.key, kind)
        if kind == "hide" then M:SetSpellSwitch(viewer, menu.key, "hide", not on)
        else M:SetSpellSwitch(viewer, menu.key, kind, not on) end
        M:RefreshSpellMenu()
    end)
    box.kind = kind
    return box
end

local function Action(menu, label, width, x, y, fn)
    local button = W.Button(menu, label, width, 26, "secondary")
    button:SetPoint("TOPLEFT", x, y)
    button.menuX = x
    button:SetScript("OnClick", function() fn(M:PreviewViewer(), menu.key); M:RefreshSpellMenu() end)
    return button
end

-- A click anywhere outside the menu (and its icon) closes it.
local function OnEvent(menu, event)
    if event == "PLAYER_REGEN_DISABLED" then menu:Hide(); return end
    local over = menu:IsMouseOver() or (menu.anchor and menu.anchor:IsMouseOver())
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
    W.Label(menu, L["This Spell"], nil, PAD, -40, INNER, T.muted)
    menu.showBox = Check(menu, -58, L["Show in This Viewer"], "hide")
    menu.procBox = Check(menu, -86, L["Proc Glow"], "proc")
    menu.readyBox = Check(menu, -114, L["Glow When Ready"], "ready")
    menu.copy = Action(menu, L["Copy"], 84, PAD, 0, function(viewer, key) M:CopySpell(viewer, key) end)
    menu.paste = Action(menu, L["Paste"], 84, PAD + 88, 0, function(viewer, key) M:PasteSpell(viewer, key) end)
    menu.apply = Action(menu, L["Apply to Viewer"], INNER - 176, PAD + 176, 0, function(viewer, key) M:ApplySpellToViewer(viewer, key) end)
    menu.more = W.Button(menu, L["All Glow Settings"], INNER, 26, "secondary")
    menu.more:SetPoint("BOTTOMLEFT", PAD, 12)
    menu.more:SetScript("OnClick", function() menu:Hide(); M:JumpTo("glows") end)
    menu:SetScript("OnEvent", OnEvent)
    menu:SetScript("OnShow", function()
        for _, event in ipairs({ "GLOBAL_MOUSE_DOWN", "PLAYER_REGEN_DISABLED" }) do
            if not menu:IsEventRegistered(event) then menu:RegisterEvent(event) end
        end
    end)
    menu:SetScript("OnHide", function()
        menu:UnregisterAllEvents()
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
    local menu = self:SpellMenu()
    menu.view, menu.key, menu.anchor = view, key, anchor
    view.menuKey = key
    Place(menu, anchor)
    menu:Show()
    self:RefreshSpellMenu()
    view.Refresh()
end

-- The spell's name, else its cooldown ID.
function M:SpellLabel(key)
    local spell = Cooldowns.SpellID(tonumber(key))
    return (spell and Cooldowns.SpellName(spell)) or string.format(L["Spell %s"], key)
end

-- Buff viewers have no glows: the menu is just the Show switch and the copy row.
function M:RefreshSpellMenu()
    local menu = self.spellMenu
    if not menu or not menu:IsShown() or not menu.key then return end
    local viewer = self:PreviewViewer()
    local style, glows = self.db[viewer], not self:IsBuff(viewer)
    menu.title:SetText(self:SpellLabel(menu.key))
    menu.showBox:SetSelected(not self:SpellSwitch(viewer, menu.key, "hide"))
    menu.procBox:SetSelected(self:SpellSwitch(viewer, menu.key, "proc"))
    menu.readyBox:SetSelected(self:SpellSwitch(viewer, menu.key, "ready"))
    for _, box in ipairs({ menu.procBox, menu.readyBox }) do box:SetShown(glows); box.text:SetShown(glows) end
    -- The viewer's own switches gray out what they turn off.
    menu.procBox:SetEnabled(style.procGlow ~= "none")
    menu.readyBox:SetEnabled(style.readyGlow)
    local y = glows and -146 or -90
    for _, button in ipairs({ menu.copy, menu.paste, menu.apply }) do
        button:ClearAllPoints(); button:SetPoint("TOPLEFT", button.menuX, y)
    end
    menu.paste:SetEnabled(self.spellClipboard ~= nil)
    menu.more:SetShown(glows)
    menu:SetHeight(glows and 230 or 136)
end
