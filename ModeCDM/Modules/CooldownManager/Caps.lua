local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M then return end

-- What the client offers, worked out once (owner, November 24, 2026: Forever
-- first, ready for a Midnight port). Features and their settings ask these,
-- never the edition's name, so a client without one simply doesn't show it.
-- Checked against Blizzard's Forever source (Gethe/wow-ui-source, forever
-- branch, 1.60.1); each still needs an in-game look.
local function Has(t, key) return type(t) == "table" and type(t[key]) == "function" end
-- Worked out at load and again when the module starts (Driver.lua).
function M.DetectCaps()
    M.caps = {
    -- Forever's own swing timer (SwingTimerDocumentation.lua): PLAYER_SWING.
    swingTimer = Has(_G.C_SwingTimer, "EnableRangeCheck"),
    -- Blizzard's per-spell alerts in its Cooldown Settings (CooldownViewerAlert.lua).
    cdmAlerts = Has(_G.C_CooldownViewer, "GetValidAlertTypes"),
    -- Weapon poisons and imbues (the Character window reads them too).
    weaponEnchants = Has(_G.C_Item, "GetWeaponEnchantInfo"),
    -- Forever's Cooldown Manager tracks items by their shared cooldown category.
    categoryCooldowns = Has(_G.C_Spell, "GetItemCooldown"),
    -- Sounds a spell's own alert can play.
    sounds = type(_G.PlaySoundFile) == "function",
}
end
M.DetectCaps()

-- /mcdm check: what this client offers, in the chat frame, for the in-game
-- checks the Forever-only features still need (owner, November 24, 2026).
local function CategoryCount(name)
    local enum = _G.Enum and _G.Enum.CooldownViewerCategory
    local cv = _G.C_CooldownViewer
    if not (enum and enum[name] ~= nil and type(cv) == "table" and type(cv.GetCooldownViewerCategorySet) == "function") then return "none" end
    local ok, set = pcall(cv.GetCooldownViewerCategorySet, enum[name], true)
    return ok and type(set) == "table" and tostring(#set) or "unknown"
end
function M:CapsReport()
    M.DetectCaps()
    local function Yes(on) return on and "yes" or "no" end
    local swing = self.swingSeen
    local lines = {
        "ModeCDM check (Forever " .. tostring(_G.WOW_PROJECT_ID) .. "):",
        "  Swing timer API: " .. Yes(self.caps.swingTimer) .. (swing and ("; last swing duration " .. (swing.public and "a plain number" or "secret or missing")) or "; no swing seen yet"),
        "  Blizzard's alert editor: " .. Yes(self.caps.cdmAlerts) .. "; Cooldown Settings window: " .. Yes(self:CanOpenCooldownSettings()),
        "  Spec-independent entries (racials, potions): " .. CategoryCount("SpecAgnosticEssential") .. " / " .. CategoryCount("SpecAgnosticTracked"),
        "  Equipment entries (trinkets): " .. CategoryCount("EquipSlotEssential") .. " / " .. CategoryCount("EquipSlotTracked"),
        "  Item category cooldowns: " .. Yes(self.caps.categoryCooldowns) .. "; weapon enchants: " .. Yes(self.caps.weaponEnchants),
        "  Action bar spell lookup (keybinds): " .. Yes(type(_G.C_ActionBar) == "table" and type(_G.C_ActionBar.FindSpellActionButtons) == "function"),
    }
    return lines
end
function M:PrintCapsReport()
    local frame = _G.DEFAULT_CHAT_FRAME
    for _, line in ipairs(self:CapsReport()) do
        if frame and frame.AddMessage then frame:AddMessage(line) else print(line) end
    end
end
