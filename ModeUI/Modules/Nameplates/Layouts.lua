local _, addon = ...
local M = addon.Nameplates
if not M or not addon.Layouts then return end

-- The nameplates' part of the built-in Mode-Default layout (DPS / Tank,
-- Shared/Runtime/Layouts.lua; owner, November 18, 2026): the module on, with
-- the owner's baseline (November 23, 2026), which is now every plate's
-- default (Init.lua): aura icons 1px apart, so neighbours share one shadow
-- pixel like every icon in the layout (an aura icon's band is inside its
-- size, only its 1px shadow ring past it). See docs/NAMEPLATES.md,
-- "Mode-Default layout".
local function Part(db)
    db.enabled = true
    for _, kind in ipairs(M.kinds) do db[kind].auraSpacing = 1 end
end
-- The Healer layout keeps this part as it is (owner, November 19, 2026).
for _, layout in ipairs({ "mode-default", "healer" }) do addon.Layouts:Contribute(layout, "nameplates", Part) end
