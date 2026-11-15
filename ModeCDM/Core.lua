local addonName, ns = ...
-- ModeCDM: ModeUI's Cooldown Manager as a companion addon (docs/ARCHITECTURE.md,
-- "Companion addons"). It needs ModeUI (## Dependencies) and sits under it in
-- the AddOn list (## Group). Its module files run inside ModeUI's own addon
-- table, which ModeUI-Core hands to the companions it knows by name: the
-- module uses ModeUI's Style, Domain, Kit, Edit Mode and settings widgets,
-- and keeps its settings in ModeUIDB's profiles under
-- modules.cooldownManager, exactly as when it shipped inside ModeUI. Without
-- ModeUI (or on another client) nothing here runs.
local Core = LibStub and LibStub("ModeUI-Core", true)
ns.ModeUI = Core and type(Core.Companion) == "function" and Core.Companion(addonName) or nil
