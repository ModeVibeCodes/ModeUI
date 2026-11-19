local _, addon = ...
local M = addon.Minimap
if not M or not addon.Layouts then return end

-- The minimap's part of the built-in Mode-Default layout (DPS / Tank,
-- Shared/Runtime/Layouts.lua): a square map in the top-right corner, text On
-- Map, the addon buttons in their row below it (their default place). The
-- map's `frame` edge sits outside the map (Map Border Mode: its 1px shadow
-- ring and 2px band, 3px each side), so a 224 map shows 230 wide: the same
-- as the damage meters in this layout (Modules/DamageMeters/Layouts.lua).
-- The Minimap element is the map itself, 224 x 224; the edge reaches 3
-- past it. The same at 1080 and 1440. See docs/MINIMAP.md, "Mode-Default layout".
local SIZE = 224

local function Part(db, ctx)
    db.enabled = true
    db.size, db.difference, db.border, db.textLayout = SIZE, 0, "mode", "map"
    -- The element is the map; its edge shows 3 past it, so 11 in puts what
    -- shows 8 from the top and right, like the meters' outer edge below it.
    ctx.Place(M.ELEMENT_ID, "screen", "TOPRIGHT", "TOPRIGHT", -11, -11)
end
-- The Healer layout keeps this part as it is (owner, November 19, 2026).
for _, layout in ipairs({ "mode-default", "healer" }) do addon.Layouts:Contribute(layout, "minimap", Part) end
