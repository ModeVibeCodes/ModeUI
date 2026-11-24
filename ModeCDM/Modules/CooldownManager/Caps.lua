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
