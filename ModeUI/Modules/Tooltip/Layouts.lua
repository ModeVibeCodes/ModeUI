local _, addon = ...
local M = addon.Tooltip
if not M or not addon.Layouts then return end

-- Tooltip's part of the built-in layouts (Mode-DPS/TANK and Mode-Healer;
-- Shared/Runtime/Layouts.lua; owner, November 20, 2026): the tooltip just
-- left of the damage meters, its bottom on the bottom meter's (Damage Done,
-- Modules/DamageMeters/Layouts.lua), 4 apart like the two meters. It grows up
-- and left from its bottom-right corner (Anchor Point: Bottom Right), so a
-- tall tooltip never covers the meters. Both edges sit inside their frames,
-- so the 4 units show as the gap.
local GAP = 4

local function Part(db, ctx)
    db.enabled = true
    db.position, db.anchorPoint = "anchor", "BOTTOMRIGHT"
    ctx.Place(M.ELEMENT_ID, "damageMetersWindow1", "BOTTOMRIGHT", "BOTTOMLEFT", -GAP, 0)
end
for _, layout in ipairs({ "mode-default", "healer" }) do addon.Layouts:Contribute(layout, "tooltip", Part) end
