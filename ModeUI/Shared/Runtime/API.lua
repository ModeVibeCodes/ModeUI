local addonName, addon = ...
-- The ModeUI-Core LibStub API (docs/ARCHITECTURE.md, "The Mode design
-- system"): how companion addons and probes reach the Mode design system and
-- the guarded game readers without copying them. Read only: a caller draws
-- with Style and reads with Domain; it never changes ModeUI's modules or
-- settings through this table.
if not LibStub then return end
local Core = LibStub:NewLibrary("ModeUI-Core", 1)
if not Core then return end

Core.addonName = addonName
-- Tokens, presets and factories (Shared/Style).
Core.Style = addon.Style
-- Secret-safe game readers (Shared/Domain).
Core.Domain = addon.Domain
Core.IsPublic = addon.IsPublic
Core.IsNumber = addon.IsNumber
Core.InCombat = addon.InCombat

-- True once ModeUI has finished loading its settings and modules.
function Core.Ready() return addon.initialized == true end
