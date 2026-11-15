local _, ns = ...
-- Loaded last. When ModeUI started before ModeCDM's files ran, the module
-- registered late; it starts now that every file is loaded (its settings
-- checked and migrated, then switched on or left off). When ModeUI hasn't
-- started yet, its own startup takes the module with the rest.
local addon = ns.ModeUI
if addon and addon.StartLateModules then addon:StartLateModules() end
