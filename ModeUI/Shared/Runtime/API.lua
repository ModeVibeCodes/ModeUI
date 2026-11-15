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

-- Companion addons (docs/ARCHITECTURE.md, "Companion addons"): a ModeUI
-- module shipped as an addon of its own gets ModeUI's addon table, so its
-- files run exactly as they would inside ModeUI and its settings stay in
-- ModeUIDB. The one exception to "read only" above, for the names listed
-- here only (each needs ModeUI in its ## Dependencies); anything else gets nil.
local COMPANIONS = { ModeCDM = true }
function Core.Companion(name)
    if type(name) == "string" and COMPANIONS[name] then return addon end
end
