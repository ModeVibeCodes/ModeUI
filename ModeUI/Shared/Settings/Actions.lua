local _, addon = ...
local W, T = addon.ConfigWidgets, addon.InterfaceTheme

-- Copy To… and Reset… (docs/DESIGN_LANGUAGE.md, "Standard tabs"): the only
-- two actions a module page has, in the footer beside Done. Each opens a menu
-- of scopes the module declares; one scope skips the menu. Every choice asks
-- first.
--   module:ResetScopes() -> { { label, run, prompt? } }: what Reset… offers.
--     Without it, a module with ResetToDefaults offers the whole module.
--   module:CopyActions() -> { { label, run, prompt? } }: what Copy To…
--     offers; the button shows only for a module that has it.
-- run() does the change; the window refreshes after it.

-- A menu of actions under (or over) a button: one row per item.
function W.ActionMenu(button, width)
    local menu = W.Popup(button, width or 280, 40)
    W.Texture(menu, "Window")
    local rows = {}
    menu.field = button
    function menu:Open(items, pick)
        if InCombatLockdown() or UnitAffectingCombat("player") then return end
        if addon.CloseFontDropdown then addon:CloseFontDropdown() end
        local rowWidth = (width or 280) - 12
        for index, item in ipairs(items) do
            local row = rows[index]
            if not row then
                row = W.Button(self, "", rowWidth, 28, "tab"); rows[index] = row
                row:SetPoint("TOPLEFT", 6, -6 - (index - 1) * 30)
                row.label:ClearAllPoints(); row.label:SetPoint("LEFT", 10, 0); row.label:SetPoint("RIGHT", -10, 0)
                row.label:SetJustifyH("LEFT"); row.label:SetWordWrap(false)
                row:SetScript("OnClick", function() self:Hide(); self.pick(row.item) end)
            end
            row.item = item; row.label:SetText(item.label); row:SetSelected(false); row:Show()
        end
        for index = #items + 1, #rows do rows[index]:Hide() end
        self.pick = pick
        self:SetSize(width or 280, 12 + #items * 30)
        W.PlacePopup(self, button)
        self:Show()
    end
    menu:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then self:Hide(); return end
        local over = self:IsMouseOver() or self.field:IsMouseOver()
        if not (addon.IsPublic(over) and over) then self:Hide() end
    end)
    menu:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN"); self:RegisterEvent("PLAYER_REGEN_DISABLED") end)
    menu:SetScript("OnHide", function(self) self:UnregisterEvent("GLOBAL_MOUSE_DOWN"); self:UnregisterEvent("PLAYER_REGEN_DISABLED") end)
    button:HookScript("OnHide", function() menu:Hide() end)
    addon.fontDropdownMenus = addon.fontDropdownMenus or {}; addon.fontDropdownMenus[menu] = true
    button.actionMenu, menu.rows = menu, rows
    return menu
end

-- The selected module's scopes for one action ("reset" or "copy").
function addon:ConfigActionItems(kind, module)
    module = module or (self.configWindow and self.modules[self.configWindow.selectedPage])
    if not module then return {} end
    local items
    if kind == "reset" then
        items = module.ResetScopes and module:ResetScopes()
        if not items and module.ResetToDefaults then
            items = { { label = "All of " .. module.title, run = function() module:ResetToDefaults() end,
                prompt = "Put every " .. module.title .. " setting back to its default?" } }
        end
    else items = module.CopyActions and module:CopyActions() end
    return items or {}
end

-- Asks, then runs one item and refreshes the window.
function addon:RunConfigAction(kind, item)
    local verb = kind == "reset" and "Reset" or "Copy"
    W.Confirm(verb .. " " .. item.label, item.prompt or (verb .. " " .. item.label .. "?"), verb, function()
        item.run()
        self:RefreshConfig()
    end)
end

-- Opens an action's menu from its footer button (a single scope asks at once).
function addon:OpenConfigAction(kind, button)
    local items = self:ConfigActionItems(kind)
    if #items == 0 then return false end
    if #items == 1 then self:RunConfigAction(kind, items[1]); return true end
    local menu = button.actionMenu or W.ActionMenu(button, 300)
    menu:Open(items, function(item) self:RunConfigAction(kind, item) end)
    return true
end
