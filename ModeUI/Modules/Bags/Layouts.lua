local _, addon = ...
local M = addon.Bags
if not M or not addon.Layouts then return end

-- Bags' part of the built-in layouts (Mode-DPS/TANK and Mode-Healer;
-- Shared/Runtime/Layouts.lua; owner, November 20, 2026): the bag window's
-- bottom-right corner on the top damage meter's top-left corner (Healing
-- Done, Modules/DamageMeters/Layouts.lua), 4 apart each way like the meters.
-- The window grows from its bottom-right corner (Grow From: Bottom Right),
-- so more bags make it taller and wider away from the meters. Both edges sit
-- inside their frames.
local GAP = 4

local function Part(db, ctx)
    db.enabled = true
    db.growFrom = "BOTTOMRIGHT"
    ctx.Place(M.ELEMENT_ID, "damageMetersWindow2", "BOTTOMRIGHT", "TOPLEFT", -GAP, GAP)
end
for _, layout in ipairs({ "mode-default", "healer" }) do addon.Layouts:Contribute(layout, "bags", Part) end
