local _, ns = ...
local addon = ns.ModeUI or {}
local M = addon.CooldownManager
if not M then return end

-- What Initialize (Migrations.lua) checks after the bars: the resource bars
-- (ResourceInit.lua), the Cast Bar (CastInit.lua) and the Swing Timer
-- (SwingInit.lua), each added without a version step (a profile saved before
-- them takes their defaults); then the Bar Style (BarStyle.lua, version 12)
-- and spells' own alerts (Alerts.lua); last, every bar that follows the Bar
-- Style takes its values again. Bad data stops startup; nothing is reset.
function M.InitializeParts(db, barStyleStep, fresh)
    M.ValidateResources(db)
    M.ValidateCast(db)
    if M.ValidateSwing then M.ValidateSwing(db) end
    if barStyleStep then M.MigrateV12(db, fresh) end
    M.ValidateBarStyle(db)
    if M.ValidateAlerts then M.ValidateAlerts(db) end
    M.ApplyBarStyleAll(db)
end
